import 'dart:convert';

import '../../../core/serialization/persisted_json_equality.dart';
import '../data/baf_knowledge_model.dart';
import 'knowledge_governance_models.dart';

/// Immutable reviewed content. Getters return fresh mutable editor objects.
class KnowledgeImportRowIntent {
  final String rowCode;
  final String draftJson;
  final String reason;
  final String? beforeJson;

  const KnowledgeImportRowIntent({
    required this.rowCode,
    required this.draftJson,
    required this.reason,
    required this.beforeJson,
  });

  BafKnowledgeRow? get before => beforeJson == null
      ? null
      : BafKnowledgeRow.fromCloudMap(
          jsonDecode(beforeJson!) as Map<String, dynamic>,
          rowCode,
        );

  int get versionAfter => (before?.version ?? 0) + 1;
  String get auditId => 'knowledge_revision_${rowCode}_$versionAfter';

  KnowledgeRowDraft get draft {
    final entry = jsonDecode(draftJson) as Map<String, dynamic>;
    final row = BafKnowledgeRow.fromCloudMap({
      ...entry,
      'schemaVersion': 1,
      'version': 1,
      'createdAt': DateTime.utc(2000),
      'updatedAt': DateTime.utc(2000),
      'createdByUid': 'retained-import',
      'createdByName': 'Retained import',
      'updatedByUid': 'retained-import',
      'updatedByName': 'Retained import',
      'changeSummary': reason,
      'isDeleted': false,
    }, rowCode);
    final result = KnowledgeRowDraft.fromRow(row)..changeSummary = reason;
    // Absence of structured presets is part of the original producer shape.
    if (!entry.containsKey('suggestedFieldPresets')) {
      result.suggestedFieldPresets = null;
    }
    if (!persistedJsonEquivalent(jsonEncode(result.toEntryMap()), draftJson)) {
      throw const FormatException('Saved import draft changed while decoding.');
    }
    return result;
  }

  Map<String, dynamic> toMap() => {
    'rowCode': rowCode,
    'draftJson': draftJson,
    'reason': reason,
    'beforeJson': beforeJson,
  };

  factory KnowledgeImportRowIntent.fromMap(Map<String, dynamic> map) {
    _keys(map, const {'rowCode', 'draftJson', 'reason', 'beforeJson'});
    final result = KnowledgeImportRowIntent(
      rowCode: _text(map['rowCode'], 64),
      draftJson: _text(map['draftJson'], 20000),
      reason: _text(map['reason'], 2000),
      beforeJson: map['beforeJson'] == null
          ? null
          : _text(map['beforeJson'], 20000),
    );
    final before = result.before;
    if (before?.isDeleted == true ||
        !result.draft.validateForSave(isCreate: before == null).canSave) {
      throw const FormatException('Saved import row cannot be applied safely.');
    }
    return result;
  }
}

class KnowledgeImportIntent {
  final String requestId;
  final String actorUid;
  final String actorName;
  final List<KnowledgeImportRowIntent> rows;

  KnowledgeImportIntent({
    required this.requestId,
    required this.actorUid,
    required this.actorName,
    required List<KnowledgeImportRowIntent> rows,
  }) : rows = List.unmodifiable(rows);

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'requestId': requestId,
    'actorUid': actorUid,
    'actorName': actorName,
    'rows': rows.map((row) => row.toMap()).toList(),
  };

  factory KnowledgeImportIntent.decode(String raw) {
    if (raw.length > 20000000) {
      throw const FormatException('Saved import exceeds its supported size.');
    }
    final map = _map(jsonDecode(raw));
    _keys(map, const {
      'schemaVersion',
      'requestId',
      'actorUid',
      'actorName',
      'rows',
    });
    final values = map['rows'];
    if (map['schemaVersion'] != 1 ||
        values is! List ||
        values.isEmpty ||
        values.length > 1000) {
      throw const FormatException('Unsupported saved import.');
    }
    final rows = values
        .map((value) => KnowledgeImportRowIntent.fromMap(_map(value)))
        .toList();
    if (rows.map((row) => row.rowCode).toSet().length != rows.length) {
      throw const FormatException('Saved import repeats a row.');
    }
    return KnowledgeImportIntent(
      requestId: _id(map['requestId']),
      actorUid: _text(map['actorUid'], 128),
      actorName: _text(map['actorName'], 256),
      rows: rows,
    );
  }
}

enum KnowledgeImportOutcomeState { pending, accepted, rejected }

class KnowledgeImportOutcome {
  final String requestId;
  final String importId;
  final String rowCode;
  final int versionAfter;
  final KnowledgeImportOutcomeState state;
  final bool adopted;
  final String message;

  const KnowledgeImportOutcome({
    required this.requestId,
    required this.importId,
    required this.rowCode,
    required this.versionAfter,
    required this.state,
    required this.adopted,
    required this.message,
  });

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'requestId': requestId,
    'importId': importId,
    'rowCode': rowCode,
    'versionAfter': versionAfter,
    'state': state.name,
    'adopted': adopted,
    'message': message,
  };

  factory KnowledgeImportOutcome.decode(String raw) {
    final map = _map(jsonDecode(raw));
    _keys(map, const {
      'schemaVersion',
      'requestId',
      'importId',
      'rowCode',
      'versionAfter',
      'state',
      'adopted',
      'message',
    });
    final version = map['versionAfter'];
    final state = KnowledgeImportOutcomeState.values
        .where((value) => value.name == map['state'])
        .firstOrNull;
    if (map['schemaVersion'] != 1 ||
        version is! int ||
        version < 1 ||
        state == null ||
        map['adopted'] is! bool ||
        (map['adopted'] == true &&
            state != KnowledgeImportOutcomeState.accepted)) {
      throw const FormatException('Saved import outcome is malformed.');
    }
    return KnowledgeImportOutcome(
      requestId: _id(map['requestId']),
      importId: _id(map['importId']),
      rowCode: _text(map['rowCode'], 64),
      versionAfter: version,
      state: state,
      adopted: map['adopted'] as bool,
      message: _text(map['message'], 2000),
    );
  }
}

class KnowledgeImportRecovery {
  final KnowledgeImportIntent intent;
  final Map<String, KnowledgeImportOutcome> outcomes;
  KnowledgeImportRecovery(
    this.intent,
    Map<String, KnowledgeImportOutcome> outcomes,
  ) : outcomes = Map.unmodifiable(outcomes);

  bool get needsRecovery => intent.rows.any((row) {
    final outcome = outcomes[row.rowCode];
    return outcome == null ||
        outcome.state == KnowledgeImportOutcomeState.pending ||
        (outcome.state == KnowledgeImportOutcomeState.accepted &&
            !outcome.adopted);
  });
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Saved import must be an object.');
  }
  return value;
}

void _keys(Map<String, dynamic> map, Set<String> expected) {
  if (map.length != expected.length || !expected.containsAll(map.keys)) {
    throw const FormatException('Saved import has unexpected fields.');
  }
}

String _text(Object? value, int maximum) {
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    throw const FormatException('Saved import contains invalid text.');
  }
  return value;
}

String _id(Object? value) {
  final text = _text(value, 64);
  if (!RegExp(r'^[a-zA-Z0-9_-]{10,64}$').hasMatch(text)) {
    throw const FormatException('Saved import identity is invalid.');
  }
  return text;
}
