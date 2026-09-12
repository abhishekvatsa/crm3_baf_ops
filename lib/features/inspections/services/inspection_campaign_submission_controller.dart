import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/data/user_model.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../data/inspection_campaign.dart';
import '../domain/inspection_campaign_submission.dart';
import '../repositories/inspection_campaign_creation_reader.dart';

/// A dedicated durable owner for campaign creation, independent of the legacy
/// workflow executor/outbox. Only an explicit operator check dispatches work.
class InspectionCampaignSubmissionController {
  InspectionCampaignSubmissionController({
    required this.store,
    required this.gateway,
    required this.reader,
    required this.requireActor,
    required this.requireCapability,
  });
  final DurableSubmissionRepository store;
  final OriginBoundWorkflowCommandGateway gateway;
  final InspectionCampaignCreationReader reader;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;

  AppUser _actor([String? original]) {
    final actor = requireActor();
    if (!actor.canManageInspectionCampaigns) {
      throw const InspectionCampaignSubmissionException(
        'An approved programme manager account is required. Saved entries are retained.',
      );
    }
    if (original != null && actor.uid != original) {
      throw const InspectionCampaignSubmissionException(
        'Return to the account that saved these programme entries before continuing.',
      );
    }
    return actor;
  }

  Future<DurableSubmission?> restore() async {
    final actor = _actor();
    final saved = await store.findUnresolvedForResource(
      'inspectionCampaignCreation:${actor.uid}',
    );
    _actor(actor.uid);
    if (saved != null) _frozen(saved);
    return saved;
  }

  Future<DurableSubmission> prepare({
    required String originActorUid,
    required Map<String, Object?> payload,
    required String definitionCode,
    required String definitionTitle,
    String? commandId,
    String? campaignId,
  }) async {
    _actor(originActorUid);
    final frozen = InspectionCampaignSubmission.prepare(
      actorUid: originActorUid,
      commandId: commandId ?? 'createInspectionCampaign_${const Uuid().v4()}',
      campaignId: campaignId ?? 'inspection-campaign-${const Uuid().v4()}',
      payload: payload,
    );
    if (definitionCode.trim().isEmpty || definitionTitle.trim().isEmpty) {
      throw const InspectionCampaignSubmissionException(
        'The governed definition identity is missing.',
      );
    }
    final command = frozen.command;
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: command.commandId,
        actorUid: originActorUid,
        requestId: command.commandId,
        aggregateId: command.aggregateId,
        resourceKey: frozen.resourceKey,
        protocol: 'maintenanceWorkflow.v2',
        envelopeJson: frozen.envelopeJson,
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'definitionCode': definitionCode,
          'definitionTitle': definitionTitle,
        }),
      ),
    );
    _actor(originActorUid);
    return saved;
  }

  InspectionCampaignSubmission _frozen(DurableSubmission saved) {
    final frozen = InspectionCampaignSubmission.parse(saved.envelopeJson);
    final command = frozen.command;
    if (saved.protocol != 'maintenanceWorkflow.v2' ||
        saved.actorUid != frozen.actorUid ||
        saved.requestId != command.commandId ||
        saved.aggregateId != command.aggregateId ||
        saved.resourceKey != frozen.resourceKey) {
      throw const InspectionCampaignSubmissionException(
        'Saved programme identities disagree and need review.',
      );
    }
    _metadata(saved);
    return frozen;
  }

  Map<String, dynamic> _metadata(DurableSubmission saved) {
    final raw = saved.displayMetadataJson;
    if (raw == null) {
      throw const InspectionCampaignSubmissionException(
        'The saved definition identity needs review.',
      );
    }
    final data = durableSubmissionJsonObject(raw);
    if (data.length != 3 ||
        data['schemaVersion'] != 1 ||
        const ['definitionCode', 'definitionTitle'].any(
          (key) => data[key] is! String || (data[key] as String).trim().isEmpty,
        )) {
      throw const InspectionCampaignSubmissionException(
        'The saved definition identity needs review.',
      );
    }
    return data;
  }

  Future<InspectionCampaign> check(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const InspectionCampaignSubmissionException(
        'The saved programme could not be found. Nothing was sent.',
      );
    }
    final frozen = _frozen(saved);
    _actor(frozen.actorUid);
    if (saved.state.isAccepted) return _reconcile(saved);
    await requireCapability(frozen.actorUid);
    _actor(frozen.actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: frozen.actorUid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _reconcile(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const InspectionCampaignSubmissionException(
        'This saved programme is already being checked or needs review. No replacement request was sent.',
      );
    }
    final String receiptJson;
    try {
      _actor(frozen.actorUid);
      final receipt = await gateway.executeOriginBoundEnvelope(
        frozen.envelopeJson,
      );
      receiptJson = jsonEncode({
        'commandId': receipt.commandId,
        'resultKey': receipt.resultKey,
        'aggregateVersion': receipt.aggregateVersion,
        'result': receipt.result,
        'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
      });
      _receipt(saved, durableSubmissionJsonObject(receiptJson));
    } catch (_) {
      // A refusal can also follow an earlier accepted attempt (for example a
      // changed permission). Keep its original identity until reconciled.
      final outcome = await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        errorCode: 'campaign-outcome-uncertain',
        message:
            'Programme creation is not confirmed. Its original entries and request are saved.',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await store.read(submissionId);
        if (accepted != null) return _reconcile(accepted);
      }
      throw const InspectionCampaignSubmissionException(
        'Programme creation is not confirmed. Check the saved programme to retry the same request.',
      );
    }
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: receiptJson,
      validateReceipt: (value, receipt) {
        _receipt(value, receipt);
        return true;
      },
    );
    return _reconcile(accepted);
  }

  WorkflowCommandReceipt _receipt(
    DurableSubmission saved,
    Map<String, dynamic> raw,
  ) {
    final frozen = _frozen(saved);
    final receipt = WorkflowCommandReceipt.fromMap(raw);
    if (receipt.commandId != frozen.command.commandId ||
        receipt.resultKey != 'inspection-campaign-created' ||
        receipt.aggregateVersion != 1 ||
        receipt.result.length != 3 ||
        receipt.result['campaignId'] != frozen.command.aggregateId ||
        receipt.result['status'] != 'open' ||
        receipt.result['definitionCode'] !=
            _metadata(saved)['definitionCode']) {
      throw const InspectionCampaignSubmissionException(
        'The server receipt does not confirm this saved programme.',
      );
    }
    return receipt;
  }

  Future<InspectionCampaign> _reconcile(DurableSubmission saved) async {
    final frozen = _frozen(saved);
    _actor(frozen.actorUid);
    final receiptJson = saved.receiptJson;
    final hash = saved.receiptSha256;
    if (!saved.state.isAccepted || receiptJson == null || hash == null) {
      throw const InspectionCampaignSubmissionException(
        'Accepted programme evidence needs review.',
      );
    }
    final receipt = _receipt(saved, durableSubmissionJsonObject(receiptJson));
    final raw = await reader.read(frozen.command.aggregateId);
    _actor(frozen.actorUid);
    final campaign = InspectionCampaign.fromMap(
      raw,
      frozen.command.aggregateId,
    );
    final payload = frozen.command.payload;
    bool sameMembers(Iterable<Object?> left, Object? right) =>
        right is List &&
        left.length == right.length &&
        left.toSet().length == left.length &&
        right.toSet().length == right.length &&
        left.toSet().containsAll(right);
    final baselineMatches =
        raw['campaignId'] == frozen.command.aggregateId &&
        raw['createdByUid'] == frozen.actorUid &&
        campaign.createdAt.isAtSameMomentAs(receipt.appliedAt) &&
        campaign.definition.id == payload['definitionId'] &&
        campaign.definition.version == payload['definitionVersion'] &&
        campaign.definition.code == receipt.result['definitionCode'] &&
        campaign.purpose == payload['purpose'] &&
        campaign.assetTypeKey == payload['assetTypeKey'] &&
        campaign.assetClassId == payload['assetClassId'] &&
        campaign.populationMode.name == payload['populationMode'] &&
        campaign.hostAssetClassId == payload['hostAssetClassId'] &&
        campaign.baselineCampaignId == payload['baselineCampaignId'] &&
        sameMembers(campaign.observerRoleKeys, payload['observerRoleKeys']);
    final numbers = (payload['targetAssetNumbers'] as List).cast<int>();
    final positions = (payload['physicalPositionLabels'] as List)
        .cast<String>();
    final populationMatches = campaign.version == 1
        ? campaign.status == InspectionCampaignStatus.open &&
              campaign.expectedPopulation == payload['expectedPopulation'] &&
              sameMembers(campaign.targetAssetNumbers, numbers) &&
              sameMembers(campaign.physicalPositionLabels, positions)
        : campaign.targetAssetNumbers.toSet().containsAll(numbers) &&
              campaign.physicalPositionLabels.toSet().containsAll(positions) &&
              campaign.expectedPopulation >=
                  (payload['expectedPopulation'] as int);
    if (!baselineMatches || !populationMatches) {
      throw const InspectionCampaignSubmissionException(
        'Acceptance is saved, but the current programme does not match its original evidence. It needs review before another programme is opened.',
      );
    }
    _actor(frozen.actorUid);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: hash,
    );
    _actor(frozen.actorUid);
    return campaign;
  }

  Future<void> cancelNeverSent(String submissionId) async {
    final actor = _actor();
    await store.cancelNeverSent(
      submissionId: submissionId,
      actorUid: actor.uid,
    );
    _actor(actor.uid);
  }
}
