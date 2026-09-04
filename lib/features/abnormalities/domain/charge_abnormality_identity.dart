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
