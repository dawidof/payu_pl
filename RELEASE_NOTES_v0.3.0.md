# PayuPl v0.3.0 Release Notes

**Release Date:** January 9, 2026  
**Gem:** `payu_pl-0.3.0.gem` (29KB)  
**Tests:** 70 passing (25 new webhook tests)

## 🎉 Major New Feature: Webhook Integration

This release adds comprehensive webhook validation support, making it easy to securely process PayU payment notifications in any Ruby application.

### Why This Matters

PayU sends webhook notifications when payment status changes. This gem now provides:
- Secure signature verification (prevents webhook spoofing)
- Framework-agnostic validator (Rails, Sinatra, Hanami, Rack)
- Production-ready with all PayU algorithms supported
- Complete documentation and examples

## ✨ What's New

### Webhook Validation System

Complete implementation for validating and processing PayU webhooks:

- **Signature Verification**: Supports all PayU algorithms (MD5, SHA1, SHA256, SHA384, SHA512)
- **Automatic MD5 Handling**: Checks both concatenation variants automatically
- **Framework Agnostic**: Works with Rails, Sinatra, Hanami, plain Rack
- **Security First**: Constant-time signature comparison prevents timing attacks
- **Optional Logging**: Debug webhook processing with detailed logs

### Simple API

```ruby
result = PayuPl::Webhooks::Validator.new(request).validate_and_parse

if result.success?
  payload = result.data
  order_id = payload.dig('order', 'orderId')
  status = payload.dig('order', 'status')
  # Process webhook...
else
  logger.error("Validation failed: #{result.error}")
end
```

### Configuration Options

Three flexible ways to configure your webhook secret:

```ruby
# 1. Via initializer
PayuPl.configure { |c| c.second_key = ENV['PAYU_SECOND_KEY'] }

# 2. Via ENV (automatic)
ENV['PAYU_SECOND_KEY'] = 'your_secret'

# 3. Direct parameter
PayuPl::Webhooks::Validator.new(request, second_key: 'secret')
```

### Comprehensive Documentation

- **Integration Guide**: Step-by-step webhook setup (`examples/WEBHOOK_GUIDE.md`)
- **Framework Examples**: Rails, Sinatra, Rack implementations
- **Best Practices**: Duplicate handling, async processing, status codes
- **PayU Details**: IP whitelisting, retry mechanism, official payload structure

## 🐛 Bug Fixes

- **Amount Display**: Fixed logging to show amounts in major currency units
  - Before: `Amount: 2900 PLN` ❌
  - After: `Amount: 29.00 PLN` ✅

## � Files Structure

### Core Implementation
```
lib/payu_pl/webhooks/
  ├── validator.rb (228 lines) - Main webhook validator
  └── result.rb (34 lines) - Result object

lib/payu_pl/configuration.rb
  └── Added second_key attribute
```

### Documentation & Examples
```
examples/
  ├── WEBHOOK_GUIDE.md - Complete integration guide
  ├── webhooks_controller.rb - Rails example
  ├── sinatra_webhook_example.rb - Sinatra example
  └── rack_webhook_example.ru - Rack example

README.md - Updated with webhook section
CHANGELOG.md - Complete v0.3.0 entry
```

### Tests
```
spec/webhooks/
  ├── validator_spec.rb - 19 tests
  └── result_spec.rb - 6 tests
```

## �📊 Testing

- **70 total tests** (up from 45)
- **25 new webhook tests** with full coverage
- All signature algorithms tested
- Configuration priority tested
- Error handling tested

## 📦 Package Info

```
Name: payu_pl
Version: 0.3.0
Size: 29KB (up from 17KB in v0.2.0)
Ruby: >= 2.7.0
```

**Dependencies:**
- Runtime: `dry-initializer`, `dry-validation`, `i18n` (unchanged)
- Development: Added `rack ~> 3.0` for webhook testing

## 📖 Documentation

All documentation updated with PayU official specifications:
- **IP Whitelisting**: Production (`185.68.12.10-12`, `185.68.12.26-28`) and Sandbox (`185.68.14.10-12`, `185.68.14.26-28`)
- **Retry Mechanism**: 20 attempts over 72 hours with specific intervals
- **Payment Statuses**: PENDING, WAITING_FOR_CONFIRMATION, COMPLETED, CANCELED
- **Webhook Headers**: OpenPayu-Signature, PayU-Processing-Time, Content-Type
- **Payload Details**: localReceiptDateTime, PAYMENT_ID, payMethod.type, amount in minor units
- **Best Practices**: Return 200 OK, handle duplicates, process async

## 🔧 Implementation Highlights

### Security
- ✅ Constant-time signature comparison (prevents timing attacks)
- ✅ Support for all PayU algorithms (MD5, SHA1, SHA256, SHA384, SHA512)
- ✅ Automatic MD5 variant detection (body+key and key+body)

### Developer Experience
- ✅ Simple API: `result = validator.validate_and_parse`
- ✅ Clear success/failure pattern
- ✅ Optional detailed logging
- ✅ Framework-agnostic (works everywhere)
- ✅ Three flexible configuration methods

## 🚀 Upgrade Guide

### From v0.2.0

1. Update your Gemfile:
   ```ruby
   gem 'payu_pl', '~> 0.3.0'
   ```

2. Run bundle:
   ```bash
   bundle update payu_pl
   ```

3. Configure webhook secret (if using webhooks):
   ```ruby
   # config/initializers/payu.rb
   PayuPl.configure do |config|
     config.second_key = ENV.fetch('PAYU_SECOND_KEY')
   end
   ```

4. Set up webhook endpoint (see examples for your framework)

## 📝 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for complete details.

## 🔗 Resources

- **Repository**: https://github.com/dawidof/payu_pl
- **Documentation**: See README.md and examples/
- **PayU API Docs**: https://developers.payu.com/europe/api/
- **Issues**: https://github.com/dawidof/payu_pl/issues

## 🙏 Contributors

Special thanks to everyone who contributed to this release!

---

**Questions or Issues?**
Please open an issue on GitHub: https://github.com/dawidof/payu_pl/issues
