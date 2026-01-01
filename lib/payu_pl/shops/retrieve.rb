# frozen_string_literal: true

module PayuPl
  module Shops
    class Retrieve < Operations::Base
      def call(shop_id)
        validate_id!(shop_id, input_key: :shop_id)
        transport.request(:get, Endpoints.shop(shop_id))
      end
    end
  end
end
