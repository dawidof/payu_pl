# frozen_string_literal: true

require "dry/validation"

module PayuPl
  module Contracts
    class RefundCreateContract < Dry::Validation::Contract
      params do
        required(:order_id).filled(:string)
        required(:description).filled(:string)
        optional(:amount).maybe(:string)
        optional(:ext_refund_id).maybe(:string)
      end

      rule(:amount) do
        next if value.nil?

        amount_string = value.to_s
        key.failure(PayuPl.t(:numeric_string)) unless amount_string.match?(/\A\d+\z/)
      end

      rule(:ext_refund_id) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 1024)) if value.length > 1024
      end

      rule(:description) do
        key.failure(PayuPl.t(:max_length, max: 4000)) if value.length > 4000
      end
    end
  end
end
