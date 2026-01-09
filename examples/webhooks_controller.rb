# frozen_string_literal: true

# Example Rails controller for handling PayU webhooks
#
# To use this in your Rails app:
# 1. Copy this file to app/controllers/webhooks/payu_controller.rb
# 2. Add route: post '/webhooks/payu', to: 'webhooks/payu#create'
# 3. Configure PayU second_key in config/initializers/payu.rb
#
# Note: This is just an example. Adjust to your application's needs.

module Webhooks
  class PayuController < ApplicationController
    # Skip CSRF token verification for webhooks
    skip_before_action :verify_authenticity_token

    def create
      # Validate webhook signature and parse payload
      result = PayuPl::Webhooks::Validator.new(request, logger: Rails.logger).validate_and_parse

      if result.failure?
        Rails.logger.error("PayU webhook validation failed: #{result.error}")
        return head :bad_request
      end

      # Extract webhook data
      payload = result.data
      order_id = payload.dig("order", "orderId")
      status = payload.dig("order", "status")
      payload["eventId"] || "#{order_id}_#{status}"

      # Format amount (PayU sends in minor units: 2900 = 29.00 PLN)
      total_amount = payload.dig("order", "totalAmount").to_i
      currency = payload.dig("order", "currencyCode")
      formatted_amount = format("%.2f", total_amount / 100.0)

      Rails.logger.info("PayU webhook received - Order: #{order_id}, Status: #{status}")
      Rails.logger.info("Amount: #{formatted_amount} #{currency}")

      # Optional: Log PayU processing time for monitoring
      Rails.logger.info("PayU processing time: #{request.headers["PayU-Processing-Time"]}ms") if request.headers["PayU-Processing-Time"]

      # Check for duplicate events (optional but recommended)
      # You'll need a WebhookEvent model or similar to track processed events
      # if WebhookEvent.exists?(provider: 'payu', event_id: event_id)
      #   Rails.logger.warn("Duplicate PayU webhook event: #{event_id}")
      #   return head :ok
      # end

      # Store the webhook event (optional)
      # WebhookEvent.create!(
      #   provider: 'payu',
      #   event_id: event_id,
      #   event_type: status,
      #   payload: payload
      # )

      # Process the webhook asynchronously (recommended)
      # PayuWebhookJob.perform_async(order_id, status, payload)

      # Or process synchronously (not recommended for production)
      # process_webhook(order_id, status, payload)

      head :ok
    rescue StandardError => e
      # Log unexpected errors
      Rails.logger.error("PayU webhook processing error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))

      # Return 500 so PayU will retry
      head :internal_server_error
    end

    private

    def process_webhook(order_id, status, _payload)
      # Your business logic here
      # For example:
      # - Update order status in your database
      # - Send confirmation emails
      # - Trigger fulfillment processes
      # - etc.

      case status
      when "PENDING"
        Rails.logger.info("Order #{order_id} is pending payment")
      when "WAITING_FOR_CONFIRMATION"
        Rails.logger.info("Order #{order_id} is waiting for manual capture")
        # This status appears when auto-receive is disabled
        # You need to manually capture or cancel the order
      when "COMPLETED"
        Rails.logger.info("Order #{order_id} completed successfully")
        # Update your order status, trigger fulfillment, etc.
      when "CANCELED"
        Rails.logger.info("Order #{order_id} was canceled")
        # Handle cancellation
      else
        Rails.logger.warn("Unknown status #{status} for order #{order_id}")
      end
    end
  end
end
