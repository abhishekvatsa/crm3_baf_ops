# R1.15 Maintenance-Router Contract Correction

R1.15 is a test-contract correction over the sealed R1.14 candidate.

## Preserved bytes

The following authority-bearing areas are unchanged from R1.14:

- `firestore.rules`;
- all `lib/` product source;
- all `functions/` source and tests;
- root and Functions dependency lockfiles;
- Firebase configuration;
- Android build identity;
- release policy and workflows.

## Corrected contract

`test/maintenance_lifecycle_replay_contract_test.dart` now verifies the R1.14 single-router maintenance update design rather than the removed four-parallel-allow design.

The replacement assertion is behavioural-structural:

1. isolate the `maintenance_records` Rules match block;
2. prove exactly one `allow update`;
3. prove that update calls `validMaintenanceUpdate()`;
4. isolate the router;
5. prove deleted/resolved state selection;
6. prove all four governed validators remain present;
7. reject a parallel OR chain.

This closes the only failure in the authenticated R1.14 Flutter run without weakening the Rules or deleting lifecycle coverage.
