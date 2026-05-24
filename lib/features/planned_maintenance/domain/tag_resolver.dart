// FILE: lib/features/planned_maintenance/domain/tag_resolver.dart
//
// RETAINED LEGACY EXACT-TAG FALLBACK.
//
// New UI callsites should use BafTagResolverV2.resolveToMap(). This resolver is
// intentionally kept for exact DomainRegistry parity until the V2 knowledge
// layer covers every legacy plant tag and its output has been verified against
// existing maintenance/directive/action workflows.

import 'package:flutter/foundation.dart';
import 'domain_registry.dart';

// ─────────────────────────────────────────────────────────────
// TagInfo
// ─────────────────────────────────────────────────────────────

class TagInfo {
  final String asset;
  final List<String> fullPath;
  final String component;

  const TagInfo({
    required this.asset,
    required this.fullPath,
    required this.component,
  });

  String? get system => fullPath.length > 1 ? fullPath[1] : null;
  String? get subsystem => fullPath.length > 2 ? fullPath[2] : null;
}

// ─────────────────────────────────────────────────────────────
// TagResolver (GOLD VERSION)
// ─────────────────────────────────────────────────────────────

class TagResolver {
  static final Map<String, TagInfo> _index = _buildIndex();

  // 🔥 Normalize tag input
  static String _normalize(String tag) {
    return tag.trim().toUpperCase();
  }

  // ─────────────────────────────────────────────
  // INDEX BUILDER
  // ─────────────────────────────────────────────

  static Map<String, TagInfo> _buildIndex() {
    final Map<String, TagInfo> index = {};

    void traverse(String asset, Map<String, dynamic> node, List<String> path) {
      node.forEach((key, value) {
        if (key == 'components' && value is List) {
          for (final comp in value) {
            if (comp is! Map<String, dynamic>) continue;

            final compName = comp['name'] as String? ?? '';
            final tags = comp['tags'];

            if (tags is List) {
              for (final rawTag in tags) {
                if (rawTag is String && rawTag.isNotEmpty) {
                  final tag = _normalize(rawTag);

                  // 🔥 Prevent silent overwrite
                  if (!index.containsKey(tag)) {
                    index[tag] = TagInfo(
                      asset: asset,
                      fullPath: List.unmodifiable(path),
                      component: compName,
                    );
                  }
                }
              }
            }

            final subComps = comp['subComponents'];
            if (subComps is List) {
              for (final sub in subComps) {
                if (sub is Map<String, dynamic>) {
                  final subTags = sub['tags'];
                  final subName = sub['name'] as String? ?? '';

                  if (subTags is List) {
                    for (final rawTag in subTags) {
                      if (rawTag is String && rawTag.isNotEmpty) {
                        final tag = _normalize(rawTag);

                        if (!index.containsKey(tag)) {
                          index[tag] = TagInfo(
                            asset: asset,
                            fullPath: List.unmodifiable(path),
                            component: '$compName / $subName',
                          );
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } else if (value is Map<String, dynamic>) {
          traverse(asset, value, [...path, key]);
        }
      });
    }

    DomainRegistry.data.forEach((asset, value) {
      if (value is Map<String, dynamic>) {
        traverse(asset, value, [asset]);
      }
    });

    return index;
  }

  // ─────────────────────────────────────────────
  // RESOLVE
  // ─────────────────────────────────────────────

  static TagInfo? resolve(String tag) {
    final normalized = _normalize(tag);
    if (normalized.isEmpty) return null;
    return _index[normalized];
  }

  // ─────────────────────────────────────────────
  // SAFE MAP OUTPUT
  // ─────────────────────────────────────────────

  static Map<String, dynamic> resolveToMap(String tag) {
    final info = resolve(tag);

    if (info == null) {
      return const {
        'asset': null,
        'system': null,
        'subsystem': null,
        'component': null,
        'hierarchyPath': null,
        'isAutoResolved': false,
      };
    }

    return {
      'asset': info.asset,
      'system': info.system,
      'subsystem': info.subsystem,
      'component': info.component,
      'hierarchyPath': List<String>.from(info.fullPath),
      'isAutoResolved': true,
    };
  }

  // ─────────────────────────────────────────────
  // DEBUG
  // ─────────────────────────────────────────────

  static void debugPrintIndex() {
    _index.forEach((tag, info) {
      debugPrint('[$tag] → ${info.fullPath.join(' > ')} | ${info.component}');
    });
  }
}
