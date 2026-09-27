import 'dart:convert';

import '../../../core/serialization/persisted_json_equality.dart';
import '../data/abnormality_model.dart';

void requireSameChargeAbnormalityIdentity(
  ChargeAbnormality local,
  ChargeAbnormality remote,
) {
  if (!sameChargeAbnormalityIdentity(local, remote)) {
    throw StateError(
      'The remote record belongs to a different original abnormality. '
      'Local evidence was preserved.',
    );
  }
}

bool sameChargeAbnormalityIdentity(
  ChargeAbnormality local,
  ChargeAbnormality remote,
) =>
    local.firestoreId != null &&
    local.firestoreId == remote.firestoreId &&
    local.sourceChargeNo == remote.sourceChargeNo &&
    local.loggedAt.isAtSameMomentAs(remote.loggedAt) &&
    local.loggedByUid == remote.loggedByUid &&
    local.loggedByName == remote.loggedByName &&
    local.linkedTicketFirestoreId == remote.linkedTicketFirestoreId &&
    local.linkedExecutionFirestoreId == remote.linkedExecutionFirestoreId;

/// A server readback may replace a queued row only when its business evidence
/// matches, including optional assessment added by this client version.
bool sameChargeAbnormalitySyncContent(
  ChargeAbnormality local,
  ChargeAbnormality remote,
) =>
    sameChargeAbnormalityIdentity(local, remote) &&
    local.version == remote.version &&
    local.abnormalityTypeId == remote.abnormalityTypeId &&
    local.severity == remote.severity &&
    encodeAffectedAssets(local.affectedAssets) ==
        encodeAffectedAssets(remote.affectedAssets) &&
    local.component == remote.component &&
    local.observedReason == remote.observedReason &&
    local.description == remote.description &&
    local.possibleRootReasonCategory == remote.possibleRootReasonCategory &&
    local.possibleRootReasonNotes == remote.possibleRootReasonNotes &&
    local.reannealingStatus == remote.reannealingStatus &&
    local.reannealedToChargeNo == remote.reannealedToChargeNo &&
    persistedJsonEquivalent(
      jsonEncode(local.assessment?.toMap()),
      jsonEncode(remote.assessment?.toMap()),
    ) &&
    local.isDeleted == remote.isDeleted &&
    local.deleteReason == remote.deleteReason;
