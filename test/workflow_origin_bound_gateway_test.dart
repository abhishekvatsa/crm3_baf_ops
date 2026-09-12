import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_submission.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/inspection_campaign_submission_fixture.dart';

void main() {
  late _Functions functions;
  late FirebaseWorkflowCommandGateway gateway;
  late InspectionCampaignSubmission frozen;
  setUp(() {
    functions = _Functions();
    gateway = FirebaseWorkflowCommandGateway(
      functions: functions,
      currentActorUid: () => 'manager-a',
    );
    frozen = InspectionCampaignSubmission.prepare(
      actorUid: 'manager-a',
      commandId: 'command-1',
      campaignId: 'campaign-1',
      payload: campaignCreationPayload(),
    );
  });
  test(
    'V2 sends the original complete wrapper to the exact V2 endpoint',
    () async {
      await gateway.executeOriginBoundEnvelope(frozen.envelopeJson);
      expect(functions.endpoint, maintenanceWorkflowV2CallableName);
      expect(functions.data, jsonDecode(frozen.envelopeJson));
    },
  );
  test('V1 remains a flat command on the existing endpoint', () async {
    await gateway.execute(frozen.command);
    expect(functions.endpoint, maintenanceWorkflowCallableName);
    expect(functions.data, frozen.command.toMap());
  });
  test(
    'changed live actor cannot dispatch saved wrapper or invent an origin',
    () async {
      final changed = FirebaseWorkflowCommandGateway(
        functions: functions,
        currentActorUid: () => 'manager-b',
      );
      await expectLater(
        Future(() => changed.executeOriginBoundEnvelope(frozen.envelopeJson)),
        throwsA(
          isA<WorkflowException>().having(
            (error) => error.code,
            'code',
            WorkflowErrorCode.permissionDenied,
          ),
        ),
      );
      expect(functions.calls, 0);
    },
  );
  test(
    'mismatched receipt remains uncertain after a potentially accepted write',
    () async {
      functions.wrongReceipt = true;
      await expectLater(
        gateway.executeOriginBoundEnvelope(frozen.envelopeJson),
        throwsA(
          isA<WorkflowException>().having(
            (error) => error.code,
            'code',
            WorkflowErrorCode.unavailable,
          ),
        ),
      );
      expect(functions.calls, 1);
    },
  );
}

class _Functions extends Fake implements FirebaseFunctions {
  String? endpoint;
  Object? data;
  int calls = 0;
  bool wrongReceipt = false;
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
    owner.data = parameters;
    return _Result<T>(
      {
            'commandId': owner.wrongReceipt ? 'another-request' : 'command-1',
            'resultKey': 'inspection-campaign-created',
            'aggregateVersion': 1,
            'result': {
              'campaignId': 'campaign-1',
              'status': 'open',
              'definitionCode': 'FURNACE_PT',
            },
            'appliedAt': '2026-09-12T10:00:00.000Z',
          }
          as T,
    );
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}
