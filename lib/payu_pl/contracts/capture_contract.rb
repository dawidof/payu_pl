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
        amount_raw = values[:amount]
        currency_raw = values[:currency_code]

        amount = amount_raw.is_a?(String) ? amount_raw.strip : amount_raw
        currency_code = currency_raw.is_a?(String) ? currency_raw.strip : currency_raw

        amount_present = !(amount.nil? || (amount.respond_to?(:empty?) && amount.empty?))
        currency_present = !(currency_code.nil? || (currency_code.respond_to?(:empty?) && currency_code.empty?))

        next if !amount_present && !currency_present

        key(:amount).failure(PayuPl.t(:required_with_currency_code)) if currency_present && !amount_present
        key(:currency_code).failure(PayuPl.t(:required_with_amount)) if amount_present && !currency_present

        key(:currency_code).failure(PayuPl.t(:iso_4217)) if currency_present && !currency_code.match?(/\A[A-Z]{3}\z/)

        key(:amount).failure(PayuPl.t(:numeric_string)) if amount_present && !amount.to_s.match?(/\A\d+\z/)
      end
    end
  end
end
