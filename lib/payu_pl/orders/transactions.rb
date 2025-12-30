# frozen_string_literal: true

module PayuPl
  module Orders
    class Transactions < Operations::Base
      def call(order_id)
        validate_id!(order_id, input_key: :order_id)
        transport.request(:get, Endpoints.order_transactions(order_id))
      end
    end
  end
end
