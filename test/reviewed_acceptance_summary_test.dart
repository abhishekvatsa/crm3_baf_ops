import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_review_acceptance.dart';
import 'package:flutter_test/flutter_test.dart';

// Contract projections from submissionRecovery.ts receiptSummary. This checks
// the cross-domain comparison, not domain acceptance or transport authenticity;
// the native settlement tests exercise the mandatory real domain validator.
void main() {
  const id = 'request-a';
  const time = '2026-09-12T10:00:00.000Z';
  final cases =
      <
        ({
          String domain,
          String family,
          String protocol,
          String aggregate,
          Map<String, dynamic> request,
          Map<String, dynamic> response,
          Map<String, dynamic> summary,
        })
      >[
        (
          domain: 'publishedTemplateAssignment',
          family: 'publishedTemplateAssignment',
          protocol: 'publishedTemplateAssignment.v2',
          aggregate: id,
          request: {'requestId': id, 'expectedVersionNumber': 7},
          response: {
            'ok': true,
            'requestId': id,
            'executionId': 'server-execution',
            'assignedAt': time,
          },
          summary: {
            'operation': 'assignPublishedTemplateVersion',
            'entityId': 'server-execution',
            'version': 7,
            'status': 'completed',
          },
        ),
        (
          domain: 'morningReview',
          family: 'morningReview',
          protocol: 'assetHierarchy.v2',
          aggregate: id,
          request: {'requestId': id, 'operation': 'START_MORNING_REVIEW'},
          response: {
            'requestId': id,
            'operation': 'START_MORNING_REVIEW',
            'entityId': '2026-09-12',
            'version': 1,
            'status': 'open',
            'committedAt': time,
          },
          summary: {
            'operation': 'START_MORNING_REVIEW',
            'entityId': '2026-09-12',
            'version': 1,
            'status': 'open',
          },
        ),
        (
          domain: 'morningReview',
          family: 'morningReview',
          protocol: 'assetHierarchy.v2',
          aggregate: '2026-09-12',
          request: {
            'requestId': id,
            'operation': 'COMPLETE_MORNING_REVIEW_ACTION',
            'sessionId': '2026-09-12',
            'expectedVersion': 3,
          },
          response: {
            'requestId': id,
            'operation': 'COMPLETE_MORNING_REVIEW_ACTION',
            'entityId': 'action-a',
            'version': 4,
            'status': 'completed',
            'committedAt': time,
          },
          summary: {
            'operation': 'COMPLETE_MORNING_REVIEW_ACTION',
            'entityId': 'action-a',
            'version': 4,
            'status': 'completed',
          },
        ),
        (
          domain: 'burnerEvidence',
          family: 'burnerEvidence',
          protocol: 'assetHierarchy.v2',
          aggregate: 'furnace-7',
          request: {
            'requestId': id,
            'operation': 'RECORD_BURNER_CONDITION_ROUND',
            'assetInstanceId': 'furnace-7',
            'expectedAssetVersion': 9,
          },
          response: {
            'requestId': id,
            'operation': 'RECORD_BURNER_CONDITION_ROUND',
            'assetInstanceId': 'furnace-7',
            'committedAt': time,
          },
          summary: {
            'operation': 'RECORD_BURNER_CONDITION_ROUND',
            'entityId': 'furnace-7',
            'version': 9,
            'status': null,
          },
        ),
        (
          domain: 'burnerEvidence',
          family: 'burnerEvidence',
          protocol: 'assetHierarchy.v2',
          aggregate: 'furnace-7',
          request: {
            'requestId': id,
            'operation': 'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
            'assetInstanceId': 'furnace-7',
            'expectedAssetVersion': 9,
            'expectedDirectiveVersion': 2,
          },
          response: {
            'requestId': id,
            'operation': 'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
            'assetInstanceId': 'furnace-7',
            'closedDirectiveVersion': 3,
            'committedAt': time,
          },
          summary: {
            'operation': 'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
            'entityId': 'furnace-7',
            'version': 3,
            'status': null,
          },
        ),
        (
          domain: 'qualityMonitoring',
          family: 'qualityMonitoringCreation',
          protocol: 'chargeAbnormality.v2',
          aggregate: 'monitoring-a',
          request: {
            'requestId': id,
            'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
            'monitoringRequestId': 'monitoring-a',
            'expectedVersion': 0,
          },
          response: {
            'requestId': id,
            'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
            'entityId': 'monitoring-a',
            'version': 1,
            'committedAt': time,
          },
          summary: {
            'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
            'entityId': 'monitoring-a',
            'version': 1,
            'status': null,
          },
        ),
        (
          domain: 'inspectionCampaign',
          family: 'inspectionCampaignCreation',
          protocol: 'maintenanceWorkflow.v2',
          aggregate: 'campaign-a',
          request: {
            'commandId': id,
            'commandType': 'createInspectionCampaign',
            'aggregateId': 'campaign-a',
            'expectedVersion': 0,
          },
          response: {
            'commandId': id,
            'resultKey': 'inspection-campaign-created',
            'aggregateVersion': 1,
            'appliedAt': time,
            'result': {
              'campaignId': 'campaign-a',
              'status': 'open',
              'definitionCode': 'DEF',
            },
          },
          summary: {
            'operation': 'createInspectionCampaign',
            'entityId': 'campaign-a',
            'version': 1,
            'status': null,
          },
        ),
      ];
  for (final example in cases) {
    test(
      '${example.domain}/${example.summary['operation']} binds the server review projection',
      () {
        final row = DurableSubmission(
          submissionId: 'submission',
          actorUid: 'origin',
          requestId: id,
          aggregateId: example.aggregate,
          resourceKey: '${example.family}:subject',
          protocol: example.protocol,
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'origin',
            example.domain == 'inspectionCampaign' ? 'command' : 'request':
                example.request,
          }),
          displayMetadataJson: null,
          state: DurableSubmissionState.reviewResolved,
          attemptCount: 1,
          createdAt: DateTime.parse(time),
          updatedAt: DateTime.parse(time),
          claimToken: null,
          claimExpiresAt: null,
          nextRetryAt: null,
          receiptJson: null,
          receiptSha256: null,
          lastErrorCode: null,
          lastErrorMessage: null,
          legacySourceKey: null,
          legacySourceBase64: null,
        );
        final summary = {
          'actorUid': 'origin',
          ...example.summary,
          'committedAt': time,
        };
        final proof = {
          'schemaVersion': 1,
          'domain': example.domain,
          'requestId': id,
          'evidenceSha256': row.reviewEvidenceSha256,
          'originalActorUid': 'origin',
          'reviewerUid': 'admin',
          'outcome': 'reviewedExisting',
          'decisionId': 'decision',
          'decidedAt': time,
          'receiptSha256': 'a' * 64,
          'receiptSummary': summary,
          'reason': 'Reviewed original acceptance.',
        };
        final history = {
          'schemaVersion': 1,
          'kind': 'savedSubmissionReview',
          'decisions': [proof],
          'lateAcceptances': <dynamic>[],
        };
        expect(
          confirmsReviewedAcceptance(row, history, example.response),
          isTrue,
        );
        for (final key in [
          'actorUid',
          'operation',
          'entityId',
          'version',
          'committedAt',
          'status',
        ]) {
          final original = summary[key];
          summary[key] = key == 'version' ? 99 : 'different';
          expect(
            confirmsReviewedAcceptance(row, history, example.response),
            isFalse,
            reason: key,
          );
          summary[key] = original;
        }
        summary['unreviewedField'] = true;
        expect(
          confirmsReviewedAcceptance(row, history, example.response),
          isFalse,
        );
      },
    );
  }
}
