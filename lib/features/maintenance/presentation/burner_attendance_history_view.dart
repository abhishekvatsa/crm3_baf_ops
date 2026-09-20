import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/burner_attendance_history.dart';

class BurnerAttendanceHistoryView extends StatelessWidget {
  const BurnerAttendanceHistoryView({super.key, required this.metadataJson});
  final String? metadataJson;

  @override
  Widget build(BuildContext context) {
    try {
      final entries = readBurnerAttendanceHistory(metadataJson);
      if (entries.isEmpty) return const SizedBox.shrink();
      final format = DateFormat('dd MMM yyyy, HH:mm');
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Burner attendance before restoration', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final entry in entries) ListTile(contentPadding: EdgeInsets.zero,
            title: Text('Work: ${format.format(entry.performedAt.toLocal())}'),
            subtitle: Text('${entry.remarks}\n${entry.summary}\nRecorded: ${format.format(entry.recordedAt.toLocal())}\n${entry.recordedBy}')),
        ],
      )));
    } catch (_) {
      return const ListTile(leading: Icon(Icons.warning_amber),
        title: Text('Burner attendance history is incomplete or unreadable.'),
        subtitle: Text('Review the saved evidence before relying on this history.'));
    }
  }
}
