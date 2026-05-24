import '../../auth/data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/template_governance_model.dart';
import 'module_composer_json_builder.dart';
import 'module_composer_models.dart';
import 'module_composer_validator.dart';
import 'template_version_snapshot_contract.dart';

const int kPublishReasonMinLength = 10;

class PublishMetadataInput {
  final String packageCode;
  final String packageTitle;
  final String packageDescription;
  final AssetType assetType;
  final String assetNumberScope;
  final Set<String> disciplineScope;
  final String versionLabel;
  final String releaseNotes;
  final String changeSummary;
  final String minAppVersion;
  final String publishReason;

  const PublishMetadataInput({
    required this.packageCode,
    required this.packageTitle,
    required this.packageDescription,
    required this.assetType,
    required this.assetNumberScope,
    required this.disciplineScope,
    required this.versionLabel,
    required this.releaseNotes,
    required this.changeSummary,
    required this.minAppVersion,
    required this.publishReason,
  });
}

class PublishMetadataValidation {
  final List<String> errors;
  final List<String> warnings;
  final TemplateVersionSnapshotBundle? snapshot;

  const PublishMetadataValidation({
    this.errors = const <String>[],
    this.warnings = const <String>[],
    this.snapshot,
    this.publishReasonValid = false,
  });

  bool get canSaveDraft => errors.isEmpty && snapshot != null;

  bool get canPublish => canSaveDraft && publishReasonValid;

  final bool publishReasonValid;
}

bool publishReasonIsValid(String value) {
  return value.trim().length >= kPublishReasonMinLength;
}

PublishMetadataValidation validatePublishMetadata({
  required PublishMetadataInput input,
  required TemplateComposerDraft draft,
}) {
  final errors = <String>[];
  final warnings = <String>[];

  if (input.packageCode.trim().isEmpty) {
    errors.add('Package code is required.');
  }
  if (input.packageTitle.trim().isEmpty) {
    errors.add('Package title is required.');
  }
  if (input.disciplineScope.isEmpty) {
    errors.add('Select at least one discipline scope.');
  }

  final composerValidation = ModuleComposerValidator.validate(draft);
  errors.addAll(composerValidation.errors);
  errors.addAll(composerValidation.justificationsRequired);
  warnings.addAll(composerValidation.warnings);

  TemplateVersionSnapshotBundle? snapshot;
  if (errors.isEmpty) {
    try {
      final output = ModuleComposerJsonBuilder.build(draft);
      snapshot = TemplateVersionSnapshotBundle.fromRawJson(
        jobTemplateSnapshotJson: output.jobTemplateSnapshotJson,
        moduleSnapshotsJson: output.moduleSnapshotsJson,
        fieldDefinitionsJson: output.fieldDefinitionsJson,
        checklistJson: output.checklistJson,
      );
      final snapshotValidation = snapshot.validate();
      errors.addAll(snapshotValidation.errors);
      warnings.addAll(snapshotValidation.warnings);
    } on Object catch (error) {
      errors.add('Snapshot cannot be built: $error');
    }
  }

  return PublishMetadataValidation(
    errors: errors.toSet().toList(growable: false),
    warnings: warnings.toSet().toList(growable: false),
    snapshot: snapshot,
    publishReasonValid: publishReasonIsValid(input.publishReason),
  );
}

TemplatePackage buildTemplatePackageForPublish({
  required PublishMetadataInput input,
  required AppUser actor,
  TemplatePackage? existingPackage,
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final package = existingPackage ?? TemplatePackage();

  package
    ..packageCode = input.packageCode.trim()
    ..title = input.packageTitle.trim()
    ..description = _cleanOptional(input.packageDescription)
    ..assetType = input.assetType.name
    ..assetNumberScope = _cleanOptional(input.assetNumberScope)
    ..disciplineScope = _disciplineScopeString(input.disciplineScope)
    ..lifecycleStatus = TemplatePackageLifecycleStatus.active
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..updatedAt = timestamp;

  if (_tryReadCreatedAt(package) == null) {
    package.createdAt = timestamp;
  }
  package.createdByUid ??= actor.uid;
  package.createdByName ??= actor.name;

  return package;
}

TemplateVersion buildTemplateVersionForPublish({
  required PublishMetadataInput input,
  required TemplateComposerDraft draft,
  required TemplatePackage package,
  required int nextVersionNumber,
  AppUser? actor,
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final output = ModuleComposerJsonBuilder.build(draft);
  final version =
      TemplateVersion()
        ..packageFirestoreId = package.firestoreId
        ..versionNumber = nextVersionNumber < 1 ? 1 : nextVersionNumber
        ..versionLabel = _cleanOptional(input.versionLabel)
        ..status = TemplateVersionStatus.draft
        ..jobTemplateSnapshotJson = output.jobTemplateSnapshotJson
        ..moduleSnapshotsJson = output.moduleSnapshotsJson
        ..fieldDefinitionsJson = output.fieldDefinitionsJson
        ..checklistJson = output.checklistJson
        ..releaseNotes = _cleanOptional(input.releaseNotes)
        ..changeSummary = _cleanOptional(input.changeSummary)
        ..minAppVersion = _cleanOptional(input.minAppVersion)
        ..targetRefs = _unionStrings(draft.modules.expand((m) => m.targetRefs))
        ..deviceTagRefs = _unionStrings(
          draft.modules.expand((m) => m.deviceTagRefs),
        )
        ..procedureRefs = _unionStrings(
          draft.modules.expand((m) => m.procedureRefs),
        )
        ..operationalStatePreconditions = _unionStrings(
          draft.modules.expand((m) => m.operationalStatePreconditions),
        )
        ..safetyClass = _cleanOptional(
          _unionStrings(draft.modules.expand((m) => m.safetyClasses)).join(','),
        )
        ..createdAt = timestamp
        ..updatedAt = timestamp;

  if (actor != null) {
    version
      ..createdByUid = actor.uid
      ..createdByName = actor.name
      ..updatedByUid = actor.uid
      ..updatedByName = actor.name;
  }

  version.refreshContentHash();
  return version;
}

DateTime? _tryReadCreatedAt(TemplatePackage package) {
  try {
    return package.createdAt;
  } catch (_) {
    return null;
  }
}

String? _cleanOptional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _disciplineScopeString(Set<String> values) {
  final cleaned =
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return cleaned.join(',');
}

List<String> _unionStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (seen.add(trimmed.toLowerCase())) {
      result.add(trimmed);
    }
  }
  return result;
}
