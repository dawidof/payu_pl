# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "maps 429 to RateLimitedError" do
    token = "token-123"

    stub_request(:get, "#{base_url}/api/v2_1/orders/OID")
      .to_return(status: 429, headers: { "Content-Type" => "application/json" }, body: { status: { statusCode: "TOO_MANY_REQUESTS" } }.to_json)

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)

    expect { client.retrieve_order("OID") }.to raise_error(PayuPl::RateLimitedError)
  end

  it "keeps non-JSON response body as string in errors" do
    token = "token-123"

    stub_request(:get, "#{base_url}/api/v2_1/orders/OID")
      .to_return(status: 500, headers: { "Content-Type" => "text/plain" }, body: "Internal error")

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)

    expect { client.retrieve_order("OID") }
      .to raise_error(PayuPl::ServerError) { |e|
        expect(e.parsed_body).to eq("Internal error")
      }
  end
end
