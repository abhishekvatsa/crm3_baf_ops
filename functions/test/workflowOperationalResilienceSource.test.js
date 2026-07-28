const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

describe('workflow operational resilience source contract', () => {
  test('remote workflow mapping quarantines malformed documents per record', () => {
    const remote = read('lib/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart');
    expect(remote).toContain('class WorkflowRemoteFailure');
    expect(remote).toContain('class WorkflowRemoteBatch<T>');
    expect(remote).toContain('for (final document in page.docs)');
    expect(remote).toContain('records.add(map(document))');
    expect(remote).toContain('WorkflowRemoteFailure(');
    expect(remote).toContain('observedTimestamps');
  });

  test('pull service isolates local upsert failures and retains bounded diagnostics', () => {
    const pull = read('lib/features/maintenance_workflow/services/workflow_pull_service.dart');
    expect(pull).toContain("stage: 'remote-map'");
    expect(pull).toContain("stage: 'local-upsert'");
    expect(pull).toContain('_maxQuarantineRecords = 100');
    expect(pull).toContain('readQuarantine()');
    expect(pull).toContain('clearQuarantine()');
    expect(pull).toContain("'a failed record had no valid server timestamp'");
    expect(pull).toContain("if (localUpsertFailed) 'a local upsert failed'");
    expect(pull).toContain('if (!unknownFailureTimestamp && !localUpsertFailed)');
  });

  test('workflow mutations use serialized equipment counters instead of query-then-write', () => {
    const facts = read('functions/src/maintenanceWorkflow/equipmentFacts.ts');
    const equipment = read('functions/src/maintenanceWorkflow/equipmentHandlers.ts');
    const mutators = [
      'jobCreationHandler.ts',
      'finalizeJobHandler.ts',
      'redHandlers.ts',
      'laneHandlers.ts',
      'complianceHandlers.ts',
    ];

    expect(facts).toContain('equipmentFactsFromProjection');
    expect(facts).toContain('withoutWorkflowContribution');
    expect(facts).toContain('equipmentProjectionCounterFields');
    expect(facts).toContain('Object.prototype.hasOwnProperty.call');
    expect(facts).toContain('equipment-projection-missing');
    expect(facts).toContain('equipment-projection-counter-set-incomplete');
    expect(facts).not.toContain('if (value == null) return 0');
    expect(equipment).toContain('loadEquipmentFacts');
    for (const file of mutators) {
      const source = read(`functions/src/maintenanceWorkflow/${file}`);
      expect(source).toContain('equipmentFactsFromProjection');
      expect(source).not.toContain('loadEquipmentFacts');
    }
  });

  test('R1.16 cutover requires governed equipment projection reconciliation', () => {
    const authority = read('docs/v4_2_r1/FIREBASE_COMBINED_AUTHORITY_RECONCILIATION.md');
    expect(authority).toContain('Equipment projection pilot/cutover prerequisite');
    expect(authority).toContain('Workflow mutations must remain disabled');
    expect(authority).toContain('run the Admin/SI `reconcileEquipment` command');
    expect(authority).toContain('contains all three non-negative safe-integer counters');
    expect(authority).toContain('zero unresolved exceptions');
    expect(authority).toContain('ordinary job creation cannot initialize an unknown projection');
  });

  test('Admin/SI workflow diagnostics exposes quarantine and uncertain commands read-only', () => {
    const user = read('lib/features/auth/data/user_model.dart');
    const hub = read('lib/features/maintenance_workflow/presentation/screens/workflow_hub_screen.dart');
    const screen = read('lib/features/maintenance_workflow/presentation/screens/workflow_diagnostics_screen.dart');
    const repository = read('lib/features/maintenance_workflow/repositories/workflow_repository.dart');
    expect(user).toContain('canViewMaintenanceWorkflowDiagnostics');
    expect(user).toContain('isApproved && (isAdmin || isSI)');
    expect(hub).toContain('WorkflowDiagnosticsScreen');
    expect(hub).toContain('canViewMaintenanceWorkflowDiagnostics');
    expect(repository).toContain('getPendingCommands()');
    expect(screen).toContain('WorkflowPullService.readQuarantine()');
    expect(screen).toContain('getPendingCommands()');
    expect(screen).toContain('This page is diagnostic only');
    expect(screen).not.toContain('retryDueCommands');
  });

  test('workflow callable shares default-off mutating App Check policy', () => {
    const callable = read('functions/src/maintenanceWorkflow/callable.ts');
    const security = read('functions/src/callableSecurityConfig.ts');
    const client = read('lib/core/security/app_check_bootstrap.dart');
    expect(callable).toContain('MUTATING_CALLABLE_SECURITY_OPTIONS');
    expect(security).toContain('CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK');
    expect(security).toContain('default: false');
    expect(security).toContain(
      'enforceAppCheck: MUTATING_CALLABLE_ENFORCE_APP_CHECK',
    );
    expect(client).toContain('CRM3_APP_CHECK_ENABLED');
    expect(client).toContain('AndroidPlayIntegrityProvider');
  });

  test('workflow history links canonical events to original execution audit evidence', () => {
    const panel = read('lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart');
    const closure = read('functions/src/maintenanceWorkflow/canonicalClosure.ts');
    const lanes = read('functions/src/maintenanceWorkflow/laneHandlers.ts');
    const modules = read('functions/src/maintenanceWorkflow/moduleLifecycleHandlers.ts');
    expect(panel).toContain('AuditTimelineScreen');
    expect(panel).toContain("entityType: 'execution'");
    expect(panel).toContain('workflow.jobExecutionFirestoreId');
    expect(closure).toContain('workflowAggregateId: args.workflowAggregateId');
    expect(lanes).toContain('workflowAggregateId: command.aggregateId');
    expect(modules).toContain('workflowAggregateId: command.aggregateId');
  });

  test('escalation re-reads eligible state transactionally and terminal tier leaves the query', () => {
    const sweep = read('functions/src/maintenanceWorkflow/escalationSweep.ts');
    const policy = read('functions/src/maintenanceWorkflow/escalationPolicy.ts');
    expect(sweep).toContain('db.runTransaction');
    expect(sweep).toContain('const source = await tx.get(candidate.ref)');
    expect(sweep).toContain('sourceIsStillEligible');
    expect(sweep).toContain('existingEvent = await tx.get(eventRef)');
    expect(sweep).toContain('MAX_PER_QUERY_PER_SWEEP = 1000');
    expect(policy).toContain('nextTier >= MAX_ESCALATION_TIER');
    expect(policy).toContain('? null');
  });
});
