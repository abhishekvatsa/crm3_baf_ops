import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../domain/morning_review_models.dart';

const morningReviewCallableName = 'mutateAssetHierarchy';
const morningReviewCallableRegion = 'asia-south1';

bool isUncertainMorningReviewCommandCode(String code) => const {
  'aborted',
  'deadline-exceeded',
  'internal',
  'unavailable',
  'unknown',
}.contains(code);

enum MorningReviewCommand {
  start('START_MORNING_REVIEW'),
  join('JOIN_MORNING_REVIEW'),
  addEntry('ADD_MORNING_REVIEW_ENTRY'),
  createAction('CREATE_MORNING_REVIEW_ACTION'),
  acceptAction('ACCEPT_MORNING_REVIEW_ACTION'),
  completeAction('COMPLETE_MORNING_REVIEW_ACTION'),
  takeOver('TAKE_OVER_MORNING_REVIEW'),
  finalize('FINALIZE_MORNING_REVIEW'),
  recordNotHeld('RECORD_MORNING_REVIEW_NOT_HELD'),
  createStandingConcern('CREATE_MORNING_REVIEW_STANDING_CONCERN'),
  resolveStandingConcern('RESOLVE_MORNING_REVIEW_STANDING_CONCERN'),
  checkStandingConcern('CHECK_MORNING_REVIEW_STANDING_CONCERN'),
  addAddendum('ADD_MORNING_REVIEW_ADDENDUM');

  const MorningReviewCommand(this.wireName);
  final String wireName;
}

class MorningReviewCommandException implements Exception {
  const MorningReviewCommandException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class MorningReviewCommandResult {
  const MorningReviewCommandResult({
    required this.requestId,
    required this.operation,
    required this.sessionId,
    required this.entityId,
    required this.status,
    required this.version,
    required this.committedAt,
    required this.idempotentReplay,
  });

  final String requestId;
  final MorningReviewCommand operation;
  final String? sessionId;
  final String entityId;
  final String status;
  final int version;
  final DateTime committedAt;
  final bool idempotentReplay;

  factory MorningReviewCommandResult.fromMap(
    Map<String, dynamic> map, {
    required String expectedRequestId,
    required MorningReviewCommand expectedOperation,
  }) {
    final source = '$morningReviewCallableName/$expectedRequestId';
    const expectedKeys = {
      'ok',
      'requestId',
      'operation',
      'sessionId',
      'entityId',
      'status',
      'version',
      'committedAt',
      'idempotentReplay',
    };
    if (map.keys.toSet().length != expectedKeys.length ||
        !map.keys.toSet().containsAll(expectedKeys) ||
        map['ok'] != true ||
        map['requestId'] != expectedRequestId ||
        map['operation'] != expectedOperation.wireName) {
      throw PersistedDataFormatException(
        field: 'responseIdentity',
        source: source,
        detail: 'response shape, request, or operation mismatch',
      );
    }
    final committedAt = readRequiredPersistedDateTime(
      map['committedAt'],
      field: 'committedAt',
      source: source,
    );
    if (map['committedAt'] is! String ||
        map['committedAt'] != _canonicalUtcInstant(committedAt)) {
      throw PersistedDataFormatException(
        field: 'committedAt',
        source: source,
        detail: 'must be a canonical UTC instant',
      );
    }
    return MorningReviewCommandResult(
      requestId: expectedRequestId,
      operation: expectedOperation,
      sessionId: readOptionalPersistedString(
        map['sessionId'],
        field: 'sessionId',
        source: source,
      ),
      entityId: readRequiredPersistedString(
        map['entityId'],
        field: 'entityId',
        source: source,
      ),
      status: readRequiredPersistedString(
        map['status'],
        field: 'status',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      committedAt: committedAt,
      idempotentReplay: readRequiredPersistedBool(
        map['idempotentReplay'],
        field: 'idempotentReplay',
        source: source,
      ),
    );
  }
}

class MorningReviewEntryInput {
  const MorningReviewEntryInput({
    required this.section,
    required this.kind,
    required this.text,
    this.assetClassId,
    this.assetClassName,
    this.assetInstanceId,
    this.assetNumber,
    this.sourceReferences = const [],
  });

  final MorningReviewSection section;
  final MorningReviewEntryKind kind;
  final String text;
  final String? assetClassId;
  final String? assetClassName;
  final String? assetInstanceId;
  final String? assetNumber;
  final List<String> sourceReferences;

  Map<String, dynamic> toMap() => {
    'section': section.name,
    'kind': kind.name,
    'text': text.trim(),
    'assetClassId': assetClassId,
    'assetClassName': assetClassName,
    'assetInstanceId': assetInstanceId,
    'assetNumber': assetNumber,
    'sourceReferences': sourceReferences,
  };
}

class MorningReviewActionInput {
  const MorningReviewActionInput({
    required this.section,
    required this.text,
    required this.assigneeUid,
    required this.assigneeRole,
    this.assetClassId,
    this.assetClassName,
    this.assetInstanceId,
    this.assetNumber,
    this.dueAt,
  });

  final MorningReviewSection section;
  final String text;
  final String? assigneeUid;
  final String? assigneeRole;
  final String? assetClassId;
  final String? assetClassName;
  final String? assetInstanceId;
  final String? assetNumber;
  final DateTime? dueAt;

  Map<String, dynamic> toMap() => {
    'section': section.name,
    'text': text.trim(),
    'assigneeUid': assigneeUid,
    'assigneeRole': assigneeRole,
    'assetClassId': assetClassId,
    'assetClassName': assetClassName,
    'assetInstanceId': assetInstanceId,
    'assetNumber': assetNumber,
    'dueAt': dueAt == null ? null : _canonicalUtcInstant(dueAt!),
  };
}

class MorningReviewStandingConcernInput {
  const MorningReviewStandingConcernInput({
    required this.title,
    required this.detail,
    required this.criticality,
  });

  final String title;
  final String detail;
  final MorningReviewConcernCriticality criticality;

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'detail': detail.trim(),
    'criticality': criticality.name,
  };
}

Map<String, dynamic> buildMorningReviewCommandRequest({
  required MorningReviewCommand operation,
  required String requestId,
  String? sessionId,
  Map<String, dynamic> extra = const {},
}) {
  final request = <String, dynamic>{
    'requestId': requestId,
    'operation': operation.wireName,
    if (sessionId != null) 'sessionId': sessionId,
  };
  String? duplicate;
  for (final key in extra.keys) {
    if (request.containsKey(key)) {
      duplicate = key;
      break;
    }
  }
  if (duplicate != null) {
    throw ArgumentError.value(
      duplicate,
      'extra',
      'must not replace a governed Morning Review envelope field',
    );
  }
  request.addAll(extra);
  return request;
}

class MorningReviewCommandService {
  MorningReviewCommandService({
    FirebaseFunctions? functions,
    String actorScope = 'unresolved-actor',
  }) : _functions = functions,
       _actorScope = actorScope;

  final FirebaseFunctions? _functions;
  final String _actorScope;
  static const _uuid = Uuid();
  final Map<String, String> _pendingRequestIds = <String, String>{};

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: morningReviewCallableRegion);

  Future<MorningReviewCommandResult> start() =>
      _call(MorningReviewCommand.start);

  Future<MorningReviewCommandResult> join(String sessionId) =>
      _call(MorningReviewCommand.join, sessionId: sessionId);

  Future<MorningReviewCommandResult> addEntry({
    required String sessionId,
    required MorningReviewEntryInput entry,
  }) => _call(
    MorningReviewCommand.addEntry,
    sessionId: sessionId,
    extra: {'entryDraft': entry.toMap()},
  );

  Future<MorningReviewCommandResult> addAddendum({
    required String sessionId,
    required MorningReviewEntryInput entry,
    required String reason,
  }) => _call(
    MorningReviewCommand.addAddendum,
    sessionId: sessionId,
    extra: {'entryDraft': entry.toMap(), 'reason': reason.trim()},
  );

  Future<MorningReviewCommandResult> createAction({
    required String sessionId,
    required MorningReviewActionInput action,
  }) => _call(
    MorningReviewCommand.createAction,
    sessionId: sessionId,
    extra: {'actionDraft': action.toMap()},
  );

  Future<MorningReviewCommandResult> acceptAction({
    required String sessionId,
    required MorningReviewAction action,
  }) => _call(
    MorningReviewCommand.acceptAction,
    sessionId: sessionId,
    extra: {'actionId': action.actionId, 'expectedVersion': action.version},
  );

  Future<MorningReviewCommandResult> completeAction({
    required String sessionId,
    required MorningReviewAction action,
    required String note,
  }) => _call(
    MorningReviewCommand.completeAction,
    sessionId: sessionId,
    extra: {
      'actionId': action.actionId,
      'expectedVersion': action.version,
      'reason': note.trim(),
    },
  );

  Future<MorningReviewCommandResult> takeOver({
    required MorningReviewSession session,
    required String reason,
  }) => _call(
    MorningReviewCommand.takeOver,
    sessionId: session.sessionId,
    extra: {'expectedVersion': session.version, 'reason': reason.trim()},
  );

  Future<MorningReviewCommandResult> finalize({
    required MorningReviewSession session,
    required String summary,
  }) => _call(
    MorningReviewCommand.finalize,
    sessionId: session.sessionId,
    extra: {'expectedVersion': session.version, 'summary': summary.trim()},
  );

  Future<MorningReviewCommandResult> recordNotHeld(String reason) => _call(
    MorningReviewCommand.recordNotHeld,
    extra: {'reason': reason.trim()},
  );

  Future<MorningReviewCommandResult> createStandingConcern({
    required String sessionId,
    required MorningReviewStandingConcernInput concern,
  }) => _call(
    MorningReviewCommand.createStandingConcern,
    sessionId: sessionId,
    extra: {'concernDraft': concern.toMap()},
  );

  Future<MorningReviewCommandResult> resolveStandingConcern({
    required String sessionId,
    required MorningReviewStandingConcern concern,
    required String reason,
  }) => _call(
    MorningReviewCommand.resolveStandingConcern,
    sessionId: sessionId,
    extra: {
      'concernId': concern.concernId,
      'expectedVersion': concern.version,
      'reason': reason.trim(),
    },
  );

  Future<MorningReviewCommandResult> checkStandingConcern({
    required String sessionId,
    required MorningReviewStandingConcern concern,
    required MorningReviewConcernCheckState state,
    required String note,
  }) => _call(
    MorningReviewCommand.checkStandingConcern,
    sessionId: sessionId,
    extra: {
      'concernId': concern.concernId,
      'checkState': state.name,
      'reason': note.trim(),
    },
  );

  Future<MorningReviewCommandResult> _call(
    MorningReviewCommand operation, {
    String? sessionId,
    Map<String, dynamic> extra = const {},
  }) async {
    final fingerprint = jsonEncode(<String, dynamic>{
      'actorScope': _actorScope,
      'operation': operation.wireName,
      'sessionId': sessionId,
      'extra': extra,
    });
    final requestId = _pendingRequestIds.putIfAbsent(fingerprint, _uuid.v4);
    final request = buildMorningReviewCommandRequest(
      operation: operation,
      requestId: requestId,
      sessionId: sessionId,
      extra: extra,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .httpsCallable(morningReviewCallableName)
            .call<Object?>(request);
        final result = MorningReviewCommandResult.fromMap(
          _stringMap(response.data),
          expectedRequestId: requestId,
          expectedOperation: operation,
        );
        _pendingRequestIds.remove(fingerprint);
        return result;
      } on FirebaseFunctionsException catch (error) {
        final uncertain = isUncertainMorningReviewCommandCode(error.code);
        if (uncertain && attempt == 0) continue;
        if (!uncertain) _pendingRequestIds.remove(fingerprint);
        throw MorningReviewCommandException(
          uncertain
              ? 'The server outcome could not be confirmed. Refresh today\'s '
                  'Morning Review before retrying; an unchanged retry will '
                  'reuse the same protected request.'
              : error.message ??
                  'The Morning Review command could not be completed.',
          code: error.code,
        );
      } on PersistedDataFormatException catch (error) {
        throw MorningReviewCommandException(
          'The server returned invalid Morning Review evidence: $error',
          code: 'data-loss',
        );
      }
    }
    throw const MorningReviewCommandException(
      'The Morning Review command outcome could not be confirmed.',
      code: 'unavailable',
    );
  }
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) {
    throw PersistedDataFormatException(
      field: 'response',
      source: morningReviewCallableName,
      detail: 'must be an object',
    );
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw PersistedDataFormatException(
      field: 'response',
      source: morningReviewCallableName,
      detail: 'object keys must be strings',
    );
  }
}

String _canonicalUtcInstant(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  String three(int number) => number.toString().padLeft(3, '0');
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${two(utc.month)}-${two(utc.day)}T'
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}.'
      '${three(utc.millisecond)}Z';
}
