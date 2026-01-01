# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "retrieves shop data" do
    token = "token-123"
    shop_id = "SHOP1"

    stub_request(:get, "#{base_url}/api/v2_1/shops/#{shop_id}")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { shopId: shop_id, name: "Test Shop", currencyCode: "PLN", balance: { total: 12_345 } }.to_json
      )

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.retrieve_shop_data(shop_id)

    expect(response.fetch("shopId")).to eq(shop_id)
    expect(response.fetch("currencyCode")).to eq("PLN")
  end
end
