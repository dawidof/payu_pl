# frozen_string_literal: true

require "spec_helper"

RSpec.describe PayuPl::Client do
  let(:client_id) { "300746" }
  let(:client_secret) { "secret" }
  let(:base_url) { "https://secure.snd.payu.com" }

  it "retrieves a statement file (binary + filename)" do
    token = "token-123"
    report_id = "RID"
    binary = "PK\x03\x04".b

    stub_request(:get, "#{base_url}/api/v2_1/reports/#{report_id}")
      .with(headers: { "Authorization" => "Bearer #{token}", "Accept" => "application/octet-stream" })
      .to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/octet-stream",
          "Content-Disposition" => "attachment; filename=\"statement.zip\""
        },
        body: binary
      )

    client = described_class.new(client_id: client_id, client_secret: client_secret, base_url: base_url, access_token: token)
    response = client.retrieve_statement(report_id)

    expect(response.fetch(:filename)).to eq("statement.zip")
    expect(response.fetch(:content_type)).to eq("application/octet-stream")
    expect(response.fetch(:data)).to eq(binary)
  end
end
