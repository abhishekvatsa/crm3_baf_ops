import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/workflow_event_record.dart';

class WorkflowTimeline extends StatelessWidget {
  final List<WorkflowEventRecord> events;
  const WorkflowTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const Center(child: Text('No workflow events yet.'));
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (_, index) {
        final event = events[index];
        final delegated = event.representedLaneKey == null
            ? null
            : ' on behalf of ${event.representedLaneKey!.toUpperCase()}';
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(event.eventTypeKey),
          subtitle: Text(
            '${event.actorName ?? event.actorUid ?? 'Server'}$delegated\n'
            '${event.occurredAt.toLocal()}\n'
            '${_summary(event.payloadJson)}',
          ),
          isThreeLine: true,
        );
      },
    );
  }

  String _summary(String jsonText) {
    try {
      final value = jsonDecode(jsonText);
      return value is Map ? value.entries.take(3).map((e) => '${e.key}: ${e.value}').join(' · ') : '$value';
    } catch (_) {
      return jsonText;
    }
  }
}
