# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Contracts::CaptureContract do
  it "requires currency_code when amount is provided" do
    result = described_class.new.call(order_id: "OID", amount: "1000", currency_code: nil)
    expect(result.errors.to_h.fetch(:currency_code)).to include(PayuPl.t(:required_with_amount))
  end

  it "treats blank currency_code as missing (required error, not format error)" do
    result = described_class.new.call(order_id: "OID", amount: "1000", currency_code: "   ")
    errors = result.errors.to_h.fetch(:currency_code)

    expect(errors).to include(PayuPl.t(:required_with_amount))
    expect(errors).not_to include(PayuPl.t(:iso_4217))
  end

  it "validates currency_code format only when present" do
    result = described_class.new.call(order_id: "OID", amount: "1000", currency_code: "PL")
    expect(result.errors.to_h.fetch(:currency_code)).to include(PayuPl.t(:iso_4217))
  end

  it "requires amount when currency_code is provided" do
    result = described_class.new.call(order_id: "OID", amount: nil, currency_code: "PLN")
    expect(result.errors.to_h.fetch(:amount)).to include(PayuPl.t(:required_with_currency_code))
  end

  it "treats blank amount as missing (required error, not numeric error)" do
    result = described_class.new.call(order_id: "OID", amount: " ", currency_code: "PLN")
    errors = result.errors.to_h.fetch(:amount)

    expect(errors).to include(PayuPl.t(:required_with_currency_code))
    expect(errors).not_to include(PayuPl.t(:numeric_string))
  end

  it "validates amount is numeric string when present" do
    result = described_class.new.call(order_id: "OID", amount: "10.00", currency_code: "PLN")
    expect(result.errors.to_h.fetch(:amount)).to include(PayuPl.t(:numeric_string))
  end
end
