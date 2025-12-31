## [Unreleased]

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
