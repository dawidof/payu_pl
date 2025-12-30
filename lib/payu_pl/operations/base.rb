# frozen_string_literal: true

require "uri"
require "dry-initializer"

module PayuPl
  module Operations
    class Base
      extend Dry::Initializer

      option :client

      private

      def transport
        client.transport
      end

      def escape_path(segment)
        URI.encode_www_form_component(segment.to_s)
      end

      def validate_contract!(contract_class, params, input: params)
        result = contract_class.new.call(params)
        return if result.success?

        raise ValidationError.new(errors: result.errors.to_h, input: input)
      end

      def validate_id!(value, input_key: :id)
        result = Contracts::IdContract.new.call(id: value.to_s)
        return if result.success?

        raise ValidationError.new(
          errors: { input_key => result.errors.to_h[:id] }.compact,
          input: { input_key => value }
        )
      end

      def validate_ids!(**ids)
        id_contract = Contracts::IdContract.new
        errors = {}

        ids.each do |key, value|
          res = id_contract.call(id: value.to_s)
          errors[key] = res.errors.to_h[:id] unless res.success?
        end

        return if errors.empty?

        raise ValidationError.new(errors: errors, input: ids)
      end
    end
  end
end
