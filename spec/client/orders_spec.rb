# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "creates an order using Bearer token and JSON (supports 302 + JSON body)" do
    token = "token-123"
    payload = {
      notifyUrl: "https://example.test/notify",
      customerIp: "127.0.0.1",
      merchantPosId: "300746",
      description: "Test order",
      currencyCode: "PLN",
      totalAmount: "21000",
      products: [{ name: "Mouse", unitPrice: "21000", quantity: "1" }]
    }

    stub_request(:post, "#{base_url}/api/v2_1/orders")
      .with(
        headers: {
          "Authorization" => "Bearer #{token}",
          "Content-Type" => "application/json"
        },
        body: payload.to_json
      )
      .to_return(
        status: 302,
        headers: { "Content-Type" => "application/json", "Location" => "https://example.test/redirect" },
        body: { status: { statusCode: "SUCCESS" }, redirectUri: "https://example.test/redirect", orderId: "OID" }.to_json
      )

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.create_order(payload)

    expect(response.dig("status", "statusCode")).to eq("SUCCESS")
    expect(response.fetch("orderId")).to eq("OID")
  end

  it "validates create order payload (required keys + formats)" do
    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: "t")

    expect { client.create_order({}) }
      .to raise_error(PayuPl::ValidationError) { |e|
        expect(e.errors).to be_a(Hash)
        expect(e.errors.keys).to include(:customerIp, :merchantPosId, :description, :currencyCode, :totalAmount, :products)
      }
  end

  it "retrieves order data" do
    token = "token-123"
    order_id = "OID"

    stub_request(:get, "#{base_url}/api/v2_1/orders/#{order_id}")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { orders: [{ orderId: order_id }] }.to_json)

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.retrieve_order(order_id)

    expect(response.dig("orders", 0, "orderId")).to eq(order_id)
  end

  it "captures an order (full capture with empty body)" do
    token = "token-123"
    order_id = "OID"

    stub_request(:post, "#{base_url}/api/v2_1/orders/#{order_id}/captures")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { status: { statusCode: "SUCCESS" } }.to_json)

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.capture_order(order_id)

    expect(response.dig("status", "statusCode")).to eq("SUCCESS")
  end

  it "validates partial capture requires amount + currency_code" do
    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: "t")

    expect { client.capture_order("OID", amount: "1000") }
      .to raise_error(PayuPl::ValidationError) { |e|
        expect(e.errors.keys).to include(:currency_code)
      }
  end

  it "cancels an order" do
    token = "token-123"
    order_id = "OID"

    stub_request(:delete, "#{base_url}/api/v2_1/orders/#{order_id}")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { orderId: order_id, status: { statusCode: "SUCCESS" } }.to_json)

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.cancel_order(order_id)

    expect(response.fetch("orderId")).to eq(order_id)
  end

  it "retrieves transactions" do
    token = "token-123"
    order_id = "OID"

    stub_request(:get, "#{base_url}/api/v2_1/orders/#{order_id}/transactions")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { transactions: [{ payMethod: { value: "c" } }] }.to_json)

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.retrieve_transactions(order_id)

    expect(response).to have_key("transactions")
  end
end
