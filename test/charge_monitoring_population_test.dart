import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_monitoring_submission_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final f =
      jsonDecode(
            File(
              'test/fixtures/charge_monitoring_review_actual_handler.json',
            ).readAsStringSync(),
          )
          as Map;
  Map<String, dynamic> raw(String key) =>
      Map<String, dynamic>.from((f[key] as Map)['entity'] as Map);
  QualityMonitoringPopulation population(
    List<Map<String, dynamic>> rows, {
    bool cache = false,
  }) => decodeQualityMonitoringPopulation(
    rows.map((r) => (id: r['requestId'] as String, data: r)),
    isFromCache: cache,
    hasPendingWrites: false,
  );
  test(
    'bad neighbour preserves valid monitoring but prevents certified counts',
    () {
      final good = raw('created');
      final result = population([
        good,
        {'requestId': 'bad', 'schemaVersion': 999},
      ]);
      expect(result.single.requestId, good['requestId']);
      expect(result.rejectedIds, {'bad'});
      expect(result.isQualified, false);
      expect(population([good], cache: true).isQualified, false);
      expect(population([good]).isQualified, true);
    },
  );
  test(
    'original context with a partial registered Base identity is rejected',
    () {
      final data = raw('corrected');
      data['originalMonitoringContext'] = {
        ...data['originalMonitoringContext'] as Map,
        'baseAssetClassId': null,
      };
      expect(
        () =>
            QualityMonitoringRequest.fromMap(data, data['requestId'] as String),
        throwsFormatException,
      );
    },
  );
  test(
    'shared warning command service does not open native monitoring storage',
    () {
      final container = ProviderContainer(
        overrides: [
          qualityMonitoringSubmissionControllerProvider.overrideWith(
            (ref) => throw StateError('Native storage must stay lazy'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        () => container.read(qualityCommandServiceProvider),
        returnsNormally,
      );
    },
  );
  testWidgets(
    'old active delivery cannot resurrect archived higher-version closure; missing full rows are qualified',
    (tester) async {
      final current = StreamController<List<QualityMonitoringRequest>>();
      final legacy = StreamController<List<QualityMonitoringRequest>>();
      final events = <List<QualityMonitoringRequest>>[];
      final subscription = combineQualityMonitoringWindows(
        current.stream,
        legacy.stream,
      ).listen(events.add);
      addTearDown(() async {
        await subscription.cancel();
        await current.close();
        await legacy.close();
      });
      current.add(
        population([Map<String, dynamic>.from(f['archived'] as Map)]),
      );
      legacy.add([]);
      await tester.pump();
      expect(events.last, isEmpty);
      current.add(population([raw('created')]));
      await tester.pump();
      expect(events.last, isEmpty);
      current.add(population([]));
      await tester.pump();
      expect(monitoringPopulationIsQualified(events.last), false);
    },
  );
  testWidgets(
    'contradictory same-version business evidence cannot publish success',
    (tester) async {
      final current = StreamController<List<QualityMonitoringRequest>>();
      final legacy = StreamController<List<QualityMonitoringRequest>>();
      final errors = <Object>[];
      final subscription = combineQualityMonitoringWindows(
        current.stream,
        legacy.stream,
      ).listen((_) {}, onError: errors.add);
      addTearDown(() async {
        await subscription.cancel();
        await current.close();
        await legacy.close();
      });
      current.add(population([raw('created')]));
      legacy.add([]);
      await tester.pump();
      current.add(
        population([
          {...raw('created'), 'grade': 'contradiction'},
        ]),
      );
      await tester.pump();
      expect(errors, hasLength(1));
    },
  );
}
