# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Webhooks::Result do
  describe ".success" do
    it "creates a successful result with data" do
      data = { order_id: "123" }
      result = described_class.success(data)

      expect(result).to be_success
      expect(result.failure?).to be false
      expect(result.data).to eq(data)
      expect(result.error).to be_nil
    end
  end

  describe ".failure" do
    it "creates a failed result with error" do
      error = "Something went wrong"
      result = described_class.failure(error)

      expect(result).to be_failure
      expect(result.success?).to be false
      expect(result.error).to eq(error)
      expect(result.data).to be_nil
    end
  end

  describe "#success?" do
    it "returns true when error is nil" do
      result = described_class.new({ test: "data" }, nil)
      expect(result.success?).to be true
    end

    it "returns false when error is present" do
      result = described_class.new(nil, "error")
      expect(result.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns false when error is nil" do
      result = described_class.new({ test: "data" }, nil)
      expect(result.failure?).to be false
    end

    it "returns true when error is present" do
      result = described_class.new(nil, "error")
      expect(result.failure?).to be true
    end
  end
end
