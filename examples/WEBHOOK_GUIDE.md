# PayU Webhook Integration Guide

This guide shows how to integrate PayU webhook validation into your application.

## Overview

PayU sends webhook notifications when order status changes. Each webhook includes:
- Order details (ID, status, amount, etc.)
- A signature header for verification
- JSON payload with the order data

The `PayuPl::Webhooks::Validator` class handles signature verification and payload parsing.

## Configuration

### Option 1: Via Initializer (Recommended for Rails)

```ruby
# config/initializers/payu.rb
PayuPl.configure do |config|
  config.second_key = ENV.fetch('PAYU_SECOND_KEY')
end
```

### Option 2: Via Environment Variable

Set `PAYU_SECOND_KEY` in your environment:

```bash
export PAYU_SECOND_KEY=your_second_key_here
```

The validator will automatically use this if no other configuration is provided.

### Option 3: Pass Directly

```ruby
validator = PayuPl::Webhooks::Validator.new(request, second_key: 'custom_key')
```

## Finding Your Second Key

1. Log in to PayU merchant panel
2. Go to Settings > POS Configuration
3. Find "Second Key" (also called "MD5 Key")
4. This is the secret used for webhook signature verification

**Important**: Keep this key secure! Never commit it to version control.

## Basic Usage

```ruby
# Create validator with request object
validator = PayuPl::Webhooks::Validator.new(request)

# Validate and parse in one step
result = validator.validate_and_parse

if result.success?
  payload = result.data
  order_id = payload.dig('order', 'orderId')
  status = payload.dig('order', 'status')
  
  # Convert amount from minor units to major units
  amount_minor = payload.dig('order', 'totalAmount').to_i  # e.g., 2900
  amount_major = amount_minor / 100.0                      # e.g., 29.00
  currency = payload.dig('order', 'currencyCode')          # e.g., "PLN"
  
  logger.info("Order #{order_id}: #{amount_major} #{currency}")
  # Process webhook...
else
  # Handle validation error
  logger.error("Webhook validation failed: #{result.error}")
end
```

## Framework-Specific Examples

### Rails

See [webhooks_controller.rb](webhooks_controller.rb) for a complete Rails example.

Key points:
- Skip CSRF token verification
- Use logger for debugging
- Handle duplicates
- Process asynchronously

### Sinatra

See [sinatra_webhook_example.rb](sinatra_webhook_example.rb) for a complete Sinatra example.

Key points:
- Simple route definition
- Direct request handling
- Minimal boilerplate

### Rack

See [rack_webhook_example.ru](rack_webhook_example.ru) for a complete Rack example.

Key points:
- Works with any Rack-compatible framework
- No framework dependencies
- Easy to integrate

## Webhook Payload Structure

PayU sends notifications in JSON format using POST method.

Example payload from PayU:

```json
{
  "order": {
    "orderId": "WZHF5FFDRJ140731GUEST000P01",
    "extOrderId": "your-order-id-123",
    "orderCreateDate": "2024-01-15T10:30:00.000Z",
    "notifyUrl": "https://your-app.com/webhooks/payu",
    "customerIp": "127.0.0.1",
    "merchantPosId": "300000",
    "description": "Order description",
    "currencyCode": "PLN",
    "totalAmount": "21000",
    "status": "COMPLETED",
    "products": [
      {
        "name": "Product Name",
        "unitPrice": "21000",
        "quantity": "1"
      }
    ]
  },
  "localReceiptDateTime": "2024-01-15T10:35:00.000Z",
  "properties": [
    {
      "name": "PAYMENT_ID",
      "value": "123456789"
    }
  ]
}
```

**Important Payload Notes**:

- `totalAmount` / `unitPrice` - **Always in minor units** (e.g., 2900 = 29.00 PLN, 1050 = 10.50 EUR)
  - Divide by 100 to convert to major currency units
  - Example: `"totalAmount": "2900"` means 29.00 PLN
- `localReceiptDateTime` - Only present for **COMPLETED** status
- `properties[PAYMENT_ID]` - Payment identifier shown on transaction statements (Trans ID in management panel)
- `payMethod.type` - Payment method used (if present):
  - `PBL` - Online/standard transfer
  - `CARD_TOKEN` - Card payment
  - `INSTALLMENTS` - PayU Installments

## Order Status Values

PayU sends notifications for orders in these statuses:

- `PENDING` - Payment is currently being processed
- `WAITING_FOR_CONFIRMATION` - PayU is waiting for merchant to capture payment (when auto-receive is disabled)
- `COMPLETED` - Payment accepted, funds will be paid out shortly
- `CANCELED` - Payment cancelled, buyer was not charged

## PayU Notification Retry Mechanism

PayU expects a **200 HTTP status code** response. If a different status is received, PayU will retry sending the notification up to **20 times** with increasing intervals:

| Attempt | Retry After |
|---------|-------------|
| 1 | Immediately |
| 2 | 1 minute |
| 3 | 2 minutes |
| 4 | 5 minutes |
| 5 | 10 minutes |
| 6 | 30 minutes |
| 7 | 1 hour |
| 8-20 | 2-72 hours |

**Important**: Always return 200 OK to acknowledge receipt, even if processing fails internally. Process errors should be handled asynchronously.

## IP Address Whitelisting

If you filter incoming requests by IP, allow these PayU addresses:

### Production
```
185.68.12.10, 185.68.12.11, 185.68.12.12
185.68.12.26, 185.68.12.27, 185.68.12.28
```

### Sandbox
```
185.68.14.10, 185.68.14.11, 185.68.14.12
185.68.14.26, 185.68.14.27, 185.68.14.28
```

## Notification Headers

PayU sends these headers with each notification:

- `OpenPayu-Signature` - Signature for verification (also sent as `X-OpenPayU-Signature`)
- `Content-Type` - Always `application/json;charset=UTF-8`
- `Authorization` - Basic auth credentials
- `PayU-Processing-Time` - Time (ms) spent processing at PayU side (selected statuses only)

Example signature header:
```
OpenPayu-Signature: sender=checkout;signature=d47d8a771d558c29285887febddd9327;algorithm=MD5;content=DOCUMENT
```

## Best Practices

### 1. Handle Duplicates

PayU may send the same webhook multiple times due to:
- Retry mechanism (if you don't return 200)
- Network issues
- PayU's intentional duplicate prevention

Always check for duplicates and return 200 even for duplicates:

```ruby
event_id = payload['eventId'] || "#{order_id}_#{status}"

if WebhookEvent.exists?(event_id: event_id)
  logger.warn("Duplicate webhook: #{event_id}")
  return head :ok  # Return 200 to acknowledge
end

# Store event...
```

### 2. Process Asynchronously

Don't block the webhook endpoint. Respond quickly and process in background:

```ruby
# Store webhook
WebhookEvent.create!(event_id: event_id, payload: payload)

# Process asynchronously
PayuWebhookJob.perform_async(event_id)

# Respond immediately
head :ok
```

### 3. Return Correct Status Codes

**Critical**: Always return `200 OK` after validating the signature, even if your business logic fails.

```ruby
# ✅ GOOD - Return 200 after validation
result = validator.validate_and_parse
if result.failure?
  return head :bad_request  # Invalid signature
end

# Store and process asynchronously
WebhookEvent.create!(payload: result.data)
head :ok  # Return 200 immediately

# ❌ BAD - Don't return 500 for business logic errors
# This will cause PayU to retry unnecessarily
```

Status code meanings:
- `200 OK` - Webhook received and validated (return this even if your processing fails)
- `400 Bad Request` - Invalid signature/payload only
- `500 Internal Server Error` - Should be avoided; causes PayU to retry

**Note**: If you return non-200, PayU will retry up to 20 times over 72 hours.

### 4. Enable Logging

Use logging to debug issues:

```ruby
validator = PayuPl::Webhooks::Validator.new(request, logger: Rails.logger)
```

This logs:
- Signature verification steps
- Algorithm used
- Payload parsing
- Any errors

### 5. Test Webhook Integration

#### Manual Testing

Use curl to simulate a webhook:

```bash
# Generate signature (example for MD5)
BODY='{"order":{"orderId":"TEST123","status":"COMPLETED"}}'
KEY='your_second_key'
SIGNATURE=$(echo -n "${BODY}${KEY}" | md5sum | cut -d' ' -f1)

# Send webhook
curl -X POST http://localhost:3000/webhooks/payu \
  -H "Content-Type: application/json" \
  -H "OpenPayU-Signature: signature=${SIGNATURE};algorithm=MD5" \
  -d "${BODY}"
```

#### Using PayU Sandbox

1. Create an order in sandbox
2. Configure notifyUrl to your webhook endpoint
3. PayU will send real webhook notifications
4. Use a tool like ngrok to expose local server

## Signature Algorithms

PayU supports multiple signature algorithms:

- **MD5** - PayU may use `MD5(body + key)` or `MD5(key + body)`
  - Validator checks both automatically
- **SHA1** - HMAC-SHA1
- **SHA256** - HMAC-SHA256 (recommended)
- **SHA384** - HMAC-SHA384
- **SHA512** - HMAC-SHA512

The validator automatically detects the algorithm from the webhook header.

## Troubleshooting

### "Missing OpenPayU signature header"

- PayU didn't send the signature header
- Check if request is actually from PayU
- Verify your notifyUrl is correct

### "Signature verification failed"

- Wrong second_key configured
- Payload was modified in transit
- Algorithm mismatch

**Debug steps**:
1. Enable logging to see expected vs received signature
2. Verify second_key matches PayU merchant panel
3. Check raw request body hasn't been modified

### "PayU second_key not configured"

- No configuration found
- Set via `PayuPl.configure`, ENV, or pass directly

### Tests Failing

Ensure rack gem is available for tests:

```ruby
# Gemfile
group :test do
  gem 'rack', '~> 3.0'
end
```

## Security Considerations

1. **Always verify signatures** - Never trust webhook data without verification
2. **Keep second_key secret** - Don't commit to version control
3. **Use HTTPS** - Configure notifyUrl with https://
4. **Validate IP addresses** (optional) - PayU webhooks come from known IPs
5. **Rate limiting** (optional) - Protect against abuse

## Additional Resources

- [PayU Webhook Documentation](https://developers.payu.com/europe/docs/webhooks/)
- [PayU API Reference](https://developers.payu.com/europe/api/)
- [Sandbox Testing Guide](https://developers.payu.com/europe/docs/testing/sandbox/)

## Support

For issues with this gem:
- GitHub Issues: https://github.com/dawidof/payu_pl/issues

For PayU API issues:
- PayU Support: https://www.payu.pl/pomoc
