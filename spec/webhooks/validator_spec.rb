# frozen_string_literal: true

require "spec_helper"
require "rack"

RSpec.describe PayuPl::Webhooks::Validator do
  let(:second_key) { "test_secret_key" }
  let(:payload_json) do
    {
      order: {
        orderId: "WZHF5FFDRJ140731GUEST000P01",
        status: "COMPLETED",
        totalAmount: "21000",
        currencyCode: "PLN"
      }
    }.to_json
  end

  def create_mock_request(body, signature_header)
    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/webhooks/payu",
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_OPENPAYU_SIGNATURE" => signature_header,
      "rack.input" => StringIO.new(body)
    }
    Rack::Request.new(env)
  end

  describe "#initialize" do
    it "uses provided second_key" do
      request = create_mock_request("", nil)
      validator = described_class.new(request, second_key: "custom_key")
      expect(validator.second_key).to eq("custom_key")
    end

    it "falls back to configuration second_key" do
      PayuPl.configure do |config|
        config.second_key = "config_key"
      end

      request = create_mock_request("", nil)
      validator = described_class.new(request)
      expect(validator.second_key).to eq("config_key")

      # Reset configuration
      PayuPl.config.second_key = nil
    end

    it "falls back to ENV variable" do
      ENV["PAYU_SECOND_KEY"] = "env_key"
      PayuPl.config.second_key = nil

      request = create_mock_request("", nil)
      validator = described_class.new(request)
      expect(validator.second_key).to eq("env_key")

      ENV.delete("PAYU_SECOND_KEY")
    end

    it "accepts optional logger" do
      logger = Logger.new(nil)
      request = create_mock_request("", nil)
      validator = described_class.new(request, second_key: "key", logger: logger)
      expect(validator.logger).to eq(logger)
    end
  end

  describe "#verify_signature!" do
    context "with SHA256 algorithm" do
      it "validates correct signature" do
        signature = OpenSSL::HMAC.hexdigest("sha256", second_key, payload_json)
        header = "signature=#{signature};algorithm=SHA256"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        expect { validator.verify_signature! }.not_to raise_error
      end

      it "raises error for incorrect signature" do
        header = "signature=invalid_signature;algorithm=SHA256"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        expect { validator.verify_signature! }.to raise_error(/Signature verification failed/)
      end
    end

    context "with MD5 algorithm" do
      it "validates correct signature with body+key" do
        signature = Digest::MD5.hexdigest(payload_json + second_key)
        header = "signature=#{signature};algorithm=MD5"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        expect { validator.verify_signature! }.not_to raise_error
      end

      it "validates correct signature with key+body" do
        signature = Digest::MD5.hexdigest(second_key + payload_json)
        header = "signature=#{signature};algorithm=MD5"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        expect { validator.verify_signature! }.not_to raise_error
      end

      it "raises error for incorrect MD5 signature" do
        header = "signature=invalid_md5_signature;algorithm=MD5"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        expect { validator.verify_signature! }.to raise_error(/Signature verification failed/)
      end
    end

    context "without algorithm specified" do
      it "defaults to SHA256" do
        signature = OpenSSL::HMAC.hexdigest("sha256", second_key, payload_json)
        header = "signature=#{signature}"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        expect { validator.verify_signature! }.not_to raise_error
      end
    end

    it "raises error when signature header is missing" do
      request = create_mock_request(payload_json, nil)
      validator = described_class.new(request, second_key: second_key)

      expect { validator.verify_signature! }.to raise_error("Missing OpenPayU signature header")
    end
  end

  describe "#parse_payload" do
    it "parses valid JSON payload" do
      request = create_mock_request(payload_json, nil)
      validator = described_class.new(request, second_key: second_key)

      result = validator.parse_payload
      expect(result).to be_a(Hash)
      expect(result["order"]["orderId"]).to eq("WZHF5FFDRJ140731GUEST000P01")
      expect(result["order"]["status"]).to eq("COMPLETED")
    end

    it "allows reading body multiple times" do
      request = create_mock_request(payload_json, nil)
      validator = described_class.new(request, second_key: second_key)

      first_parse = validator.parse_payload
      second_parse = validator.parse_payload

      expect(first_parse).to eq(second_parse)
    end
  end

  describe "#validate_and_parse" do
    context "with valid signature and payload" do
      it "returns success result with parsed data" do
        signature = OpenSSL::HMAC.hexdigest("sha256", second_key, payload_json)
        header = "signature=#{signature};algorithm=SHA256"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        result = validator.validate_and_parse

        expect(result).to be_success
        expect(result.failure?).to be false
        expect(result.data).to be_a(Hash)
        expect(result.data["order"]["orderId"]).to eq("WZHF5FFDRJ140731GUEST000P01")
        expect(result.error).to be_nil
      end
    end

    context "with invalid signature" do
      it "returns failure result with error message" do
        header = "signature=invalid;algorithm=SHA256"
        request = create_mock_request(payload_json, header)

        validator = described_class.new(request, second_key: second_key)
        result = validator.validate_and_parse

        expect(result).to be_failure
        expect(result.success?).to be false
        expect(result.error).to include("Signature verification failed")
        expect(result.data).to be_nil
      end
    end

    context "with missing signature header" do
      it "returns failure result" do
        request = create_mock_request(payload_json, nil)
        validator = described_class.new(request, second_key: second_key)
        result = validator.validate_and_parse

        expect(result).to be_failure
        expect(result.error).to eq("Missing OpenPayU signature header")
      end
    end

    context "with invalid JSON" do
      it "returns failure result" do
        invalid_json = "{ invalid json"
        signature = OpenSSL::HMAC.hexdigest("sha256", second_key, invalid_json)
        header = "signature=#{signature};algorithm=SHA256"
        request = create_mock_request(invalid_json, header)

        validator = described_class.new(request, second_key: second_key)
        result = validator.validate_and_parse

        expect(result).to be_failure
        expect(result.error).not_to be_nil
      end
    end
  end

  describe "logging" do
    let(:logger) { instance_double(Logger) }

    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:error)
    end

    it "logs validation process when logger is provided" do
      signature = OpenSSL::HMAC.hexdigest("sha256", second_key, payload_json)
      header = "signature=#{signature};algorithm=SHA256"
      request = create_mock_request(payload_json, header)

      validator = described_class.new(request, second_key: second_key, logger: logger)
      validator.validate_and_parse

      expect(logger).to have_received(:info).at_least(:once)
    end

    it "does not raise errors when logger is nil" do
      signature = OpenSSL::HMAC.hexdigest("sha256", second_key, payload_json)
      header = "signature=#{signature};algorithm=SHA256"
      request = create_mock_request(payload_json, header)

      validator = described_class.new(request, second_key: second_key, logger: nil)
      expect { validator.validate_and_parse }.not_to raise_error
    end
  end
end
