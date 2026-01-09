# frozen_string_literal: true

require "digest"
require "openssl"
require "json"

module PayuPl
  module Webhooks
    # Validates PayU webhook signatures and parses payloads
    #
    # @example Basic usage in Rails controller
    #   result = PayuPl::Webhooks::Validator.new(request).validate_and_parse
    #   if result.success?
    #     payload = result.data
    #     # Process payload...
    #   else
    #     # Handle error: result.error
    #   end
    #
    # @example With custom secret key
    #   validator = PayuPl::Webhooks::Validator.new(request, second_key: 'custom_secret')
    #   result = validator.validate_and_parse
    #
    # @example With custom logger
    #   validator = PayuPl::Webhooks::Validator.new(request, logger: Logger.new(STDOUT))
    #   result = validator.validate_and_parse
    class Validator
      attr_reader :request, :logger, :second_key

      # Initialize a new webhook validator
      #
      # @param request [Rack::Request, ActionDispatch::Request] The request object
      # @param second_key [String, nil] The PayU second key for signature verification
      #   Defaults to PayuPl.configuration.second_key or ENV['PAYU_SECOND_KEY']
      # @param logger [Logger, nil] Optional logger for debugging
      def initialize(request, second_key: nil, logger: nil)
        @request = request
        @second_key = second_key || fetch_second_key
        @logger = logger
      end

      # Validates the webhook signature and parses the payload
      #
      # @return [PayuPl::Webhooks::Result] Result object with data or error
      def validate_and_parse
        log_header

        begin
          verify_signature!
          log_signature_passed

          payload = parse_payload
          log_payload_parsed(payload)

          Result.success(payload)
        rescue StandardError => e
          log_error(e)
          Result.failure(e.message)
        ensure
          log_footer
        end
      end

      # Validates only the signature without parsing the payload
      #
      # @return [Boolean] true if signature is valid
      # @raise [RuntimeError] if signature is invalid or missing
      # rubocop:disable Naming/PredicateMethod
      def verify_signature!
        header = request.env["HTTP_OPENPAYU_SIGNATURE"]
        raise "Missing OpenPayU signature header" unless header

        log_signature_header(header)

        signature_parts = parse_signature_header(header)
        incoming_signature = signature_parts["signature"]
        algorithm = (signature_parts["algorithm"] || "SHA256").downcase

        body = read_body

        expected_signature = compute_expected_signature(algorithm, body)

        log_signature_comparison(algorithm, incoming_signature, expected_signature)

        # For MD5, PayU might use either body+key or key+body
        # Try both approaches
        if algorithm == "md5"
          alternative_signature = Digest::MD5.hexdigest(second_key + body)

          unless secure_compare(expected_signature, incoming_signature) ||
                 secure_compare(alternative_signature, incoming_signature)
            raise "Signature verification failed for algorithm #{algorithm}"
          end
        else
          raise "Signature verification failed for algorithm #{algorithm}" unless secure_compare(expected_signature, incoming_signature)
        end

        true
      end
      # rubocop:enable Naming/PredicateMethod

      # Parses the webhook payload
      #
      # @return [Hash] The parsed JSON payload
      def parse_payload
        raw_payload = read_body
        log_raw_payload(raw_payload)
        JSON.parse(raw_payload)
      end

      private

      def fetch_second_key
        if PayuPl.config.second_key
          PayuPl.config.second_key
        elsif ENV["PAYU_SECOND_KEY"]
          ENV["PAYU_SECOND_KEY"]
        else
          raise KeyError, "PayU second_key not configured. Set it via PayuPl.configure or ENV['PAYU_SECOND_KEY']"
        end
      end

      def parse_signature_header(header)
        header.split(";").to_h { |part| part.split("=", 2) }
      end

      def read_body
        body = request.body.read
        request.body.rewind
        body
      end

      def compute_expected_signature(algorithm, body)
        case algorithm
        when "md5"
          # PayU uses MD5(body + key) or MD5(key + body)
          first_attempt = Digest::MD5.hexdigest(body + second_key)
          log_debug("MD5(body+key): #{first_attempt}")

          first_attempt
        when "sha", "sha1"
          OpenSSL::HMAC.hexdigest("sha1", second_key, body)
        when "sha256"
          OpenSSL::HMAC.hexdigest("sha256", second_key, body)
        when "sha384"
          OpenSSL::HMAC.hexdigest("sha384", second_key, body)
        when "sha512"
          OpenSSL::HMAC.hexdigest("sha512", second_key, body)
        else
          # Default to the algorithm provided
          OpenSSL::HMAC.hexdigest(algorithm, second_key, body)
        end
      end

      # Constant-time string comparison to prevent timing attacks
      # rubocop:disable Naming/MethodParameterName
      def secure_compare(a, b)
        return false if a.nil? || b.nil? || a.bytesize != b.bytesize

        # Use Rack's secure_compare if available
        if defined?(Rack::Utils) && Rack::Utils.respond_to?(:secure_compare)
          Rack::Utils.secure_compare(a, b)
        else
          # Fallback implementation
          l = a.unpack("C*")
          r = 0
          b.each_byte { |byte| r |= byte ^ l.shift }
          r.zero?
        end
      end
      # rubocop:enable Naming/MethodParameterName

      # Logging methods
      def log_header
        return unless logger

        logger.info("=" * 80)
        logger.info("PayU Webhook Validation Started")
        logger.info("=" * 80)
        logger.info("Remote IP: #{request.ip}") if request.respond_to?(:ip)
        logger.info("Method: #{request.request_method}") if request.respond_to?(:request_method)
        logger.info("Path: #{request.path}") if request.respond_to?(:path)
      end

      def log_signature_header(header)
        logger&.info("Signature Header: #{header}")
      end

      def log_signature_comparison(algorithm, incoming, expected)
        return unless logger

        logger.info("Algorithm: #{algorithm}")
        logger.info("Incoming Signature: #{incoming}")
        logger.info("Expected Signature: #{expected}")
        logger.info("Match: #{incoming == expected}")
      end

      def log_signature_passed
        logger&.info("✓ Signature verification passed")
      end

      def log_raw_payload(payload)
        logger&.debug("Raw Payload: #{payload}")
      end

      def log_payload_parsed(payload)
        return unless logger

        logger.info("✓ Payload parsed successfully")
        logger.info("Order ID: #{payload.dig("order", "orderId")}")
        logger.info("Status: #{payload.dig("order", "status")}")

        # Format amount (PayU sends in minor units: 2900 = 29.00 PLN)
        total_amount = payload.dig("order", "totalAmount")
        currency = payload.dig("order", "currencyCode")
        return unless total_amount

        formatted_amount = format("%.2f", total_amount.to_i / 100.0)
        logger.info("Amount: #{formatted_amount} #{currency}")
      end

      def log_error(error)
        return unless logger

        logger.error("✗ Error: #{error.class} - #{error.message}")
        logger.error("Backtrace: #{error.backtrace.first(5).join("\n")}") if error.backtrace
      end

      def log_footer
        logger&.info("=" * 80)
      end

      def log_debug(message)
        logger&.debug(message)
      end
    end
  end
end
