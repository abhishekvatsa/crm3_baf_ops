# C-02 Audit Package Coverage

Status: SOURCE_IMPLEMENTED

## Finding

The 13 July deep audit found that the source audit package omitted four
material tracked files: `release_gate.ps1`, `jest.config.js`, and the governed
Firebase CLI `package.json` and `package-lock.json`. A complete Git archive can
contain those files without making their presence an independently verified
package contract.

## Source Correction

Both governed artifact builders now hash-bind these audit-critical entries
from canonical Git-archive bytes:

- `release_gate.ps1`
- `jest.config.js`
- `governance/programme-ledger.json`
- `tooling/firebase-cli/package.json`
- `tooling/firebase-cli/package-lock.json`

The verification artifact also records the governed Firebase CLI lockfile in
its dependency lockfile inventory, matching the production artifact path.

Both package-only verifiers require the complete set before trusting the
manifest and then recompute every recorded source-entry digest from the
packaged archive. Removing a required entry from either builder or verifier is
covered by `test/c02_audit_package_coverage_contract_test.dart` and the
canonical audit.

## Boundary

This change modifies package custody only. It does not build or distribute an
artifact, invoke a production workflow, deploy Firebase, mutate cloud state,
or claim device/runtime evidence.

C-02 remains `SOURCE_IMPLEMENTED` until exact-head pull-request CI and
post-merge main CI are recorded in a separate closure adjudication.
