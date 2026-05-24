// FILE: lib/features/planned_maintenance/domain/runtime_module_lineage.dart

import 'dart:convert';

import '../data/job_module_model.dart';

/// Source class for a runtime [JobModuleInstance].
///
/// This is display/audit helper logic only. It does not mutate module payloads
/// or introduce new persistence fields; it interprets the lineage fields already
/// carried on JobModuleInstance, metadataJson, and moduleSnapshotJson.
enum RuntimeModuleLineageSource {
  publishedTemplateVersionRuntimeAdd,
  publishedTemplateVersionModule,
  emergencyManualSeed,
  manualRuntimeAdd,
  legacyOrManual,
}

class RuntimeModuleLineageRow {
  final String label;
  final String value;

  const RuntimeModuleLineageRow({required this.label, required this.value});
}

class RuntimeModuleLineageInfo {
  final RuntimeModuleLineageSource source;
  final String label;
  final String summary;
  final String badgeLabel;
  final String? warning;
  final List<RuntimeModuleLineageRow> detailRows;

  const RuntimeModuleLineageInfo({
    required this.source,
    required this.label,
    required this.summary,
    required this.badgeLabel,
    required this.warning,
    required this.detailRows,
  });

  bool get isGovernedPublishedSource =>
      source == RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd ||
      source == RuntimeModuleLineageSource.publishedTemplateVersionModule;

  bool get isEmergencyManualFallback =>
      source == RuntimeModuleLineageSource.emergencyManualSeed;

  factory RuntimeModuleLineageInfo.fromModule(JobModuleInstance module) {
    final metadata = _decodeJsonObject(module.metadataJson);
    final snapshot = _decodeJsonObject(module.moduleSnapshotJson);
    final metadataSource = _clean(metadata['source']);

    if (metadataSource == 'published_template_version_runtime_add') {
      return _publishedRuntimeAdd(module, metadata);
    }

    if (_isEmergencyManualSeed(module, metadata, snapshot)) {
      return _emergencyManualSeed(module, metadata, snapshot);
    }

    if (_hasPublishedTemplateReference(module)) {
      return _publishedTemplateVersionModule(module, metadata);
    }

    if (module.addedDuringExecution) {
      return _manualRuntimeAdd(module, metadata);
    }

    return _legacyOrManual(module, metadata);
  }
}

RuntimeModuleLineageInfo _publishedRuntimeAdd(
  JobModuleInstance module,
  Map<String, dynamic> metadata,
) {
  final packageLabel = _firstClean([
    metadata['packageCode'],
    metadata['packageTitle'],
    metadata['packageFirestoreId'],
    module.templatePackageId,
  ]);
  final versionLabel = _versionLabel(metadata, module);
  final moduleLabel = _firstClean([
    metadata['moduleCode'],
    module.moduleCode,
    metadata['templateModuleId'],
    module.templateModuleId,
  ]);
  final summary = _joinClean([packageLabel, versionLabel, moduleLabel]);

  return RuntimeModuleLineageInfo(
    source: RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd,
    label: 'Published TemplateVersion runtime add',
    badgeLabel: 'Published runtime add',
    summary:
        summary ?? 'Governed module added from a published TemplateVersion.',
    warning: null,
    detailRows: _rows([
      ('Package', packageLabel),
      ('Version', versionLabel),
      ('Module code', moduleLabel),
      (
        'Template module id',
        _firstClean([metadata['templateModuleId'], module.templateModuleId]),
      ),
      ('Content hash', _firstClean([metadata['contentHash']])),
      (
        'Runtime add reason',
        _firstClean([metadata['runtimeAddReason'], module.addReason]),
      ),
      ('Added by', _firstClean([module.addedByName])),
    ]),
  );
}

RuntimeModuleLineageInfo _publishedTemplateVersionModule(
  JobModuleInstance module,
  Map<String, dynamic> metadata,
) {
  final packageLabel = _firstClean([
    metadata['packageCode'],
    metadata['packageTitle'],
    module.templatePackageId,
  ]);
  final versionLabel = _versionLabel(metadata, module);
  final moduleLabel = _firstClean([module.moduleCode, module.templateModuleId]);
  final summary = _joinClean([packageLabel, versionLabel, moduleLabel]);

  return RuntimeModuleLineageInfo(
    source: RuntimeModuleLineageSource.publishedTemplateVersionModule,
    label: 'Published TemplateVersion module',
    badgeLabel: 'Published template',
    summary: summary ?? 'Module originated from a governed published template.',
    warning: null,
    detailRows: _rows([
      ('Package', packageLabel),
      ('Version', versionLabel),
      ('Module code', moduleLabel),
      ('Template module id', _clean(module.templateModuleId)),
      ('Content hash', _firstClean([metadata['contentHash']])),
    ]),
  );
}

RuntimeModuleLineageInfo _emergencyManualSeed(
  JobModuleInstance module,
  Map<String, dynamic> metadata,
  Map<String, dynamic> snapshot,
) {
  final seedVersion = _firstClean([
    metadata['seedVersion'],
    snapshot['seedVersion'],
  ]);
  final area = _firstClean([
    metadata['catalogueArea'],
    snapshot['catalogueArea'],
    module.componentGroup,
  ]);
  final moduleLabel = _firstClean([module.moduleCode, module.templateModuleId]);
  final summary = _joinClean([seedVersion, area, moduleLabel]);

  return RuntimeModuleLineageInfo(
    source: RuntimeModuleLineageSource.emergencyManualSeed,
    label: 'Emergency/manual seed fallback',
    badgeLabel: 'Emergency/manual seed',
    summary:
        summary ?? 'Module was added from the Emergency/manual seed catalogue.',
    warning:
        'Fallback source: verify this module against the governed package before relying on it for final closure.',
    detailRows: _rows([
      ('Seed version', seedVersion),
      ('Catalogue area', area),
      ('Module code', moduleLabel),
      ('Add reason', _clean(module.addReason)),
      ('Added by', _clean(module.addedByName)),
    ]),
  );
}

RuntimeModuleLineageInfo _manualRuntimeAdd(
  JobModuleInstance module,
  Map<String, dynamic> metadata,
) {
  final moduleLabel = _firstClean([module.moduleCode, module.templateModuleId]);
  return RuntimeModuleLineageInfo(
    source: RuntimeModuleLineageSource.manualRuntimeAdd,
    label: 'Manual runtime module',
    badgeLabel: 'Manual runtime add',
    summary:
        _joinClean([moduleLabel, module.addReason]) ??
        'Module was added during execution without governed source metadata.',
    warning:
        'Manual runtime source: confirm provenance before using this module as closure-critical evidence.',
    detailRows: _rows([
      ('Module code', moduleLabel),
      ('Add reason', _clean(module.addReason)),
      ('Added by', _clean(module.addedByName)),
    ]),
  );
}

RuntimeModuleLineageInfo _legacyOrManual(
  JobModuleInstance module,
  Map<String, dynamic> metadata,
) {
  final moduleLabel = _firstClean([module.moduleCode, module.templateModuleId]);
  final templateLabel = _firstClean([
    module.templateName,
    module.templateFirestoreId,
  ]);
  return RuntimeModuleLineageInfo(
    source: RuntimeModuleLineageSource.legacyOrManual,
    label: 'Legacy/manual module',
    badgeLabel: 'Legacy/manual',
    summary:
        _joinClean([templateLabel, moduleLabel]) ??
        'No governed runtime lineage metadata is attached to this module.',
    warning: null,
    detailRows: _rows([
      ('Template', templateLabel),
      ('Module code', moduleLabel),
    ]),
  );
}

bool _isEmergencyManualSeed(
  JobModuleInstance module,
  Map<String, dynamic> metadata,
  Map<String, dynamic> snapshot,
) {
  final metadataSource = _clean(metadata['source']);
  final snapshotSource = _clean(snapshot['source']);
  final seedVersion = _firstClean([
    metadata['seedVersion'],
    snapshot['seedVersion'],
  ]);

  final sourceText =
      [
        module.templateVersionId,
        module.templatePackageId,
        module.templateModuleId,
        module.templateFirestoreId,
        metadataSource,
        snapshotSource,
      ].map(_clean).whereType<String>().join(' ').toLowerCase();

  return metadataSource == 'baf_module_catalogue_seed' ||
      snapshotSource == 'baf_module_catalogue_seed' ||
      sourceText.contains('baf_module_catalogue_seed') ||
      sourceText.contains('seed:') ||
      sourceText.contains('emergency/manual seed') ||
      seedVersion != null;
}

bool _hasPublishedTemplateReference(JobModuleInstance module) {
  final references = <String?>[
    _clean(module.templateVersionId),
    _clean(module.templatePackageId),
  ];
  return references.any(
    (reference) =>
        reference != null && !reference.toLowerCase().startsWith('seed:'),
  );
}

Map<String, dynamic> _decodeJsonObject(String? rawJson) {
  final raw = rawJson?.trim();
  if (raw == null || raw.isEmpty) return const <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Malformed legacy JSON remains display-safe as unknown lineage.
  }
  return const <String, dynamic>{};
}

String? _versionLabel(Map<String, dynamic> metadata, JobModuleInstance module) {
  final number = _clean(metadata['versionNumber']);
  final label = _clean(metadata['versionLabel']);
  if (number != null && label != null) return 'v$number · $label';
  if (number != null) return 'v$number';
  return _firstClean([label, module.templateName, module.templateVersionId]);
}

List<RuntimeModuleLineageRow> _rows(List<(String, String?)> candidates) {
  return candidates
      .where((candidate) => candidate.$2 != null)
      .map(
        (candidate) =>
            RuntimeModuleLineageRow(label: candidate.$1, value: candidate.$2!),
      )
      .toList(growable: false);
}

String? _joinClean(List<String?> values) {
  final cleaned =
      values
          .map(_clean)
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList();
  return cleaned.isEmpty ? null : cleaned.join(' · ');
}

String? _firstClean(List<dynamic> values) {
  for (final value in values) {
    final cleaned = _clean(value);
    if (cleaned != null) return cleaned;
  }
  return null;
}

String? _clean(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
