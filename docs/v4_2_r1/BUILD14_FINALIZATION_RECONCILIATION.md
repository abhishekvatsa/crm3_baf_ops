# Build 14 Finalization Reconciliation

## Decision

Build 14 is a production-signed, independently verified, dual-custodied
pre-release artifact. Construction and finalization are complete. This record
does not authorize controlled-pilot handout or unrestricted distribution.

## Exact authority

- Source commit: `f0d51819bfa4c81ad73b5d7f83675fa8b6a07b11`
- Source tree: `627a8260231e834978c6f4b7445d76160b45964c`
- Merged pull request: `#267`
- GitHub Actions run: `32572743604`
- GitHub artifact: `9475994815`
- Governed package SHA-256:
  `496D990749A0658D73AEE4D908451424B185137F04EDFCA8B1C932195D994F2F`
- APK SHA-256:
  `979B0A61883FB520253634DDFEE8C933780465AE75DBBEFA5FC92D986E578FF1`
- Production certificate SHA-256:
  `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`
- Reserved tag: `crm3-build-reserved/14`
- Built tag: `crm3-build-built/14`

The protected production-signing environment approved the exact run. Four
required secret names were verified; no secret value was inspected. The
governed package and closure archive were hash-verified on distinct `C:` and
`D:` custody roots.

## Boundary

Closed by this tranche:

- `BUILD14_PRODUCTION_SIGNED_FINALIZATION`

Still open:

- `BUILD14_SIGNED_DEVICE_MIGRATION_AND_BUSINESS_FLOW_VALIDATION`
- `BUILD14_EXPLICIT_PILOT_PROMOTION`

The finalization receipt intentionally records runtime validation, business
flow validation, controlled-pilot approval, distribution and unrestricted
release as false. Device evidence and any later promotion require separate,
exact Build 14 receipts.
