import '../data/template_governance_model.dart';
import 'module_composer_models.dart';
import 'module_workshop_actions.dart';

/// Read-only, cloneable module source derived from an immutable published
/// TemplateVersion snapshot.
///
/// Issue 65D deliberately does not introduce a registry, Firestore schema,
/// sync entity, or mutable link to a published module. The module held here is
/// a defensive working copy parsed from frozen TemplateVersion JSON.
class PublishedModuleSource {
  final ComposerModuleDraft module;
  final String? packageFirestoreId;
  final String packageCode;
  final String packageTitle;
  final String? versionFirestoreId;
  final int versionNumber;
  final String? versionLabel;
  final DateTime? publishedAt;
  final String? contentHash;

  const PublishedModuleSource({
    required this.module,
    required this.packageFirestoreId,
    required this.packageCode,
    required this.packageTitle,
    required this.versionFirestoreId,
    required this.versionNumber,
    required this.versionLabel,
    required this.publishedAt,
    required this.contentHash,
  });

  String get sourceLabel {
    final version =
        versionLabel?.trim().isNotEmpty == true
            ? 'v$versionNumber · $versionLabel'
            : 'v$versionNumber';
    return '$packageCode · $version';
  }
}

List<PublishedModuleSource> publishedModuleSourcesFromTemplateVersions({
  required Iterable<TemplateVersion> versions,
  Iterable<TemplatePackage> packages = const <TemplatePackage>[],
}) {
  final packagesById = <String, TemplatePackage>{
    for (final package in packages)
      if ((package.firestoreId ?? '').trim().isNotEmpty)
        package.firestoreId!.trim(): package,
  };

  final sources = <PublishedModuleSource>[];
  for (final version in versions) {
    if (!version.isPublished || version.isDeleted) {
      continue;
    }
    final package = packagesById[version.packageFirestoreId?.trim() ?? ''];
    sources.addAll(
      publishedModuleSourcesFromTemplateVersion(
        version: version,
        package: package,
      ),
    );
  }

  sources.sort((a, b) {
    final publishedCompare = (b.publishedAt ??
            DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (publishedCompare != 0) {
      return publishedCompare;
    }
    return a.module.moduleCode.compareTo(b.module.moduleCode);
  });
  return sources;
}

List<PublishedModuleSource> publishedModuleSourcesFromTemplateVersion({
  required TemplateVersion version,
  TemplatePackage? package,
}) {
  if (!version.isPublished || version.isDeleted) {
    return const <PublishedModuleSource>[];
  }

  late final TemplateComposerDraft draft;
  try {
    draft = TemplateComposerDraft.fromPayloads(
      jobTemplateSnapshotJson: version.jobTemplateSnapshotJson,
      moduleSnapshotsJson: version.moduleSnapshotsJson,
      fieldDefinitionsJson: version.fieldDefinitionsJson,
      checklistJson: version.checklistJson,
    );
  } catch (_) {
    return const <PublishedModuleSource>[];
  }

  final packageCode =
      _cleanText(package?.packageCode) ??
      _cleanText(version.packageFirestoreId) ??
      'PUBLISHED-TEMPLATE';
  final packageTitle = _cleanText(package?.title) ?? packageCode;

  return <PublishedModuleSource>[
    for (final module in draft.modules)
      PublishedModuleSource(
        module: _moduleWithPublishedLineage(
          module,
          version: version,
          packageCode: packageCode,
          packageTitle: packageTitle,
        ),
        packageFirestoreId: version.packageFirestoreId,
        packageCode: packageCode,
        packageTitle: packageTitle,
        versionFirestoreId: version.firestoreId,
        versionNumber: version.versionNumber,
        versionLabel: version.versionLabel,
        publishedAt: version.publishedAt,
        contentHash: version.contentHash,
      ),
  ];
}

ComposerModuleDraft clonePublishedModuleIntoDraft({
  required PublishedModuleSource source,
  required Iterable<ComposerModuleDraft> existingModules,
  DateTime? now,
}) {
  final copy = duplicateComposerModule(
    source: source.module,
    existingModules: existingModules,
    now: now,
  );
  copy.metadata = <String, dynamic>{
    ...cloneComposerMetadata(copy.metadata),
    'source': 'publishedTemplateVersionSnapshot',
    'sourcePackageFirestoreId': source.packageFirestoreId,
    'sourcePackageCode': source.packageCode,
    'sourcePackageTitle': source.packageTitle,
    'sourceTemplateVersionFirestoreId': source.versionFirestoreId,
    'sourceTemplateVersionNumber': source.versionNumber,
    if ((source.versionLabel ?? '').trim().isNotEmpty)
      'sourceTemplateVersionLabel': source.versionLabel,
    if ((source.contentHash ?? '').trim().isNotEmpty)
      'sourceTemplateVersionContentHash': source.contentHash,
    'sourceModuleCode': source.module.moduleCode,
  };
  copy.authoringNotes = _appendLineageNote(
    copy.authoringNotes,
    'Cloned from published TemplateVersion ${source.sourceLabel}. Review before publish.',
  );
  return copy;
}

ComposerModuleDraft _moduleWithPublishedLineage(
  ComposerModuleDraft module, {
  required TemplateVersion version,
  required String packageCode,
  required String packageTitle,
}) {
  final copy = cloneComposerModuleDraft(module);
  copy.metadata = <String, dynamic>{
    ...cloneComposerMetadata(copy.metadata),
    'source': 'publishedTemplateVersionSnapshot',
    'sourcePackageFirestoreId': version.packageFirestoreId,
    'sourcePackageCode': packageCode,
    'sourcePackageTitle': packageTitle,
    'sourceTemplateVersionFirestoreId': version.firestoreId,
    'sourceTemplateVersionNumber': version.versionNumber,
    if ((version.versionLabel ?? '').trim().isNotEmpty)
      'sourceTemplateVersionLabel': version.versionLabel,
    if ((version.contentHash ?? '').trim().isNotEmpty)
      'sourceTemplateVersionContentHash': version.contentHash,
    'sourceModuleCode': module.moduleCode,
  };
  return copy;
}

String _appendLineageNote(String existing, String note) {
  final trimmed = existing.trim();
  if (trimmed.isEmpty) {
    return note;
  }
  if (trimmed.contains(note)) {
    return trimmed;
  }
  return '$trimmed\n$note';
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
