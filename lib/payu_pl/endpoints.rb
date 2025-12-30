# frozen_string_literal: true

require "uri"

module PayuPl
  module Endpoints
    OAUTH_TOKEN = "/pl/standard/user/oauth/authorize"

    ORDERS = "/api/v2_1/orders"

    def self.order(order_id)
      "#{ORDERS}/#{URI.encode_www_form_component(order_id.to_s)}"
    end

    def self.order_captures(order_id)
      "#{order(order_id)}/captures"
    end

    def self.order_transactions(order_id)
      "#{order(order_id)}/transactions"
    end

    def self.order_refunds(order_id)
      "#{order(order_id)}/refunds"
    end

    def self.order_refund(order_id, refund_id)
      "#{order_refunds(order_id)}/#{URI.encode_www_form_component(refund_id.to_s)}"
    end
  end
end
