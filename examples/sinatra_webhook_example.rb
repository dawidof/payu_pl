# frozen_string_literal: true

# Example Sinatra app for handling PayU webhooks
#
# To use this:
# 1. Install sinatra: gem install sinatra
# 2. Set PAYU_SECOND_KEY environment variable
# 3. Run: ruby examples/sinatra_webhook_example.rb
#
# Or integrate into your existing Sinatra app

require 'sinatra'
require 'payu_pl'
require 'json'

# Configure PayU (optional - can also use ENV['PAYU_SECOND_KEY'])
PayuPl.configure do |config|
  config.second_key = ENV['PAYU_SECOND_KEY']
end

# PayU webhook endpoint
post '/webhooks/payu' do
  # Validate webhook signature and parse payload
  result = PayuPl::Webhooks::Validator.new(request).validate_and_parse
  
  if result.failure?
    logger.error("PayU webhook validation failed: #{result.error}")
    status 400
    return
  end

  # Extract webhook data
  payload = result.data
  order_id = payload.dig('order', 'orderId')
  status_value = payload.dig('order', 'status')
  
  logger.info("PayU webhook - Order: #{order_id}, Status: #{status_value}")
  
  # Process the webhook
  # Your business logic here...
  
  status 200
end

# Health check endpoint
get '/health' do
  content_type :json
  { status: 'ok' }.to_json
end

# Start the server (for standalone usage)
if __FILE__ == $0
  set :port, 4567
  set :bind, '0.0.0.0'
  
  puts "PayU webhook listener starting on http://0.0.0.0:4567"
  puts "Webhook endpoint: POST /webhooks/payu"
end
