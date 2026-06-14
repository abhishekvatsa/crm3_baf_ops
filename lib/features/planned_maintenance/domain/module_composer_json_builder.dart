// FILE: lib/features/planned_maintenance/domain/module_composer_json_builder.dart

import 'dart:convert';

import '../data/job_module_model.dart';
import 'module_composer_models.dart';

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

class ModuleComposerJsonBuilder {
  ModuleComposerJsonBuilder._();

  /// Stable in-memory fingerprint used to detect whether a resumed governed
  /// draft has been edited since it was loaded/saved.
  ///
  /// The snapshot's generatedAt value is deliberately excluded because it is
  /// volatile and does not represent an authoring change.
  static String semanticFingerprint(TemplateComposerDraft draft) {
    final output = build(draft);
    final job = jsonDecode(output.jobTemplateSnapshotJson);
    if (job is Map<String, dynamic>) {
      job.remove('generatedAt');
    }

    return jsonEncode(
      _canonicalizeJson(<String, dynamic>{
        'jobTemplateSnapshot': job,
        'moduleSnapshots': jsonDecode(output.moduleSnapshotsJson),
        'fieldDefinitions': jsonDecode(output.fieldDefinitionsJson),
        'checklist': jsonDecode(output.checklistJson),
      }),
    );
  }

  static dynamic _canonicalizeJson(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalizeJson(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalizeJson).toList(growable: false);
    }
    return value;
  }

  static TemplateComposerOutput build(TemplateComposerDraft draft) {
    final moduleSnapshots = <Map<String, dynamic>>[];
    final fieldDefinitions = <Map<String, dynamic>>[];
    final checklist = <Map<String, dynamic>>[];
    final safetyClasses = <String>{};
    var closureCriticalCount = 0;

    for (
      var moduleIndex = 0;
      moduleIndex < draft.modules.length;
      moduleIndex++
    ) {
      final module = draft.modules[moduleIndex];
      safetyClasses.addAll(module.safetyClasses);
      if (module.requiredForClosure) closureCriticalCount += 1;

      moduleSnapshots.add(_moduleToSnapshot(module, moduleIndex));
      final sortedFields = [...module.fields]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final field in sortedFields) {
        fieldDefinitions.add(field.toMap(moduleCode: module.moduleCode));
      }
      final sortedChecklist = [...module.checklistItems]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final item in sortedChecklist) {
        checklist.add(item.toMap(moduleCode: module.moduleCode));
      }
    }

    final jobTemplateSnapshot = <String, dynamic>{
      'schemaVersion': 1,
      'title': draft.title,
      'templateName': draft.title,
      'assetType': draft.assetType.name,
      'source': 'moduleComposer',
      'moduleCount': draft.modules.length,
      'closureCriticalCount': closureCriticalCount,
      'safetyClasses': safetyClasses.toList()..sort(),
      'generatedAt': DateTime.now().toIso8601String(),
      'composerVersion': '5C/5D-RC3',
      'composer': <String, dynamic>{
        'draftLocalId': draft.localId,
        'sourceKnowledgeVersion':
            draft.metadata['matrixVersion'] ?? 'bafKnowledge-v0.1',
        'knowledgeSource': draft.metadata['knowledgeSource'],
        'knowledgeSourceLabel': draft.metadata['knowledgeSourceLabel'],
        'knowledgeCloudUpdatedAt': draft.metadata['knowledgeCloudUpdatedAt'],
        'knowledgeLocalCachedAt': draft.metadata['knowledgeLocalCachedAt'],
        'knowledgeRowCount': draft.metadata['knowledgeRowCount'],
        'knowledgeTagRowCount': draft.metadata['knowledgeTagRowCount'],
        'closureReviewConfirmed': draft.closureReviewConfirmed,
        'closureReviewConfirmedAt': draft.metadata['closureReviewConfirmedAt'],
        'closureReviewConfirmedByUid':
            draft.metadata['closureReviewConfirmedByUid'],
        'closureReviewConfirmedByName':
            draft.metadata['closureReviewConfirmedByName'],
        'maintenanceManualRef': draft.metadata['maintenanceManualRef'],
        'safetyOperationsManualRef':
            draft.metadata['safetyOperationsManualRef'],
        'tagResolverCorrections':
            draft.tagResolverCorrections.map((item) => item.toMap()).toList(),
        'safetyJustifications':
            draft.safetyJustifications.map((item) => item.toMap()).toList(),
      },
    };

    return TemplateComposerOutput(
      jobTemplateSnapshotJson: _prettyJson.convert(jobTemplateSnapshot),
      moduleSnapshotsJson: _prettyJson.convert(moduleSnapshots),
      fieldDefinitionsJson: _prettyJson.convert(fieldDefinitions),
      checklistJson: _prettyJson.convert(checklist),
    );
  }

  static Map<String, dynamic> _moduleToSnapshot(
    ComposerModuleDraft module,
    int order,
  ) {
    return <String, dynamic>{
      'moduleCode': module.moduleCode,
      'moduleTitle': module.title,
      'moduleDescription': module.description,
      'assetType': module.assetType.name,
      'discipline': module.discipline.name,
      'useMode': module.useMode.name,
      'safetyClass': module.primarySafetyClass.name,
      'isRequired': module.requiredForClosure,
      'requiredForClosure': module.requiredForClosure,
      'displayOrder': order,
      'functionalSection': module.functionalSection,
      'componentGroup': module.componentGroup,
      'subsystem': module.subsystem,
      'targetRefs': module.targetRefs,
      'deviceTagRefs': module.deviceTagRefs,
      'procedureRefs': module.procedureRefs,
      'operationalStatePreconditions': module.operationalStatePreconditions,
      'metadata': <String, dynamic>{
        ...module.metadata,
        'ownerDisciplines': module.ownerDisciplines,
        'primaryOwner': module.primaryOwner,
        'requiresJointReview': module.requiresJointReview,
        'safetyClasses': module.safetyClasses,
        'frequency': module.frequency.name,
        'partRefs': module.partRefs,
        'sourceManualRef': module.sourceManualRef,
        'sourceKnowledgeId': module.sourceKnowledgeId,
        'sourceSeedCode': module.sourceSeedCode,
        'sourceReadiness': module.sourceReadiness.name,
        'confidence': module.confidence.name,
        'authoringNotes': module.authoringNotes,
        'sharedSubmissionPolicy':
            module.discipline == JobModuleDiscipline.shared
                ? 'admin_si_supervisor_only'
                : 'discipline_or_supervisor_policy',
      },
    };
  }
}
