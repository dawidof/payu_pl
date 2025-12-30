# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Transport do
  let(:base_url) { "https://secure.snd.payu.com" }

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
end
