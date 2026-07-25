# v4.2_R1.4 Changed Files

R1.4 is a bounded Firebase CLI tooling and laboratory-governance correction over R1.3.

## Dependency custody

- `tooling/firebase-cli/package.json`
  - `@hono/node-server`: `2.0.5` → `1.19.14`
  - `fast-uri`: `3.1.3` → `3.1.4`
  - `firebase-tools` remains `15.22.4`.
- `tooling/firebase-cli/package-lock.json`
  - only the corresponding installed package records change, with exact public npm URLs and integrity values.

## Laboratory and audits

- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
  - adds pre-install lock-policy verification;
  - adds post-install exact-version verification;
  - retains strict tooling audit;
  - adds precise HOLD outcomes;
  - renumbers downstream gates and R1.4 evidence naming.
- `tools/v4/v4_2_r1_canonical_audit.py`
  - proves the exact tooling policy and harness gates.
- `tools/v4/v4_2_ultimate_audit.py`
  - advances the inherited tooling expectation to the R1.4 versions.

## Documentation and evidence

- `docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json`
  - updates only the hashes of the two canonical-captured tooling files.
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_4_FIREBASE_CLI_DEPENDENCY_HOTFIX.md`
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_4_VALIDATION.md`
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_4_CHANGED_FILES.md`

## Explicitly unchanged

No Flutter source, Functions source, Firestore Rules, Isar model/binding source, Android configuration, workflow policy, programme ledger, or release authority changed from R1.3.
