# v4.2 → v4.2_R1 Authored Delta

Patch-authored paths: **31**

```text
A	V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_IMPLEMENTATION_REPORT.md
A	V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_RESIDUAL_GATES.md
M	docs/v4_2/CURRENT_PRE_V4_SOURCE_AUTHORITY_RECONCILIATION.md
A	docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md
A	docs/v4_2_r1/CANONICAL_ISAR_SCHEMA_BASELINE.json
A	docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json
A	docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.md
A	docs/v4_2_r1/CANONICAL_MAIN_SOURCE_MANIFEST.json
A	docs/v4_2_r1/CLEAN_CUTOVER_AND_ROLLBACK_POLICY.md
A	docs/v4_2_r1/LOCAL_ONLY_57BE731_ADJUDICATION.md
A	docs/v4_2_r1/STAGING_AND_LIVE_ROLLBACK_PLAN.md
M	functions/src/backendReleaseIdentity.ts
M	functions/src/maintenanceWorkflow/callable.ts
M	functions/src/notifications.ts
M	functions/src/plannedJobClosure.ts
M	functions/src/publishedTemplateAssignment.ts
M	functions/src/runtimeJobModulePopulation.ts
A	functions/src/userAuthority.ts
M	functions/test/backendReleaseIdentity.test.js
M	functions/test/notifications.test.js
M	functions/test/plannedJobClosure.test.js
A	functions/test/userAuthority.test.js
M	governance/v4_successor_programme_authority_v1.json
A	tools/isar/verify_canonical_main_isar_continuity.py
M	tools/maintenance_workflow/full_tree_source_audit.py
A	tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1
A	tools/v4/firestore_integrity_sweep.mjs
A	tools/v4/firestore_integrity_sweep.test.mjs
A	tools/v4/trial_workspace_custody.py
A	tools/v4/v4_2_r1_canonical_audit.py
M	tools/v4/v4_2_ultimate_audit.py
```

## Diff stat

```text
.../CRM3_APP_V4_2_R1_IMPLEMENTATION_REPORT.md      |   35 +
 V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_RESIDUAL_GATES.md |   31 +
 ...RRENT_PRE_V4_SOURCE_AUTHORITY_RECONCILIATION.md |    4 +-
 docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md    |  103 +
 docs/v4_2_r1/CANONICAL_ISAR_SCHEMA_BASELINE.json   | 3551 ++++++++++++++++++++
 docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json    | 3304 ++++++++++++++++++
 docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.md      |   66 +
 docs/v4_2_r1/CANONICAL_MAIN_SOURCE_MANIFEST.json   | 1650 +++++++++
 docs/v4_2_r1/CLEAN_CUTOVER_AND_ROLLBACK_POLICY.md  |   43 +
 docs/v4_2_r1/LOCAL_ONLY_57BE731_ADJUDICATION.md    |   31 +
 docs/v4_2_r1/STAGING_AND_LIVE_ROLLBACK_PLAN.md     |   60 +
 functions/src/backendReleaseIdentity.ts            |    8 +-
 functions/src/maintenanceWorkflow/callable.ts      |   25 +-
 functions/src/notifications.ts                     |   14 +-
 functions/src/plannedJobClosure.ts                 |    8 +-
 functions/src/publishedTemplateAssignment.ts       |    8 +-
 functions/src/runtimeJobModulePopulation.ts        |   21 +-
 functions/src/userAuthority.ts                     |   57 +
 functions/test/backendReleaseIdentity.test.js      |   24 +
 functions/test/notifications.test.js               |   10 +
 functions/test/plannedJobClosure.test.js           |    2 +
 functions/test/userAuthority.test.js               |   52 +
 .../v4_successor_programme_authority_v1.json       |   44 +-
 .../isar/verify_canonical_main_isar_continuity.py  |  213 ++
 .../maintenance_workflow/full_tree_source_audit.py |    4 +-
 tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1     |  484 +++
 tools/v4/firestore_integrity_sweep.mjs             |  185 +
 tools/v4/firestore_integrity_sweep.test.mjs        |   38 +
 tools/v4/trial_workspace_custody.py                |  162 +
 tools/v4/v4_2_r1_canonical_audit.py                |  234 ++
 tools/v4/v4_2_ultimate_audit.py                    |   14 +-
 31 files changed, 10409 insertions(+), 76 deletions(-)
```

Packaging-only files such as the final manifest, reconstruction proof and validation log are generated after this authored patch and are not self-included.
