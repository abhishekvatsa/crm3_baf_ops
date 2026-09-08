import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../data/operational_event.dart';
import 'operational_event_creation_store.dart';

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
  const OperationalEventCommandException(
    this.message, {
    this.code,
    this.details,
  });

  final String message;
  final String? code;
  final Object? details;

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
  OperationalEventService({
    FirebaseFunctions? functions,
    String? Function()? actorUidResolver,
    OperationalEventCreationStore? creationStore,
  }) : _functions = functions,
       _actorUidResolver =
           actorUidResolver ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _creationStore = creationStore ?? OperationalEventCreationStore();

  final FirebaseFunctions? _functions;
  final String? Function() _actorUidResolver;
  final OperationalEventCreationStore _creationStore;
  static const _uuid = Uuid();

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: operationalEventCallableRegion);

  Future<OperationalEventCommandResult> create({
    required OperationalEventDraft draft,
    required String reason,
    String? expectedActorUid,
  }) async {
    final actorUid = _creationActor();
    _requireCreationActor(actorUid, expectedActorUid);
    final identity = await _creationStore.resolve(
      actorUid: actorUid,
      payload: <String, dynamic>{
        'reason': reason.trim(),
        'eventDraft': draft.toCommandMap(),
      },
    );
    return _sendCreation(actorUid, identity);
  }

  String _creationActor() {
    final actorUid = _actorUidResolver()?.trim();
    if (actorUid == null || actorUid.isEmpty) {
      throw const OperationalEventCommandException(
        'Sign in again before recording an operational event.',
        code: 'unauthenticated',
      );
    }
    return actorUid;
  }

  Future<PendingOperationalEventCreation?> pendingCreation() =>
      _creationStore.pending(_creationActor());

  void _requireCreationActor(String actorUid, String? expectedActorUid) {
    if (expectedActorUid != null && actorUid != expectedActorUid) {
      throw const OperationalEventCommandException(
        'The account changed. Open the event form again for the current account.',
        code: 'unauthenticated',
      );
    }
  }

  Future<OperationalEventCommandResult> retryPendingCreation({
    String? expectedActorUid,
    String? expectedRequestId,
  }) async {
    final actorUid = _creationActor();
    _requireCreationActor(actorUid, expectedActorUid);
    final identity = await _creationStore.pending(actorUid);
    if (identity == null) {
      throw const OperationalEventCommandException(
        'There is no event awaiting confirmation for this account.',
      );
    }
    if (expectedRequestId != null && identity.requestId != expectedRequestId) {
      throw const OperationalEventCommandException(
        'The saved event changed. Open its confirmation again.',
      );
    }
    return _sendCreation(actorUid, identity);
  }

  Future<OperationalEventCommandResult> _sendCreation(
    String actorUid,
    PendingOperationalEventCreation identity,
  ) async {
    if (_creationActor() != actorUid) {
      throw const OperationalEventCommandException(
        'The signed-in account changed. The saved event was not sent.',
        code: 'unauthenticated',
      );
    }
    late final OperationalEventCommandResult result;
    try {
      result = await _send(<String, dynamic>{
        ...identity.toRequest(),
        'expectedActorUid': actorUid,
      }, OperationalEventCommand.create);
    } on OperationalEventCommandException catch (error) {
      // Only committed terminal evidence may release this intent. A lost error,
      // generic domain error, or different actor/payload must remain retryable.
      if (_actorUidResolver()?.trim() == actorUid &&
          _isTerminalCreationRejection(error, actorUid, identity)) {
        await _creationStore.clearIfMatches(
          actorUid: actorUid,
          identity: identity,
        );
      }
      rethrow;
    }
    if (_creationActor() != actorUid) {
      throw const OperationalEventCommandException(
        'The account changed while confirming the event. Sign in to the original account to confirm it.',
        code: 'unauthenticated',
      );
    }
    await _creationStore.clearIfMatches(actorUid: actorUid, identity: identity);
    return result;
  }

  bool _isTerminalCreationRejection(
    OperationalEventCommandException error,
    String actorUid,
    PendingOperationalEventCreation identity,
  ) {
    final details = error.details;
    if (details is! Map) return false;
    final reasonCode = details['reasonCode'];
    const expectedCodes = <String, String>{
      'operational-event-asset-class-missing': 'not-found',
      'operational-event-asset-missing': 'not-found',
      'operational-event-asset-class-invalid': 'failed-precondition',
      'operational-event-asset-invalid': 'failed-precondition',
      'operational-event-asset-class-mismatch': 'failed-precondition',
    };
    if (reasonCode is! String ||
        !expectedCodes.containsKey(reasonCode) ||
        error.code != expectedCodes[reasonCode]) {
      return false;
    }
    final proof = details['terminalRejection'];
    if (proof is! Map ||
        proof.length != 8 ||
        proof['schemaVersion'] != 1 ||
        proof['outcome'] != 'rejected' ||
        proof['requestId'] != identity.requestId ||
        proof['eventId'] != identity.eventId ||
        proof['actorUid'] != actorUid ||
        proof['operation'] != OperationalEventCommand.create.wireName ||
        proof['fingerprint'] != identity.commandFingerprint ||
        proof['committedAt'] is! String) {
      return false;
    }
    final committedAt = DateTime.tryParse(proof['committedAt'] as String);
    return committedAt != null &&
        committedAt.toUtc().toIso8601String() == proof['committedAt'];
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
    return _send(request, operation);
  }

  Future<OperationalEventCommandResult> _send(
    Map<String, dynamic> request,
    OperationalEventCommand operation,
  ) async {
    try {
      final response = await _client
          .httpsCallable(operationalEventCallableName)
          .call<Map<String, dynamic>>(request);
      return OperationalEventCommandResult.fromMap(
        Map<String, dynamic>.from(response.data),
        expectedRequestId: request['requestId'] as String,
        expectedOperation: operation,
        expectedEventId: request['eventId'] as String,
      );
    } on FirebaseFunctionsException catch (error) {
      throw OperationalEventCommandException(
        error.message ?? 'The operational event could not be changed.',
        code: error.code,
        details: error.details,
      );
    } on PersistedDataFormatException catch (error) {
      throw OperationalEventCommandException(
        'The server returned invalid event evidence: $error',
        code: 'data-loss',
      );
    }
  }
}
