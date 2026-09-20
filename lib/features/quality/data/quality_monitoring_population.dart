import 'dart:collection';

import '../../../core/serialization/tolerant_snapshot_decode.dart';
import 'quality_warning.dart';

/// A list-compatible qualified population. Consumers must check qualification
/// before publishing a complete count; good rows remain independently usable.
class QualityMonitoringPopulation extends ListBase<QualityMonitoringRequest> {
  QualityMonitoringPopulation({
    required Iterable<QualityMonitoringRequest> records,
    required Iterable<String> rejectedIds,
    required this.isFromCache,
    required this.hasPendingWrites,
  }) : _records = List.unmodifiable(records),
       rejectedIds = Set.unmodifiable(rejectedIds);

  final List<QualityMonitoringRequest> _records;
  final Set<String> rejectedIds;
  final bool isFromCache;
  final bool hasPendingWrites;
  bool get isComplete => rejectedIds.isEmpty;
  bool get isServerConfirmed => !isFromCache && !hasPendingWrites;
  bool get isQualified => isComplete && isServerConfirmed;
  @override
  int get length => _records.length;
  @override
  set length(int value) =>
      throw UnsupportedError('Immutable monitoring evidence');
  @override
  QualityMonitoringRequest operator [](int index) => _records[index];
  @override
  void operator []=(int index, QualityMonitoringRequest value) =>
      throw UnsupportedError('Immutable monitoring evidence');

  QualityMonitoringPopulation withRecords(
    Iterable<QualityMonitoringRequest> records, {
    Iterable<String> missingIds = const [],
  }) => QualityMonitoringPopulation(
    records: records,
    rejectedIds: {...rejectedIds, ...missingIds},
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
  );
}

QualityMonitoringPopulation decodeQualityMonitoringPopulation(
  Iterable<({String id, Map<String, dynamic> data})> documents, {
  required bool isFromCache,
  required bool hasPendingWrites,
}) {
  final rejected = <String>{};
  final records = decodeDocuments(
    documents,
    QualityMonitoringRequest.fromMap,
    source: 'quality-monitoring',
    onQuarantined: (id, _) => rejected.add(id),
  );
  return QualityMonitoringPopulation(
    records: records,
    rejectedIds: rejected,
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
  );
}

bool monitoringPopulationIsQualified(List<QualityMonitoringRequest>? records) =>
    records != null &&
    (records is! QualityMonitoringPopulation || records.isQualified);
