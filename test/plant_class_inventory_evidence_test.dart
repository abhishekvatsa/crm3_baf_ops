import 'dart:async';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as f;

final _class = f.assetClass(
  id: 'furnaces',
  code: 'FURNACE',
  name: 'Furnaces',
  legacyKey: 'furnace',
);
final _asset = f.asset(id: 'furnace-1', assetClass: _class, number: 1);

PlantEvidenceBatch<T> _batch<T>(
  List<T> rows, {
  bool current = true,
  bool rejected = false,
}) => PlantEvidenceBatch(
  rows: rows,
  rejected: rejected ? {'unreadable-row': 'Unreadable record'} : {},
  fromServer: current,
  observedAt: DateTime.utc(2026, 10, 2),
);

ProviderContainer _provider({
  String? cachedSource,
  String? rejectedSource,
  bool empty = false,
  Stream<PlantEvidenceBatch<AssetClassRecord>>? classes,
  Stream<PlantEvidenceBatch<AssetInstanceRecord>>? assets,
}) {
  PlantEvidenceBatch<T> batch<T>(String source, List<T> rows) => _batch(
    rows,
    current: cachedSource != source,
    rejected: rejectedSource == source,
  );
  final container = ProviderContainer(
    overrides: [
      plantClassEvidenceProvider.overrideWith(
        (ref) => classes ?? Stream.value(batch('classes', [_class])),
      ),
      plantAssetEvidenceProvider.overrideWith(
        (ref) => assets ?? Stream.value(batch('assets', empty ? [] : [_asset])),
      ),
      plantManualEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('manual', [])),
      ),
      plantWorkflowEvidenceProvider.overrideWith(
        (ref) => Stream.value(
          batch(
            'workflow',
            empty ? [] : [f.workflow(key: 'furnace', number: 1)],
          ),
        ),
      ),
      plantAvailabilityEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('availability', [])),
      ),
      plantTicketEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('tickets', [])),
      ),
      plantInnerCoverEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('covers', [])),
      ),
      plantConditionTicketsProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  final subscription = container.listen(plantAssetOverviewProvider, (_, _) {});
  addTearDown(() {
    subscription.close();
    container.dispose();
  });
  return container;
}

Future<void> _settle(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

void main() {
  test(
    'complete server registers enable only their class denominator',
    () async {
      final container = _provider();
      await _settle(container);
      final overview = container.read(plantAssetOverviewProvider).requireValue;
      expect(overview.physicalInventoryComplete, isTrue);
      expect(overview.classes.single.inventoryComplete, isTrue);
      expect(overview.classes.single.availabilityRate, 1);
    },
  );

  for (final source in ['classes', 'assets']) {
    for (final mode in ['cached', 'rejected']) {
      test(
        '$mode $source retain recorded count without certifying total',
        () async {
          final container = _provider(
            cachedSource: mode == 'cached' ? source : null,
            rejectedSource: mode == 'rejected' ? source : null,
          );
          await _settle(container);
          final overview = container
              .read(plantAssetOverviewProvider)
              .requireValue;
          expect(overview.total, 1);
          expect(overview.physicalInventoryComplete, isFalse);
          expect(overview.classes.single.inventoryComplete, isFalse);
          expect(overview.classes.single.availabilityRate, isNull);
        },
      );
    }
  }

  test(
    'unverified condition evidence does not falsely change inventory coverage',
    () async {
      final container = _provider(cachedSource: 'workflow');
      await _settle(container);
      final overview = container.read(plantAssetOverviewProvider).requireValue;
      final summary = overview.classes.single;
      expect(overview.physicalInventoryComplete, isTrue);
      expect(summary.inventoryComplete, isTrue);
      expect(summary.available, 0);
      expect(summary.unavailable, 0);
      expect(summary.unverifiedAvailability, 1);
      expect(summary.availabilityRate, isNull);
    },
  );

  test(
    'confirmed empty registry is distinct from cached empty registry',
    () async {
      final current = _provider(empty: true);
      final cached = _provider(empty: true, cachedSource: 'assets');
      await _settle(current);
      await _settle(cached);
      expect(
        current
            .read(plantAssetOverviewProvider)
            .requireValue
            .physicalInventoryComplete,
        isTrue,
      );
      expect(
        cached
            .read(plantAssetOverviewProvider)
            .requireValue
            .physicalInventoryComplete,
        isFalse,
      );
      expect(
        current
            .read(plantAssetOverviewProvider)
            .requireValue
            .classes
            .single
            .availabilityRate,
        isNull,
      );
      expect(
        cached
            .read(plantAssetOverviewProvider)
            .requireValue
            .classes
            .single
            .availabilityRate,
        isNull,
      );
    },
  );

  test(
    'unresolved registry stream remains loading rather than zero assets',
    () async {
      final source =
          StreamController<PlantEvidenceBatch<AssetInstanceRecord>>();
      addTearDown(source.close);
      final container = _provider(assets: source.stream);
      await _settle(container);
      expect(container.read(plantAssetOverviewProvider).isLoading, isTrue);
      source.add(_batch([_asset]));
      await _settle(container);
      expect(container.read(plantAssetOverviewProvider).requireValue.total, 1);
    },
  );

  test('registry read error is not a zero-asset success', () async {
    final container = _provider(
      assets: Stream.error(StateError('Registry unavailable')),
    );
    await _settle(container);
    expect(container.read(plantAssetOverviewProvider).hasError, isTrue);
  });
}
