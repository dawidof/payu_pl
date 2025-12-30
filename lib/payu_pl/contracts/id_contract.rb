# frozen_string_literal: true

require "dry/validation"

module PayuPl
  module Contracts
    class IdContract < Dry::Validation::Contract
      params do
        required(:id).filled(:string)
      end
    end
  end
end
