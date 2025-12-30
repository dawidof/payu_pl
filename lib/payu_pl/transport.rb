# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module PayuPl
  class Transport
    def initialize(base_url:, access_token_provider:, open_timeout: 10, read_timeout: 30)
      @base_url = base_url
      @access_token_provider = access_token_provider
      @open_timeout = open_timeout
      @read_timeout = read_timeout

      validate!
    end

    def request(method, path, headers: {}, json: :__no_json_argument_given, form: nil, authorize: true)
      uri = URI.join(@base_url, path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      request_klass = case method.to_s.downcase
                      when "get" then Net::HTTP::Get
                      when "post" then Net::HTTP::Post
                      when "put" then Net::HTTP::Put
                      when "delete" then Net::HTTP::Delete
                      else
                        raise ArgumentError, "Unsupported HTTP method: #{method.inspect}"
                      end

      req = request_klass.new(uri)
      req["Accept"] = "application/json"

      if authorize
        token = @access_token_provider.call
        raise ArgumentError, "access_token is required for this request (call oauth_token first or pass access_token:)" if token.nil? || token.to_s.empty?

        req["Authorization"] = "Bearer #{token}"
      end

      headers.each { |k, v| req[k] = v }

      if method.to_s.downcase == "get"
        # PayU rejects GET with a body (HTTP 403) per RFC 9110 note in docs
        raise ArgumentError, "GET requests must not include a JSON body" if json != :__no_json_argument_given && !json.nil?
        raise ArgumentError, "GET requests must not include a form body" if form
      end

      if form
        req["Content-Type"] ||= "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(form)
      elsif json != :__no_json_argument_given
        # json:nil means explicit empty body for endpoints that accept it
        req["Content-Type"] ||= "application/json"
        req.body = json.nil? ? nil : JSON.generate(json)
      end

      begin
        res = http.request(req)
      rescue Timeout::Error, Errno::ETIMEDOUT => e
        raise NetworkError.new("Request timed out", original: e)
      rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, EOFError => e
        raise NetworkError.new("Network failure", original: e)
      end

      handle_response(res)
    end

    private

    def validate!
      uri = URI.parse(@base_url)
      raise ArgumentError, "base_url must be http(s)" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      raise ArgumentError, "base_url is invalid"
    end

    def handle_response(res)
      http_status = res.code.to_i
      correlation_id = res["Correlation-Id"] || res["correlation-id"]
      raw_body = res.body
      parsed = parse_body(res)

      return parsed if http_status >= 200 && http_status < 400

      message = build_error_message(http_status, parsed, raw_body)

      error_class = case http_status
                    when 401 then UnauthorizedError
                    when 403 then ForbiddenError
                    when 404 then NotFoundError
                    when 429 then RateLimitedError
                    when 400..499 then ClientError
                    else
                      ServerError
                    end

      raise error_class.new(
        message,
        http_status: http_status,
        correlation_id: correlation_id,
        raw_body: raw_body,
        parsed_body: parsed
      )
    end

    def parse_body(res)
      body = res.body
      return nil if body.nil? || body.empty?

      content_type = res["Content-Type"].to_s
      if content_type.include?("application/json") || body.lstrip.start_with?("{", "[")
        JSON.parse(body)
      else
        body
      end
    rescue JSON::ParserError
      body
    end

    def build_error_message(http_status, parsed, raw_body)
      status_desc = nil
      status_code = nil

      if parsed.is_a?(Hash) && parsed["status"].is_a?(Hash)
        status_code = parsed.dig("status", "statusCode")
        status_desc = parsed.dig("status", "statusDesc")
      end

      parts = ["HTTP #{http_status}"]
      parts << status_code if status_code
      parts << status_desc if status_desc

      if parts.length == 1
        preview = raw_body.to_s.strip
        preview = "#{preview[0, 300]}…" if preview.length > 300
        parts << preview unless preview.empty?
      end

      parts.compact.join(" - ")
    end
  end
end
