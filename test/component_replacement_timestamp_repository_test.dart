import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test(
    'real component replacement preserves a precise installed-client fixture',
    () async {
      final functions = _Functions();
      final repository = AssetHierarchyRepository(
        firestore: _Firestore(),
        functions: functions,
        uuid: _Ids(),
      );
      final now = DateTime.utc(2026, 9, 12);
      final asset = AssetInstanceRecord(
        id: '77777777-7777-4777-8777-777777777777',
        assetClassId: '11111111-1111-4111-8111-111111111111',
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        assetNumber: 1,
        name: 'Furnace 1',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Operations',
        accountableRoleKeys: const ['operations'],
        status: AssetHierarchyStatus.active,
        activeComponentCount: 1,
        version: 2,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'prior-create',
      );
      final before = InstalledComponentRecord(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        assetInstanceId: asset.id,
        assetInstanceVersionAtMutation: 1,
        assetNumber: asset.assetNumber,
        assetInstanceName: asset.name,
        assetClassId: asset.assetClassId,
        assetClassCode: asset.assetClassCode,
        assetClassName: asset.assetClassName,
        definitionNodeId: '33333333-3333-4333-8333-333333333333',
        definitionNodeVersion: 1,
        definitionName: 'Pressure transmitter',
        hierarchyPath: const ['Pressure transmitter'],
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Instrumentation',
        accountableRoleKeys: const ['seniorInstrumentation'],
        status: AssetHierarchyStatus.active,
        version: 1,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'prior-component-create',
      );
      final input = DateTime.parse('2026-09-12T08:30:00.123456Z');
      final replacementId = await repository.replaceInstalledComponent(
        asset: asset,
        before: before,
        replacement: InstalledComponentDraft(
          definitionNodeId: before.definitionNodeId,
          serialNumber: 'PT-NEW-001',
          installedOn: input,
          serviceState: AssetServiceState.inService,
          ownershipStatus: AssetOwnershipStatus.confirmed,
          ownerDiscipline: 'Instrumentation',
          accountableRoleKeys: const ['seniorInstrumentation'],
        ),
        actor: AppUser(
          uid: 'admin-1',
          name: 'Admin One',
          email: 'admin@example.test',
          roles: const [AppRole.admin],
          isApproved: true,
          createdAt: now,
        ),
        reason: 'Replace the pressure transmitter after calibration failure.',
      );
      final request = functions.request!;
      expect(replacementId, request['replacementComponentInstanceId']);
      expect(input.microsecond, 456);
      expect(
        (request['componentDraft'] as Map)['installedOn'],
        '2026-09-12T08:30:00.123Z',
      );
      final legacyRequest = <String, dynamic>{
        ...request,
        'componentDraft': <String, dynamic>{
          ...Map<String, dynamic>.from(request['componentDraft'] as Map),
          // The actual old Dart expression, not a handwritten JS approximation.
          'installedOn': input.toUtc().toIso8601String(),
        },
      };
      const paths = [
        'functions/test/fixtures/component_replacement_dart_request.json',
        'functions/test/fixtures/component_replacement_legacy_dart_request.json',
      ];
      final payloads = [request, legacyRequest];
      for (var index = 0; index < paths.length; index++) {
        final file = File(paths[index]);
        if (const bool.fromEnvironment('UPDATE_COMPONENT_DART_FIXTURE')) {
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert(payloads[index])}\n',
          );
        }
        expect(jsonDecode(file.readAsStringSync()), payloads[index]);
      }
    },
  );
}

class _Firestore extends Fake implements FirebaseFirestore {}

class _Ids extends Fake implements Uuid {
  final _values = [
    '21212121-2121-4121-8121-212121212121',
    '23232323-2323-4232-8232-232323232323',
  ];
  int _index = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => invocation.memberName == #v4
      ? _values[_index++]
      : super.noSuchMethod(invocation);
}

class _Functions extends Fake implements FirebaseFunctions {
  Map<String, dynamic>? request;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, assetHierarchyCallableName);
    return _Callable(this);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.owner);
  final _Functions owner;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final request = Map<String, dynamic>.from(parameters as Map);
    owner.request = request;
    return _Result<T>(
      <String, dynamic>{
            'ok': true,
            'requestId': request['requestId'],
            'operation': request['operation'],
            'assetClassId': request['assetClassId'],
            'nodeId': request['replacementComponentInstanceId'],
            'version': 1,
            'auditId': 'asset_registry_${request['requestId']}',
            'committedAt': '2026-09-12T08:31:00.000Z',
            'idempotentReplay': false,
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
