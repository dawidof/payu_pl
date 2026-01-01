# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Contracts::OrderCreateContract do
  let(:base_payload) do
    {
      customerIp: "127.0.0.1",
      merchantPosId: "300746",
      description: "Test order",
      currencyCode: "PLN",
      totalAmount: "21000",
      products: [{ name: "Mouse", unitPrice: "21000", quantity: "1" }]
    }
  end

  it "accepts valid IPv6 addresses" do
    result = described_class.new.call(base_payload.merge(customerIp: "2001:db8::1"))
    expect(result).to be_success
  end

  it "rejects invalid IPv6-like strings" do
    result = described_class.new.call(base_payload.merge(customerIp: ":::::::"))
    expect(result.errors.to_h.fetch(:customerIp)).to include("must be a valid IPv4 or IPv6 address")
  end

  it "rejects non-IP strings" do
    result = described_class.new.call(base_payload.merge(customerIp: "gggg:hhhh"))
    expect(result.errors.to_h.fetch(:customerIp)).to include("must be a valid IPv4 or IPv6 address")
  end

  it "does not treat IPv4 integer forms as valid" do
    result = described_class.new.call(base_payload.merge(customerIp: "1"))
    expect(result.errors.to_h.fetch(:customerIp)).to include("must be a valid IPv4 or IPv6 address")
  end

  it "accepts validityTime as numeric string" do
    result = described_class.new.call(base_payload.merge(validityTime: "100000"))
    expect(result).to be_success
  end

  it "rejects validityTime when not numeric string" do
    result = described_class.new.call(base_payload.merge(validityTime: "10.00"))
    expect(result.errors.to_h.fetch(:validityTime)).to include("must be a numeric string")
  end

  it "accepts product virtual boolean" do
    payload = base_payload.merge(products: [{ name: "Mouse", unitPrice: "21000", quantity: "1", virtual: true }])
    result = described_class.new.call(payload)
    expect(result).to be_success
  end
end
