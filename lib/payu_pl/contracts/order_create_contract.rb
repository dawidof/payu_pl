# frozen_string_literal: true

require "dry/validation"

module PayuPl
  module Contracts
    class OrderCreateContract < Dry::Validation::Contract
      IPV4_SEGMENT = "(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)"
      IPV4_REGEX = /\A#{IPV4_SEGMENT}(?:\.#{IPV4_SEGMENT}){3}\z/.freeze
      # Simplified IPv6 pattern; API accepts full IPv6 variants.
      IPV6_REGEX = /\A[0-9a-fA-F:]+\z/.freeze

      params do
        optional(:continueUrl).filled(:string)
        optional(:notifyUrl).filled(:string)

        required(:customerIp).filled(:string)
        required(:merchantPosId).filled(:string)
        required(:description).filled(:string)

        optional(:additionalDescription).filled(:string)
        optional(:visibleDescription).filled(:string)
        optional(:statementDescription).filled(:string)
        optional(:extOrderId).filled(:string)

        required(:currencyCode).filled(:string)
        required(:totalAmount).filled(:string)

        required(:products).array(:hash) do
          required(:name).filled(:string)
          required(:unitPrice).filled(:string)
          required(:quantity).filled(:string)
        end
      end

      rule(:continueUrl) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 1024)) if value.length > 1024
      end

      rule(:notifyUrl) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 1024)) if value.length > 1024
      end

      rule(:customerIp) do
        ip = value

        key.failure(PayuPl.t(:ip_address)) unless IPV4_REGEX.match?(ip) || IPV6_REGEX.match?(ip)
      end

      rule(:description) do
        key.failure(PayuPl.t(:max_length, max: 4000)) if value.length > 4000
      end

      rule(:additionalDescription) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 1024)) if value.length > 1024
      end

      rule(:visibleDescription) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 80)) if value.length > 80
      end

      rule(:statementDescription) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 22)) if value.length > 22
      end

      rule(:extOrderId) do
        next if value.nil?

        key.failure(PayuPl.t(:max_length, max: 1024)) if value.length > 1024
      end

      rule(:currencyCode) do
        code = value
        key.failure(PayuPl.t(:iso_4217)) unless code.match?(/\A[A-Z]{3}\z/)
      end

      rule(:totalAmount) do
        # API uses a string containing minor units
        key.failure(PayuPl.t(:numeric_string)) unless value.match?(/\A\d+\z/)
      end

      rule(:products) do
        key.failure(PayuPl.t(:min_items, min: 1)) if value.nil? || value.empty?
      end

      rule(:products).each do
        unit_price = value[:unitPrice]
        quantity = value[:quantity]

        key(:unitPrice).failure(PayuPl.t(:numeric_string)) if unit_price && !unit_price.match?(/\A\d+\z/)

        key(:quantity).failure(PayuPl.t(:numeric_string)) if quantity && !quantity.match?(/\A\d+\z/)
      end
    end
  end
end
