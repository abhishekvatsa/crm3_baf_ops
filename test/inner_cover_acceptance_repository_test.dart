import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_acceptance_input.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_acceptance_submission.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restored acceptance sends the original envelope through V2 and retains a valid receipt',
    () async {
      final now = DateTime.utc(2026, 8, 1);
      final original = InnerCoverAcceptanceSubmission.prepare(
        cover: _cover(now),
        input: InnerCoverAcceptanceInput(
          inspectedOn: now,
          acceptanceReference: ' Original inspection ',
          reason: ' Original reason ',
        ),
        actorUid: 'original-admin',
        requestId: 'original-request',
        now: now,
      );
      final restored = InnerCoverAcceptanceSubmission.parse(
        original.envelopeJson,
      );
      final functions = _Functions(
        expectedCallable: assetHierarchyV2CallableName,
      );
      final repository = AssetHierarchyRepository(
        firestore: _Firestore(),
        functions: functions,
      );
      final receipt = await repository.dispatchFrozenInnerCoverAcceptance(
        restored.request,
        originActorUid: restored.actorUid,
      );
      expect(functions.outerRequest, jsonDecode(original.envelopeJson));
      expect(restored.input.acceptanceReference, 'Original inspection');
      expect(restored.expectedVersion, 1);
      expect(restored.envelopeJson, original.envelopeJson);
      final storedReceipt = jsonEncode(receipt.toInnerCoverMap());
      final validated = AssetHierarchyMutationReceipt.fromMap(
        Map<String, dynamic>.from(jsonDecode(storedReceipt) as Map),
        request: restored.request,
      );
      expect(validated.requestId, 'original-request');
      expect(validated.version, 2);
    },
  );

  test(
    'acceptance refuses a shape-valid receipt for the wrong version',
    () async {
      final functions = _Functions()..responseVersion = 3;
      final repository = AssetHierarchyRepository(
        firestore: _Firestore(),
        functions: functions,
      );
      final now = DateTime.utc(2026, 8, 1);
      await expectLater(
        repository.acceptInnerCover(
          cover: _cover(now),
          inspectedOn: now,
          acceptanceReference: 'Inspection',
          actor: _admin(now),
          reason: 'Reviewed inspection',
        ),
        throwsA(isA<AssetHierarchyException>()),
      );
    },
  );

  for (final length in [0, 1, 1000, 1001]) {
    test(
      'acceptance reason length $length is checked before dispatch',
      () async {
        final functions = _Functions();
        final repository = AssetHierarchyRepository(
          firestore: _Firestore(),
          functions: functions,
        );
        final now = DateTime.utc(2026, 8, 1);
        final request = repository.acceptInnerCover(
          cover: _cover(now),
          inspectedOn: now,
          acceptanceReference: 'Inspection reference',
          actor: _admin(now),
          reason: 'x' * length,
        );
        if (length == 0 || length > 1000) {
          await expectLater(
            request,
            throwsA(isA<AssetHierarchyInputRejected>()),
          );
          expect(functions.request, isNull);
        } else {
          await request;
          expect(functions.request?['reason'], 'x' * length);
        }
      },
    );
  }
  for (final field in ['leakTestReference', 'ndtReference', 'notes']) {
    test(
      'overlong $field is a local refusal with no callable request',
      () async {
        final functions = _Functions();
        final repository = AssetHierarchyRepository(
          firestore: _Firestore(),
          functions: functions,
        );
        final now = DateTime.utc(2026, 8, 1);
        await expectLater(
          repository.acceptInnerCover(
            cover: _cover(now),
            inspectedOn: now,
            acceptanceReference: 'Inspection reference',
            actor: _admin(now),
            reason: 'Inspection reviewed.',
            leakTestReference: field == 'leakTestReference' ? 'x' * 241 : null,
            ndtReference: field == 'ndtReference' ? 'x' * 241 : null,
            notes: field == 'notes' ? 'x' * 2001 : null,
          ),
          throwsA(isA<AssetHierarchyInputRejected>()),
        );
        expect(functions.request, isNull);
      },
    );
  }
  test(
    'real repository sends UTC milliseconds for a microsecond inspection instant',
    () async {
      final functions = _Functions();
      final repository = AssetHierarchyRepository(
        firestore: _Firestore(),
        functions: functions,
      );
      final now = DateTime.utc(2026, 9, 12);
      final cover = _cover(now);
      final input = DateTime.parse('2026-09-12T08:30:00.123456Z');
      expect(input.microsecond, 456);
      final receipt = await repository.acceptInnerCover(
        cover: cover,
        inspectedOn: input,
        acceptanceReference: 'Inspection IC-30',
        actor: AppUser(
          uid: 'admin-1',
          name: 'Admin One',
          email: 'admin@example.test',
          roles: const [AppRole.admin],
          isApproved: true,
          createdAt: now,
        ),
        reason: 'Inspected and accepted with recorded evidence.',
        requestId: '88888888-8888-4888-8888-888888888888',
      );
      final request = functions.request!;
      final legacyRequest = <String, dynamic>{
        ...request,
        'acceptanceDraft': <String, dynamic>{
          ...Map<String, dynamic>.from(request['acceptanceDraft'] as Map),
          'inspectedOn': input.toUtc().toIso8601String(),
        },
      };
      expect(
        (request['acceptanceDraft'] as Map)['inspectedOn'],
        '2026-09-12T08:30:00.123Z',
      );
      expect(
        input.microsecond,
        456,
        reason: 'Only new command transport is normalized.',
      );
      expect(receipt.version, 2);
      const fixturePath =
          'functions/test/fixtures/inner_cover_acceptance_dart_request.json';
      const legacyFixturePath =
          'functions/test/fixtures/inner_cover_acceptance_legacy_dart_request.json';
      const update = bool.fromEnvironment('UPDATE_INNER_COVER_DART_FIXTURE');
      if (update) {
        final file = File(fixturePath);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(request)}\n',
        );
        File(legacyFixturePath).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(legacyRequest)}\n',
        );
      }
      expect(
        jsonDecode(File(fixturePath).readAsStringSync()),
        request,
        reason:
            'The backend fixture must match a request emitted by the real Dart repository.',
      );
      expect(
        jsonDecode(File(legacyFixturePath).readAsStringSync()),
        legacyRequest,
        reason:
            'Legacy fixture uses the actual Dart ISO serializer used by Build 27, with the same otherwise valid command.',
      );
    },
  );
  for (final scenario in <({String code, String? reason, bool editable})>[
    (
      code: 'invalid-argument',
      reason: 'invalid-inner-cover-lifecycle-request',
      editable: true,
    ),
    (code: 'aborted', reason: 'inner-cover-version-mismatch', editable: true),
    (
      code: 'failed-precondition',
      reason: 'inner-cover-not-awaiting-acceptance',
      editable: true,
    ),
    (
      code: 'failed-precondition',
      reason: 'inner-cover-legacy-replay-reconciliation-required',
      editable: false,
    ),
    (
      code: 'failed-precondition',
      reason: 'inner-cover-profile-malformed',
      editable: false,
    ),
    (
      code: 'failed-precondition',
      reason: 'inner-cover-projection-incomplete',
      editable: false,
    ),
    (
      code: 'data-loss',
      reason: 'inner-cover-request-id-reused',
      editable: false,
    ),
    (
      code: 'data-loss',
      reason: 'inner-cover-replay-evidence-drift',
      editable: false,
    ),
    (code: 'failed-precondition', reason: null, editable: false),
    (
      code: 'invalid-argument',
      reason: 'unknown-validation-origin',
      editable: false,
    ),
    (code: 'deadline-exceeded', reason: null, editable: false),
  ]) {
    test(
      'callable ${scenario.code}/${scenario.reason} editable=${scenario.editable}',
      () async {
        final functions = _Functions()
          ..failure = FirebaseFunctionsException(
            code: scenario.code,
            message: 'Server explanation',
            details: scenario.reason == null
                ? null
                : {'reasonCode': scenario.reason},
          );
        final repository = AssetHierarchyRepository(
          firestore: _Firestore(),
          functions: functions,
        );
        final now = DateTime.utc(2026, 9, 12);
        final future = repository.acceptInnerCover(
          cover: _cover(now),
          inspectedOn: now,
          acceptanceReference: 'Inspection IC-30',
          actor: AppUser(
            uid: 'admin-1',
            name: 'Admin One',
            email: 'admin@example.test',
            roles: const [AppRole.admin],
            isApproved: true,
            createdAt: now,
          ),
          reason: 'Inspected and accepted with recorded evidence.',
          requestId: '88888888-8888-4888-8888-888888888888',
        );
        await expectLater(
          future,
          throwsA(
            predicate<Object>(
              (error) =>
                  error is AssetHierarchyException &&
                  (error is AssetHierarchyCommandRefused) == scenario.editable,
            ),
          ),
        );
        expect(functions.request?['operation'], 'ACCEPT_INNER_COVER');
      },
    );
  }
}

AppUser _admin(DateTime now) => AppUser(
  uid: 'admin-1',
  name: 'Admin One',
  email: 'admin@example.test',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: now,
);

InnerCoverProfile _cover(DateTime now) => InnerCoverProfile(
  id: '33333333-3333-4333-8333-333333333333',
  assetClassId: '11111111-1111-4111-8111-111111111111',
  assetClassCode: 'INNER_COVER',
  assetClassName: 'Inner Cover',
  serialNumber: 'GR30',
  normalizedSerialNumber: 'GR30',
  sourceType: InnerCoverSourceType.purchased,
  originClassification: InnerCoverOriginClassification.documentedPurchase,
  lifecycleState: InnerCoverLifecycleState.awaitingInspection,
  traceabilityGrade: InnerCoverTraceabilityGrade.t3,
  version: 1,
  createdAt: now,
  updatedAt: now,
  lastMutationId: '77777777-7777-4777-8777-777777777777',
);

class _Firestore extends Fake implements FirebaseFirestore {}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions({this.expectedCallable = assetHierarchyCallableName});
  final String expectedCallable;
  Map<String, dynamic>? request;
  Map<String, dynamic>? outerRequest;
  int responseVersion = 2;
  FirebaseFunctionsException? failure;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, expectedCallable);
    return _Callable(this);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.owner);
  final _Functions owner;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.outerRequest = Map<String, dynamic>.from(parameters as Map);
    final request = Map<String, dynamic>.from(
      owner.expectedCallable == assetHierarchyV2CallableName
          ? owner.outerRequest!['request'] as Map
          : parameters,
    );
    owner.request = request;
    if (owner.failure != null) throw owner.failure!;
    return _Result<T>(
      <String, dynamic>{
            'ok': true,
            'requestId': request['requestId'],
            'operation': request['operation'],
            'innerCoverId': request['innerCoverId'],
            'version': owner.responseVersion,
            'secondaryVersion': null,
            'auditId': 'inner_cover_${request['requestId']}',
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
