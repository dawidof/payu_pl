## [Unreleased]

## [0.3.0] - 2026-01-09

### Added

- **Webhook Validation**: Complete webhook signature verification and payload parsing
  - `PayuPl::Webhooks::Validator` - Validates PayU webhook signatures and parses JSON payloads
  - `PayuPl::Webhooks::Result` - Success/failure result object for webhook validation
  - Support for all PayU signature algorithms: MD5, SHA1, SHA256, SHA384, SHA512
  - Automatic detection and verification of both MD5 concatenation variants (body+key and key+body)
  - Framework-agnostic design (works with Rails, Sinatra, Hanami, plain Rack)
  - Optional logging for debugging webhook processing
  - Constant-time signature comparison for security

- **Configuration**: `PayuPl::Configuration#second_key` for webhook signature verification
  - Three configuration methods: initializer, ENV variable, or direct parameter
  - Automatic fallback from config → ENV → direct parameter

- **Documentation**:
  - Comprehensive webhook integration guide (`examples/WEBHOOK_GUIDE.md`)
  - Rails controller example (`examples/webhooks_controller.rb`)
  - Sinatra example (`examples/sinatra_webhook_example.rb`)
  - Rack example (`examples/rack_webhook_example.ru`)
  - Updated README with webhook section and best practices
  - PayU IP addresses for webhook whitelisting (production + sandbox)
  - PayU notification retry mechanism details (20 attempts over 72 hours)
  - Official webhook header documentation
  - Payment status lifecycle documentation

- **Testing**: 25 comprehensive webhook tests
  - Signature verification tests for all algorithms
  - MD5 variant testing (both concatenation orders)
  - Configuration priority testing
  - Error handling and edge cases
  - Logging behavior tests

### Fixed

- Amount display in logs now correctly converts from minor units to major currency units
  - Example: `2900` (minor units) now displays as `29.00 PLN` (major units)
  - Updated validator logs and example controllers

### Dependencies

- Added `rack ~> 3.0` to development dependencies for webhook testing

## [0.2.0] - 2025-12-31

- Add Shop Data endpoint: `GET /api/v2_1/shops/{shopId}` (`Client#retrieve_shop_data`)
- Add Payouts endpoints: `POST /api/v2_1/payouts`, `GET /api/v2_1/payouts/{payoutId}` (`Client#create_payout`, `Client#retrieve_payout`)
- Add Statements endpoint: `GET /api/v2_1/reports/{reportId}` (`Client#retrieve_statement`) returning binary `data` + extracted `filename`
- Extend `Transport#request` with `return_headers:` to expose response headers for binary downloads
- Update README and RBS, and add client specs for the new endpoints

## [0.1.0] - 2025-12-30

- Add i18n-backed validation messages (English + Polish) and `PayuPl.configure` locale support
- DRY up ID validation in operations (`validate_id!` / `validate_ids!` in base)
- Split specs into multiple focused files and expand coverage
- Add PayU documentation links to README
- Consolidate CI workflows (single `ci.yml`)
