# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "generates oauth token with form encoding" do
    stub_request(:post, "#{base_url}/pl/standard/user/oauth/authorize")
      .with(
        headers: { "Content-Type" => "application/x-www-form-urlencoded" },
        body: "grant_type=client_credentials&client_id=300746&client_secret=secret"
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          access_token: "token-123",
          token_type: "bearer",
          expires_in: 43_199,
          grant_type: "client_credentials"
        }.to_json
      )

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url)
    response = client.oauth_token

    expect(response.fetch("access_token")).to eq("token-123")
    expect(client.access_token).to eq("token-123")
  end

  it "raises UnauthorizedError with correlation id on 401" do
    stub_request(:post, "#{base_url}/pl/standard/user/oauth/authorize")
      .to_return(
        status: 401,
        headers: { "Content-Type" => "application/json", "Correlation-Id" => "corr-1" },
        body: { status: { statusCode: "UNAUTHORIZED", statusDesc: "Invalid credentials" } }.to_json
      )

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url)

    expect { client.oauth_token }
      .to raise_error(PayuPl::UnauthorizedError) { |e|
        expect(e.http_status).to eq(401)
        expect(e.correlation_id).to eq("corr-1")
        expect(e.parsed_body.dig("status", "statusCode")).to eq("UNAUTHORIZED")
      }
  end
end
