import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_json_builder.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/planned_job_closure_guard.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/published_runtime_module_catalogue.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_version_snapshot_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Published template runtime contract', () {
    test(
      'carries Composer output through published catalogue, runtime module, and closure guard',
      () {
        final draft = _composerDraft();
        final output = ModuleComposerJsonBuilder.build(draft);

        final bundle = TemplateVersionSnapshotBundle.fromRawJson(
          jobTemplateSnapshotJson: output.jobTemplateSnapshotJson,
          moduleSnapshotsJson: output.moduleSnapshotsJson,
          fieldDefinitionsJson: output.fieldDefinitionsJson,
          checklistJson: output.checklistJson,
        );
        final validation = bundle.validate();

        expect(validation.errors, isEmpty);
        expect(bundle.closureCriticalModuleCount, 1);
        expect(bundle.closureReviewConfirmed, isTrue);

        final version = _publishedVersionFrom(output);
        version.refreshContentHash();

        expect(version.contentHash, startsWith('tg2-sha256:'));
        expect(version.closureReviewConfirmed, isTrue);
        expect(version.closureCriticalModuleCount, 1);

        final candidates = publishedRuntimeModuleCandidatesFromVersion(
          version: version,
          package: _package(),
          assetType: AssetType.base,
        );

        expect(candidates, hasLength(1));
        final candidate = candidates.single;
        expect(candidate.moduleCode, 'B-66A-GAS');
        expect(candidate.moduleTitle, '66A gas permissive verification');
        expect(candidate.requiredForClosure, isTrue);
        expect(candidate.safetyClass, JobModuleSafetyClass.gasRisk);
        expect(candidate.requiresElevatedRuntimeAddControl(), isTrue);
        expect(candidate.fieldDefinitionsJson, contains('gas_pressure_ok'));
        expect(
          candidate.moduleSnapshotJson,
          contains('66A gas permissive verification'),
        );

        final runtimeModule = candidate.toJobModuleInstance(
          execution: _execution(),
          actor: _actor(),
          now: DateTime.utc(2026, 5, 21, 10),
          addReason: '66A governed runtime proof',
        );

        expect(runtimeModule.addedDuringExecution, isTrue);
        expect(runtimeModule.templatePackageId, 'package_66a');
        expect(runtimeModule.templateVersionId, 'version_66a');
        expect(runtimeModule.templateModuleId, 'B-66A-GAS');
        expect(runtimeModule.requiredForClosure, isTrue);
        expect(
          runtimeModule.metadataJson,
          contains('published_template_version_runtime_add'),
        );
        expect(runtimeModule.metadataJson, contains(version.contentHash!));

        final openIssues = PlannedJobClosureGuard.collectIssues([
          runtimeModule,
        ]);
        expect(
          openIssues.map((issue) => issue.type),
          contains(PlannedJobClosureIssueType.openRequiredModule),
        );

        runtimeModule
          ..firestoreId = 'job_module_66a'
          ..status = JobModuleStatus.accepted
          ..responses = [
            FieldResponse(
              key: 'gas_pressure_ok',
              fieldLabel: 'Gas pressure verified',
              fieldType: FieldType.yesNo,
              value: true,
            ),
          ];

        expect(PlannedJobClosureGuard.collectIssues([runtimeModule]), isEmpty);

        final attestation = PlannedJobClosureGuard.assertReadyAndAttest(
          executionFirestoreId: 'execution_66a',
          modules: [runtimeModule],
          completedByUid: 'si_1',
          completedByName: 'Senior Inspector',
          completedAt: DateTime.utc(2026, 5, 21, 11),
          executionVersionAtCompletion: 7,
        );

        expect(attestation.hash, hasLength(64));
        expect(
          attestation.payload['moduleCounts'],
          containsPair('requiredForClosure', 1),
        );
        expect(attestation.canonicalJson, contains('job_module_66a'));
      },
    );
  });
}

TemplateComposerDraft _composerDraft() {
  final module =
      ComposerModuleDraft.manual(assetType: AssetType.base)
        ..moduleCode = 'B-66A-GAS'
        ..title = '66A gas permissive verification'
        ..description = 'Verify gas-related permissive before closure.'
        ..discipline = JobModuleDiscipline.shared
        ..ownerDisciplines = const <String>['operations', 'instrumentation']
        ..primaryOwner = 'operations'
        ..requiresJointReview = true
        ..useMode = JobModuleUseMode.scheduledPM
        ..functionalSection = 'BAF safety interlocks'
        ..componentGroup = 'Gas permissive'
        ..subsystem = 'H2/O2 safety'
        ..safetyClasses = const <String>['gasRisk']
        ..targetRefs = const <String>['BAF-BASE-01']
        ..deviceTagRefs = const <String>['PT-GAS-66A']
        ..procedureRefs = const <String>['PROC-66A-GAS']
        ..operationalStatePreconditions = const <String>['isolated', 'purged']
        ..requiredForClosure = true
        ..fields = [
          ComposerFieldDraft(
            key: 'gas_pressure_ok',
            label: 'Gas pressure verified',
            type: ComposerFieldType.yesNo,
            isRequired: true,
            order: 1,
            instructionText:
                'Confirm gas pressure is within safe permissive range.',
          ),
        ]
        ..checklistItems = [
          ComposerChecklistItemDraft(
            id: 'gas-pressure-check',
            title: 'Confirm gas pressure evidence is captured',
            isRequired: true,
            order: 1,
            linkedFieldKey: 'gas_pressure_ok',
            safetyClasses: const <String>['gasRisk'],
          ),
        ];

  return TemplateComposerDraft(
    title: '66A governed runtime proof template',
    assetType: AssetType.base,
    modules: [module],
    closureReviewConfirmed: true,
    metadata: <String, dynamic>{
      'closureReviewConfirmedAt':
          DateTime.utc(2026, 5, 21, 9).toIso8601String(),
      'closureReviewConfirmedByUid': 'si_1',
      'closureReviewConfirmedByName': 'Senior Inspector',
    },
  );
}

TemplateVersion _publishedVersionFrom(TemplateComposerOutput output) {
  return TemplateVersion()
    ..firestoreId = 'version_66a'
    ..packageFirestoreId = 'package_66a'
    ..versionNumber = 1
    ..versionLabel = '66A runtime proof'
    ..status = TemplateVersionStatus.published
    ..jobTemplateSnapshotJson = output.jobTemplateSnapshotJson
    ..moduleSnapshotsJson = output.moduleSnapshotsJson
    ..fieldDefinitionsJson = output.fieldDefinitionsJson
    ..checklistJson = output.checklistJson
    ..createdAt = DateTime.utc(2026, 5, 21, 9)
    ..updatedAt = DateTime.utc(2026, 5, 21, 9);
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'package_66a'
    ..packageCode = 'BAF-66A'
    ..title = '66A governed runtime package';
}

JobExecution _execution() {
  return JobExecution()
    ..id = 66
    ..firestoreId = 'execution_66a'
    ..templateFirestoreId = 'version_66a'
    ..templatePackageId = 'package_66a'
    ..templateVersionId = 'version_66a'
    ..assetType = AssetType.base
    ..assetNumber = 1
    ..chargeNoAtEvent = 6601
    ..createdAt = DateTime.utc(2026, 5, 21, 9)
    ..updatedAt = DateTime.utc(2026, 5, 21, 9);
}

AppUser _actor() {
  return AppUser(
    uid: 'si_1',
    name: 'Senior Inspector',
    email: 'si@example.com',
    roles: const [AppRole.si],
    isApproved: true,
    createdAt: DateTime.utc(2026, 5, 21),
  );
}
