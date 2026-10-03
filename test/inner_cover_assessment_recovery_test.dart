import 'dart:convert';

import 'package:crm3_baf_ops/features/assets/services/inner_cover_assessment_recovery.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm3_baf_ops/features/assets/providers/inner_cover_assessment_provider.dart';

AppUser user(String uid, {AppRole role = AppRole.admin}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

WorkflowCommandRecord saved() => WorkflowCommandRecord()
  ..commandId = 'settle-1'
  ..aggregateId = 'case-1'
  ..commandTypeKey = 'settleInnerCoverAssessment'
  ..expectedVersion = 3
  ..stateKey = 'manualReview'
  ..attemptCount = 2
  ..payloadJson = jsonEncode({
    '__workflowOriginBoundV1': 'original-si',
    'payload': {
      'innerCoverId': 'cover-1',
      'innerCoverSerialNumber': 'IC-1',
      'eventLinkageId': 'link-1',
      'expectedTicketVersion': 2,
      'expectedCoverVersion': 4,
      'acceptanceRequestId': 'accept-1',
      'assessorConfirmed': true,
      'reason': 'Post-event inspection resolves the concern.',
    },
  });

class Journal implements WorkflowRepository {
  WorkflowCommandRecord? row = saved();
  @override
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) async => row;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected write/read: $invocation');
}

class Harness {
  final journal = Journal();
  AppUser actor = user('reviewer');
  final requests = <Map<String, Object?>>[];
  Future<void> Function()? onCapability;
  Future<Object?> Function(Map<String, Object?>)? onInvoke;
  late final service = InnerCoverAssessmentRecovery(
    repository: journal,
    actor: () => actor,
    requireCapability: (_) async => onCapability?.call(),
    invoke: (request) async {
      requests.add(request);
      return onInvoke?.call(request) ?? response();
    },
  );
  InnerCoverRecoveryEvidence get evidence =>
      InnerCoverRecoveryEvidence.from(journal.row!);
  Map<String, dynamic> response({
    String? outcome,
    bool receipt = false,
    bool inspected = false,
    String reviewer = 'reviewer',
  }) => {
    'schemaVersion': 1,
    'domain': 'inspectionCampaign',
    'requestId': 'settle-1',
    'evidenceSha256': evidence.sha256Hex,
    'originalActorUid': 'original-si',
    'reviewerUid': reviewer,
    if (outcome != null) ...{
      'outcome': outcome,
      'decisionId': 'b' * 64,
      'decidedAt': '2026-10-03T01:02:03.000Z',
      'reason': 'Checked original assessment and saved request.',
    } else if (inspected)
      'reviewToken': 'c' * 64,
    if (outcome == null)
      'observation': inspected
          ? (receipt ? 'receiptPresent' : 'receiptAbsent')
          : 'unresolved',
    if (outcome != null || inspected) ...{
      'receiptSha256': receipt ? 'd' * 64 : null,
      'receiptSummary': receipt
          ? {
              'actorUid': 'original-si',
              'operation': 'settleInnerCoverAssessment',
              'entityId': 'case-1',
              'version': 4,
              'committedAt': '2026-10-03T00:01:02.000Z',
              'status': null,
            }
          : null,
    },
  };
}

void main() {
  const reason = 'Checked original assessment and saved request.';
  test(
    'malformed original envelopes refuse recovery and retain raw bytes',
    () async {
      for (final invalid in ['{', '[]', 'null', '{"payload":{}}']) {
        final h = Harness();
        h.journal.row!.payloadJson = invalid;
        final original = h.journal.row!;
        await expectLater(
          h.service.status(original),
          throwsA(isA<InnerCoverRecoveryException>()),
        );
        expect(h.requests, isEmpty, reason: invalid);
        expect(h.journal.row, same(original));
        expect(original.payloadJson, invalid);
        expect(original.stateKey, 'manualReview');
      }
    },
  );
  test(
    'noncanonical decision and receipt timestamps keep original requests held',
    () async {
      for (final field in ['decidedAt', 'committedAt']) {
        for (final invalid in <Object?>[
          null,
          42,
          '',
          'not-a-date',
          '2026-02-30T01:02:03.000Z',
          '2026-10-03T01:02:03Z',
          '2026-10-03T01:02:03.000+00:00',
          '2026-10-03T01:02:03.000001Z',
        ]) {
          final h = Harness();
          final original = h.journal.row!;
          final bytes = original.payloadJson;
          h.onInvoke = (_) async {
            final result = h.response(
              outcome: 'reviewedExisting',
              receipt: true,
            );
            if (field == 'decidedAt') {
              result[field] = invalid;
            } else {
              (result['receiptSummary'] as Map)[field] = invalid;
            }
            return result;
          };
          await expectLater(
            h.service.status(original),
            throwsA(isA<InnerCoverRecoveryException>()),
          );
          expect(h.journal.row, same(original));
          expect(original.payloadJson, bytes, reason: '$field: $invalid');
          expect(original.stateKey, 'manualReview');
        }
      }
    },
  );
  test(
    'current actor requires ready authority and matching live authentication',
    () {
      final ready = user('approved');
      final value = AsyncData<AppUser?>(ready);
      expect(verifiedInnerCoverAssessmentActor(value, 'approved'), same(ready));
      expect(verifiedInnerCoverAssessmentActor(value, 'other'), isNull);
      expect(verifiedInnerCoverAssessmentActor(value, null), isNull);
      expect(
        verifiedInnerCoverAssessmentActor(
          const AsyncLoading<AppUser?>().copyWithPrevious(value),
          'approved',
        ),
        isNull,
      );
      expect(
        verifiedInnerCoverAssessmentActor(
          AsyncError<AppUser?>(
            StateError('failed'),
            StackTrace.current,
          ).copyWithPrevious(value),
          'approved',
        ),
        isNull,
      );
    },
  );

  test(
    'accepted summary requires exact keys including explicit null status',
    () async {
      final h = Harness();
      h.onInvoke = (_) async {
        final result = h.response(outcome: 'reviewedExisting', receipt: true);
        final summary = result['receiptSummary'] as Map;
        summary.remove('status');
        summary['unexpected'] = null;
        return result;
      };
      await expectLater(
        h.service.status(h.journal.row!),
        throwsA(isA<InnerCoverRecoveryException>()),
      );
    },
  );

  test(
    'shared Node hash vector preserves Unicode, escapes and original spacing',
    () {
      final row = saved()
        ..commandId = 'settle-vector-1'
        ..payloadJson = const JsonEncoder.withIndent('  ').convert({
          '__workflowOriginBoundV1': 'si-1',
          'payload': {
            'innerCoverId': 'cover-1',
            'innerCoverSerialNumber': 'IC-7',
            'eventLinkageId': 'link-1',
            'expectedTicketVersion': 4,
            'expectedCoverVersion': 5,
            'acceptanceRequestId': 'accept-1',
            'assessorConfirmed': true,
            'reason':
                '  Reviewed café — 已检查.\nThe "cover" passed \\ inspection.  ',
          },
        });
      expect(
        InnerCoverRecoveryEvidence.from(row).sha256Hex,
        '76fd9b98efb14f0bc09508d19ecfe89a7b9243d0cdd8485c4cf2d10576bcbd06',
      );
    },
  );
  test(
    'supplied resolved observation is revalidated before server query',
    () async {
      final h = Harness();
      final fabricated = InnerCoverRecoveryObservation(
        evidence: h.evidence,
        reviewerUid: 'reviewer',
        reason: reason,
        response: {
          ...h.response(outcome: 'cancelled'),
          'originalActorUid': 'other-origin',
        },
      );
      await expectLater(
        h.service.finalize(fabricated),
        throwsA(isA<InnerCoverRecoveryException>()),
      );
      expect(h.requests, isEmpty);
    },
  );

  test(
    'status binds exact original bytes and does not mutate retained journal',
    () async {
      final h = Harness();
      final row = h.journal.row!;
      final bytes = row.payloadJson;
      final result = await h.service.status(row);
      expect(result.resolved, isFalse);
      final request = h.requests.single;
      final recovery = request['recovery']! as Map;
      expect(recovery['phase'], 'status');
      expect(recovery['originalActorUid'], 'original-si');
      expect((recovery['assessmentEvidence'] as Map)['payloadJson'], bytes);
      expect(request['originActorUid'], 'reviewer');
      expect(row.payloadJson, bytes);
      expect(row.stateKey, 'manualReview');
      expect(row.attemptCount, 2);
    },
  );
  test('only exact cancelled decision permits a fresh review', () async {
    final h = Harness();
    h.onInvoke = (_) async => h.response(outcome: 'cancelled');
    expect((await h.service.status(h.journal.row!)).cancelled, isTrue);
    expect(h.journal.row!.stateKey, 'manualReview');
  });
  test(
    'accepted proof is adopted as accepted and never cancellation',
    () async {
      final h = Harness();
      h.onInvoke = (_) async =>
          h.response(outcome: 'reviewedExisting', receipt: true);
      final result = await h.service.status(h.journal.row!);
      expect(result.accepted, isTrue);
      expect(result.cancelled, isFalse);
    },
  );
  test('SI may check status but may not inspect or finalize', () async {
    final h = Harness()..actor = user('reviewer', role: AppRole.si);
    await h.service.status(h.journal.row!);
    await expectLater(
      h.service.inspect(h.journal.row!, reason),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
    expect(h.requests.length, 1);
  });
  test('nonassessor cannot query status', () async {
    final h = Harness()..actor = user('operations', role: AppRole.operations);
    await expectLater(
      h.service.status(h.journal.row!),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
    expect(h.requests, isEmpty);
  });
  test('legacy payload cannot acquire today actor identity', () async {
    final h = Harness();
    h.journal.row!.payloadJson = '{"reason":"legacy"}';
    await expectLater(
      h.service.status(h.journal.row!),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
    expect(h.requests, isEmpty);
  });
  test('other workflow types remain outside recovery admission', () async {
    final h = Harness();
    h.journal.row!.commandTypeKey = 'finalizeWorkflow';
    await expectLater(
      h.service.status(h.journal.row!),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
    expect(h.requests, isEmpty);
  });
  test('whitespace in immutable payload changes evidence identity', () {
    final row = saved();
    final first = InnerCoverRecoveryEvidence.from(row).sha256Hex;
    row.payloadJson = ' ${row.payloadJson}';
    expect(InnerCoverRecoveryEvidence.from(row).sha256Hex, isNot(first));
  });
  for (final field in [
    'evidenceSha256',
    'originalActorUid',
    'requestId',
    'domain',
  ]) {
    test('mismatched $field never releases retained command', () async {
      final h = Harness();
      h.onInvoke = (_) async => {
        ...h.response(outcome: 'cancelled'),
        field: 'wrong',
      };
      await expectLater(
        h.service.status(h.journal.row!),
        throwsA(isA<InnerCoverRecoveryException>()),
      );
      expect(h.journal.row!.stateKey, 'manualReview');
    });
  }
  test('wrong accepted case cannot be adopted', () async {
    final h = Harness();
    h.onInvoke = (_) async {
      final r = h.response(outcome: 'reviewedExisting', receipt: true);
      (r['receiptSummary'] as Map)['entityId'] = 'other-case';
      return r;
    };
    await expectLater(
      h.service.status(h.journal.row!),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
  });
  test('same actor checked after capability await before network', () async {
    final h = Harness();
    h.onCapability = () async {
      h.actor = user('other-admin');
    };
    await expectLater(
      h.service.inspect(h.journal.row!, reason),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
    expect(h.requests, isEmpty);
  });
  test('actor change after server response prevents adoption', () async {
    final h = Harness();
    h.onInvoke = (_) async {
      h.actor = user('other-admin');
      return h.response(outcome: 'cancelled');
    };
    await expectLater(
      h.service.status(h.journal.row!),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
  });
  test('concurrent local payload change prevents adoption', () async {
    final h = Harness();
    h.onInvoke = (_) async {
      final result = h.response(outcome: 'cancelled');
      h.journal.row!.payloadJson = ' ${h.journal.row!.payloadJson}';
      return result;
    };
    await expectLater(
      h.service.status(h.journal.row!),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
  });
  test(
    'finalize requires explicit inspection token and unchanged evidence',
    () async {
      final h = Harness();
      h.onInvoke = (_) async => h.response(inspected: true);
      final inspection = await h.service.inspect(h.journal.row!, reason);
      h.onInvoke = (request) async {
        expect((request['recovery'] as Map)['reviewToken'], 'c' * 64);
        expect((request['recovery'] as Map)['phase'], 'finalize');
        return h.response(outcome: 'cancelled');
      };
      expect((await h.service.finalize(inspection)).cancelled, isTrue);
      expect(h.journal.row!.stateKey, 'manualReview');
      expect(h.requests.length, 2);
    },
  );
  test('changed journal after inspection cannot be finalized', () async {
    final h = Harness();
    h.onInvoke = (_) async => h.response(inspected: true);
    final inspection = await h.service.inspect(h.journal.row!, reason);
    h.journal.row!.expectedVersion++;
    await expectLater(
      h.service.finalize(inspection),
      throwsA(isA<InnerCoverRecoveryException>()),
    );
    expect(h.requests.length, 1);
  });
  test(
    'acceptance race requires fresh inspection, never accepts changed result',
    () async {
      final h = Harness();
      h.onInvoke = (_) async => h.response(inspected: true);
      final inspection = await h.service.inspect(h.journal.row!, reason);
      h.onInvoke = (_) async =>
          h.response(outcome: 'reviewedExisting', receipt: true);
      await expectLater(
        h.service.finalize(inspection),
        throwsA(isA<InnerCoverRecoveryException>()),
      );
    },
  );
  test(
    'lost final reply can recover immutable decision by different Admin',
    () async {
      final h = Harness();
      h.onInvoke = (_) async =>
          h.response(outcome: 'cancelled', reviewer: 'earlier-admin');
      final result = await h.service.inspect(h.journal.row!, reason);
      expect(result.cancelled, isTrue);
      expect(result.response['reviewerUid'], 'earlier-admin');
      expect((await h.service.finalize(result)).cancelled, isTrue);
      expect(h.requests.length, 2); // Read-only status, no second finalization.
    },
  );
  test('transport failure leaves manual review intact', () async {
    final h = Harness();
    h.onInvoke = (_) async => throw StateError('lost transport');
    await expectLater(h.service.status(h.journal.row!), throwsStateError);
    expect(h.journal.row!.stateKey, 'manualReview');
    expect(h.journal.row!.attemptCount, 2);
  });
}
