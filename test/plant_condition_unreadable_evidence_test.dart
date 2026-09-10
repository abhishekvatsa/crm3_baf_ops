import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `isAvailable` requires `!isDown`, and `isDown` requires an active condition
/// record. So if a Down declaration is dropped rather than surfaced, the asset
/// computes as Available and a Down base is counted available on the plant
/// condition board.
///
/// Tolerant decoding was briefly applied to those reads, which turned
/// unreadable restriction evidence into absence of restriction. These bind the
/// containment: reads that decide a restriction stay strict, so damaged
/// evidence surfaces as an error rather than as a healthier plant.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('availability still depends on the condition record being present', () {
    final domain = read('lib/features/assets/domain/plant_asset_overview.dart');

    // If this stops being true, dropping a condition record no longer implies
    // Available and the reasoning below needs revisiting.
    expect(domain, contains('bool get isDown =>'));
    expect(domain, contains('operationalCondition?.active == true'));
    expect(domain, contains('!isDown'));
  });

  test('condition and availability reads decode strictly', () {
    for (final path in const <String>[
      'lib/features/assets/repositories/asset_hierarchy_repository.dart',
      'lib/features/assets/providers/asset_availability_provider.dart',
      'lib/features/assets/providers/furnace_stuckup_provider.dart',
    ]) {
      final source = read(path);
      for (final type in const <String>[
        'AssetOperationalConditionRecord',
        'AssetAvailabilityRecord',
        'AssetConditionDeclarationRecord',
      ]) {
        if (!source.contains(type)) continue;
        expect(
          source,
          contains('$type.fromMap(doc.data(), doc.id)'),
          reason:
              '$type decides whether an asset is restricted; a dropped record '
              'would read as no restriction',
        );
      }
    }
  });

  test('inspection report evidence decodes strictly', () {
    // A dropped finding is not there to contradict the completeness check,
    // and both reads drop the same one, so an incomplete population passes.
    final source =
        read('lib/features/inspections/repositories/inspection_repository.dart');
    final evidence = source.substring(
      source.indexOf('InspectionCampaignReportEvidence('),
    );
    final body = evidence.substring(0, evidence.indexOf('\n  }'));

    expect(body, contains('InspectionFinding.fromMap(doc.data(), doc.id)'));
    expect(body, contains('InspectionObservation.fromMap(doc.data(), doc.id)'));
    expect(body, isNot(contains('decodeSnapshotDocuments')));
  });

  final closeBrace = '${String.fromCharCode(10)}  }';

  test('the plant population itself decodes strictly', () {
    // Separate from the Down-to-Available case. That one dropped a
    // restriction while keeping the asset; this one would drop the asset from
    // the population, so a published total silently understates the plant.
    final repo =
        read('lib/features/assets/repositories/asset_hierarchy_repository.dart');

    for (final method in const <String>[
      'watchAllAssetInstances',
      'watchAssetInstances',
      'watchAssetClasses',
    ]) {
      final start = repo.indexOf('$method(');
      expect(start, greaterThan(-1), reason: '$method should still exist');
      final body = repo.substring(start, repo.indexOf(closeBrace, start));
      expect(
        body,
        isNot(contains('decodeSnapshotDocuments')),
        reason:
            '$method feeds counts and selection; a dropped asset would be '
            'indistinguishable from one that is not registered',
      );
    }
  });

  test('the overview cannot see incompleteness it was never told about', () {
    // The provider surfaces AsyncError, but a tolerant decode returns
    // AsyncData holding a short list - so nothing signals it. That is why the
    // population reads stay strict rather than the provider gaining a check.
    final provider =
        read('lib/features/assets/providers/plant_asset_overview_provider.dart');

    expect(provider, contains('asError'));
    expect(provider, isNot(contains('quarantined')));
  });

  test('the selection fallback reads a value that cannot throw', () {
    // Riverpod 2.6.1 AsyncValue.value throws when there is no previous value,
    // so `.value` on an errored provider would throw before the retained
    // fallback could run - in exactly the case it exists for.
    final form =
        read('lib/features/maintenance/presentation/maintenance_form.dart');

    expect(form, contains('assetClassesProvider).valueOrNull'));
    expect(form, contains('assetInstancesProvider(physicalClassId)).valueOrNull'));
  });
}
