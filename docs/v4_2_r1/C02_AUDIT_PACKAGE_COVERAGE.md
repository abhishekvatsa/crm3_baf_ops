# C-02 Audit Package Coverage

Status: CLOSED

Source merge and CI evidence: COMPLETE

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

## Closure Evidence

PR #154 merged exact green head
`06dac6a5b2048592652005f83324b5dc0009dc77`, tree
`18f1c9881c971132a16a5f092dbc7fc3cd7d40b2`, to main as
`a3d3a95c44ab788a44952b8de9260fa39b96f462` with the identical tree.

Exact-head pull-request run `30971588062` passed all four governed jobs.
Post-merge run `30972062651` independently passed the same four jobs on the
exact admitted main commit. The closure record is
`release/evidence/c02-audit-package-coverage-closure.json`.

Decision: `PASS_C02_AUDIT_PACKAGE_COVERAGE_SOURCE_AND_CI_CLOSURE`

## Operational Boundary

Closure proves source and CI package custody. It does not construct or
distribute a production artifact, reserve a build number, deploy Firebase,
mutate cloud state, claim physical-device evidence, or authorize pilot
handout.
