# frozen_string_literal: true

module PayuPl
  module Payouts
    class Retrieve < Operations::Base
      def call(payout_id)
        validate_id!(payout_id, input_key: :payout_id)
        transport.request(:get, Endpoints.payout(payout_id))
      end
    end
  end
end
