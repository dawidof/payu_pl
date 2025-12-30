# frozen_string_literal: true

module PayuPl
  module Refunds
    class Create < Operations::Base
      def call(order_id, description:, amount: nil, ext_refund_id: nil)
        params = {
          order_id: order_id.to_s,
          description: description,
          amount: amount,
          ext_refund_id: ext_refund_id
        }
        validate_contract!(Contracts::RefundCreateContract, params, input: params)

        refund = {
          description: description,
          amount: amount,
          extRefundId: ext_refund_id
        }.compact

        transport.request(
          :post,
          Endpoints.order_refunds(order_id),
          json: { refund: refund }
        )
      end
    end
  end
end
