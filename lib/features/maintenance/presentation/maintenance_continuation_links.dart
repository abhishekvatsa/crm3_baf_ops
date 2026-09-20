import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/maintenance_model.dart';
import '../providers/maintenance_provider.dart';


class MaintenanceContinuationLinks extends ConsumerWidget {
  const MaintenanceContinuationLinks({super.key, required this.ticket, required this.onOpen});
  final MaintenanceRecord ticket;
  final ValueChanged<MaintenanceRecord> onOpen;

  Widget _record(BuildContext context, MaintenanceRecord linked, String relation) => ListTile(
    leading: const Icon(Icons.link), title: Text('$relation: ${linked.description}'),
    subtitle: Text('${linked.firestoreId} · ${linked.lifecycleSummaryLabel}'),
    onTap: () => onOpen(linked),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ticket.firestoreId;
    if (id == null) return const SizedBox.shrink();
    final repository = ref.watch(maintenanceRepositoryProvider);
    return Column(children: [
      if (ticket.continuesIssueId != null)
        FutureBuilder<MaintenanceRecord?>(
          future: repository.getByFirestoreId(ticket.continuesIssueId!),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const ListTile(title: Text('The originating concern could not be verified.'));
            if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
            final source = snapshot.data;
            return source == null
                ? const ListTile(title: Text('The originating concern is missing or unreadable.'))
                : _record(context, source, 'Originating concern');
          },
        ),
      StreamBuilder<List<MaintenanceRecord>>(
        stream: repository.watchContinuations(id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const ListTile(title: Text('Linked follow-up work is incomplete or could not be verified.'));
          final rows = [...?snapshot.data]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return Column(children: [for (final row in rows) _record(context, row, 'Follow-up work')]);
        },
      ),
    ]);
  }
}
