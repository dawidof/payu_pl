# frozen_string_literal: true

module PayuPl
  module Payouts
    class Create < Operations::Base
      def call(payout_request)
        validate_contract!(Contracts::PayoutCreateContract, { payload: payout_request }, input: payout_request)

        # Do NOT use result.to_h here: dry-schema would drop unknown keys, and PayU supports multiple payout schemas.
        transport.request(:post, Endpoints::PAYOUTS, json: payout_request)
      end
    end
  end
end
