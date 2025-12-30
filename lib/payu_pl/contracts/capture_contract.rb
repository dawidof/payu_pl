# frozen_string_literal: true

require "dry/validation"

module PayuPl
  module Contracts
    class CaptureContract < Dry::Validation::Contract
      params do
        required(:order_id).filled(:string)
        optional(:amount).maybe(:string)
        optional(:currency_code).maybe(:string)
      end

      rule(:amount, :currency_code) do
        amount = values[:amount]
        currency_code = values[:currency_code]

        next if amount.nil? && currency_code.nil?

        key(:amount).failure(PayuPl.t(:required_with_currency_code)) if amount.nil? || (amount.respond_to?(:empty?) && amount.empty?)

        if currency_code.nil? || currency_code.to_s.empty?
          key(:currency_code).failure(PayuPl.t(:required_with_amount))
        elsif !currency_code.match?(/\A[A-Z]{3}\z/)
          key(:currency_code).failure(PayuPl.t(:iso_4217))
        end

        amount_string = amount.to_s
        key(:amount).failure(PayuPl.t(:numeric_string)) unless amount_string.match?(/\A\d+\z/)
      end
    end
  end
end
