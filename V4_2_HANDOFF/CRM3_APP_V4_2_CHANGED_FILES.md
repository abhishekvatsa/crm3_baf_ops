# CRM3 v4.1 → v4.2 Changed-File Register

This register covers the 33 patch-authored source and documentation paths. The binary-safe patch, reconstruction proof, final manifest and package verification are derived custody artifacts and are intentionally excluded from their own patch.

```text
M	README.md
A	V4_2_HANDOFF/CRM3_APP_V4_2_CRITIQUE_ADJUDICATION.md
A	V4_2_HANDOFF/CRM3_APP_V4_2_RESIDUAL_GATES.md
A	V4_2_HANDOFF/CRM3_APP_V4_2_ULTIMATE_IMPLEMENTATION_REPORT.md
A	V4_2_HANDOFF/CRM3_APP_V4_2_VALIDATION_LOG.md
A	docs/v4_2/CURRENT_PRE_V4_SOURCE_AUTHORITY_RECONCILIATION.md
A	docs/v4_2/ISAR_SCHEMA_CONTINUITY.json
A	docs/v4_2/PROGRAMME_AUTHORITY.md
A	docs/v4_2/TOMORROW_LOCAL_TRIAL_RUNBOOK.md
M	firestore.rules
M	functions/package-lock.json
M	functions/src/maintenanceWorkflow/callable.ts
M	functions/src/maintenanceWorkflow/firebaseStore.ts
A	functions/test/maintenanceWorkflowCallableAuthority.test.js
M	functions/test/maintenanceWorkflowFirebaseStore.test.js
M	functions/test/stage2dSecuritySource.test.js
M	functions/test/userRulesHardeningSource.test.js
A	governance/v4_successor_programme_authority_v1.json
M	lib/features/auth/data/user_model.dart
M	lib/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart
M	package-lock.json
M	package.json
M	release/production-release-policy.json
M	test/maintenance_workflow/compliance_request_mapper_test.dart
A	test/user_authority_schema_test.dart
M	tooling/firebase-cli/package-lock.json
M	tooling/firebase-cli/package.json
M	tools/release/Test-ProductionReleasePolicy.ps1
A	tools/v4/Invoke-Crm3V42LocalTrial.ps1
M	tools/v4/v4_1_due_diligence_audit.py
A	tools/v4/v4_2_ultimate_audit.py
A	tools/v4/verify_file_manifest.py
M	tools/v4/whole_app_reconciliation_audit.py
```

## Diff statistics

```text
 README.md                                          |  26 +-
 .../CRM3_APP_V4_2_CRITIQUE_ADJUDICATION.md         |  31 ++
 V4_2_HANDOFF/CRM3_APP_V4_2_RESIDUAL_GATES.md       |  44 +++
 ...CRM3_APP_V4_2_ULTIMATE_IMPLEMENTATION_REPORT.md | 103 +++++++
 V4_2_HANDOFF/CRM3_APP_V4_2_VALIDATION_LOG.md       |  48 ++++
 ...RRENT_PRE_V4_SOURCE_AUTHORITY_RECONCILIATION.md | 120 ++++++++
 docs/v4_2/ISAR_SCHEMA_CONTINUITY.json              | 286 +++++++++++++++++++
 docs/v4_2/PROGRAMME_AUTHORITY.md                   |  14 +
 docs/v4_2/TOMORROW_LOCAL_TRIAL_RUNBOOK.md          | 151 ++++++++++
 firestore.rules                                    | 121 ++++----
 functions/package-lock.json                        |  21 +-
 functions/src/maintenanceWorkflow/callable.ts      |  47 ++-
 functions/src/maintenanceWorkflow/firebaseStore.ts |  11 +
 .../maintenanceWorkflowCallableAuthority.test.js   |  39 +++
 .../test/maintenanceWorkflowFirebaseStore.test.js  |  84 ++++++
 functions/test/stage2dSecuritySource.test.js       |   6 +-
 functions/test/userRulesHardeningSource.test.js    |  50 +++-
 .../v4_successor_programme_authority_v1.json       |  59 ++++
 lib/features/auth/data/user_model.dart             |  22 +-
 .../firestore_workflow_read_repository.dart        | 242 ++++++++++------
 package-lock.json                                  |  20 +-
 package.json                                       |   2 +-
 release/production-release-policy.json             |   9 +-
 .../compliance_request_mapper_test.dart            |  47 +++
 test/user_authority_schema_test.dart               |  54 ++++
 tooling/firebase-cli/package-lock.json             | 206 +++++++++-----
 tooling/firebase-cli/package.json                  |   9 +-
 tools/release/Test-ProductionReleasePolicy.ps1     |   2 +-
 tools/v4/Invoke-Crm3V42LocalTrial.ps1              | 316 +++++++++++++++++++++
 tools/v4/v4_1_due_diligence_audit.py               |  17 +-
 tools/v4/v4_2_ultimate_audit.py                    | 291 +++++++++++++++++++
 tools/v4/verify_file_manifest.py                   |  61 ++++
 tools/v4/whole_app_reconciliation_audit.py         |   9 +-
 33 files changed, 2283 insertions(+), 285 deletions(-)
```
