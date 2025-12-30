# frozen_string_literal: true

module PayuPl
  module Authorize
    class OAuthToken < Operations::Base
      def call(grant_type: "client_credentials")
        form = {
          grant_type: grant_type,
          client_id: client.client_id,
          client_secret: client.client_secret
        }

        response = transport.request(
          :post,
          Endpoints::OAUTH_TOKEN,
          headers: { "Content-Type" => "application/x-www-form-urlencoded" },
          form: form,
          authorize: false
        )

        token = response.fetch("access_token")
        client.access_token = token
        response
      end
    end
  end
end
