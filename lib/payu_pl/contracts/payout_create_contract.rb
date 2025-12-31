# frozen_string_literal: true

require "dry/validation"

module PayuPl
  module Contracts
    class PayoutCreateContract < Dry::Validation::Contract
      params do
        required(:payload).filled
      end

      rule(:payload) do
        val = value

        unless val.is_a?(Hash)
          key.failure(PayuPl.t(:hash))
          next
        end

        key.failure(PayuPl.t(:min_items, min: 1)) if val.empty?
      end
    end
  end
end
