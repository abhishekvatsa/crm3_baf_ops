import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_server_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/published_assignment_receipt_fixture.dart';

void main() {
  const request = PublishedTemplateAssignmentRequest(
    requestId: '11111111-1111-4111-8111-111111111111',
    packageFirestoreId: 'package-1',
    versionFirestoreId: 'version-1',
    expectedVersionNumber: 1,
    expectedContentHash: 'hash-1',
    assetType: AssetType.base,
    assetNumber: 101,
    assetClassId: 'class-base',
    assetInstanceId: 'base-101',
  );
  late _Functions functions;
  late PublishedTemplateAssignmentServerService server;
  late String envelope;
  setUp(() {
    functions = _Functions(retainedAssignmentReceipt(request.requestId));
    server = PublishedTemplateAssignmentServerService(
      functions: functions,
      currentActorUid: () => 'assigner-1',
    );
    envelope = jsonEncode({
      'protocolVersion': 2,
      'originActorUid': 'assigner-1',
      'request': request.toCallableData(),
    });
  });

  test('assignment V2 sends exact frozen wrapper to its V2 endpoint', () async {
    await server.assignFrozenEnvelope(envelope);
    expect(functions.endpoint, publishedTemplateAssignmentV2CallableName);
    expect(functions.payload, jsonDecode(envelope));
    expect(functions.calls, 1);
  });

  test('assignment V1 remains flat at its original endpoint', () async {
    await server.assign(request: request);
    expect(functions.endpoint, publishedTemplateAssignmentCallableName);
    expect(functions.payload, request.toCallableData());
  });

  test(
    'actor mismatch prevents dispatch without replacing the frozen actor',
    () async {
      final changed = PublishedTemplateAssignmentServerService(
        functions: functions,
        currentActorUid: () => 'assigner-2',
      );
      await expectLater(
        changed.assignFrozenEnvelope(envelope),
        throwsA(isA<PublishedTemplateAssignmentServerException>()),
      );
      expect(functions.calls, 0);
    },
  );

  test('unsupported frozen field fails before dispatch', () async {
    final changed = jsonDecode(envelope) as Map<String, dynamic>;
    (changed['request'] as Map)['expectedVersion'] = 0;
    await expectLater(
      server.assignFrozenEnvelope(jsonEncode(changed)),
      throwsFormatException,
    );
    expect(functions.calls, 0);
  });

  test(
    'completed current projection permits only changed completion remarks',
    () async {
      final execution = functions.response['execution'] as Map;
      execution.addAll(<String, dynamic>{
        'isCompleted': true,
        'completedAt': '2026-06-20T12:00:00.000Z',
        'updatedAt': '2026-06-20T12:00:00.000Z',
        'version': 2,
        'remarks': 'Later completion note',
      });
      final response = await server.assignFrozenEnvelope(envelope);
      expect(
        (response['execution'] as Map)['remarks'],
        'Later completion note',
      );
      execution['assetNumber'] = 102;
      await expectLater(
        server.assignFrozenEnvelope(envelope),
        throwsFormatException,
      );
    },
  );

  test(
    'completed projection cannot excuse changed original actor or request origin',
    () async {
      final execution = functions.response['execution'] as Map;
      execution.addAll(<String, dynamic>{
        'isCompleted': true,
        'completedAt': '2026-06-20T12:00:00.000Z',
        'updatedAt': '2026-06-20T12:00:00.000Z',
        'version': 2,
        'remarks': 'Later completion note',
        'assignedByUid': 'another-actor',
      });
      await expectLater(
        server.assignFrozenEnvelope(envelope),
        throwsFormatException,
      );
      execution['assignedByUid'] = 'assigner-1';
      final origin = jsonDecode(execution['metadataJson'] as String) as Map;
      origin['requestId'] = 'another-request';
      execution['metadataJson'] = jsonEncode(origin);
      await expectLater(
        server.assignFrozenEnvelope(envelope),
        throwsFormatException,
      );
    },
  );
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.response);
  final Map<String, dynamic> response;
  String? endpoint;
  Object? payload;
  int calls = 0;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    endpoint = name;
    return _Callable(this);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.owner);
  final _Functions owner;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.calls++;
    owner.payload = parameters;
    return _Result(owner.response as T);
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}
