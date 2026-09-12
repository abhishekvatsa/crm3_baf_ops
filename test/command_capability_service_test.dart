import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/core/release/command_capability_service.dart';
import 'package:flutter_test/flutter_test.dart';

const endpoint = 'mutateAssetHierarchyV2';
Map<String, Object?> response() => <String, Object?>{
  'schemaVersion': 1,
  'callableName': endpoint,
  'protocolVersion': 2,
  'capabilityRevision': 'assetHierarchy.v2.20260912',
  'capabilities': <String>['assetHierarchy.v2', 'innerCoverAcceptance.v1'],
};

void main() {
  test(
    'same-endpoint probe has explicit origin and never contains a business request',
    () async {
      final calls = <Map<String, Object?>>[];
      final service = CommandCapabilityService(
        currentActorUid: () => 'actor-a',
        invoke: (name, probe) async {
          expect(name, endpoint);
          calls.add(probe);
          return response();
        },
      );
      final result = await service.requireCapabilities(
        callableName: endpoint,
        originActorUid: 'actor-a',
        requiredCapabilities: {'assetHierarchy.v2', 'innerCoverAcceptance.v1'},
      );
      expect(result.capabilities, contains('innerCoverAcceptance.v1'));
      expect(calls, [
        {
          'protocolVersion': 2,
          'originActorUid': 'actor-a',
          'probe': 'capabilities',
        },
      ]);
    },
  );

  test('wrong account or missing original actor makes zero calls', () async {
    var calls = 0;
    final service = CommandCapabilityService(
      currentActorUid: () => 'actor-b',
      invoke: (_, _) async {
        calls++;
        return response();
      },
    );
    for (final origin in ['actor-a', '', ' actor-b ']) {
      await expectLater(
        service.requireCapabilities(
          callableName: endpoint,
          originActorUid: origin,
          requiredCapabilities: {'assetHierarchy.v2'},
        ),
        throwsA(isA<CommandCapabilityException>()),
      );
    }
    expect(calls, 0);
  });

  test('account switch during probe cannot authorize continuation', () async {
    var actor = 'actor-a';
    final service = CommandCapabilityService(
      currentActorUid: () => actor,
      invoke: (_, _) async {
        actor = 'actor-b';
        return response();
      },
    );
    await expectLater(
      service.requireCapabilities(
        callableName: endpoint,
        originActorUid: 'actor-a',
        requiredCapabilities: {'assetHierarchy.v2'},
      ),
      throwsA(
        isA<CommandCapabilityException>().having(
          (error) => error.code,
          'code',
          'origin-account-mismatch',
        ),
      ),
    );
  });

  test(
    'missing capability, wrong endpoint, malformed marker, and metadata-only identity fail closed',
    () async {
      for (final value in <Object?>[
        {
          ...response(),
          'capabilities': <String>['assetHierarchy.v2'],
        },
        {...response(), 'callableName': 'executeMaintenanceWorkflowCommandV2'},
        {...response(), 'protocolVersion': 1},
        {...response(), 'capabilityRevision': ''},
        {
          ...response(),
          'capabilities': <String>['assetHierarchy.v2', 'assetHierarchy.v2'],
        },
        {'releaseId': 'production-label', 'gitCommit': 'claimed-new-source'},
      ]) {
        final service = CommandCapabilityService(
          currentActorUid: () => 'actor-a',
          invoke: (_, _) async => value,
        );
        await expectLater(
          service.requireCapabilities(
            callableName: endpoint,
            originActorUid: 'actor-a',
            requiredCapabilities: {'innerCoverAcceptance.v1'},
          ),
          throwsA(isA<CommandCapabilityException>()),
        );
      }
    },
  );

  test(
    'unavailable V2 never falls back to V1 and probes are not cached across rollback',
    () async {
      var calls = 0;
      final service = CommandCapabilityService(
        currentActorUid: () => 'actor-a',
        invoke: (name, _) async {
          expect(name, endpoint);
          calls++;
          if (calls == 1) return response();
          throw FirebaseFunctionsException(
            code: 'not-found',
            message: 'Endpoint absent',
          );
        },
      );
      await service.requireCapabilities(
        callableName: endpoint,
        originActorUid: 'actor-a',
        requiredCapabilities: {'assetHierarchy.v2'},
      );
      await expectLater(
        service.requireCapabilities(
          callableName: endpoint,
          originActorUid: 'actor-a',
          requiredCapabilities: {'assetHierarchy.v2'},
        ),
        throwsA(
          isA<CommandCapabilityException>().having(
            (error) => error.code,
            'code',
            'not-found',
          ),
        ),
      );
      expect(calls, 2);
    },
  );
}
