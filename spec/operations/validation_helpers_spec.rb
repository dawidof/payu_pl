# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Operation validation helpers" do
  it "maps IdContract errors onto the provided input_key" do
    client = instance_double(PayuPl::Client, transport: instance_double(PayuPl::Transport))

    operation = PayuPl::Orders::Retrieve.new(client: client)

    expect { operation.call(nil) }
      .to raise_error(PayuPl::ValidationError) { |e|
        expect(e.errors).to have_key(:order_id)
      }
  end

  it "validates multiple ids with distinct keys" do
    client = instance_double(PayuPl::Client, transport: instance_double(PayuPl::Transport))

    operation = PayuPl::Refunds::Retrieve.new(client: client)

    expect { operation.call("", nil) }
      .to raise_error(PayuPl::ValidationError) { |e|
        expect(e.errors).to have_key(:order_id)
        expect(e.errors).to have_key(:refund_id)
      }
  end
end
