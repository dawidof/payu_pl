# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "creates a refund (validates amount format)" do
    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: "t")

    expect { client.create_refund("OID", description: "Refund", amount: "10.00") }
      .to raise_error(PayuPl::ValidationError)
  end

  it "lists and retrieves refunds" do
    token = "token-123"
    order_id = "OID"
    refund_id = "RID"

    stub_request(:get, "#{base_url}/api/v2_1/orders/#{order_id}/refunds")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: [{ refundId: refund_id }].to_json)

    stub_request(:get, "#{base_url}/api/v2_1/orders/#{order_id}/refunds/#{refund_id}")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { refundId: refund_id }.to_json)

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)

    list = client.list_refunds(order_id)
    expect(list).to be_a(Array)
    expect(list.dig(0, "refundId")).to eq(refund_id)

    refund = client.retrieve_refund(order_id, refund_id)
    expect(refund.fetch("refundId")).to eq(refund_id)
  end
end
