# Whole-App Source Atlas

- Source/config files inventoried: **320**
- Application Dart source (excluding generated): **250**
- Functions TypeScript source: **42**
- Test files indexed: **115**

## Risk-tag counts

- `lifecycle`: 227
- `sync`: 206
- `persistence`: 155
- `no_direct_test_reference`: 127
- `authority`: 97
- `medium_large`: 52
- `security_identity`: 49
- `many_remote_writes`: 43
- `large`: 31
- `serialization_hub`: 23
- `notification`: 12
- `platform_root`: 8
- `empty_catch`: 4

## Highest-priority source surfaces

| Score | File | Lines | Incoming | Tests | Tags |
|---:|---|---:|---:|---:|---|
| 42 | `lib/features/auth/providers/auth_provider.dart` | 232 | 36 | 5 | authority,persistence,sync,lifecycle,notification,security_identity,empty_catch |
| 41 | `lib/main.dart` | 1374 | 11 | 16 | authority,persistence,sync,lifecycle,notification,security_identity,platform_root,large |
| 40 | `lib/features/planned_maintenance/domain/module_composer_models.dart` | 1730 | 24 | 12 | authority,persistence,lifecycle,large,empty_catch,many_remote_writes,serialization_hub |
| 39 | `lib/features/planned_maintenance/data/job_template_model.dart` | 697 | 30 | 12 | authority,persistence,sync,lifecycle,medium_large,empty_catch,serialization_hub |
| 39 | `lib/features/planned_maintenance/providers/planned_maintenance_provider.dart` | 1894 | 17 | 6 | authority,persistence,sync,lifecycle,large,many_remote_writes,serialization_hub |
| 38 | `lib/features/auth/data/user_model.dart` | 567 | 32 | 17 | authority,persistence,sync,lifecycle,notification,security_identity,medium_large |
| 34 | `lib/features/planned_maintenance/data/template_governance_model.dart` | 814 | 15 | 12 | persistence,sync,lifecycle,security_identity,medium_large,serialization_hub |
| 34 | `lib/features/planned_maintenance/providers/template_governance_provider.dart` | 2331 | 6 | 6 | authority,persistence,sync,lifecycle,security_identity,large,many_remote_writes,serialization_hub |
| 33 | `lib/features/maintenance/data/maintenance_model.dart` | 247 | 59 | 34 | authority,persistence,sync,lifecycle,serialization_hub |
| 33 | `lib/features/maintenance/providers/maintenance_provider.dart` | 1708 | 11 | 7 | persistence,sync,lifecycle,large,empty_catch,many_remote_writes |
| 30 | `lib/features/planned_maintenance/data/job_module_model.dart` | 726 | 30 | 25 | persistence,sync,lifecycle,medium_large,serialization_hub |
| 30 | `lib/features/planned_maintenance/providers/job_module_provider.dart` | 1947 | 6 | 8 | authority,persistence,sync,lifecycle,large,many_remote_writes,serialization_hub |
| 30 | `firestore.rules` | 2743 | 0 | 12 | authority,persistence,sync,lifecycle,notification,security_identity,platform_root,large |
| 29 | `lib/features/directives/providers/operational_directive_provider.dart` | 1559 | 8 | 1 | authority,persistence,sync,lifecycle,large,many_remote_writes |
| 29 | `lib/features/planned_maintenance/domain/knowledge_governance_models.dart` | 504 | 7 | 1 | authority,persistence,sync,lifecycle,medium_large,many_remote_writes,serialization_hub |
| 28 | `lib/core/theme/baf_design_system.dart` | 141 | 58 | 0 | authority,sync,lifecycle,no_direct_test_reference |
| 28 | `lib/features/planned_maintenance/data/baf_knowledge_model.dart` | 434 | 11 | 0 | authority,persistence,sync,lifecycle,no_direct_test_reference |
| 28 | `lib/features/planned_maintenance/domain/baf_knowledge_repository.dart` | 760 | 6 | 4 | authority,persistence,sync,lifecycle,medium_large,many_remote_writes,serialization_hub |
| 28 | `functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts` | 148 | 1 | 0 | authority,persistence,sync,lifecycle,notification,security_identity,many_remote_writes,no_direct_test_reference |
| 27 | `lib/features/directives/data/operational_directive_model.dart` | 155 | 10 | 0 | authority,persistence,sync,lifecycle,no_direct_test_reference |
| 26 | `lib/features/audit/models/audit_event_model.dart` | 294 | 26 | 1 | persistence,sync,lifecycle |
| 26 | `lib/features/abnormalities/providers/abnormality_provider.dart` | 2193 | 6 | 1 | persistence,sync,lifecycle,large,many_remote_writes,serialization_hub |
| 26 | `lib/features/planned_maintenance/providers/knowledge_governance_provider.dart` | 667 | 5 | 0 | authority,persistence,sync,lifecycle,medium_large,many_remote_writes,no_direct_test_reference |
| 26 | `lib/features/admin/presentation/local_diagnostics_screen.dart` | 1518 | 2 | 2 | persistence,sync,lifecycle,security_identity,large,many_remote_writes,serialization_hub |
| 26 | `functions/src/publishedTemplateAssignment.ts` | 1905 | 1 | 3 | authority,persistence,sync,lifecycle,security_identity,large,many_remote_writes |
| 25 | `lib/features/abnormalities/data/abnormality_model.dart` | 893 | 8 | 0 | persistence,sync,lifecycle,medium_large,serialization_hub,no_direct_test_reference |
| 25 | `lib/features/planned_maintenance/services/planned_job_server_completion_service.dart` | 260 | 4 | 5 | authority,persistence,sync,lifecycle,many_remote_writes,serialization_hub |
| 24 | `functions/src/maintenanceWorkflow/types.ts` | 104 | 21 | 0 | authority,lifecycle,no_direct_test_reference |
| 24 | `functions/src/maintenanceWorkflow/errors.ts` | 33 | 15 | 0 | authority,lifecycle,no_direct_test_reference |
| 24 | `lib/features/maintenance_workflow/data/job_lane_record.dart` | 91 | 11 | 0 | persistence,sync,lifecycle,no_direct_test_reference |
| 24 | `lib/features/maintenance_workflow/data/workflow_event_record.dart` | 25 | 7 | 0 | authority,persistence,sync,lifecycle,no_direct_test_reference |
| 24 | `lib/features/planned_maintenance/data/baf_module_catalogue_seed.dart` | 1412 | 3 | 1 | persistence,sync,lifecycle,security_identity,large,serialization_hub |
| 24 | `functions/src/notifications.ts` | 437 | 2 | 1 | authority,persistence,sync,lifecycle,notification,security_identity |
| 23 | `lib/core/services/sync_coordinator.dart` | 617 | 26 | 2 | sync,lifecycle,medium_large |
| 23 | `lib/features/maintenance_workflow/domain/workflow_error.dart` | 42 | 14 | 0 | authority,lifecycle,no_direct_test_reference |
| 23 | `lib/features/planned_maintenance/presentation/complete_job_screen.dart` | 1931 | 2 | 2 | authority,persistence,sync,lifecycle,large,many_remote_writes |
| 23 | `functions/src/runtimeJobModulePopulation.ts` | 1844 | 2 | 5 | authority,persistence,sync,lifecycle,large,many_remote_writes |
| 23 | `lib/core/services/live_remote_sync_service.dart` | 862 | 2 | 0 | authority,persistence,sync,lifecycle,medium_large,many_remote_writes,no_direct_test_reference |
| 23 | `lib/features/planned_maintenance/presentation/template_publisher_sections.dart` | 1231 | 1 | 3 | authority,persistence,sync,lifecycle,security_identity,large |
| 23 | `lib/home_screen.dart` | 1207 | 1 | 2 | authority,sync,lifecycle,notification,platform_root,large |
| 23 | `lib/core/services/sync_service.executions.dart` | 600 | 1 | 2 | authority,persistence,sync,lifecycle,medium_large,many_remote_writes,serialization_hub |
| 22 | `lib/features/audit/repositories/audit_repository.dart` | 600 | 10 | 1 | persistence,sync,lifecycle,medium_large |
| 22 | `lib/features/maintenance_workflow/data/compliance_request_record.dart` | 99 | 9 | 0 | persistence,sync,lifecycle,no_direct_test_reference |
| 22 | `lib/features/planned_maintenance/services/published_template_assignment_server_service.dart` | 296 | 3 | 1 | authority,persistence,sync,lifecycle,security_identity |
| 22 | `lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart` | 1219 | 1 | 4 | authority,persistence,sync,lifecycle,large,many_remote_writes |
| 22 | `functions/src/maintenanceWorkflow/callable.ts` | 111 | 1 | 0 | authority,persistence,sync,lifecycle,security_identity,no_direct_test_reference |
| 22 | `functions/src/index.ts` | 327 | 0 | 6 | authority,persistence,sync,lifecycle,notification,security_identity |
| 22 | `tools/maintenance_workflow/full_tree_source_audit.py` | 306 | 0 | 0 | authority,persistence,sync,lifecycle,notification,security_identity |
| 21 | `lib/features/planned_maintenance/models/component_action_model.dart` | 233 | 11 | 2 | persistence,lifecycle,serialization_hub |
| 21 | `lib/features/maintenance_workflow/providers/workflow_providers.dart` | 127 | 10 | 1 | persistence,sync,lifecycle |
| 21 | `functions/src/backendReleaseIdentity.ts` | 166 | 2 | 2 | authority,persistence,sync,lifecycle,security_identity |
| 21 | `functions/src/plannedJobClosure.ts` | 861 | 1 | 3 | authority,persistence,sync,lifecycle,security_identity,medium_large |
| 21 | `functions/src/maintenanceWorkflow/complianceHandlers.ts` | 454 | 1 | 0 | authority,sync,lifecycle,security_identity,many_remote_writes,no_direct_test_reference |
| 21 | `functions/src/maintenanceWorkflow/laneHandlers.ts` | 292 | 1 | 0 | authority,sync,lifecycle,security_identity,many_remote_writes,no_direct_test_reference |
| 20 | `lib/features/audit/providers/audit_provider.dart` | 15 | 11 | 0 | sync,lifecycle,no_direct_test_reference |
| 20 | `lib/features/planned_maintenance/domain/baf_knowledge_layer.dart` | 113 | 9 | 4 | persistence,sync,lifecycle |
| 20 | `lib/core/services/app_logger.dart` | 326 | 8 | 1 | authority,sync,security_identity |
| 20 | `lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart` | 770 | 2 | 0 | authority,persistence,sync,lifecycle,medium_large,no_direct_test_reference |
| 20 | `lib/core/services/sync_service.template_governance.dart` | 966 | 1 | 2 | persistence,sync,lifecycle,security_identity,medium_large,many_remote_writes |
| 20 | `functions/src/backendReleaseIdentityComposite.ts` | 249 | 1 | 1 | authority,persistence,sync,lifecycle,security_identity |
| 20 | `lib/core/release/backend_release_identity_service.dart` | 169 | 1 | 1 | authority,persistence,sync,lifecycle,security_identity |
| 20 | `tools/release/Test-ProductionReleaseManifest.ps1` | 829 | 0 | 1 | authority,persistence,sync,lifecycle,security_identity,medium_large |
| 19 | `lib/features/maintenance_workflow/domain/maintenance_lane.dart` | 119 | 12 | 5 | authority,lifecycle |
| 19 | `lib/features/planned_maintenance/data/job_diary_model.dart` | 439 | 8 | 4 | persistence,sync,lifecycle |
| 19 | `lib/features/maintenance_workflow/data/equipment_status_record.dart` | 36 | 6 | 0 | persistence,sync,lifecycle,no_direct_test_reference |
| 19 | `lib/features/maintenance_workflow/services/workflow_command_gateway.dart` | 75 | 2 | 0 | authority,persistence,sync,lifecycle,no_direct_test_reference |
| 19 | `lib/features/planned_maintenance/presentation/job_module_detail_screen.dart` | 1869 | 1 | 4 | authority,persistence,sync,lifecycle,large |
| 19 | `lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart` | 1394 | 1 | 2 | persistence,sync,lifecycle,security_identity,large |
| 19 | `lib/core/widgets/sync_status_indicator.dart` | 1313 | 1 | 2 | authority,persistence,sync,lifecycle,large |
| 19 | `lib/features/planned_maintenance/presentation/module_composer_dialogs.dart` | 1090 | 1 | 4 | authority,persistence,sync,lifecycle,large |
| 19 | `lib/features/admin/presentation/user_management_screen.dart` | 873 | 1 | 0 | authority,persistence,sync,lifecycle,medium_large,no_direct_test_reference |
| 19 | `lib/features/planned_maintenance/providers/module_registry_provider.dart` | 756 | 1 | 1 | persistence,sync,lifecycle,medium_large,many_remote_writes,serialization_hub |
| 19 | `lib/core/services/sync_service.job_modules.dart` | 592 | 1 | 3 | persistence,sync,lifecycle,medium_large,many_remote_writes,serialization_hub |
| 19 | `lib/core/services/sync_service.push_infrastructure.dart` | 439 | 1 | 2 | authority,persistence,sync,lifecycle,many_remote_writes |
| 19 | `.github/workflows/production-artifact.yml` | 387 | 0 | 1 | authority,persistence,sync,lifecycle,security_identity |
| 19 | `.github/workflows/release-gate.yml` | 258 | 0 | 2 | authority,persistence,sync,lifecycle,security_identity |
| 18 | `lib/features/maintenance_workflow/domain/workflow_types.dart` | 63 | 19 | 4 | lifecycle |
| 18 | `lib/features/maintenance_workflow/data/workflow_command_record.dart` | 36 | 5 | 0 | persistence,sync,lifecycle,no_direct_test_reference |
| 18 | `lib/features/planned_maintenance/providers/job_diary_provider.dart` | 930 | 3 | 2 | persistence,sync,lifecycle,medium_large,serialization_hub |
| 18 | `functions/src/maintenanceWorkflow/finalizeJobHandler.ts` | 373 | 1 | 0 | authority,persistence,sync,lifecycle,no_direct_test_reference |
