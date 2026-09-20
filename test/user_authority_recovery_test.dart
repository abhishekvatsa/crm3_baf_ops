import 'package:crm3_baf_ops/features/auth/services/auth_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/admin/services/user_authority_command_service.dart';
import 'package:crm3_baf_ops/features/admin/services/user_authority_durable_command_controller.dart';
import 'package:crm3_baf_ops/features/admin/repositories/user_directory_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import '../tool/test_support/test_isar_core.dart';

class _Transport implements UserAuthorityCommandTransport {
  late Future<Object?> Function(Map<String, dynamic>) invoke;
  @override
  Future<Object?> call(Map<String, dynamic> request) => invoke(request);
}

AppUser user(
  String uid, {
  bool approved = true,
  List<AppRole> roles = const [AppRole.admin],
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@test.local',
  roles: roles,
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);
Map<String, dynamic> result(
  Map<String, dynamic> request, {
  String status = 'available',
}) {
  final approved = request['operation'] != 'REVOKE';
  final roles = request['roles'] as List? ?? ['operations'];
  final digest = userAuthorityDigest(
    isApproved: approved,
    roles: roles.map((r) => AppRole.values.byName(r)),
  );
  return {
    'ok': true,
    'requestId': request['requestId'],
    'targetUid': request['targetUid'],
    'operation': request['operation'],
    'isApproved': approved,
    'roles': roles,
    'authorityDigest': digest,
    'authorityRevision': 1,
    'currentAuthorityStatus': status,
    'currentAuthorityDigest': status == 'available' ? digest : null,
    'currentAuthorityRevision': status == 'available' ? 1 : null,
    'supersededByLaterChange': false,
    'auditId': 'server_authority_${request['requestId']}',
    'committedAt': '2026-09-20T10:00:00.000Z',
    'idempotentReplay': true,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late DurableSubmissionRepository store;
  late AppUser? actor;
  late DateTime now;
  late _Transport transport;
  late List<Map<String, dynamic>> sent;
  Future<void> open() async {
    db = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'authority-journal',
      inspector: false,
    );
    store = DurableSubmissionRepository(db, now: () => now);
  }

  UserAuthorityDurableCommandController owner({
    Future<void> Function(String)? verify,
  }) => UserAuthorityDurableCommandController(
    store: store,
    service: UserAuthorityCommandService(transport: transport),
    requireActor: () => actor,
    verifyFreshActor: verify,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('authority-journal-');
    now = DateTime.utc(2026, 9, 20);
    actor = user('admin');
    sent = [];
    transport = _Transport();
    transport.invoke = (envelope) async {
      sent.add(envelope);
      return result(Map<String, dynamic>.from(envelope['request'] as Map));
    };
    await open();
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  final target = user('target', approved: false, roles: [AppRole.operations]);
  test(
    'late original and replay observations confirm the same authority decision',
    () async {
      final dispatched = Completer<Map<String, dynamic>>();
      final originalReply = Completer<Object?>();
      transport.invoke = (envelope) async {
        sent.add(envelope);
        if (envelope.containsKey('request')) {
          dispatched.complete(
            Map<String, dynamic>.from(envelope['request'] as Map),
          );
          return originalReply.future;
        }
        return result(
          Map<String, dynamic>.from(envelope['receiptLookup'] as Map),
          status: 'not-disclosed',
        );
      };
      final first = owner().approve(target, reason: 'Reviewed access decision');
      final request = await dispatched.future;
      final saved = (await store.listForActor('admin')).single;
      now = now.add(const Duration(minutes: 6));
      final replay = await owner().check(saved.submissionId);
      expect(replay.currentAuthorityStatus, 'not-disclosed');
      originalReply.complete({...result(request), 'idempotentReplay': false});
      expect((await first).requestId, saved.requestId);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(sent, hasLength(2));
    },
  );

  test(
    'authority acceptance must advance the exact reviewed revision once',
    () async {
      transport.invoke = (envelope) async {
        sent.add(envelope);
        return {
          ...result(Map<String, dynamic>.from(envelope['request'] as Map)),
          'authorityRevision': 9,
          'currentAuthorityRevision': 9,
        };
      };
      await expectLater(
        owner().approve(target, reason: 'Reviewed access decision'),
        throwsA(isA<DurableSubmissionException>()),
      );
      final saved = (await store.listForActor(
        'admin',
        includeTerminal: true,
      )).single;
      expect(saved.state.isAccepted, isFalse);
      expect(saved.state.isUnresolved, isTrue);
    },
  );
  test(
    'late contradictory decision time cannot replace a retained acceptance',
    () async {
      final dispatched = Completer<Map<String, dynamic>>();
      final originalReply = Completer<Object?>();
      transport.invoke = (envelope) async {
        if (envelope.containsKey('request')) {
          dispatched.complete(
            Map<String, dynamic>.from(envelope['request'] as Map),
          );
          return originalReply.future;
        }
        return result(
          Map<String, dynamic>.from(envelope['receiptLookup'] as Map),
        );
      };
      final first = owner().approve(target, reason: 'Reviewed access decision');
      final request = await dispatched.future;
      final saved = (await store.listForActor('admin')).single;
      now = now.add(const Duration(minutes: 6));
      await owner().check(saved.submissionId);
      final retained = (await store.read(saved.submissionId))!.receiptJson;
      final refused = expectLater(
        first,
        throwsA(
          isA<DurableSubmissionException>().having(
            (error) => error.code,
            'code',
            'acceptance-conflict',
          ),
        ),
      );
      originalReply.complete({
        ...result(request),
        'committedAt': '2026-09-20T11:00:00.000Z',
      });
      await refused;
      expect((await store.read(saved.submissionId))!.receiptJson, retained);
    },
  );
  test(
    'lost acceptance recovers exact actor and payload after journal close/reopen',
    () async {
      Map<String, dynamic>? original;
      transport.invoke = (envelope) async {
        sent.add(envelope);
        original = Map<String, dynamic>.from(envelope['request'] as Map);
        expect(
          (await store.listForActor('admin')).single.state,
          DurableSubmissionState.sending,
        );
        throw StateError('lost server reply');
      };
      await expectLater(
        owner().approve(target, reason: 'Reviewed return'),
        throwsA(isA<DurableSubmissionException>()),
      );
      final pending = (await store.listForActor('admin')).single;
      await db.close();
      await open();
      now = now.add(const Duration(minutes: 10));
      actor = user('admin', approved: false);
      transport.invoke = (envelope) async {
        sent.add(envelope);
        expect(envelope['originActorUid'], 'admin');
        expect(envelope.containsKey('request'), false);
        expect(envelope['receiptLookup'], original);
        return result(original!, status: 'not-disclosed');
      };
      final accepted = await owner().check(pending.submissionId);
      expect(accepted.currentAuthorityStatus, 'not-disclosed');
      expect(accepted.isApproved, true);
      expect(
        (await store.read(pending.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(sent, hasLength(2));
    },
  );
  test('another account cannot check or adopt saved evidence', () async {
    transport.invoke = (envelope) async {
      sent.add(envelope);
      throw StateError('network');
    };
    await expectLater(
      owner().approve(target, reason: 'Review'),
      throwsA(isA<DurableSubmissionException>()),
    );
    final pending = (await store.listForActor('admin')).single;
    actor = user('other');
    await expectLater(
      owner().check(pending.submissionId),
      throwsA(
        isA<DurableSubmissionException>().having(
          (e) => e.code,
          'code',
          'actor-mismatch',
        ),
      ),
    );
    expect(sent, hasLength(1));
    expect(await owner().listForCurrentActor(), isEmpty);
  });
  test(
    'account switch during fresh authority check cannot create a command',
    () async {
      await expectLater(
        owner(
          verify: (_) async {
            actor = user('other');
          },
        ).approve(target, reason: 'Review'),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(sent, isEmpty);
      expect(await store.listForActor('admin'), isEmpty);
    },
  );
  test('unconfirmed server authority cannot prepare a new grant', () async {
    await expectLater(
      owner(
        verify: (_) async {
          throw StateError('offline');
        },
      ).approve(target, reason: 'Review'),
      throwsStateError,
    );
    expect(sent, isEmpty);
    expect(await store.listForActor('admin'), isEmpty);
  });
  test(
    'absence in an outcome lookup retains uncertainty and cannot release the resource',
    () async {
      transport.invoke = (envelope) async {
        throw StateError('network');
      };
      await expectLater(
        owner().approve(target, reason: 'Review'),
        throwsA(isA<DurableSubmissionException>()),
      );
      final pending = (await store.listForActor('admin')).single;
      now = now.add(const Duration(minutes: 10));
      transport.invoke = (envelope) async {
        expect(envelope.containsKey('receiptLookup'), true);
        throw const UserAuthorityMutationException(
          code: 'failed-precondition',
          reasonCode: 'authority-outcome-not-established',
          message: 'Unknown',
        );
      };
      await expectLater(
        owner().check(pending.submissionId),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(
        (await store.read(pending.submissionId))!.state,
        DurableSubmissionState.uncertain,
      );
      await expectLater(
        owner().approve(target, reason: 'New decision'),
        throwsA(
          isA<DurableSubmissionException>().having(
            (e) => e.code,
            'code',
            'resource-pending',
          ),
        ),
      );
    },
  );
  test(
    'retained acceptance can be read after the actor loses approval',
    () async {
      await owner().approve(target, reason: 'Review');
      final saved = (await store.listForActor(
        'admin',
        includeTerminal: true,
      )).single;
      expect(jsonDecode(saved.envelopeJson)['originActorUid'], 'admin');
      actor = user('admin', approved: false);
      transport.invoke = (_) async {
        throw StateError('must not redispatch');
      };
      expect(
        (await owner().check(saved.submissionId)).requestId,
        saved.requestId,
      );
    },
  );
  test('sign-in refresh preserves revoked decisions and reviewed names', () {
    final patch = existingUserProfileRefresh(
      {
        'name': 'Plant verified name',
        'isApproved': false,
        'roles': ['admin'],
        'authorityRevision': 7,
        'accessDisposition': 'revoked',
        'lastAuthorityDecision': {'reason': 'Reviewed withdrawal'},
      },
      providerName: 'Google alias',
      providerEmail: 'u@test.local',
      providerPhotoUrl: null,
    );
    expect(patch, {'email': 'u@test.local', 'photoUrl': null});
    expect(
      existingUserProfileRefresh(
        {'name': ' '},
        providerName: ' Recovered name ',
        providerEmail: 'u@test.local',
      )['name'],
      'Recovered name',
    );
  });
  test(
    'qualified directory preserves healthy users and identifies damaged authority',
    () {
      Map<String, dynamic> profile(String name) => {
        'name': name,
        'email': 'u@test.local',
        'roles': ['operations'],
        'isApproved': false,
        'createdAt': DateTime.utc(2026),
      };
      final roster = UserDirectoryPopulation.decode(
        {
          'valid': profile('Valid'),
          'badName': profile(' '),
          'badRole': {
            ...profile('Bad'),
            'roles': ['unknown'],
          },
          'badRevision': {...profile('Bad'), 'authorityRevision': 'broken'},
        },
        fromCache: true,
        hasPendingWrites: false,
      );
      expect(roster.map((u) => u.uid), ['valid']);
      expect(roster.failedIds, ['badName', 'badRole', 'badRevision']);
      expect(roster.isComplete, false);
      expect(roster.single.accessDisposition, 'unknown');
      expect(roster.single.hasServerAuthorityObservation, false);
    },
  );
  test('pending roles may change without falsely marking access revoked', () {
    final pending = AppUser.fromFirestore(
      {
        'name': 'Pending',
        'email': 'p@test.local',
        'roles': ['si'],
        'isApproved': false,
        'createdAt': DateTime.utc(2026),
        'authorityRevision': 2,
        'accessDisposition': 'pending',
      },
      'p',
      fromCache: false,
      observedAt: DateTime.utc(2026),
    );
    expect(pending.accessDisposition, 'pending');
    expect(pending.hasServerAuthorityObservation, true);
  });
}
