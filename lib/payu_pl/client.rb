# frozen_string_literal: true

require "uri"

module PayuPl
  class Client
    DEFAULT_PRODUCTION_BASE_URL = "https://secure.payu.com"
    DEFAULT_SANDBOX_BASE_URL = "https://secure.snd.payu.com"

    attr_reader :base_url, :client_id, :client_secret, :transport
    attr_accessor :access_token

    def initialize(
      client_id:,
      client_secret:,
      access_token: nil,
      base_url: nil,
      environment: :production,
      open_timeout: 10,
      read_timeout: 30
    )
      @client_id = client_id
      @client_secret = client_secret
      @access_token = access_token

      @base_url = base_url || default_base_url_for(environment)
      validate!

      @transport = Transport.new(
        base_url: @base_url,
        access_token_provider: -> { @access_token },
        open_timeout: open_timeout,
        read_timeout: read_timeout
      )
    end

    # OAuth
    def oauth_token(grant_type: "client_credentials")
      Authorize::OAuthToken.new(client: self).call(grant_type: grant_type)
    end

    # Orders
    def create_order(order_create_request)
      Orders::Create.new(client: self).call(order_create_request)
    end

    def retrieve_order(order_id)
      Orders::Retrieve.new(client: self).call(order_id)
    end

    def capture_order(order_id, amount: nil, currency_code: nil)
      Orders::Capture.new(client: self).call(order_id, amount: amount, currency_code: currency_code)
    end

    def cancel_order(order_id)
      Orders::Cancel.new(client: self).call(order_id)
    end

    def retrieve_transactions(order_id)
      Orders::Transactions.new(client: self).call(order_id)
    end

    # Refunds
    def create_refund(order_id, description:, amount: nil, ext_refund_id: nil)
      Refunds::Create.new(client: self).call(order_id, description: description, amount: amount, ext_refund_id: ext_refund_id)
    end

    def list_refunds(order_id)
      Refunds::List.new(client: self).call(order_id)
    end

    def retrieve_refund(order_id, refund_id)
      Refunds::Retrieve.new(client: self).call(order_id, refund_id)
    end

    private

    def validate!
      raise ArgumentError, "client_id is required" if client_id.nil? || client_id.to_s.empty?
      raise ArgumentError, "client_secret is required" if client_secret.nil? || client_secret.to_s.empty?

      uri = URI.parse(base_url)
      raise ArgumentError, "base_url must be http(s)" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      raise ArgumentError, "base_url is invalid"
    end

    def default_base_url_for(environment)
      case environment&.to_sym
      when :production
        DEFAULT_PRODUCTION_BASE_URL
      when :sandbox
        DEFAULT_SANDBOX_BASE_URL
      else
        raise ArgumentError, "Unknown environment: #{environment.inspect} (use :production or :sandbox)"
      end
    end
  end
end
