# frozen_string_literal: true

module PayuPl
  module Orders
    class Capture < Operations::Base
      def call(order_id, amount: nil, currency_code: nil)
        params = {
          order_id: order_id.to_s,
          amount: amount,
          currency_code: currency_code
        }
        validate_contract!(Contracts::CaptureContract, params, input: params)

        path = Endpoints.order_captures(order_id)

        if amount.nil? && currency_code.nil?
          transport.request(:post, path, json: nil)
        else
          payload = {
            amount: amount,
            currencyCode: currency_code
          }.compact
          transport.request(:post, path, json: payload)
        end
      end
    end
  end
end
