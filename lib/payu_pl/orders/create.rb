# frozen_string_literal: true

module PayuPl
  module Orders
    class Create < Operations::Base
      def call(order_create_request)
        validate_contract!(Contracts::OrderCreateContract, order_create_request, input: order_create_request)

        # Do NOT use result.to_h here: dry-schema would drop unknown keys, and PayU supports many optional fields.
        transport.request(:post, Endpoints::ORDERS, json: order_create_request)
      end
    end
  end
end
