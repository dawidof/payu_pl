# frozen_string_literal: true

module PayuPl
  module Statements
    class Retrieve < Operations::Base
      FILENAME_REGEX = /filename="?(?<filename>[^";]+)"?/i.freeze

      def call(report_id)
        validate_id!(report_id, input_key: :report_id)

        response = transport.request(
          :get,
          Endpoints.report(report_id),
          headers: { "Accept" => "application/octet-stream" },
          return_headers: true
        )

        headers = response.fetch(:headers)
        content_type = headers["content-type"]
        content_disposition = headers["content-disposition"].to_s

        filename = content_disposition.match(FILENAME_REGEX)&.named_captures&.fetch("filename", nil)

        {
          data: response.fetch(:body),
          filename: filename,
          content_type: content_type,
          http_status: response.fetch(:http_status)
        }
      end
    end
  end
end
