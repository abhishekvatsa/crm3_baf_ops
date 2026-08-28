import 'package:crm3_baf_ops/features/admin/services/user_authority_command_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthorityTransport implements UserAuthorityCommandTransport {
  Map<String, dynamic>? lastRequest;
  Object? Function(Map<String, dynamic> request)? responder;
  int callCount = 0;

  @override
  Future<Object?> call(Map<String, dynamic> request) async {
    callCount += 1;
    lastRequest = Map<String, dynamic>.from(request);
    return responder?.call(request);
  }
}

AppUser _user({
  String uid = 'target_1',
  bool isApproved = true,
  List<AppRole> roles = const <AppRole>[AppRole.operations, AppRole.admin],
}) {
  return AppUser(
    uid: uid,
    name: 'Target User',
    email: 'target@test.local',
    roles: roles,
    isApproved: isApproved,
    createdAt: DateTime.utc(2026, 7, 26),
  );
}

Map<String, dynamic> _successResponse(
  Map<String, dynamic> request, {
  required bool isApproved,
  required List<AppRole> roles,
  bool idempotentReplay = false,
}) {
  return <String, dynamic>{
    'ok': true,
    'requestId': request['requestId'],
    'targetUid': request['targetUid'],
    'operation': request['operation'],
    'isApproved': isApproved,
    'roles': roles.map((role) => role.name).toList(),
    'authorityDigest': userAuthorityDigest(
      isApproved: isApproved,
      roles: roles,
    ),
    'auditId': 'server_authority_${request['requestId']}',
    'committedAt': '2026-07-26T01:00:00.000Z',
    'idempotentReplay': idempotentReplay,
  };
}

void main() {
  const requestId = '11111111-1111-4111-8111-111111111111';

  test('authority digest matches the backend canonical fixture', () {
    expect(
      userAuthorityDigest(
        isApproved: true,
        roles: const <AppRole>[
          AppRole.operations,
          AppRole.admin,
          AppRole.admin,
        ],
      ),
      'auth1-sha256:ae1c1b9c240212e9079e06b8f04c501136902437eaab96e14791d4b68d264d1a',
    );
  });

  test('replace roles sends one normalized governed command', () async {
    final transport = _FakeAuthorityTransport();
    transport.responder = (request) {
      return _successResponse(
        request,
        isApproved: true,
        roles: const <AppRole>[AppRole.operations, AppRole.si],
      );
    };
    final service = UserAuthorityCommandService(transport: transport);

    final result = await service.replaceRoles(
      _user(),
      roles: const <AppRole>[AppRole.si, AppRole.operations, AppRole.si],
      reason: 'Approved roster correction.',
      requestId: requestId,
    );

    expect(transport.callCount, 1);
    expect(transport.lastRequest, <String, dynamic>{
      'requestId': requestId,
      'targetUid': 'target_1',
      'operation': 'REPLACE_ROLES',
      'expectedAuthorityDigest':
          'auth1-sha256:ae1c1b9c240212e9079e06b8f04c501136902437eaab96e14791d4b68d264d1a',
      'roles': <String>['operations', 'si'],
      'reason': 'Approved roster correction.',
    });
    expect(result.roles, const <AppRole>[AppRole.operations, AppRole.si]);
    expect(result.idempotentReplay, isFalse);
  });

  test(
    'approve omits replacement roles and verifies replay response',
    () async {
      final transport = _FakeAuthorityTransport();
      transport.responder = (request) {
        return _successResponse(
          request,
          isApproved: true,
          roles: const <AppRole>[AppRole.operations],
          idempotentReplay: true,
        );
      };
      final service = UserAuthorityCommandService(transport: transport);

      final result = await service.approve(
        _user(isApproved: false, roles: const <AppRole>[AppRole.operations]),
        reason: 'Approved for operational access.',
        requestId: requestId,
      );

      expect(transport.lastRequest?['operation'], 'APPROVE');
      expect(transport.lastRequest?.containsKey('roles'), isFalse);
      expect(result.isApproved, isTrue);
      expect(result.idempotentReplay, isTrue);
    },
  );

  test('malformed response digest fails closed', () async {
    final transport = _FakeAuthorityTransport();
    transport.responder = (request) {
      return <String, dynamic>{
        ..._successResponse(
          request,
          isApproved: false,
          roles: const <AppRole>[AppRole.operations],
        ),
        'authorityDigest':
            'auth1-sha256:${List<String>.filled(64, '0').join()}',
      };
    };
    final service = UserAuthorityCommandService(transport: transport);

    await expectLater(
      service.revoke(
        _user(roles: const <AppRole>[AppRole.operations]),
        reason: 'Access revoked after governance review.',
        requestId: requestId,
      ),
      throwsA(
        isA<UserAuthorityMutationException>().having(
          (error) => error.reasonCode,
          'reasonCode',
          'authority-response-digest-mismatch',
        ),
      ),
    );
  });

  test(
    'non-string or non-canonical committedAt evidence fails closed',
    () async {
      for (final invalid in <Object>[20260726, '2026-07-26T01:00:00Z']) {
        final transport = _FakeAuthorityTransport();
        transport.responder = (request) {
          return <String, dynamic>{
            ..._successResponse(
              request,
              isApproved: true,
              roles: const <AppRole>[AppRole.operations],
            ),
            'committedAt': invalid,
          };
        };
        final service = UserAuthorityCommandService(transport: transport);

        await expectLater(
          service.approve(
            _user(
              isApproved: false,
              roles: const <AppRole>[AppRole.operations],
            ),
            reason: 'Approved for operational access.',
            requestId: requestId,
          ),
          throwsA(
            isA<UserAuthorityMutationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'authority-response-invalid',
            ),
          ),
        );
      }
    },
  );

  test('blank reason is rejected before transport access', () async {
    final transport = _FakeAuthorityTransport();
    final service = UserAuthorityCommandService(transport: transport);

    await expectLater(
      service.approve(
        _user(isApproved: false),
        reason: '   ',
        requestId: requestId,
      ),
      throwsA(isA<UserAuthorityMutationException>()),
    );
    expect(transport.callCount, 0);
  });
}
