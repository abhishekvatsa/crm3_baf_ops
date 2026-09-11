import 'dart:async';

import 'package:crm3_baf_ops/core/utils/combined_record_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> drain() => Future<void>.delayed(Duration.zero);

  for (final failedSource in <int>[0, 1]) {
    test('source $failedSource must recover before healthy combined data resumes', () async {
      final sources = <StreamController<List<int>>>[
        StreamController<List<int>>(),
        StreamController<List<int>>(),
      ];
      final values = <List<int>>[];
      final errors = <Object>[];
      final subscription = combineLatestUniqueRecordStreams<int>(
        streams: sources.map((source) => source.stream).toList(),
        identityOf: (value) => value,
        compare: (left, right) => left.compareTo(right),
      ).listen(values.add, onError: (Object error) => errors.add(error));
      addTearDown(() async {
        await subscription.cancel();
        for (final source in sources) { await source.close(); }
      });

      sources[0].add(<int>[1]);
      sources[1].add(<int>[2]);
      await drain();
      expect(values, <List<int>>[<int>[1, 2]]);

      sources[failedSource].addError(StateError('required source unreadable'));
      await drain();
      expect(errors, hasLength(1));
      sources[1 - failedSource].add(<int>[3]);
      await drain();
      expect(values, hasLength(1), reason: 'an unrelated update must not reuse failed evidence');

      // Empty is legitimate recovery data; it is different from an error.
      sources[failedSource].add(<int>[]);
      await drain();
      expect(values.last, <int>[3]);
    });
  }

  test('both failed sources must independently recover', () async {
    final a = StreamController<List<int>>();
    final b = StreamController<List<int>>();
    final values = <List<int>>[];
    final subscription = combineLatestUniqueRecordStreams<int>(
      streams: <Stream<List<int>>>[a.stream, b.stream],
      identityOf: (value) => value,
    ).listen(values.add, onError: (Object _) {});
    addTearDown(() async { await subscription.cancel(); await a.close(); await b.close(); });
    a.add(<int>[1]); b.add(<int>[2]); await drain();
    a.addError(StateError('a')); b.addError(StateError('b')); await drain();
    a.add(<int>[3]); await drain();
    expect(values, hasLength(1));
    b.add(<int>[4]); await drain();
    expect(values.last.toSet(), <int>{3, 4});
  });

  test('ordinary deduplication and sorting remain unchanged', () async {
    final result = await combineLatestUniqueRecordStreams<int>(
      streams: <Stream<List<int>>>[
        Stream<List<int>>.value(<int>[3, 1]),
        Stream<List<int>>.value(<int>[2, 1]),
      ],
      identityOf: (value) => value,
      compare: (left, right) => left.compareTo(right),
    ).single;
    expect(result, <int>[1, 2, 3]);
  });
}
