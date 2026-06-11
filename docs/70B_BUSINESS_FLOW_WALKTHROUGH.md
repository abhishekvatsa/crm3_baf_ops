# 70B — Business Flow Walkthrough

## Purpose

This document documents the planned-maintenance business flow and prepares the manual walkthrough after 70A TemplateVersion Publish Replay.

70B is a business-flow clarity and acceptance walkthrough. It is not a broad refactor.

## Route Under Walkthrough

Composer → Registry → TemplateVersion → Assignment → Runtime JobModuleInstance → Submit → Accept → Closure → Diagnostics

## Starting State

- Branch: chore/70b-business-flow-walkthrough

- Base commit: fe8c008

- 70A TemplateVersion Publish Replay is already merged into main.

## Business Flow Map

### 1. Authoring

Primary surfaces:

- module_composer_screen.*

- module_composer_models.dart

- module_composer_json_builder.dart

- module_composer_validator.dart

- module_workshop_screen.dart

- module_editor_screen.dart

Purpose:

A user can author or edit a reusable maintenance module draft.

Status: Pending manual walkthrough.

### 2. Registry Governance

Primary surfaces:

- module_registry_authoring_screen.dart

- module_registry_model.dart

- module_registry_provider.dart

- module_registry_content_hash.dart

Purpose:

Reusable modules can enter governed registry families and revisions.

Status: Pending manual walkthrough.

### 3. TemplateVersion Governance

Primary surfaces:

- template_governance_model.dart

- template_governance_provider.dart

- template_publisher_screen.*

- template_version_snapshot_contract.dart

- publish_metadata_builder.dart

Purpose:

A complete maintenance template can be frozen into a published TemplateVersion.

Status: 70A source replay tests passed; pending manual device walkthrough.

### 4. Assignment

Primary surfaces:

- published_template_assignment_screen.dart

- template_version_assignment_builder.dart

- job_template_model.dart

- assign_job_screen.dart

Purpose:

A published TemplateVersion can create a real planned-maintenance JobExecution.

Status: Pending manual walkthrough.

### 5. Runtime Execution

Primary surfaces:

- job_module_model.dart

- job_module_provider.dart

- planned_job_detail_screen.dart

- job_module_detail_screen.dart

- job_module_response_form.dart

- runtime_module_lineage.dart

- published_runtime_module_catalogue.dart

Purpose:

A field user performs work through runtime JobModuleInstance records.

Status: Pending manual walkthrough.

### 6. Submit / Accept

Primary surfaces:

- job_module_detail_screen.dart

- job_module_provider.dart

- sync_service.job_modules.dart

Purpose:

Module work can be submitted and accepted with audit identity.

Status: Pending manual walkthrough.

### 7. Closure

Primary surfaces:

- complete_job_screen.dart

- planned_job_closure_guard.dart

- planned_job_closure_attestation.dart

- planned_job_server_completion_service.dart

- sync_service.executions.dart

Purpose:

A job can be closed only after required modules and evidence satisfy closure conditions. Final completion must go through server completion, not direct Firestore write.

Status: Pending manual walkthrough.

### 8. Diagnostics

Primary surfaces:

- sync_status_indicator.dart

- local_diagnostics_screen.dart

- sync_service.*

- global_pull_service.*

Purpose:

Users/admins can see pending, failed, rejected, synced, and replay states without false success.

Status: Pending manual walkthrough.

## Initial Finding

Initial source-surface discovery confirms that planned maintenance has distinct surfaces for authoring, governance, assignment, runtime execution, submit/accept supervision, server-governed closure, and diagnostics.

No code change is justified yet.

## Existing Test Evidence

The following existing tests support the 70B business-flow walkthrough:

- Composer / authoring: module_composer_alias_rehydration_test.dart; module_composer_hardening_contract_test.dart; module_editor_screen_test.dart; module_workshop_actions_test.dart; module_workshop_merge_test.dart; module_workshop_screen_test.dart.
- Module Registry: module_registry_authoring_hardening_contract_test.dart; module_registry_authoring_screen_test.dart; module_registry_content_hash_test.dart; module_registry_lifecycle_contract_test.dart; module_registry_model_test.dart; module_workshop_published_sources_test.dart.
- TemplateVersion governance: template_governance_lifecycle_replay_contract_test.dart; template_version_snapshot_contract_test.dart; published_template_runtime_contract_test.dart.
- Published runtime catalogue / lineage: published_runtime_module_catalogue_test.dart; runtime_add_module_governance_contract_test.dart; runtime_add_module_governed_catalogue_contract_test.dart; runtime_module_lineage_visibility_contract_test.dart.
- JobModule runtime lifecycle: job_module_lifecycle_replay_contract_test.dart; job_module_rules.test.js; operator_runtime_ux_polish_contract_test.dart.
- Closure guard / attestation: planned_job_closure_guard_test.dart; planned_job_closure_attestation_test.dart; complete_job_screen_server_gate_test.dart.
- Server completion / no-loss: planned_job_server_completion_service_test.dart; planned_job_server_completion_no_loss_test.dart.
- Static guardrails: lifecycle_static_guardrail_contract_test.dart; firestore_deployment_readiness_contract_test.dart.

## 70B Decision

Based on source-surface discovery and existing test coverage, 70B is currently a documentation and business-flow clarity change.

No production code change is justified at this stage.

70B should remain docs-only unless a later manual walkthrough exposes a direct business-flow gap.

## Manual Device Walkthrough Ledger

This section is the field-device gate for 70B. It must be executed on a physical Android device or tablet before claiming business-flow verification.

| Stage | Precondition | Manual actions | Acceptance evidence | Result | Date / device |
|---|---|---|---|---|---|
| Composer / authoring | User has authoring access and offline-capable device state is known. | Create or edit a maintenance module draft; save locally; reconnect if offline was used. | Draft is visible after restart/reopen; diagnostics do not show false success. | Pending | Pending |
| Registry governance | Governor/SI role available; module draft exists. | Promote module into governed registry revision; verify content hash/frozen revision behavior. | Registry revision appears with expected status and no mutable published content. | Pending | Pending |
| TemplateVersion governance / 70A replay | Template package exists; device can go offline. | Publish a TemplateVersion while offline or weak-networked; reconnect; trigger sync. | Remote state reaches published through replay; diagnostics show success/replay completion; no false failure. | Pending | Pending |
| Assignment | Published TemplateVersion exists. | Assign published TemplateVersion to a planned JobExecution. | JobExecution carries TemplateVersion lineage and expected runtime module instances. | Pending | Pending |
| Runtime execution | Assigned job exists with modules. | Open job; enter module responses/evidence; save progress. | JobModuleInstance records preserve response/evidence state after restart and sync. | Pending | Pending |
| Submit / Accept | Runtime module has completed response/evidence. | Submit as eligible discipline user; accept as eligible reviewer/supervisor. | Module reaches accepted state with submitted/accepted identity and timestamps. | Pending | Pending |
| Closure | Job has accepted required modules. | Attempt completion through normal UI. | Completion goes through server-governed path; closure rejection, if any, is actionable and visible. | Pending | Pending |
| Diagnostics | Pending/replay/sync activity exists. | Inspect diagnostics during and after sync. | Pending, failed, replayed, and successful states are visible without false UI success. | Pending | Pending |

## Score Impact

This 70B document improves business-flow clarity but does not by itself raise release readiness materially.

The score should move only after the Manual Device Walkthrough Ledger is executed with recorded pass/fail evidence on a physical device.
