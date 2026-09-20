import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import 'maintenance_model.dart';
import 'remote_maintenance_reader.dart';

List<MaintenanceRecord> decodeMaintenanceFeed(
  QuerySnapshot<Map<String, dynamic>> snapshot, {
  required String queryKey,
  bool requireComplete = false,
  void Function(String, Iterable<String>)? onMalformed,
}) {
  final decoded = decodeSnapshotBatch(snapshot,
    (data, id) => readRemoteMaintenanceRecord(data, documentId: id),
    source: 'maintenance_records/$queryKey');
  onMalformed?.call(queryKey, decoded.rejectedDocumentIds);
  if (requireComplete && decoded.rejectedDocumentIds.isNotEmpty) {
    throw StateError('Maintenance evidence is incomplete: ${decoded.rejectedDocumentIds.length} record(s) need repair. A complete condition or report cannot be asserted.');
  }
  return List.unmodifiable(decoded.records);
}
