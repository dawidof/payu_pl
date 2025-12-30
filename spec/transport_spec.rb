# frozen_string_literal: true

require "spec_helper"

FakeResponse = Struct.new(:code, :body, :headers, keyword_init: true) do
  def [](key)
    headers[key]
  end
end

RSpec.describe PayuPl::Transport do
  let(:base_url) { "https://secure.snd.payu.com" }

  def stub_http_with_response(response)
    http = double("http")
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:new).and_return(http)
    http
  end

  it "prevents GET requests with a JSON body" do
    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })

    expect { transport.request(:get, "/api/v2_1/orders/1", json: { a: 1 }) }
      .to raise_error(ArgumentError, /GET requests must not include a JSON body/)
  end

  it "rejects invalid base_url" do
    expect do
      described_class.new(base_url: "notaurl", access_token_provider: -> { "t" })
    end.to raise_error(ArgumentError, /base_url/i)
  end

  it "wraps timeouts as NetworkError" do
    http = double("http")
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_raise(Timeout::Error.new("timeout"))
    allow(Net::HTTP).to receive(:new).and_return(http)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })

    expect { transport.request(:post, "/api/v2_1/orders", json: { a: 1 }) }
      .to raise_error(PayuPl::NetworkError) { |e|
        expect(e.message).to match(/timed out/i)
        expect(e.original).to be_a(Timeout::Error)
      }
  end

  it "wraps connection failures as NetworkError" do
    http = double("http")
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_raise(Errno::ECONNREFUSED.new("refused"))
    allow(Net::HTTP).to receive(:new).and_return(http)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })

    expect { transport.request(:post, "/api/v2_1/orders", json: { a: 1 }) }
      .to raise_error(PayuPl::NetworkError) { |e|
        expect(e.message).to match(/network failure/i)
        expect(e.original).to be_a(Errno::ECONNREFUSED)
      }
  end

  it "parses JSON responses when Content-Type is application/json" do
    response = FakeResponse.new(
      code: 200,
      headers: { "Content-Type" => "application/json" },
      body: { ok: true, value: 123 }.to_json
    )
    stub_http_with_response(response)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })
    res = transport.request(:post, "/api/v2_1/orders", json: { a: 1 })

    expect(res).to eq({ "ok" => true, "value" => 123 })
  end

  it "parses JSON even when Content-Type is not JSON (body hint)" do
    response = FakeResponse.new(
      code: 200,
      headers: { "Content-Type" => "text/plain" },
      body: " {\"a\":1}"
    )
    stub_http_with_response(response)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })
    res = transport.request(:post, "/api/v2_1/orders", json: { a: 1 })

    expect(res).to eq({ "a" => 1 })
  end

  it "returns raw body when JSON parsing fails" do
    response = FakeResponse.new(
      code: 200,
      headers: { "Content-Type" => "application/json" },
      body: "{not-json"
    )
    stub_http_with_response(response)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })
    res = transport.request(:post, "/api/v2_1/orders", json: { a: 1 })

    expect(res).to eq("{not-json")
  end

  it "raises UnauthorizedError and exposes parsed_body + correlation_id" do
    response = FakeResponse.new(
      code: 401,
      headers: { "Content-Type" => "application/json", "Correlation-Id" => "corr-123" },
      body: { status: { statusCode: "UNAUTHORIZED", statusDesc: "Nope" } }.to_json
    )
    stub_http_with_response(response)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })

    expect { transport.request(:post, "/api/v2_1/orders", json: { a: 1 }) }
      .to raise_error(PayuPl::UnauthorizedError) { |e|
        expect(e.http_status).to eq(401)
        expect(e.correlation_id).to eq("corr-123")
        expect(e.parsed_body.dig("status", "statusCode")).to eq("UNAUTHORIZED")
      }
  end

  it "raises ServerError and preserves non-JSON parsed_body" do
    response = FakeResponse.new(
      code: 500,
      headers: { "Content-Type" => "text/plain", "Correlation-Id" => "corr-500" },
      body: "Internal error"
    )
    stub_http_with_response(response)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })

    expect { transport.request(:post, "/api/v2_1/orders", json: { a: 1 }) }
      .to raise_error(PayuPl::ServerError) { |e|
        expect(e.http_status).to eq(500)
        expect(e.correlation_id).to eq("corr-500")
        expect(e.raw_body).to eq("Internal error")
        expect(e.parsed_body).to eq("Internal error")
        expect(e.message).to include("HTTP 500")
      }
  end

  it "includes PayU status fields in the error message when available" do
    response = FakeResponse.new(
      code: 500,
      headers: { "Content-Type" => "application/json" },
      body: { status: { statusCode: "ERROR", statusDesc: "Something broke" } }.to_json
    )
    stub_http_with_response(response)

    transport = described_class.new(base_url: base_url, access_token_provider: -> { "t" })

    expect { transport.request(:post, "/api/v2_1/orders", json: { a: 1 }) }
      .to raise_error(PayuPl::ServerError) { |e|
        expect(e.message).to include("HTTP 500")
        expect(e.message).to include("ERROR")
        expect(e.message).to include("Something broke")
      }
  end
end
