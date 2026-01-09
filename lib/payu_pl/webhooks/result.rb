# frozen_string_literal: true

module PayuPl
  module Webhooks
    # Result class for webhook validation responses
    # Provides a consistent interface for success and failure cases
    class Result
      attr_reader :data, :error

      def initialize(data = nil, error = nil)
        @data = data
        @error = error
      end

      def self.success(data)
        new(data, nil)
      end

      def self.failure(error)
        new(nil, error)
      end

      def success?
        error.nil?
      end

      def failure?
        !success?
      end
    end
  end
end
