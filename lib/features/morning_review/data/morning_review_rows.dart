import 'dart:collection';
import '../../../core/utils/combined_record_stream.dart';

/// Valid rows remain usable, but an excluded row never becomes an empty or
/// complete population. Strict frozen-document reads do not use this wrapper.
class MorningReviewRows<T> extends ListBase<T> {
  MorningReviewRows(Iterable<T> values, Iterable<String> rejected)
    : _values = List.unmodifiable(values),
      rejectedIds = List.unmodifiable(rejected);
  final List<T> _values;
  final List<String> rejectedIds;
  @override
  int get length => _values.length;
  @override
  set length(int value) =>
      throw UnsupportedError('Read-only Morning Review rows');
  @override
  T operator [](int index) => _values[index];
  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Read-only Morning Review rows');
}

int morningReviewRejectedCount(Object? rows) =>
    rows is MorningReviewRows ? rows.rejectedIds.length : 0;

MorningReviewRows<T> decodeMorningReviewRows<T>(
  Iterable<({String id, Map<String, dynamic> data})> documents,
  T Function(Map<String, dynamic>, String) decode, {
  bool Function(T)? keep,
  int Function(T, T)? compare,
}) {
  final values = <T>[];
  final rejected = <String>[];
  for (final document in documents) {
    try {
      final value = decode(document.data, document.id);
      if (keep == null || keep(value)) values.add(value);
    } on Object {
      rejected.add(document.id);
    }
  }
  if (compare != null) values.sort(compare);
  return MorningReviewRows(values, rejected);
}

Stream<List<T>> combineMorningReviewRows<T>(
  List<Stream<List<T>>> streams, {
  required String Function(T) identity,
  required int Function(T, T) compare,
}) =>
    combineLatestUniqueRecordStreams<({int source, List<T> rows})>(
      streams: [
        for (var i = 0; i < streams.length; i++)
          streams[i].map((rows) => [(source: i, rows: rows)]),
      ],
      identityOf: (page) => page.source,
    ).map((pages) {
      final byId = <String, T>{};
      final rejected = <String>{};
      for (final page in pages) {
        for (final row in page.rows) {
          byId[identity(row)] = row;
        }
        if (page.rows is MorningReviewRows<T>) {
          rejected.addAll((page.rows as MorningReviewRows<T>).rejectedIds);
        }
      }
      final values = byId.values.toList()..sort(compare);
      return MorningReviewRows(values, rejected);
    });
