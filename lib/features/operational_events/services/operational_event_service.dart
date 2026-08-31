import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../data/operational_event.dart';

const operationalEventCallableName = 'mutateAssetHierarchy';
const operationalEventCallableRegion = 'asia-south1';

enum OperationalEventCommand {
  create('CREATE_OPERATIONAL_EVENT'),
  update('UPDATE_OPERATIONAL_EVENT'),
  resolve('RESOLVE_OPERATIONAL_EVENT'),
  reopen('REOPEN_OPERATIONAL_EVENT');

  const OperationalEventCommand(this.wireName);
  final String wireName;
}

class OperationalEventCommandException implements Exception {
  const OperationalEventCommandException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class OperationalEventCommandResult {
  const OperationalEventCommandResult({
    required this.requestId,
    required this.operation,
    required this.eventId,
    required this.status,
    required this.version,
    required this.auditId,
    required this.committedAt,
    required this.idempotentReplay,
  });

  final String requestId;
  final OperationalEventCommand operation;
  final String eventId;
  final OperationalEventStatus status;
  final int version;
  final String auditId;
  final DateTime committedAt;
  final bool idempotentReplay;

  factory OperationalEventCommandResult.fromMap(
    Map<String, dynamic> map, {
    required String expectedRequestId,
    required OperationalEventCommand expectedOperation,
    required String expectedEventId,
  }) {
    final source = '$operationalEventCallableName/$expectedRequestId';
    if (map['ok'] != true) {
      throw PersistedDataFormatException(
        field: 'ok',
        source: source,
        detail: 'expected an explicit successful result',
      );
    }
    final requestId = readRequiredPersistedString(
      map['requestId'],
      field: 'requestId',
      source: source,
    );
    final operation = readRequiredPersistedString(
      map['operation'],
      field: 'operation',
      source: source,
    );
    final eventId = readRequiredPersistedString(
      map['eventId'],
      field: 'eventId',
      source: source,
    );
    if (requestId != expectedRequestId ||
        operation != expectedOperation.wireName ||
        eventId != expectedEventId) {
      throw PersistedDataFormatException(
        field: 'requestId',
        source: source,
        detail: 'response identity or operation mismatch',
      );
    }
    final committedAtRaw = map['committedAt'];
    final committedAt = readRequiredPersistedDateTime(
      map['committedAt'],
      field: 'committedAt',
      source: source,
    );
    if (committedAtRaw is! String ||
        committedAtRaw.trim() != committedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'committedAt',
        source: source,
        detail: 'must be a canonical UTC ISO instant',
      );
    }
    final auditId = readRequiredPersistedString(
      map['auditId'],
      field: 'auditId',
      source: source,
    );
    if (auditId != 'operational_event_$expectedRequestId') {
      throw PersistedDataFormatException(
        field: 'auditId',
        source: source,
        detail: 'response audit identity mismatch',
      );
    }
    return OperationalEventCommandResult(
      requestId: requestId,
      operation: expectedOperation,
      eventId: eventId,
      status: readRequiredPersistedEnum(
        OperationalEventStatus.values,
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
      auditId: auditId,
      committedAt: committedAt,
      idempotentReplay: readRequiredPersistedBool(
        map['idempotentReplay'],
        field: 'idempotentReplay',
        source: source,
      ),
    );
  }
}

class OperationalEventService {
  OperationalEventService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;
  static const _uuid = Uuid();

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: operationalEventCallableRegion);

  Future<OperationalEventCommandResult> create({
    required OperationalEventDraft draft,
    required String reason,
  }) {
    final eventId = _uuid.v4();
    return _call(
      OperationalEventCommand.create,
      eventId: eventId,
      expectedVersion: 0,
      reason: reason,
      eventDraft: draft,
    );
  }

  Future<OperationalEventCommandResult> update({
    required OperationalEvent event,
    required OperationalEventDraft draft,
    required String reason,
  }) => _call(
    OperationalEventCommand.update,
    eventId: event.eventId,
    expectedVersion: event.version,
    reason: reason,
    eventDraft: draft,
  );

  Future<OperationalEventCommandResult> resolve({
    required OperationalEvent event,
    required String resolutionNote,
    DateTime? resolvedAt,
  }) => _call(
    OperationalEventCommand.resolve,
    eventId: event.eventId,
    expectedVersion: event.version,
    reason: resolutionNote,
    resolutionNote: resolutionNote,
    resolvedAt: resolvedAt,
  );

  Future<OperationalEventCommandResult> reopen({
    required OperationalEvent event,
    required String reason,
  }) => _call(
    OperationalEventCommand.reopen,
    eventId: event.eventId,
    expectedVersion: event.version,
    reason: reason,
  );

  Future<OperationalEventCommandResult> _call(
    OperationalEventCommand operation, {
    required String eventId,
    required int expectedVersion,
    required String reason,
    OperationalEventDraft? eventDraft,
    String? resolutionNote,
    DateTime? resolvedAt,
  }) async {
    final requestId = _uuid.v4();
    final request = <String, dynamic>{
      'requestId': requestId,
      'operation': operation.wireName,
      'eventId': eventId,
      'expectedVersion': expectedVersion,
      'reason': reason.trim(),
      if (eventDraft != null) 'eventDraft': eventDraft.toCommandMap(),
      if (resolutionNote != null) 'resolutionNote': resolutionNote.trim(),
      if (resolvedAt != null)
        'resolvedAt': canonicalOperationalEventCommandTimestamp(resolvedAt),
    };
    try {
      final response = await _client
          .httpsCallable(operationalEventCallableName)
          .call<Map<String, dynamic>>(request);
      return OperationalEventCommandResult.fromMap(
        Map<String, dynamic>.from(response.data),
        expectedRequestId: requestId,
        expectedOperation: operation,
        expectedEventId: eventId,
      );
    } on FirebaseFunctionsException catch (error) {
      throw OperationalEventCommandException(
        error.message ?? 'The operational event could not be changed.',
        code: error.code,
      );
    } on PersistedDataFormatException catch (error) {
      throw OperationalEventCommandException(
        'The server returned invalid event evidence: $error',
        code: 'data-loss',
      );
    }
  }
}
