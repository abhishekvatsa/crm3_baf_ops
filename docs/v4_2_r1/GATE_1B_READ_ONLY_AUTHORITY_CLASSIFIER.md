# Gate 1B Read-Only Authority Classifier

## Source position

Gate 1A S-05 was merged through PR #41:

```text
PR head:     eb8bc9e505f559bc0e9267f56dd23ec4b6180ca2
Merge commit: 96385151d73c04904184b0bfd9c057c23b9f6e84
Decision:    PASS_GATE_1A_S05_ATOMIC_AUTHORITY_MUTATION
```

Gate 1B does not repair data. It establishes whether existing Firestore and
Firebase Authentication user populations satisfy the merged authority policy.

## Read boundary

`tools/v4/firestore_integrity_sweep.mjs` performs only:

```text
Firestore users collection read
Firebase Auth listUsers pagination
optional non-user Firestore collection reads
local evidence-file creation
```

The source contains no Firestore write, transaction, batch, Firebase Auth user
mutation, custom-claim mutation, deployment, or Rules mutation API.

The default Gate 1B run reads `users` and the complete Firebase Auth population.
`--skip-auth` is permitted only for non-production diagnostics and always
produces:

```text
HOLD_INCOMPLETE_AUTH_OR_FIRESTORE_COVERAGE
```

The optional operational collection sweep is separate from the Gate 1B
authority decision and requires `--include-operational-contracts`.

## Authority policy

The role catalogue is derived from:

```text
governance/maintenance_workflow_policy_v1.json
```

Tests prove exact parity with Firestore Rules, the generated Functions policy,
and the generated Dart policy. The current unapproved-user policy is Model B:
canonical intended roles may remain stored, but confer no authority unless
`isApproved == true`.

Duplicate canonical roles are reported as:

```text
DUPLICATE_CANONICAL_ROLE_WARNING
```

They are a non-blocking data-quality warning. New governed writers normalize
roles deterministically.

## Classifications

The classifier distinguishes canonical state, authority defects, profile-only
defects, and Auth reconciliation defects:

```text
CANONICAL_APPROVED
CANONICAL_UNAPPROVED_WITH_INTENDED_ROLES
MISSING_AUTHORITY_FIELDS
INVALID_IS_APPROVED_TYPE
ROLES_NOT_LIST
EMPTY_APPROVED_ROLES
EMPTY_UNAPPROVED_ROLES
EMPTY_ROLE_LIST
TOO_MANY_ROLES
NON_STRING_ROLE
UNKNOWN_ROLE
DUPLICATE_CANONICAL_ROLE_WARNING
PROFILE_ONLY_CORRUPTION
AUTH_USER_MISSING
FIRESTORE_USER_MISSING
AUTH_USER_DISABLED_WHILE_APPROVED
UNEXPECTED_CUSTOM_CLAIMS
NO_ENABLED_APPROVED_ADMIN
```

Profile-only corruption and duplicate-role warnings do not become authority
defects. Population mismatches, disabled approved users, unexpected custom
claims, malformed authority capsules, and the absence of at least one canonical
approved Admin who is present and enabled in Auth require adjudication.

## Privacy and custody

No raw UID, email, name, custom-claim key, or custom-claim value is emitted.
Subjects are represented as:

```text
HMAC-SHA-256(secret audit key, namespace + stable subject identifier)
```

The key:

- must contain at least 32 UTF-8 bytes;
- is supplied through `CRM3_GATE1B_HMAC_KEY` or another named environment
  variable;
- is never accepted as a command-line value;
- is never written to evidence;
- must not be stored in Git or an evidence package.

Production reads additionally require an exact project confirmation, expected
source commit, expected source tree, clean worktree, complete Auth coverage, and
the absence of emulator hosts. The checked-out branch must be `main`, and its
HEAD must equal the locally fetched `origin/main` reference. Ambient
Google/Firebase project IDs may not disagree with the production project.

## Governed invocation template

This template is documentation, not authorization to execute it:

```powershell
$env:CRM3_GATE1B_HMAC_KEY = '<controlled secret with at least 32 bytes>'

node tools/v4/firestore_integrity_sweep.mjs `
  --project crm3-baf-ops-b8638 `
  --output '<controlled-new-path>\PRODUCTION_AUTHORITY_INVENTORY.json' `
  --allow-production-read-only `
  --confirm-project crm3-baf-ops-b8638 `
  --expected-source-commit '<reviewed 40-hex main commit>' `
  --expected-source-tree '<reviewed 40-hex main tree>'
```

The controlled output directory must already exist and be writable. The output
path and its `.sha256` sidecar must not already exist. These checks complete
before any cloud read begins, and evidence is never overwritten.

## Decisions

```text
PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY
HOLD_AUTHORITY_FINDINGS_REQUIRE_ADJUDICATION
HOLD_INCOMPLETE_AUTH_OR_FIRESTORE_COVERAGE
HOLD_PRIVACY_OR_CUSTODY_FAILURE
```

Only a complete Firestore/Auth/custom-claims inventory with no blocking
authority or reconciliation findings may pass. A pass does not authorize
deployment, pilot use, repair, equipment reconciliation, or cutover.

If findings exist, the next step is human adjudication and a
finding-specific, separately authorized repair design. This tranche contains
no repair executor.

## Production execution record

A separately authorized production read-only inventory completed on
2026-07-25 from `22:04:14.603Z` through `22:04:19.739Z`.

```text
project:                    crm3-baf-ops-b8638
source commit:              4e735615c9aca86916a4382d86009bf9ad07413d
source tree:                f6de5a98461e4a74971caecd4ecd67f68dc2c470
branch / origin parity:     main / exact
worktree:                   clean
Firestore users:            3 / COMPLETE
Firebase Auth users:        3 / COMPLETE
custom claims:              COMPLETE
joined subjects:            3
canonical approved:         3
enabled approved admins:    2
blocking findings:          0
decision:                   PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY
evidence SHA-256:           ABAB502C1C830336DC3EE72A576162652D801CF35692DA0877E8F46D2AEE9BA1
```

The retained evidence files are `PRODUCTION_AUTHORITY_INVENTORY.json` and its
`.sha256` sidecar. They are held outside the repository. The report contains
only namespaced HMAC-SHA256 subject pseudonyms; the HMAC key is protected
separately with Windows current-user DPAPI and is not present in the report.
Independent readback reproduced the sidecar digest, confirmed complete
Firestore/Auth/custom-claims coverage, and found no raw-identifier fields or
protected-key material.

This pass satisfies the S-05 note requiring a read-only Gate 1B production
authority classification. It does not authorize deployment, data repair,
equipment reconciliation, pilot use, or cutover.

## Source-tranche authorization boundary

The source tranche that introduced the classifier authorized:

```text
implementation
local unit/source validation
disposable Firestore/Auth emulator validation
feature-branch commit
draft pull request
```

Production Firestore and Firebase Auth reads were performed only under a
separate explicit operator authorization for the execution recorded above.
Neither that authorization nor the Gate 1B pass authorizes:

```text
production mutation
Firebase deployment
IAM change
App Check enforcement
pilot or cutover
```
