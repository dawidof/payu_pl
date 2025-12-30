# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Validation message localization" do
  let(:valid_payload_base) do
    {
      customerIp: "127.0.0.1",
      merchantPosId: "300746",
      description: "Test order",
      currencyCode: "PLN",
      products: [{ name: "Mouse", unitPrice: "21000", quantity: "1" }]
    }
  end

  around do |example|
    previous = PayuPl.config.locale
    example.run
  ensure
    PayuPl.configure { |c| c.locale = previous }
  end

  it "uses English messages by default" do
    PayuPl.configure { |c| c.locale = :en }

    result = PayuPl::Contracts::OrderCreateContract.new.call(valid_payload_base.merge(totalAmount: "10.00"))
    expect(result.errors.to_h.fetch(:totalAmount)).to include("must be a numeric string")
  end

  it "supports Polish messages" do
    PayuPl.configure { |c| c.locale = :pl }

    result = PayuPl::Contracts::OrderCreateContract.new.call(valid_payload_base.merge(totalAmount: "10.00"))
    expect(result.errors.to_h.fetch(:totalAmount)).to include("musi być ciągiem cyfr")
  end
end
