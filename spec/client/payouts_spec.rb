# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "creates and retrieves a payout" do
    token = "token-123"

    payout_request = {
      shopId: "1a2B3Cx",
      payout: {
        extPayoutId: "payout-123",
        amount: 10_000,
        description: "Payout"
      }
    }

    stub_request(:post, "#{base_url}/api/v2_1/payouts")
      .with(
        headers: {
          "Authorization" => "Bearer #{token}",
          "Content-Type" => "application/json"
        },
        body: payout_request.to_json
      )
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: { payout: { payoutId: "PID" }, status: { statusCode: "SUCCESS" } }.to_json
      )

    stub_request(:get, "#{base_url}/api/v2_1/payouts/PID")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { payout: { payoutId: "PID", status: "PENDING" } }.to_json
      )

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)

    created = client.create_payout(payout_request)
    expect(created.dig("payout", "payoutId")).to eq("PID")

    retrieved = client.retrieve_payout("PID")
    expect(retrieved.dig("payout", "payoutId")).to eq("PID")
  end

  it "validates payout request is a non-empty hash" do
    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: "t")

    expect { client.create_payout(nil) }
      .to raise_error(PayuPl::ValidationError) { |e|
        expect(e.errors).to have_key(:payload)
      }

    expect { client.create_payout({}) }
      .to raise_error(PayuPl::ValidationError) { |e|
        expect(e.errors).to have_key(:payload)
      }
  end
end
