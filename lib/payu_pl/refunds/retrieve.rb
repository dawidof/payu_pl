# frozen_string_literal: true

module PayuPl
  module Refunds
    class Retrieve < Operations::Base
      def call(order_id, refund_id)
        validate_ids!(order_id: order_id, refund_id: refund_id)
        transport.request(:get, Endpoints.order_refund(order_id, refund_id))
      end
    end
  end
end
