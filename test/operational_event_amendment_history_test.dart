import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/operational_events/repositories/operational_event_amendment_repository.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_amendment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/test_support/operational_event_amendment_fixtures.dart';

void main() {
  Map<String, dynamic> request(
    String id,
    int version,
    String? prior,
    DateTime expected,
    DateTime corrected,
  ) => {
    'requestId': id,
    'eventId': amendmentEventId,
    'expectedVersion': version,
    'reason': 'Verified actual restoration.',
    'intervalAmendment': {
      'occurrenceIndex': 0,
      'supersedesAmendmentId': prior,
      'expectedEffectiveResolvedAt': expected.toIso8601String(),
      'correctedResolvedAt': corrected.toIso8601String(),
    },
  };
  void digest(Map<String, dynamic> raw) {
    raw.remove('evidenceDigest');
    raw['evidenceDigest'] =
        'operational-interval-amendment-v1-sha256:${sha256.convert(utf8.encode(operationalAmendmentCanonicalJson(raw)))}';
  }

  late OperationalEventAmendmentReview review;
  late Map<String, Map<String, dynamic>> records;
  setUp(() {
    final original = amendmentReview(reopened: true).originalIntervalJson;
    final first = amendmentEvidence(
      request(
        previousAmendmentId,
        3,
        null,
        amendmentTime(12),
        amendmentTime(11),
      ),
      original,
    );
    final second = amendmentEvidence(
      request(
        amendmentId,
        4,
        previousAmendmentId,
        amendmentTime(11),
        amendmentTime(10).add(const Duration(minutes: 30)),
      ),
      original,
    );
    records = {amendmentId: second, previousAmendmentId: first};
    final raw = amendmentEventRecord(reopened: true, amended: true)
      ..['version'] = 5;
    final head =
        (raw['intervalEndAmendments'] as Map)['0'] as Map<String, dynamic>;
    head['correctedResolvedAt'] = second['correctedResolvedAt'];
    head['supersedesAmendmentId'] = previousAmendmentId;
    review = OperationalEventAmendmentRepository.decodeReview(
      raw,
      amendmentEventId,
      0,
    );
  });
  test(
    'complete history orders immutable predecessors rather than query or timestamp order',
    () {
      final history = OperationalEventAmendmentRepository.verifyHistory(
        review,
        records,
      );
      expect(history.map((e) => e.amendmentId), [
        previousAmendmentId,
        amendmentId,
      ]);
      expect(
        history.last.correctedResolvedAt,
        amendmentTime(10).add(const Duration(minutes: 30)),
      );
    },
  );
  test(
    'link projection growth does not reinterpret immutable occurrence identity',
    () {
      for (final raw in records.values) {
        final original =
            jsonDecode(raw['originalIntervalJson'] as String)
                as Map<String, dynamic>;
        original['issueLinkIds'] = <String>[];
        original['linkedIssueIds'] = <String>[];
        raw['originalIntervalJson'] = operationalAmendmentCanonicalJson(
          original,
        );
        digest(raw);
      }
      expect(
        OperationalEventAmendmentRepository.verifyHistory(review, records),
        hasLength(2),
      );
    },
  );
  final mutations = <String, void Function(Map<String, Map<String, dynamic>>)>{
    'missing predecessor': (rows) => rows.remove(previousAmendmentId),
    'disconnected predecessor': (rows) =>
        rows[amendmentId]!['supersedesAmendmentId'] =
            '44444444-4444-4444-8444-444444444444',
    'duplicate successor': (rows) =>
        rows[amendmentId]!['supersedesAmendmentId'] = null,
    'reversed amendment chronology': (rows) =>
        rows[amendmentId]!['amendedAt'] = amendmentTime(15).toIso8601String(),
    'wrong prior effective end': (rows) =>
        rows[amendmentId]!['priorEffectiveResolvedAt'] = amendmentTime(
          12,
        ).toIso8601String(),
    'reversed event revision': (rows) {
      rows[amendmentId]!['expectedEventVersion'] = 2;
      rows[amendmentId]!['resultVersion'] = 3;
    },
    'current head drift': (rows) =>
        rows[amendmentId]!['amendedByName'] = 'Other reviewer',
    'wrong occurrence': (rows) => rows[amendmentId]!['occurrenceIndex'] = 1,
    'unsupported evidence': (rows) => rows[amendmentId]!['unknown'] = true,
    'wrong original interval': (rows) {
      final original =
          jsonDecode(rows[amendmentId]!['originalIntervalJson'] as String)
              as Map<String, dynamic>;
      original['resolvedByName'] = 'Different restorer';
      rows[amendmentId]!['originalIntervalJson'] =
          operationalAmendmentCanonicalJson(original);
    },
  };
  for (final mutation in mutations.entries) {
    test(
      'history rejects ${mutation.key} even with recalculated record digest',
      () {
        mutation.value(records);
        for (final raw in records.values) {
          digest(raw);
        }
        expect(
          () => OperationalEventAmendmentRepository.verifyHistory(
            review,
            records,
          ),
          throwsA(anything),
        );
      },
    );
  }
  test(
    'standalone evidence decoder admits immutable record without fabricated parent review',
    () {
      expect(
        OperationalEventAmendmentRepository.validateRetainedRecord(
          records[amendmentId]!,
          amendmentId,
        ).amendmentId,
        amendmentId,
      );
    },
  );
  test(
    'standalone decoder rejects original interval corruption and unpaired links even with fresh digest',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (raw) => raw['eventType'] = 'unknown',
        (raw) => raw['title'] = 1,
        (raw) => raw['affectedAssetInstanceIds'] = ['outside-plant-scope'],
        (raw) => raw['linkedIssueIds'] = <String>[],
        (raw) => raw['issueLinkIds'] = null,
        (raw) => raw['resolvedAt'] = '2025-08-14T12:00:00.000001Z',
      ]) {
        final data = Map<String, dynamic>.from(records[amendmentId]!);
        final original =
            jsonDecode(data['originalIntervalJson'] as String)
                as Map<String, dynamic>;
        change(original);
        data['originalIntervalJson'] = operationalAmendmentCanonicalJson(
          original,
        );
        digest(data);
        expect(
          () => OperationalEventAmendmentRepository.validateRetainedRecord(
            data,
            amendmentId,
          ),
          throwsA(anything),
        );
      }
    },
  );
  test('history rejects full-record digest tampering', () {
    records[amendmentId]!['reason'] = 'Changed reason';
    expect(
      () => OperationalEventAmendmentRepository.verifyHistory(review, records),
      throwsFormatException,
    );
  });
}
