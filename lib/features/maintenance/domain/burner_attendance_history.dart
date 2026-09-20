import 'dart:convert';
import '../../../core/serialization/persisted_data_reader.dart';

import '../../planned_maintenance/models/component_action_model.dart';

/// Physical attendance is retained separately from a technical closure.
class BurnerAttendanceEntry {
  const BurnerAttendanceEntry({required this.requestId, required this.performedAt,
    required this.recordedAt, required this.recordedBy, required this.remarks,
    required this.actions});
  final String requestId;
  final DateTime performedAt;
  final DateTime recordedAt;
  final String recordedBy;
  final String remarks;
  final List<ComponentAction> actions;

  String get summary => actions.map((action) =>
    'Burner ${action.burnerPosition}: ${action.burnerOutcome}; ${action.burnerActionCode}').join('\n');
}

List<BurnerAttendanceEntry> readBurnerAttendanceHistory(String? metadataJson) {
  if (metadataJson == null || metadataJson.trim().isEmpty) return const [];
  final metadata = jsonDecode(metadataJson);
  if (metadata is! Map) throw const FormatException('Issue metadata is malformed.');
  final rows = metadata['burnerAttendanceHistory'];
  if (rows == null) return const [];
  if (rows is! List) throw const FormatException('Burner attendance history is malformed.');
  final ids = <String>{};
  final result = <BurnerAttendanceEntry>[];
  for (final data in rows) {
    if (data is! Map) throw const FormatException('Burner attendance entry is malformed.');
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Burner attendance $key is missing.');
      }
      return value;
    }
    final id = text('requestId');
    if (!ids.add(id)) throw const FormatException('Burner attendance identity is repeated.');
    final actions = ComponentAction.decode(text('actionsJson'), source: 'burner attendance $id');
    if (actions.isEmpty) throw const FormatException('Burner attendance actions are missing.');
    result.add(BurnerAttendanceEntry(requestId: id,
      performedAt: readRequiredPersistedDateTime(data['performedAt'], field: 'performedAt', source: 'burner attendance $id'),
      recordedAt: readRequiredPersistedDateTime(data['recordedAt'], field: 'recordedAt', source: 'burner attendance $id'),
      recordedBy: '${text('recordedByName')} (${text('recordedByUid')})',
      remarks: text('remarks'), actions: actions));
  }
  return List.unmodifiable(result);
}
