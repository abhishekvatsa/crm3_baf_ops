// FILE: lib/features/planned_maintenance/domain/baf_tag_resolver_v2.dart

import 'dart:collection';

import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import 'baf_knowledge_layer.dart';
import 'module_composer_models.dart';
import 'tag_resolver.dart' as legacy_tag_resolver;

class BafTagResolverV2 {
  BafTagResolverV2._();

  static const int _maxStaticCacheEntries = 256;

  static final RegExp _tagCleanupPattern = RegExp(r'[^A-Z0-9]+');
  static final LinkedHashMap<String, BafTagResolution> _staticResolutionCache =
      LinkedHashMap<String, BafTagResolution>();

  static BafTagResolution resolve(
    String rawInput, {
    AssetType? assetContext,
    List<BafKnowledgeEntry>? entries,
  }) {
    final normalized = normalizeTag(rawInput);
    final canUseStaticCache =
        entries == null || identical(entries, BafKnowledgeLayer.entries);
    if (!canUseStaticCache) {
      return _resolveUncached(
        rawInput,
        normalized: normalized,
        assetContext: assetContext,
        entries: entries,
      );
    }

    final cacheKey = _staticCacheKey(rawInput, normalized, assetContext);
    final cached = _staticResolutionCache.remove(cacheKey);
    if (cached != null) {
      _staticResolutionCache[cacheKey] = cached;
      return cached;
    }

    final resolved = _resolveUncached(
      rawInput,
      normalized: normalized,
      assetContext: assetContext,
    );
    _rememberStatic(cacheKey, resolved);
    return resolved;
  }

  static void clearStaticCache() {
    _staticResolutionCache.clear();
  }

  /// V1-compatible adapter for UI tag-resolution callsites.
  ///
  /// This method centralizes new callsites on V2 while preserving the exact
  /// legacy [TagResolver.resolveToMap] output for tags already known by the
  /// [DomainRegistry]. That fallback is intentional: V2 knowledge is richer,
  /// but it does not yet have exact coverage for every legacy plant tag used by
  /// maintenance/directive/action workflows.
  ///
  /// Resolution order:
  /// 1. V2 knowledge / prefix resolution for extended metadata.
  /// 2. Legacy DomainRegistry exact-tag map for the V1 UI keys when present.
  /// 3. V2-compatible map for V2-only tags when sufficiently resolved.
  /// 4. Unresolved V1-compatible map.
  static Map<String, dynamic> resolveToMap(
    String rawInput, {
    AssetType? assetContext,
    List<BafKnowledgeEntry>? entries,
  }) {
    final resolution = resolve(
      rawInput,
      assetContext: assetContext,
      entries: entries,
    );

    final legacyMap = legacy_tag_resolver.TagResolver.resolveToMap(rawInput);
    final hasLegacyExact = legacyMap['isAutoResolved'] == true;
    if (hasLegacyExact) {
      return _mergeLegacyExactMap(legacyMap, resolution);
    }

    final v2Map = _v2CompatibleMap(resolution, assetContext: assetContext);
    if (v2Map != null) {
      return v2Map;
    }

    return _unresolvedMap(resolution);
  }

  static Map<String, dynamic> _mergeLegacyExactMap(
    Map<String, dynamic> legacyMap,
    BafTagResolution resolution,
  ) {
    final hasUsefulV2Metadata =
        resolution.confidence >= 0.7 &&
        resolution.resolutionSource != 'empty' &&
        resolution.resolutionSource != 'unresolved';

    return <String, dynamic>{
      // Preserve exact V1 keys/values for current UI consumers.
      'isAutoResolved': true,
      'asset': legacyMap['asset'],
      'system': legacyMap['system'],
      'subsystem': legacyMap['subsystem'],
      'component': legacyMap['component'],
      'hierarchyPath': _stringListFromDynamic(legacyMap['hierarchyPath']),
      // Add V2 metadata without changing current consuming-code behavior.
      'confidence': hasUsefulV2Metadata ? resolution.confidence : 0.65,
      'requiresReview': hasUsefulV2Metadata && resolution.requiresReview,
      'discipline': hasUsefulV2Metadata ? resolution.discipline?.name : null,
      'ownerDisciplines':
          hasUsefulV2Metadata
              ? List<String>.from(resolution.ownerDisciplines)
              : const <String>[],
      'safetyClasses':
          hasUsefulV2Metadata
              ? List<String>.from(resolution.safetyClasses)
              : const <String>[],
      'resolutionSource':
          hasUsefulV2Metadata
              ? '${resolution.resolutionSource}+legacyDomainRegistryExactTag'
              : 'legacyDomainRegistryExactTag',
      'procedureRefs':
          hasUsefulV2Metadata
              ? List<String>.from(resolution.procedureRefs)
              : const <String>[],
    };
  }

  static Map<String, dynamic>? _v2CompatibleMap(
    BafTagResolution resolution, {
    required AssetType? assetContext,
  }) {
    final component = _cleanOptional(
      resolution.componentGroup ?? resolution.displayName,
    );
    final assetLabel = _assetLabel(resolution.assetType ?? assetContext);
    final isResolvedEnoughForV1 =
        resolution.confidence >= 0.7 &&
        component != null &&
        assetLabel != null &&
        resolution.resolutionSource != 'empty' &&
        resolution.resolutionSource != 'unresolved';

    if (!isResolvedEnoughForV1) {
      return null;
    }

    return <String, dynamic>{
      'isAutoResolved': true,
      'asset': assetLabel,
      'system': _cleanOptional(resolution.functionalSection),
      'subsystem': _cleanOptional(resolution.subsystem),
      'component': component,
      'hierarchyPath': List<String>.from(resolution.hierarchyPath),
      'confidence': resolution.confidence,
      'requiresReview': resolution.requiresReview,
      'discipline': resolution.discipline?.name,
      'ownerDisciplines': List<String>.from(resolution.ownerDisciplines),
      'safetyClasses': List<String>.from(resolution.safetyClasses),
      'resolutionSource': resolution.resolutionSource,
      'procedureRefs': List<String>.from(resolution.procedureRefs),
    };
  }

  static Map<String, dynamic> _unresolvedMap(BafTagResolution resolution) {
    return <String, dynamic>{
      'asset': null,
      'system': null,
      'subsystem': null,
      'component': null,
      'hierarchyPath': null,
      'isAutoResolved': false,
      'confidence': resolution.confidence,
      'requiresReview': resolution.requiresReview,
      'discipline': null,
      'ownerDisciplines': const <String>[],
      'safetyClasses': const <String>[],
      'resolutionSource': resolution.resolutionSource,
      'procedureRefs': const <String>[],
    };
  }

  static List<String> _stringListFromDynamic(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return const <String>[];
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  static String? _assetLabel(AssetType? assetType) {
    return switch (assetType) {
      AssetType.base => 'Base',
      AssetType.furnace => 'Furnace',
      AssetType.forceCooler => 'Forced Cooler',
      AssetType.innerCover => 'Inner Cover',
      AssetType.governedCustom => 'Governed asset',
      null => null,
    };
  }

  static String normalizeTag(String rawInput) {
    return rawInput.trim().toUpperCase().replaceAll(_tagCleanupPattern, '');
  }

  static BafTagResolution _resolveUncached(
    String rawInput, {
    required String normalized,
    AssetType? assetContext,
    List<BafKnowledgeEntry>? entries,
  }) {
    if (normalized.isEmpty) {
      return BafTagResolution(
        rawInput: rawInput,
        normalizedTag: normalized,
        confidence: 0,
        requiresReview: true,
        resolutionSource: 'empty',
      );
    }

    final exact =
        entries == null
            ? BafKnowledgeLayer.byTag(normalized)
            : entries
                .where(
                  (entry) => entry.deviceTags.any(
                    (candidate) => candidate.toUpperCase() == normalized,
                  ),
                )
                .toList(growable: false);
    if (exact.isNotEmpty) {
      final best = _preferContext(exact, assetContext);
      return BafTagResolution(
        rawInput: rawInput,
        normalizedTag: normalized,
        displayName:
            best.componentGroup.isEmpty ? best.taskText : best.componentGroup,
        assetType: best.assetType,
        functionalSection: best.functionalSection,
        componentGroup: best.componentGroup,
        subsystem: best.assetFamilyKey,
        discipline: best.discipline,
        ownerDisciplines: best.ownerDisciplines,
        safetyClasses: best.safetyClasses,
        hierarchyPath: best.targetRefs,
        procedureRefs: best.procedureRefs,
        sourceManualRefs: [best.sourceLabel],
        confidence:
            best.confidence == KnowledgeConfidence.confirmedUserRatified
                ? 0.95
                : 0.9,
        requiresReview: best.needsReviewBeforeUse,
        resolutionSource: 'knowledgeMatrixExactTag',
      );
    }

    final inferred = _inferByPrefix(rawInput, normalized, assetContext);
    if (inferred != null) return inferred;

    return BafTagResolution(
      rawInput: rawInput,
      normalizedTag: normalized,
      confidence: 0.25,
      requiresReview: true,
      resolutionSource: 'unresolved',
    );
  }

  static String _staticCacheKey(
    String rawInput,
    String normalized,
    AssetType? assetContext,
  ) {
    return '$rawInput\u0000$normalized\u0000${assetContext?.name ?? ''}';
  }

  static void _rememberStatic(String cacheKey, BafTagResolution resolution) {
    _staticResolutionCache[cacheKey] = resolution;
    while (_staticResolutionCache.length > _maxStaticCacheEntries) {
      _staticResolutionCache.remove(_staticResolutionCache.keys.first);
    }
  }

  static BafKnowledgeEntry _preferContext(
    List<BafKnowledgeEntry> entries,
    AssetType? assetContext,
  ) {
    if (assetContext == null) return entries.first;
    for (final entry in entries) {
      if (entry.assetType == assetContext) return entry;
    }
    return entries.first;
  }

  static BafTagResolution? _inferByPrefix(
    String rawInput,
    String normalized,
    AssetType? assetContext,
  ) {
    final prefix = RegExp(r'^[A-Z]+').firstMatch(normalized)?.group(0) ?? '';
    if (prefix.isEmpty) return null;

    String? displayName;
    JobModuleDiscipline? discipline = JobModuleDiscipline.instrumentation;
    final owners = <String>['instrumentation'];
    final safetyClasses = <String>[];
    final hierarchy = <String>[];

    switch (prefix) {
      case 'PT':
        displayName = 'Pressure transmitter';
        safetyClasses.add('pressureSystem');
        hierarchy.add('pressure');
        break;
      case 'PSL':
      case 'PSH':
        displayName =
            prefix == 'PSL' ? 'Pressure switch low' : 'Pressure switch high';
        safetyClasses.addAll(['pressureSystem', 'safetyInterlock']);
        hierarchy.add('pressureSwitch');
        break;
      case 'FSL':
      case 'FSH':
      case 'FISL':
        displayName = 'Flow switch / flow indicator switch';
        safetyClasses.addAll(['waterFlowProtection', 'safetyInterlock']);
        hierarchy.add('flowSwitch');
        break;
      case 'TSH':
      case 'TSL':
      case 'TC':
      case 'TE':
        displayName = 'Temperature element / thermocouple / temperature switch';
        safetyClasses.add('temperatureMeasurement');
        hierarchy.add('temperature');
        break;
      case 'VT':
        displayName = 'Vibration transmitter';
        owners.addAll(['mechanical', 'electrical']);
        safetyClasses.addAll(['rotatingEquipmentRisk', 'safetyInterlock']);
        hierarchy.add('vibration');
        discipline = JobModuleDiscipline.shared;
        break;
      case 'YV':
      case 'YIV':
      case 'YS':
      case 'FV':
      case 'FOV':
        displayName = 'Valve / actuator / solenoid';
        owners.addAll(['mechanical', 'electrical']);
        safetyClasses.addAll(['safetyInterlock']);
        hierarchy.add('valve');
        discipline = JobModuleDiscipline.shared;
        break;
      case 'UV':
        displayName = 'UV flame sensor';
        owners.addAll(['electrical']);
        safetyClasses.addAll([
          'furnaceCombustionRisk',
          'gasRisk',
          'safetyInterlock',
        ]);
        hierarchy.add('flameDetection');
        discipline = JobModuleDiscipline.shared;
        break;
      default:
        return null;
    }

    final uniqueOwners = owners.toSet().toList()..sort();
    final asset = assetContext;
    final basePath = <String>[
      if (asset != null) asset.name,
      ...hierarchy,
      normalized,
    ];
    return BafTagResolution(
      rawInput: rawInput,
      normalizedTag: normalized,
      displayName: displayName,
      assetType: asset,
      functionalSection: hierarchy.isEmpty ? null : hierarchy.first,
      componentGroup: displayName,
      subsystem: asset?.name,
      discipline:
          uniqueOwners.length > 1 ? JobModuleDiscipline.shared : discipline,
      ownerDisciplines: uniqueOwners,
      safetyClasses: safetyClasses,
      hierarchyPath: basePath,
      procedureRefs: const <String>[],
      sourceManualRefs: const <String>[],
      confidence: 0.7,
      requiresReview: safetyClasses.any(
        (value) => value.toLowerCase().contains('interlock'),
      ),
      resolutionSource: 'instrumentPrefixInference',
    );
  }
}
