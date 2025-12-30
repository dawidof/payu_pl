# frozen_string_literal: true

module PayuPl
  module Orders
    class Cancel < Operations::Base
      def call(order_id)
        validate_id!(order_id, input_key: :order_id)
        transport.request(:delete, Endpoints.order(order_id), json: nil)
      end
    end
  end
end
