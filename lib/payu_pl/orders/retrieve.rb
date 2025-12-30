# frozen_string_literal: true

module PayuPl
  module Orders
    class Retrieve < Operations::Base
      def call(order_id)
        validate_id!(order_id, input_key: :order_id)
        transport.request(:get, Endpoints.order(order_id))
      end
    end
  end
end
