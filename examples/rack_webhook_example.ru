# frozen_string_literal: true

# Example Rack app for handling PayU webhooks
#
# This shows how to use the webhook validator in a plain Rack application
#
# To use this:
# 1. Set PAYU_SECOND_KEY environment variable
# 2. Run with: rackup examples/rack_webhook_example.ru
#
# Or integrate the middleware into your existing Rack app

require "payu_pl"
require "json"

class PayuWebhookApp
  def call(env)
    request = Rack::Request.new(env)

    # Only handle POST to /webhooks/payu
    return [404, { "Content-Type" => "text/plain" }, ["Not Found"]] unless request.post? && request.path == "/webhooks/payu"

    # Validate webhook signature and parse payload
    validator = PayuPl::Webhooks::Validator.new(request)
    result = validator.validate_and_parse

    if result.failure?
      puts "ERROR: PayU webhook validation failed: #{result.error}"
      return [400, { "Content-Type" => "text/plain" }, ["Bad Request"]]
    end

    # Extract webhook data
    payload = result.data
    order_id = payload.dig("order", "orderId")
    status = payload.dig("order", "status")

    puts "INFO: PayU webhook received - Order: #{order_id}, Status: #{status}"

    # Process the webhook
    # Your business logic here...

    [200, { "Content-Type" => "text/plain" }, ["OK"]]
  rescue StandardError => e
    puts "ERROR: PayU webhook processing error: #{e.class} - #{e.message}"
    [500, { "Content-Type" => "text/plain" }, ["Internal Server Error"]]
  end
end

# Optional: Add logging middleware
class LoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    puts "#{Time.now} - #{request.request_method} #{request.path}"
    @app.call(env)
  end
end

# Build the Rack app
use LoggingMiddleware
run PayuWebhookApp.new
