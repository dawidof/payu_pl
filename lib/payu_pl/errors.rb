# frozen_string_literal: true

module PayuPl
  class Error < StandardError; end

  class ValidationError < Error
    attr_reader :errors, :input

    def initialize(errors:, input: nil, message: "Validation failed")
      super(message)
      @errors = errors
      @input = input
    end
  end

  class NetworkError < Error
    attr_reader :original

    def initialize(message = "Network error", original: nil)
      super(message)
      @original = original
    end
  end

  class ResponseError < Error
    attr_reader :http_status, :correlation_id, :raw_body, :parsed_body

    def initialize(message, http_status:, correlation_id: nil, raw_body: nil, parsed_body: nil)
      super(message)
      @http_status = http_status
      @correlation_id = correlation_id
      @raw_body = raw_body
      @parsed_body = parsed_body
    end
  end

  class ClientError < ResponseError; end
  class UnauthorizedError < ClientError; end
  class ForbiddenError < ClientError; end
  class NotFoundError < ClientError; end
  class RateLimitedError < ClientError; end

  class ServerError < ResponseError; end
end
