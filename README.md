# PayuPl

A small Ruby client for the PayU GPO Europe REST API (commonly used for PayU Poland integrations), with:

- `Net::HTTP` transport
- consistent error mapping
- basic request validation via `dry-validation`

This gem focuses on the standard payment flow endpoints:

- OAuth token
- Create / retrieve order
- Capture / cancel
- Refunds
- Transaction retrieve

Additional supported areas:

- Retrieve Shop Data
- Payouts
- Statements

## Installation

Add to your Gemfile:

```ruby
gem "payu_pl"
```

Then run:

```bash
bundle install
```

## Usage

### Create a client

```ruby
client = PayuPl::Client.new(
  client_id: ENV.fetch("PAYU_CLIENT_ID"),
  client_secret: ENV.fetch("PAYU_CLIENT_SECRET"),
  environment: :sandbox # or :production
)
```

### Authenticate (OAuth)

```ruby
client.oauth_token
# => {"access_token"=>"...", "token_type"=>"bearer", "expires_in"=>43199, ...}
```

The token is stored on the client as `client.access_token` and used automatically for subsequent calls.

### Create an order

```ruby
payload = {
  notifyUrl: "https://example.com/payu/notify",
  customerIp: "127.0.0.1",
  merchantPosId: ENV.fetch("PAYU_POS_ID"),
  description: "RTV market",
  currencyCode: "PLN",
  totalAmount: "21000",
  products: [
    { name: "Wireless Mouse", unitPrice: "21000", quantity: "1" }
  ]
}

response = client.create_order(payload)
redirect_uri = response["redirectUri"]
order_id = response["orderId"]
```

Notes:

- `totalAmount` / `unitPrice` are strings in minor units.
- PayU often responds with HTTP `302` and JSON body; this client does not auto-follow redirects.

### Retrieve an order

```ruby
client.retrieve_order(order_id)
```

### Capture / cancel

```ruby
client.capture_order(order_id) # full capture (empty JSON body)

client.capture_order(order_id, amount: "1000", currency_code: "PLN") # partial capture

client.cancel_order(order_id)
```

### Refunds

```ruby
client.create_refund(order_id, description: "Refund")
client.create_refund(order_id, description: "Partial refund", amount: "1000")

client.list_refunds(order_id)
client.retrieve_refund(order_id, "5000000142")
```

### Retrieve transactions

```ruby
client.retrieve_transactions(order_id)
```

### Webhook validation

PayU sends webhook notifications when order status changes. This gem provides a validator to verify webhook signatures and parse payloads.

#### Basic usage in Rails

```ruby
# config/routes.rb
post '/webhooks/payu', to: 'webhooks/payu#create'

# app/controllers/webhooks/payu_controller.rb
class Webhooks::PayuController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    result = PayuPl::Webhooks::Validator.new(request).validate_and_parse
    
    if result.failure?
      Rails.logger.error("PayU webhook validation failed: #{result.error}")
      return head :bad_request
    end

    payload = result.data
    order_id = payload.dig('order', 'orderId')
    status = payload.dig('order', 'status')
    
    # Process the webhook...
    # (check for duplicates, enqueue background job, etc.)
    
    head :ok
  end
end
```

#### Configuration

Set your PayU second key (MD5 key) in one of three ways:

```ruby
# 1. Via initializer (recommended)
# config/initializers/payu.rb
PayuPl.configure do |config|
  config.second_key = ENV.fetch('PAYU_SECOND_KEY')
end

# 2. Via ENV variable (automatic fallback)
ENV['PAYU_SECOND_KEY'] = 'your_second_key'

# 3. Pass directly to validator
validator = PayuPl::Webhooks::Validator.new(request, second_key: 'custom_key')
```

#### With custom logger

```ruby
logger = Logger.new(STDOUT)
validator = PayuPl::Webhooks::Validator.new(request, logger: logger)
result = validator.validate_and_parse
```

#### Validation only (without parsing)

```ruby
validator = PayuPl::Webhooks::Validator.new(request)

begin
  validator.verify_signature!
  # Signature is valid
rescue => e
  # Signature validation failed
  Rails.logger.error("Invalid signature: #{e.message}")
end
```

#### Result object

The validator returns a `PayuPl::Webhooks::Result` object:

```ruby
result = validator.validate_and_parse

if result.success?
  payload = result.data
  # Access webhook data
  order_id = payload.dig('order', 'orderId')
  status = payload.dig('order', 'status')
  
  # Convert amount from minor units (2900 = 29.00 PLN)
  total_amount = payload.dig('order', 'totalAmount').to_i / 100.0
  currency = payload.dig('order', 'currencyCode')
else
  error_message = result.error
  # Handle validation error
end
```

#### Signature algorithms

PayU supports multiple signature algorithms (MD5, SHA1, SHA256, SHA384, SHA512). The validator automatically detects the algorithm from the webhook header and verifies accordingly.

For MD5, PayU may use either `MD5(body + key)` or `MD5(key + body)`. The validator checks both variants automatically.

#### Important: Webhook Best Practices

1. **Always return 200 OK** - After signature validation, return 200 even if processing fails
2. **Handle duplicates** - PayU retries up to 20 times if you don't return 200
3. **Process asynchronously** - Store webhook and process in background job
4. **IP Whitelisting** (optional) - Allow PayU IPs:
   - Production: `185.68.12.10-12`, `185.68.12.26-28`
   - Sandbox: `185.68.14.10-12`, `185.68.14.26-28`

See `examples/WEBHOOK_GUIDE.md` for comprehensive integration guide.

#### Non-Rails frameworks

The validator works with any Rack-compatible request object:

```ruby
# Sinatra
post '/webhooks/payu' do
  result = PayuPl::Webhooks::Validator.new(request).validate_and_parse
  
  if result.success?
    # Process webhook
    status 200
  else
    status 400
  end
end

# Hanami
module Web::Controllers::Webhooks
  class Payu
    include Web::Action

    def call(params)
      result = PayuPl::Webhooks::Validator.new(request).validate_and_parse
      
      if result.success?
        # Process webhook
        self.status = 200
      else
        self.status = 400
      end
    end
  end
end
```

### Retrieve shop data

```ruby
client.retrieve_shop_data("SHOP_ID")
```

### Payouts

PayU supports multiple payout request schemas (Standard Payout, Bank Account Payout, Card Payout, Payout for Marketplace, FxPayout).
This client sends the JSON payload as-is, so your request must match one of the schemas from PayU docs.

Note: Payouts are a permissioned product in PayU. If your POS/shop is not enabled for payouts (common in sandbox or without the right agreement), PayU may respond with HTTP `403` (e.g. `ERROR_VALUE_INVALID` / "Permission denied for given action").

```ruby
# Standard Payout
standard_payout = {
  shopId: "1a2B3Cx",
  payout: {
    extPayoutId: "payout-123",
    amount: 10_000,
    description: "Payout"
  }
}

# Bank Account Payout
bank_account_payout = {
  shopId: "1a2B3Cx",
  payout: { extPayoutId: "payout-124", amount: 10_000, description: "Payout" },
  account: { accountNumber: "PL61109010140000071219812874" },
  customerAddress: { name: "Jane Doe" }
}

# Card Payout (use either cardToken or card)
card_payout = {
  shopId: "1a2B3Cx",
  payout: { extPayoutId: "payout-125", amount: 10_000, description: "Payout" },
  payee: { extCustomerId: "customer-id-1", accountCreationDate: "2025-03-27T00:00:00.000Z", email: "email@email.com" },
  customerAddress: { name: "Jane Doe" },
  cardToken: "TOKC_..."
}

# Payout for Marketplace
marketplace_payout = {
  shopId: "1a2B3Cx",
  account: { extCustomerId: "submerchant1" },
  payout: { extPayoutId: "payout-126", amount: 10_000, currencyCode: "PLN", description: "Payout" }
}

# FxPayout
fx_payout = {
  shopId: "1a2B3Cx",
  account: { extCustomerId: "submerchant1" },
  payout: { extPayoutId: "payout-127", amount: 10_000, currencyCode: "PLN", description: "Payout" },
  fxData: { partnerId: "...", currencyCode: "EUR", amount: 2500, rate: 0.25, tableId: "2055" }
}

client.create_payout(standard_payout)
client.retrieve_payout("PAYOUT_ID")
```

### Statements

This endpoint returns binary data and includes filename metadata from `Content-Disposition`.

```ruby
statement = client.retrieve_statement("REPORT_ID")
# => { data: "...", filename: "...", content_type: "...", http_status: 200 }

safe_filename = File.basename(statement.fetch(:filename)).gsub(/[^0-9A-Za-z.\-]/, "_")
File.binwrite(safe_filename, statement.fetch(:data))
```

## Errors and validation

HTTP errors are mapped to Ruby exceptions:

- `PayuPl::UnauthorizedError` (401)
- `PayuPl::ForbiddenError` (403)
- `PayuPl::NotFoundError` (404)
- `PayuPl::RateLimitedError` (429)
- `PayuPl::ClientError` (other 4xx)
- `PayuPl::ServerError` (5xx)

They carry useful fields like `http_status`, `correlation_id`, `raw_body`, and `parsed_body`.

Request validation errors raise `PayuPl::ValidationError` and include an `errors` hash.

## PayU documentation

Useful official resources:

- PayU GPO Europe docs: https://developers.payu.com/europe/docs/
- REST API reference (OpenAPI): https://developers.payu.com/europe/api/
- OpenAPI YAML download: https://developers.payu.com/europe/resources/payu-gpo-europe-api-ref.yaml
- Sandbox testing guide: https://developers.payu.com/europe/docs/testing/sandbox/
- Sandbox registration: https://registration-merch-prod.snd.payu.com/boarding/#/registerSandbox/
- Sandbox status page: https://status.snd.payu.com/

## Development

Run tests:

```bash
bundle exec rspec
```
