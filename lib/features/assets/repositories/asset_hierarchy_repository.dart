import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/serialization/command_timestamp.dart';
import '../../auth/data/user_model.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../domain/inner_cover_acceptance_input.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

const assetHierarchyCallableName = 'mutateAssetHierarchy';
const assetHierarchyV2CallableName = 'mutateAssetHierarchyV2';
const assetHierarchyCallableRegion = 'asia-south1';

const _hierarchyMutationOperations = <String>{
  'CREATE_CLASS',
  'UPDATE_CLASS',
  'SET_CLASS_STATUS',
  'CREATE_NODE',
  'UPDATE_NODE',
  'SET_NODE_STATUS',
};
const _registryMutationOperations = <String>{
  'CREATE_ASSET_INSTANCE',
  'UPDATE_ASSET_INSTANCE',
  'SET_ASSET_INSTANCE_STATUS',
  'CREATE_COMPONENT_INSTANCE',
  'UPDATE_COMPONENT_INSTANCE',
  'CORRECT_COMPONENT_INSTANCE',
  'REPLACE_COMPONENT_INSTANCE',
  'SET_COMPONENT_INSTANCE_STATUS',
};
const _innerCoverMutationOperations = <String>{
  'REGISTER_INNER_COVER',
  'ACCEPT_INNER_COVER',
  'SET_INNER_COVER_STATE',
  'LINK_INNER_COVER',
  'DELINK_INNER_COVER',
  'TRANSFER_INNER_COVER',
  'REPLACE_INNER_COVER',
  'SWAP_INNER_COVERS',
};
const _assetConditionMutationOperations = <String>{
  'DECLARE_ASSET_CONDITION',
  'RESTORE_ASSET_CONDITION',
};

const assetRegistrySubmissionOperations = {
  ..._hierarchyMutationOperations,
  ..._registryMutationOperations,
};

bool _sameStrings(List<String> left, List<String> right) =>
    left.length == right.length &&
    left.asMap().entries.every((entry) => entry.value == right[entry.key]);

class AssetHierarchyException implements Exception {
  final String message;
  final List<String> errors;

  const AssetHierarchyException(this.message, {this.errors = const <String>[]});

  @override
  String toString() =>
      errors.isEmpty ? message : '$message ${errors.join(' ')}';
}

class AssetTagCollisionException extends AssetHierarchyException {
  final String normalizedTag;
  final String existingNodeId;
  final String existingNodeName;
  final String existingAssetClassId;
  final String existingAssetClassName;
  final List<String> existingPath;
  final String? existingAssetInstanceId;
  final String? existingAssetInstanceName;
  final String? existingComponentInstanceId;
  final int? existingComponentVersion;
  final AssetOwnershipStatus? existingOwnershipStatus;
  final String? existingOwnerDiscipline;
  final List<String> existingAccountableRoleKeys;
  final bool transferSupported;

  const AssetTagCollisionException({
    required this.normalizedTag,
    required this.existingNodeId,
    required this.existingNodeName,
    required this.existingAssetClassId,
    required this.existingAssetClassName,
    required this.existingPath,
    this.existingAssetInstanceId,
    this.existingAssetInstanceName,
    this.existingComponentInstanceId,
    this.existingComponentVersion,
    this.existingOwnershipStatus,
    this.existingOwnerDiscipline,
    this.existingAccountableRoleKeys = const <String>[],
    this.transferSupported = true,
  }) : super('Tag $normalizedTag already belongs to $existingNodeName.');
}

/// The service explicitly refused this command before applying it. Transport
/// uncertainty and malformed acceptance evidence deliberately use other errors.
class AssetHierarchyCommandRefused extends AssetHierarchyException {
  final String code;
  final String? reasonCode;
  const AssetHierarchyCommandRefused(
    super.message, {
    required this.code,
    this.reasonCode,
  });

  bool get requiresSubjectReview =>
      reasonCode == 'inner-cover-version-mismatch' ||
      reasonCode == 'inner-cover-not-awaiting-acceptance';
}

/// This invocation was rejected locally before any callable dispatch.
/// It does not establish the outcome of an earlier invocation of the same ID.
class AssetHierarchyInputRejected extends AssetHierarchyException {
  const AssetHierarchyInputRejected(super.message);
}

class AssetHierarchyMutationReceipt {
  const AssetHierarchyMutationReceipt({
    required this.requestId,
    required this.operation,
    required this.entityId,
    required this.version,
    required this.auditId,
    required this.committedAt,
    required this.idempotentReplay,
    this.secondaryVersion,
  });

  final String requestId;
  final String operation;
  final String entityId;
  final int version;
  final int? secondaryVersion;
  final String auditId;
  final DateTime committedAt;
  final bool idempotentReplay;

  Map<String, dynamic> toRegistryMap(Map<String, dynamic> request) {
    if (!assetRegistrySubmissionOperations.contains(operation)) {
      throw StateError('Not a register receipt.');
    }
    return {
      'ok': true,
      'requestId': requestId,
      'operation': operation,
      'assetClassId': request['assetClassId'],
      'nodeId': _hierarchyMutationOperations.contains(operation)
          ? request['nodeId']
          : entityId,
      'version': version,
      'auditId': auditId,
      'committedAt': committedAt.toUtc().toIso8601String(),
      'idempotentReplay': idempotentReplay,
    };
  }

  Map<String, dynamic> toInnerCoverMap() {
    if (!_innerCoverMutationOperations.contains(operation)) {
      throw StateError('This receipt is not an Inner Cover mutation.');
    }
    return {
      'ok': true,
      'requestId': requestId,
      'operation': operation,
      'innerCoverId': entityId,
      'version': version,
      'secondaryVersion': secondaryVersion,
      'auditId': auditId,
      'committedAt': committedAt.toUtc().toIso8601String(),
      'idempotentReplay': idempotentReplay,
    };
  }

  Map<String, dynamic> toAssetConditionMap({
    required String assetClassId,
    required String condition,
  }) {
    if (!_assetConditionMutationOperations.contains(operation)) {
      throw StateError('This receipt is not an asset-condition mutation.');
    }
    return {
      'ok': true,
      'requestId': requestId,
      'operation': operation,
      'assetClassId': assetClassId,
      'assetInstanceId': entityId,
      'condition': condition,
      'version': version,
      'auditId': auditId,
      'committedAt': committedAt.toUtc().toIso8601String(),
      'idempotentReplay': idempotentReplay,
    };
  }

  factory AssetHierarchyMutationReceipt.fromMap(
    Map<String, dynamic> map, {
    required Map<String, dynamic> request,
  }) {
    final expectedRequestId = readRequiredPersistedString(
      request['requestId'],
      field: 'request.requestId',
      source: assetHierarchyCallableName,
    );
    final expectedOperation = readRequiredPersistedString(
      request['operation'],
      field: 'request.operation',
      source: assetHierarchyCallableName,
    );
    final source = '$assetHierarchyCallableName/$expectedRequestId';
    if (map['ok'] != true ||
        map['requestId'] != expectedRequestId ||
        map['operation'] != expectedOperation) {
      throw PersistedDataFormatException(
        field: 'responseIdentity',
        source: source,
        detail: 'request, operation, or success identity mismatch',
      );
    }

    late final Set<String> expectedKeys;
    late final String entityId;
    late final String expectedAuditId;
    int? secondaryVersion;
    if (_hierarchyMutationOperations.contains(expectedOperation)) {
      expectedKeys = const <String>{
        'ok',
        'requestId',
        'operation',
        'assetClassId',
        'nodeId',
        'version',
        'auditId',
        'committedAt',
        'idempotentReplay',
      };
      final expectedClassId = _requiredRequestIdentity(
        request,
        'assetClassId',
        source,
      );
      final expectedNodeId = request['nodeId'];
      if (map['assetClassId'] != expectedClassId ||
          map['nodeId'] != expectedNodeId) {
        throw PersistedDataFormatException(
          field: 'entityIdentity',
          source: source,
          detail: 'asset class or hierarchy node mismatch',
        );
      }
      entityId = expectedNodeId is String ? expectedNodeId : expectedClassId;
      expectedAuditId = 'asset_hierarchy_$expectedRequestId';
    } else if (_registryMutationOperations.contains(expectedOperation)) {
      expectedKeys = const <String>{
        'ok',
        'requestId',
        'operation',
        'assetClassId',
        'nodeId',
        'version',
        'auditId',
        'committedAt',
        'idempotentReplay',
      };
      final expectedClassId = _requiredRequestIdentity(
        request,
        'assetClassId',
        source,
      );
      final expectedEntityId = switch (expectedOperation) {
        'CREATE_ASSET_INSTANCE' ||
        'UPDATE_ASSET_INSTANCE' ||
        'SET_ASSET_INSTANCE_STATUS' => _requiredRequestIdentity(
          request,
          'assetInstanceId',
          source,
        ),
        'REPLACE_COMPONENT_INSTANCE' => _requiredRequestIdentity(
          request,
          'replacementComponentInstanceId',
          source,
        ),
        _ => _requiredRequestIdentity(request, 'componentInstanceId', source),
      };
      if (map['assetClassId'] != expectedClassId ||
          map['nodeId'] != expectedEntityId) {
        throw PersistedDataFormatException(
          field: 'entityIdentity',
          source: source,
          detail: 'asset class or registry entity mismatch',
        );
      }
      entityId = expectedEntityId;
      expectedAuditId = 'asset_registry_$expectedRequestId';
    } else if (_innerCoverMutationOperations.contains(expectedOperation)) {
      expectedKeys = const <String>{
        'ok',
        'requestId',
        'operation',
        'innerCoverId',
        'version',
        'secondaryVersion',
        'auditId',
        'committedAt',
        'idempotentReplay',
      };
      entityId = _requiredRequestIdentity(request, 'innerCoverId', source);
      if (map['innerCoverId'] != entityId) {
        throw PersistedDataFormatException(
          field: 'entityIdentity',
          source: source,
          detail: 'Inner Cover identity mismatch',
        );
      }
      secondaryVersion = readOptionalPersistedInt(
        map['secondaryVersion'],
        field: 'secondaryVersion',
        source: source,
        minimum: 1,
      );
      expectedAuditId = 'inner_cover_$expectedRequestId';
    } else if (_assetConditionMutationOperations.contains(expectedOperation)) {
      expectedKeys = const <String>{
        'ok',
        'requestId',
        'operation',
        'assetClassId',
        'assetInstanceId',
        'condition',
        'version',
        'auditId',
        'committedAt',
        'idempotentReplay',
      };
      final expectedClassId = _requiredRequestIdentity(
        request,
        'assetClassId',
        source,
      );
      entityId = _requiredRequestIdentity(request, 'assetInstanceId', source);
      final expectedCondition = expectedOperation == 'RESTORE_ASSET_CONDITION'
          ? 'available'
          : request['condition'];
      if (map['assetClassId'] != expectedClassId ||
          map['assetInstanceId'] != entityId ||
          map['condition'] != expectedCondition) {
        throw PersistedDataFormatException(
          field: 'entityIdentity',
          source: source,
          detail: 'asset condition identity or state mismatch',
        );
      }
      expectedAuditId = 'asset_condition_$expectedRequestId';
    } else {
      throw PersistedDataFormatException(
        field: 'operation',
        source: source,
        detail: 'unsupported asset mutation receipt operation',
      );
    }

    if (map.keys.toSet().length != expectedKeys.length ||
        !map.keys.toSet().containsAll(expectedKeys)) {
      throw PersistedDataFormatException(
        field: 'response',
        source: source,
        detail: 'response field set does not match the operation contract',
      );
    }
    final auditId = readRequiredPersistedString(
      map['auditId'],
      field: 'auditId',
      source: source,
    );
    if (auditId != expectedAuditId) {
      throw PersistedDataFormatException(
        field: 'auditId',
        source: source,
        detail: 'audit identity mismatch',
      );
    }
    if (expectedOperation == 'ACCEPT_INNER_COVER') {
      final expectedVersion = readRequiredPersistedInt(
        request['expectedVersion'],
        field: 'request.expectedVersion',
        source: source,
        minimum: 1,
      );
      if (map['version'] != expectedVersion + 1 || secondaryVersion != null) {
        throw PersistedDataFormatException(
          field: 'version',
          source: source,
          detail: 'acceptance receipt does not match its submitted revision',
        );
      }
    }
    if (assetRegistrySubmissionOperations.contains(expectedOperation)) {
      final createsEntity =
          expectedOperation.startsWith('CREATE_') ||
          expectedOperation == 'REPLACE_COMPONENT_INSTANCE';
      final expectedVersion = createsEntity
          ? 1
          : readRequiredPersistedInt(
                  request['expectedVersion'],
                  field: 'request.expectedVersion',
                  source: source,
                  minimum: 1,
                ) +
                1;
      if (map['version'] != expectedVersion) {
        throw PersistedDataFormatException(
          field: 'version',
          source: source,
          detail: 'register receipt does not match the submitted revision',
        );
      }
    }
    final committedAtRaw = map['committedAt'];
    final committedAt = readRequiredPersistedDateTime(
      map['committedAt'],
      field: 'committedAt',
      source: source,
    );
    if (committedAtRaw is! String ||
        committedAtRaw.trim() != committedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'committedAt',
        source: source,
        detail: 'must be a canonical UTC ISO instant',
      );
    }

    return AssetHierarchyMutationReceipt(
      requestId: expectedRequestId,
      operation: expectedOperation,
      entityId: entityId,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      secondaryVersion: secondaryVersion,
      auditId: auditId,
      committedAt: committedAt,
      idempotentReplay: readRequiredPersistedBool(
        map['idempotentReplay'],
        field: 'idempotentReplay',
        source: source,
      ),
    );
  }
}

String _requiredRequestIdentity(
  Map<String, dynamic> request,
  String field,
  String source,
) => readRequiredPersistedString(
  request[field],
  field: 'request.$field',
  source: source,
);

class GovernedAssetEventContext {
  final AssetClassRecord assetClass;
  final AssetInstanceRecord asset;
  final BaseInnerCoverAssignment? innerCoverAssignment;

  const GovernedAssetEventContext({
    required this.assetClass,
    required this.asset,
    this.innerCoverAssignment,
  });
}

class AssetHierarchyRepository {
  static const assetClassesCollection = 'asset_classes';
  static const hierarchyNodesCollection = 'asset_hierarchy_nodes';
  static const assetInstancesCollection = 'asset_instances';
  static const componentInstancesCollection = 'asset_component_instances';
  static const hierarchyAuditsCollection = 'asset_hierarchy_audits';
  static const assetConditionsCollection = 'asset_operational_conditions';
  static const innerCoverProfilesCollection = 'inner_cover_profiles';
  static const innerCoverAssignmentsCollection = 'base_inner_cover_assignments';
  static const innerCoverLinkagesCollection = 'inner_cover_linkages';
  static const innerCoverFabricationsCollection = 'inner_cover_fabrications';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final Uuid _uuid;

  AssetHierarchyRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    Uuid uuid = const Uuid(),
    this.submitRegistry,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions,
       _uuid = uuid;

  final Future<AssetHierarchyMutationReceipt> Function(
    Map<String, dynamic>,
    AppUser,
  )?
  submitRegistry;

  Future<AssetHierarchyMutationReceipt> _invokeRegistry(
    Map<String, dynamic> request,
    AppUser actor,
  ) {
    final submit = submitRegistry;
    if (submit == null) {
      throw const AssetHierarchyException(
        'Saved register submissions are unavailable. Nothing was sent.',
      );
    }
    return submit(request, actor);
  }

  Future<AssetHierarchyMutationReceipt> dispatchFrozenRegistry(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) {
    if (!assetRegistrySubmissionOperations.contains(request['operation']) ||
        originActorUid.trim().isEmpty) {
      throw const AssetHierarchyInputRejected('Invalid saved register change.');
    }
    return _invoke(request, originActorUid: originActorUid);
  }

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: assetHierarchyCallableRegion);

  CollectionReference<Map<String, dynamic>> get _classes =>
      _firestore.collection(assetClassesCollection);
  CollectionReference<Map<String, dynamic>> get _nodes =>
      _firestore.collection(hierarchyNodesCollection);
  CollectionReference<Map<String, dynamic>> get _assetInstances =>
      _firestore.collection(assetInstancesCollection);
  CollectionReference<Map<String, dynamic>> get _componentInstances =>
      _firestore.collection(componentInstancesCollection);
  CollectionReference<Map<String, dynamic>> get _hierarchyAudits =>
      _firestore.collection(hierarchyAuditsCollection);
  CollectionReference<Map<String, dynamic>> get _assetConditions =>
      _firestore.collection(assetConditionsCollection);
  CollectionReference<Map<String, dynamic>> get _innerCoverProfiles =>
      _firestore.collection(innerCoverProfilesCollection);
  CollectionReference<Map<String, dynamic>> get _innerCoverAssignments =>
      _firestore.collection(innerCoverAssignmentsCollection);
  CollectionReference<Map<String, dynamic>> get _innerCoverLinkages =>
      _firestore.collection(innerCoverLinkagesCollection);
  CollectionReference<Map<String, dynamic>> get _innerCoverFabrications =>
      _firestore.collection(innerCoverFabricationsCollection);

  Stream<List<AssetClassRecord>> watchAssetClasses() {
    return _classes.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => AssetClassRecord.fromMap(doc.data(), doc.id))
          .toList();
      records.sort((left, right) {
        final status = left.status.index.compareTo(right.status.index);
        if (status != 0) return status;
        final area = left.majorArea.toLowerCase().compareTo(
          right.majorArea.toLowerCase(),
        );
        return area != 0
            ? area
            : left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
      return List<AssetClassRecord>.unmodifiable(records);
    });
  }

  Stream<List<AssetHierarchyNode>> watchNodes(String assetClassId) {
    return _nodes.where('assetClassId', isEqualTo: assetClassId).snapshots().map((
      snapshot,
    ) {
      final batch = decodeSnapshotBatch(
        snapshot,
        AssetHierarchyNode.fromMap,
        source: 'AssetHierarchyNode',
      );
      if (!batch.isComplete) {
        throw const AssetHierarchyException(
          'The asset register is incomplete because one or more hierarchy definitions could not be read. Reconcile the malformed records before making changes.',
        );
      }
      final records = batch.records.toList();
      records.sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0
            ? order
            : left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
      return List<AssetHierarchyNode>.unmodifiable(records);
    });
  }

  Stream<List<AssetInstanceRecord>> watchAssetInstances(String assetClassId) {
    return _assetInstances
        .where('assetClassId', isEqualTo: assetClassId)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .map((doc) => AssetInstanceRecord.fromMap(doc.data(), doc.id))
                  .toList()
                ..sort(
                  (left, right) =>
                      left.assetNumber.compareTo(right.assetNumber),
                );
          return List<AssetInstanceRecord>.unmodifiable(records);
        });
  }

  Stream<List<AssetInstanceRecord>> watchAllAssetInstances() {
    return _assetInstances.snapshots().map((snapshot) {
      final records =
          snapshot.docs
              .map((doc) => AssetInstanceRecord.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((left, right) {
              final classOrder = left.assetClassName.toLowerCase().compareTo(
                right.assetClassName.toLowerCase(),
              );
              return classOrder != 0
                  ? classOrder
                  : left.assetNumber.compareTo(right.assetNumber);
            });
      return List<AssetInstanceRecord>.unmodifiable(records);
    });
  }

  Stream<List<AssetOperationalConditionRecord>> watchAssetConditions() {
    return _assetConditions.snapshots().map((snapshot) {
      final records =
          snapshot.docs
              .map(
                (doc) =>
                    AssetOperationalConditionRecord.fromMap(doc.data(), doc.id),
              )
              .toList()
            ..sort((left, right) {
              final classOrder = left.assetClassName.toLowerCase().compareTo(
                right.assetClassName.toLowerCase(),
              );
              return classOrder != 0
                  ? classOrder
                  : left.assetNumber.compareTo(right.assetNumber);
            });
      return List<AssetOperationalConditionRecord>.unmodifiable(records);
    });
  }

  Stream<List<InnerCoverProfile>> watchInnerCoverProfiles() {
    return watchInnerCoverProfileBatches().map(
      (batch) => List<InnerCoverProfile>.unmodifiable(batch.records),
    );
  }

  Stream<DecodedSnapshotBatch<InnerCoverProfile>>
  watchInnerCoverProfileBatches() {
    return _innerCoverProfiles.snapshots(includeMetadataChanges: true).map((
      snapshot,
    ) {
      final batch = decodeSnapshotBatch(
        snapshot,
        InnerCoverProfile.fromMap,
        source: 'InnerCoverProfile',
      );
      batch.records.sort(
        (left, right) =>
            left.normalizedSerialNumber.compareTo(right.normalizedSerialNumber),
      );
      return batch;
    });
  }

  Future<InnerCoverProfile> readInnerCoverFromServer(
    String innerCoverId, {
    int? minimumVersion,
  }) async {
    final snapshot = await _innerCoverProfiles
        .doc(innerCoverId)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw const AssetHierarchyException(
        'The current Inner Cover record could not be confirmed from the server.',
      );
    }
    final profile = InnerCoverProfile.fromMap(data, snapshot.id);
    if (profile.id != innerCoverId ||
        (minimumVersion != null && profile.version < minimumVersion)) {
      throw const AssetHierarchyException(
        'The Inner Cover record has not reached the confirmed revision. Check again.',
      );
    }
    return profile;
  }

  Future<AssetInstanceRecord> readAssetInstanceFromServer(
    String assetInstanceId, {
    int? minimumVersion,
  }) async {
    final snapshot = await _assetInstances
        .doc(assetInstanceId)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw const AssetHierarchyException(
        'The current asset record could not be confirmed from the server.',
      );
    }
    final asset = AssetInstanceRecord.fromMap(data, snapshot.id);
    if (asset.id != assetInstanceId ||
        (minimumVersion != null && asset.version < minimumVersion)) {
      throw const AssetHierarchyException(
        'The asset record has not reached the confirmed revision. Check again.',
      );
    }
    return asset;
  }

  Future<AssetOperationalConditionRecord> readAssetConditionFromServer(
    String assetInstanceId, {
    int? minimumVersion,
  }) async {
    final snapshot = await _assetConditions
        .doc(assetInstanceId)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw const AssetHierarchyException(
        'The asset condition could not be confirmed from the server.',
      );
    }
    final condition = AssetOperationalConditionRecord.fromMap(
      data,
      snapshot.id,
    );
    if (condition.assetInstanceId != assetInstanceId ||
        (minimumVersion != null && condition.version < minimumVersion)) {
      throw const AssetHierarchyException(
        'The asset condition has not reached the confirmed revision. Check again.',
      );
    }
    return condition;
  }

  Stream<List<BaseInnerCoverAssignment>> watchInnerCoverAssignments() {
    return watchInnerCoverAssignmentBatches().map(
      (batch) => List<BaseInnerCoverAssignment>.unmodifiable(batch.records),
    );
  }

  Stream<DecodedSnapshotBatch<BaseInnerCoverAssignment>>
  watchInnerCoverAssignmentBatches() {
    return _innerCoverAssignments.snapshots(includeMetadataChanges: true).map((
      snapshot,
    ) {
      final batch = decodeSnapshotBatch(
        snapshot,
        BaseInnerCoverAssignment.fromMap,
        source: 'BaseInnerCoverAssignment',
      );
      batch.records.sort(
        (left, right) => left.baseAssetNumber.compareTo(right.baseAssetNumber),
      );
      return batch;
    });
  }

  Stream<List<InnerCoverLinkage>> watchInnerCoverHistory(String innerCoverId) {
    return _innerCoverLinkages
        .where('innerCoverId', isEqualTo: innerCoverId)
        .snapshots()
        .map((snapshot) {
          final records =
              decodeSnapshotDocuments(
                snapshot,
                InnerCoverLinkage.fromMap,
                source: 'InnerCoverLinkage',
              ).toList()..sort(
                (left, right) => right.installedAt.compareTo(left.installedAt),
              );
          return List<InnerCoverLinkage>.unmodifiable(records);
        });
  }

  Stream<List<InnerCoverLinkage>> watchBaseInnerCoverHistory(
    String baseAssetInstanceId,
  ) {
    return _innerCoverLinkages
        .where('baseAssetInstanceId', isEqualTo: baseAssetInstanceId)
        .snapshots()
        .map((snapshot) {
          final records =
              decodeSnapshotDocuments(
                snapshot,
                InnerCoverLinkage.fromMap,
                source: 'InnerCoverLinkage',
              ).toList()..sort(
                (left, right) => right.installedAt.compareTo(left.installedAt),
              );
          return List<InnerCoverLinkage>.unmodifiable(records);
        });
  }

  Stream<InnerCoverFabricationDossier?> watchInnerCoverFabrication(
    String innerCoverId,
  ) {
    return _innerCoverFabrications.doc(innerCoverId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return InnerCoverFabricationDossier.fromMap(doc.data()!, doc.id);
    });
  }

  Future<BaseInnerCoverAssignment?> getInnerCoverAssignmentForBase(
    String baseAssetInstanceId,
  ) async {
    final snapshot = await _innerCoverAssignments
        .doc(baseAssetInstanceId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return BaseInnerCoverAssignment.fromMap(snapshot.data()!, snapshot.id);
  }

  Future<GovernedAssetEventContext?> resolveGovernedAssetEventContext({
    required String legacyAssetTypeKey,
    required int assetNumber,
  }) async {
    final classSnapshot = await _classes
        .where('legacyAssetTypeKey', isEqualTo: legacyAssetTypeKey)
        .get();
    final matchingClasses = classSnapshot.docs
        .map((doc) => AssetClassRecord.fromMap(doc.data(), doc.id))
        .where((record) => record.isActive)
        .toList();
    if (matchingClasses.isEmpty) return null;
    if (matchingClasses.length != 1) {
      throw AssetHierarchyException(
        'More than one active asset class claims $legacyAssetTypeKey. Reconcile asset classes before raising work.',
      );
    }
    final assetClass = matchingClasses.single;
    final assetSnapshot = await _assetInstances
        .where('assetClassId', isEqualTo: assetClass.id)
        .where('assetNumber', isEqualTo: assetNumber)
        .limit(2)
        .get();
    final matchingAssets = assetSnapshot.docs
        .map((doc) => AssetInstanceRecord.fromMap(doc.data(), doc.id))
        .where((record) => record.isActive)
        .toList();
    if (matchingAssets.length != 1) {
      throw AssetHierarchyException(
        matchingAssets.isEmpty
            ? '${assetClass.name} $assetNumber is not registered as an active governed asset.'
            : '${assetClass.name} $assetNumber has duplicate governed identities.',
      );
    }
    final asset = matchingAssets.single;
    BaseInnerCoverAssignment? assignment;
    if (legacyAssetTypeKey == 'base') {
      assignment = await _verifiedInnerCoverAssignment(asset);
    }
    return GovernedAssetEventContext(
      assetClass: assetClass,
      asset: asset,
      innerCoverAssignment: assignment,
    );
  }

  Future<BaseInnerCoverAssignment?> _verifiedInnerCoverAssignment(
    AssetInstanceRecord base,
  ) async {
    final assignmentSnapshot = await _innerCoverAssignments.doc(base.id).get();
    if (!assignmentSnapshot.exists || assignmentSnapshot.data() == null) {
      final reverse = await _innerCoverProfiles
          .where('currentBaseAssetInstanceId', isEqualTo: base.id)
          .limit(1)
          .get();
      if (reverse.docs.isNotEmpty) {
        throw AssetHierarchyException(
          'Base ${base.assetNumber} has an orphaned Inner Cover projection. Reconcile the pairing before raising work.',
        );
      }
      return null;
    }
    final assignment = BaseInnerCoverAssignment.fromMap(
      assignmentSnapshot.data()!,
      assignmentSnapshot.id,
    );
    final profileSnapshot = await _innerCoverProfiles
        .doc(assignment.innerCoverId)
        .get();
    if (!profileSnapshot.exists || profileSnapshot.data() == null) {
      throw AssetHierarchyException(
        'Base ${base.assetNumber} points to a missing Inner Cover profile.',
      );
    }
    final profile = InnerCoverProfile.fromMap(
      profileSnapshot.data()!,
      profileSnapshot.id,
    );
    if (!profile.isInstalled ||
        profile.currentBaseAssetInstanceId != base.id ||
        profile.currentBaseAssetNumber != base.assetNumber ||
        profile.currentLinkageId != assignment.linkageId ||
        profile.serialNumber != assignment.innerCoverSerialNumber) {
      throw AssetHierarchyException(
        'Base ${base.assetNumber} and Inner Cover ${assignment.innerCoverSerialNumber} disagree. Reconcile the pairing before raising work.',
      );
    }
    return assignment;
  }

  Stream<List<InstalledComponentRecord>> watchInstalledComponents(
    String assetInstanceId,
  ) {
    return _componentInstances
        .where('assetInstanceId', isEqualTo: assetInstanceId)
        .snapshots()
        .map((snapshot) {
          final batch = decodeSnapshotBatch(
            snapshot,
            InstalledComponentRecord.fromMap,
            source: 'InstalledComponentRecord',
          );
          if (!batch.isComplete) {
            throw const AssetHierarchyException(
              'The installed-component register is incomplete because one or more records could not be read. Reconcile the malformed records before making changes.',
            );
          }
          final records = batch.records.toList()
            ..sort(
              (left, right) => left.definitionName.toLowerCase().compareTo(
                right.definitionName.toLowerCase(),
              ),
            );
          return List<InstalledComponentRecord>.unmodifiable(records);
        });
  }

  Stream<List<InstalledComponentLifecycleAudit>> watchInstalledComponentHistory(
    String assetInstanceId,
  ) {
    return _hierarchyAudits
        .where('assetInstanceId', isEqualTo: assetInstanceId)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .where(
                    (doc) => doc.data()['entityType'] == 'installed_component',
                  )
                  .map(
                    (doc) => InstalledComponentLifecycleAudit.fromMap(
                      doc.data(),
                      doc.id,
                    ),
                  )
                  .toList()
                ..sort(
                  (left, right) =>
                      right.performedAt.compareTo(left.performedAt),
                );
          return List<InstalledComponentLifecycleAudit>.unmodifiable(records);
        });
  }

  Future<InstalledComponentRecord?> findActiveInstalledComponentByTag(
    String rawTag,
  ) async {
    final normalized = normalizeAssetComponentTag(rawTag);
    if (normalized.isEmpty) return null;
    final claimId = sha256.convert(utf8.encode(normalized)).toString();
    final claim = await _firestore
        .collection('asset_tag_claims')
        .doc(claimId)
        .get();
    if (!claim.exists || claim.data() == null) return null;
    final AssetTagClaimRecord claimRecord;
    try {
      claimRecord = AssetTagClaimRecord.fromMap(claim.data()!, claim.id);
    } on PersistedDataFormatException {
      throw AssetHierarchyException(
        'Tag $normalized has a malformed ownership claim. Reconcile the tag register before use.',
      );
    }
    if (claimRecord.normalizedTag != normalized) {
      throw AssetHierarchyException(
        'Tag $normalized disagrees with its ownership claim. Reconcile the tag register before use.',
      );
    }
    final component = await _componentInstances
        .doc(claimRecord.componentInstanceId)
        .get();
    if (!component.exists || component.data() == null) {
      throw AssetHierarchyException(
        'Tag $normalized points to a missing component. Reconcile the tag register before use.',
      );
    }
    final record = InstalledComponentRecord.fromMap(
      component.data()!,
      component.id,
    );
    if (!record.isActive ||
        normalizeAssetComponentTag(record.componentTag ?? '') != normalized ||
        claimRecord.assetClassId != record.assetClassId ||
        claimRecord.assetClassName != record.assetClassName ||
        claimRecord.assetInstanceId != record.assetInstanceId ||
        claimRecord.assetInstanceName != record.assetInstanceName ||
        claimRecord.assetNumber != record.assetNumber ||
        claimRecord.definitionNodeId != record.definitionNodeId ||
        claimRecord.definitionName != record.definitionName ||
        claimRecord.ownershipStatus != record.ownershipStatus ||
        claimRecord.ownerDiscipline != record.ownerDiscipline ||
        !_sameStrings(
          claimRecord.accountableRoleKeys,
          record.accountableRoleKeys,
        )) {
      throw AssetHierarchyException(
        'Tag $normalized disagrees with its component record. Reconcile the tag register before use.',
      );
    }
    if (record.ownershipStatus != AssetOwnershipStatus.confirmed) {
      throw AssetHierarchyException(
        'Tag $normalized belongs to a component whose ownership is ${record.ownershipStatus.label.toLowerCase()}. Confirm its owner before using it in maintenance work.',
      );
    }
    return record;
  }

  Future<AssetClassRecord?> getAssetClass(String assetClassId) async {
    final snapshot = await _classes.doc(assetClassId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return AssetClassRecord.fromMap(snapshot.data()!, snapshot.id);
  }

  Future<String> createAssetInstance({
    required AssetClassRecord assetClass,
    required AssetInstanceDraft draft,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Physical asset is not valid.');
    final assetInstanceId = _uuid.v4();
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_ASSET_INSTANCE',
      'assetClassId': assetClass.id,
      'assetInstanceId': assetInstanceId,
      'expectedAssetClassVersion': assetClass.version,
      'reason': _validateReason(reason),
      'assetDraft': _assetDraftMap(normalized),
    }, actor);
    return assetInstanceId;
  }

  Future<void> updateAssetInstance({
    required AssetInstanceRecord before,
    required AssetInstanceDraft draft,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Physical asset is not valid.');
    if (normalized.assetNumber != before.assetNumber) {
      throw const AssetHierarchyException(
        'Asset number is permanent. Create a new asset if the identity changes.',
      );
    }
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_ASSET_INSTANCE',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'assetDraft': _assetDraftMap(normalized),
    }, actor);
  }

  Future<void> setAssetInstanceStatus({
    required AssetInstanceRecord before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
  }) async {
    if (before.status == status) return;
    if (!(status == AssetHierarchyStatus.retired &&
        actor.isApproved &&
        actor.isSI)) {
      _requireAdmin(actor);
    }
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_ASSET_INSTANCE_STATUS',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
    }, actor);
  }

  Future<String> registerInnerCover({
    required AssetClassRecord innerCoverClass,
    required String serialNumber,
    required InnerCoverSourceType sourceType,
    required InnerCoverOriginClassification originClassification,
    required AppUser actor,
    required String reason,
    String? supplierOrFabricator,
    DateTime? receivedOrCompletedOn,
    DateTime? incorporatedOn,
    String? drawingReference,
    String? materialGrade,
    String? notes,
    List<InnerCoverFabricationSectionDraft> fabricationSections = const [],
  }) async {
    _requireAdmin(actor);
    if (!innerCoverClass.isActive ||
        innerCoverClass.legacyAssetTypeKey != 'innerCover') {
      throw const AssetHierarchyException(
        'Choose the active governed Inner Cover asset class.',
      );
    }
    final serial = serialNumber.trim();
    if (normalizeInnerCoverSerial(serial).length < 2 || serial.length > 160) {
      throw const AssetHierarchyException(
        'Enter an Inner Cover serial containing at least two letters or numbers.',
      );
    }
    final errors = fabricationSections
        .expand((section) => section.validate())
        .toList();
    final originMatchesSource = switch (originClassification) {
      InnerCoverOriginClassification.documentedPurchase =>
        sourceType == InnerCoverSourceType.purchased,
      InnerCoverOriginClassification.documentedFabrication ||
      InnerCoverOriginClassification.ownerDeclaredFabricated =>
        sourceType == InnerCoverSourceType.fabricated,
      InnerCoverOriginClassification.ownerDeclaredNew ||
      InnerCoverOriginClassification.legacyUndocumented =>
        sourceType == InnerCoverSourceType.legacyExisting,
    };
    if (!originMatchesSource) {
      errors.add('The Inner Cover origin does not match its source envelope.');
    }
    final chronologyError = innerCoverRegistrationChronologyError(
      receivedOrCompletedOn: receivedOrCompletedOn,
      incorporatedOn: incorporatedOn,
    );
    if (chronologyError != null) errors.add(chronologyError);
    if (sourceType == InnerCoverSourceType.fabricated) {
      final types = fabricationSections.map((section) => section.type).toSet();
      for (final requiredType in const {
        InnerCoverFabricationSectionType.lowerAssembly,
        InnerCoverFabricationSectionType.flatVertical,
        InnerCoverFabricationSectionType.corrugatedShell,
        InnerCoverFabricationSectionType.topCover,
      }) {
        if (!types.contains(requiredType)) {
          errors.add('Fabrication must include ${requiredType.label}.');
        }
      }
    } else if (fabricationSections.isNotEmpty) {
      errors.add(
        'Fabrication sections are allowed only for fabricated covers.',
      );
    }
    _validate(errors, 'Inner Cover registration is not valid.');
    final innerCoverId = _uuid.v4();
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'REGISTER_INNER_COVER',
      'innerCoverId': innerCoverId,
      'innerCoverAssetClassId': innerCoverClass.id,
      'reason': _validateConditionReason(reason),
      'registrationDraft': <String, dynamic>{
        'serialNumber': serial,
        'sourceType': sourceType.name,
        'originClassification': originClassification.name,
        'supplierOrFabricator': cleanHierarchyText(supplierOrFabricator),
        'receivedOrCompletedOn': receivedOrCompletedOn == null
            ? null
            : commandUtcMillis(receivedOrCompletedOn),
        'incorporatedOn': incorporatedOn == null
            ? null
            : commandUtcMillis(incorporatedOn),
        'drawingReference': cleanHierarchyText(drawingReference),
        'materialGrade': cleanHierarchyText(materialGrade),
        'notes': cleanHierarchyText(notes),
        'fabricationSections': fabricationSections
            .map(
              (section) => <String, dynamic>{
                'sectionId': _uuid.v4(),
                'sectionType': section.type.name,
                'materialSource': section.materialSource.name,
                'donorInnerCoverId': section.donor?.id,
                'donorSectionKey': cleanHierarchyText(section.donorSectionKey),
                'donorExpectedVersion': section.donor?.version,
                'lengthMm': section.lengthMm,
                'cutCount': section.cutCount,
                'notes': cleanHierarchyText(section.notes),
              },
            )
            .toList(growable: false),
      },
    });
    return innerCoverId;
  }

  Future<AssetHierarchyMutationReceipt> acceptInnerCover({
    required InnerCoverProfile cover,
    required DateTime inspectedOn,
    required String acceptanceReference,
    required AppUser actor,
    required String reason,
    String? leakTestReference,
    String? ndtReference,
    String? notes,
    String? requestId,
  }) async {
    if (!actor.isApproved || !actor.isAdmin) {
      throw const AssetHierarchyInputRejected(
        'Only an approved admin can accept this Inner Cover.',
      );
    }
    final input = InnerCoverAcceptanceInput(
      inspectedOn: inspectedOn,
      acceptanceReference: acceptanceReference,
      reason: reason,
      leakTestReference: leakTestReference,
      ndtReference: ndtReference,
      notes: notes,
    );
    final error = input.validationError(
      now: DateTime.now(),
      receivedOn: cover.receivedOrCompletedOn,
    );
    if (error != null) throw AssetHierarchyInputRejected(error);
    return _invoke(<String, dynamic>{
      'requestId': requestId ?? _uuid.v4(),
      'operation': 'ACCEPT_INNER_COVER',
      'innerCoverId': cover.id,
      'expectedVersion': cover.version,
      'reason': _validateConditionReason(reason),
      'acceptanceDraft': <String, dynamic>{
        'inspectedOn': commandUtcMillis(inspectedOn),
        'acceptanceReference': acceptanceReference.trim(),
        'leakTestReference': cleanHierarchyText(leakTestReference),
        'ndtReference': cleanHierarchyText(ndtReference),
        'notes': cleanHierarchyText(notes),
      },
    });
  }

  Future<void> setInnerCoverState({
    required InnerCoverProfile cover,
    required InnerCoverLifecycleState targetState,
    required InnerCoverRetirementCondition? retirementCondition,
    required AppUser actor,
    required String reason,
    required DateTime physicalEventAt,
  }) async {
    _requireAdmin(actor);
    final retiring = targetState == InnerCoverLifecycleState.retiredForSalvage;
    final legacyReturn =
        cover.lifecycleState == InnerCoverLifecycleState.retiredForSalvage &&
        targetState == InnerCoverLifecycleState.awaitingInspection &&
        cover.retirementCondition == null;
    if ((retiring || legacyReturn) != (retirementCondition != null)) {
      throw const AssetHierarchyException(
        'Record whether the Inner Cover was bulged at retirement.',
      );
    }
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_INNER_COVER_STATE',
      'innerCoverId': cover.id,
      'expectedVersion': cover.version,
      'targetState': targetState.name,
      if (retirementCondition != null)
        'retirementCondition': retirementCondition.name,
      'physicalEventAt': commandUtcMillis(physicalEventAt),
      'reason': _validateConditionReason(reason),
    });
  }

  Future<void> linkInnerCover({
    required InnerCoverProfile cover,
    required AssetInstanceRecord base,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'LINK_INNER_COVER',
      'innerCoverId': cover.id,
      'expectedVersion': cover.version,
      'targetBaseAssetInstanceId': base.id,
      'reason': _validateConditionReason(reason),
    });
  }

  Future<void> delinkInnerCover({
    required InnerCoverProfile cover,
    required BaseInnerCoverAssignment assignment,
    required InnerCoverLifecycleState targetState,
    required AppUser actor,
    required String reason,
    required DateTime physicalEventAt,
  }) async {
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'DELINK_INNER_COVER',
      'innerCoverId': cover.id,
      'expectedVersion': cover.version,
      'sourceBaseAssetInstanceId': assignment.baseAssetInstanceId,
      'expectedSourceAssignmentVersion': assignment.version,
      'targetState': targetState.name,
      'physicalEventAt': commandUtcMillis(physicalEventAt),
      'reason': _validateConditionReason(reason),
    });
  }

  Future<void> transferInnerCover({
    required InnerCoverProfile cover,
    required BaseInnerCoverAssignment sourceAssignment,
    required AssetInstanceRecord targetBase,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'TRANSFER_INNER_COVER',
      'innerCoverId': cover.id,
      'expectedVersion': cover.version,
      'sourceBaseAssetInstanceId': sourceAssignment.baseAssetInstanceId,
      'expectedSourceAssignmentVersion': sourceAssignment.version,
      'targetBaseAssetInstanceId': targetBase.id,
      'reason': _validateConditionReason(reason),
    });
  }

  Future<void> replaceInnerCover({
    required InnerCoverProfile incoming,
    required InnerCoverProfile displaced,
    required BaseInnerCoverAssignment targetAssignment,
    required InnerCoverLifecycleState displacedState,
    required AppUser actor,
    required String reason,
    required DateTime physicalEventAt,
  }) async {
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'REPLACE_INNER_COVER',
      'innerCoverId': incoming.id,
      'expectedVersion': incoming.version,
      'targetBaseAssetInstanceId': targetAssignment.baseAssetInstanceId,
      'expectedTargetAssignmentVersion': targetAssignment.version,
      'displacedInnerCoverId': displaced.id,
      'expectedDisplacedVersion': displaced.version,
      'targetState': displacedState.name,
      'physicalEventAt': commandUtcMillis(physicalEventAt),
      'reason': _validateConditionReason(reason),
    });
  }

  Future<void> swapInnerCovers({
    required InnerCoverProfile incoming,
    required BaseInnerCoverAssignment sourceAssignment,
    required InnerCoverProfile displaced,
    required BaseInnerCoverAssignment targetAssignment,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SWAP_INNER_COVERS',
      'innerCoverId': incoming.id,
      'expectedVersion': incoming.version,
      'sourceBaseAssetInstanceId': sourceAssignment.baseAssetInstanceId,
      'expectedSourceAssignmentVersion': sourceAssignment.version,
      'targetBaseAssetInstanceId': targetAssignment.baseAssetInstanceId,
      'expectedTargetAssignmentVersion': targetAssignment.version,
      'displacedInnerCoverId': displaced.id,
      'expectedDisplacedVersion': displaced.version,
      'reason': _validateConditionReason(reason),
    });
  }

  /// Creates the exact request that a durable Inner Cover submission retains.
  /// Callers must not rebuild this map from today's profile when retrying it.
  Map<String, dynamic> newInnerCoverLifecycleRequest({
    required String operation,
    required String innerCoverId,
    int? expectedVersion,
    Map<String, dynamic> fields = const <String, dynamic>{},
    String? requestId,
  }) {
    return <String, dynamic>{
      'requestId': requestId ?? _uuid.v4(),
      'operation': operation,
      'innerCoverId': innerCoverId,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
      ...fields,
    };
  }

  Future<String> createInstalledComponent({
    required AssetInstanceRecord asset,
    required InstalledComponentDraft draft,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
    int? expectedTagOwnerComponentVersion,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Installed component is not valid.');
    final componentInstanceId = _uuid.v4();
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_COMPONENT_INSTANCE',
      'assetClassId': asset.assetClassId,
      'assetInstanceId': asset.id,
      'componentInstanceId': componentInstanceId,
      'expectedAssetInstanceVersion': asset.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'expectedTagOwnerComponentId': expectedTagOwnerComponentId,
      'expectedTagOwnerComponentVersion': expectedTagOwnerComponentVersion,
      'componentDraft': _componentDraftMap(normalized),
    }, actor);
    return componentInstanceId;
  }

  Future<void> updateInstalledComponent({
    required InstalledComponentRecord before,
    required InstalledComponentDraft draft,
    required AppUser actor,
    required String reason,
    bool correctInstallationFacts = false,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
    int? expectedTagOwnerComponentVersion,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Installed component is not valid.');
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': correctInstallationFacts
          ? 'CORRECT_COMPONENT_INSTANCE'
          : 'UPDATE_COMPONENT_INSTANCE',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.assetInstanceId,
      'componentInstanceId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'expectedTagOwnerComponentId': expectedTagOwnerComponentId,
      'expectedTagOwnerComponentVersion': expectedTagOwnerComponentVersion,
      'componentDraft': _componentDraftMap(normalized),
    }, actor);
  }

  Future<String> replaceInstalledComponent({
    required AssetInstanceRecord asset,
    required InstalledComponentRecord before,
    required InstalledComponentDraft replacement,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
    int? expectedTagOwnerComponentVersion,
    ComponentReplacementEvidenceReference? evidenceReference,
  }) async {
    _requireAdmin(actor);
    if (!asset.isActive ||
        !before.isActive ||
        before.assetInstanceId != asset.id ||
        before.assetClassId != asset.assetClassId) {
      throw const AssetHierarchyException(
        'Select an active component belonging to the active physical asset.',
      );
    }
    final normalized = replacement.normalized();
    _validate(normalized.validate(), 'Replacement component is not valid.');
    if (normalized.definitionNodeId != before.definitionNodeId) {
      throw const AssetHierarchyException(
        'A replacement must use the same governed component definition.',
      );
    }
    if (normalized.installedOn == null) {
      throw const AssetHierarchyException(
        'Record the replacement installation date and time.',
      );
    }
    final replacementComponentInstanceId = _uuid.v4();
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'REPLACE_COMPONENT_INSTANCE',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.assetInstanceId,
      'componentInstanceId': before.id,
      'replacementComponentInstanceId': replacementComponentInstanceId,
      'expectedVersion': before.version,
      'expectedAssetInstanceVersion': asset.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'expectedTagOwnerComponentId': expectedTagOwnerComponentId,
      'expectedTagOwnerComponentVersion': expectedTagOwnerComponentVersion,
      if (evidenceReference != null)
        'evidenceReference': evidenceReference.toMap(),
      'componentDraft': _componentDraftMap(normalized),
    }, actor);
    return replacementComponentInstanceId;
  }

  Future<void> setInstalledComponentStatus({
    required InstalledComponentRecord before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
    int? expectedTagOwnerComponentVersion,
  }) async {
    if (before.status == status) return;
    _requireAdmin(actor);
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_COMPONENT_INSTANCE_STATUS',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.assetInstanceId,
      'componentInstanceId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'expectedTagOwnerComponentId': expectedTagOwnerComponentId,
      'expectedTagOwnerComponentVersion': expectedTagOwnerComponentVersion,
    }, actor);
  }

  Map<String, dynamic> buildDeclareAssetConditionRequest({
    required AssetInstanceRecord asset,
    required AssetOperationalCondition condition,
    required Set<AssetConditionCause> causes,
    required AssetConditionBasis basis,
    required AssetHierarchyReference? componentReference,
    required String reason,
    required List<String> linkedIssueIds,
    required int expectedVersion,
    required String requestId,
  }) {
    if (condition == AssetOperationalCondition.available || causes.isEmpty) {
      throw const AssetHierarchyException(
        'Choose Down or Unfit and at least one cause.',
      );
    }
    if (basis == AssetConditionBasis.innerCoverUnavailable
        ? componentReference != null
        : componentReference == null) {
      throw const AssetHierarchyException(
        'Choose the affected governed component, except when the Inner Cover is unavailable.',
      );
    }
    return <String, dynamic>{
      'requestId': requestId,
      'operation': 'DECLARE_ASSET_CONDITION',
      'assetClassId': asset.assetClassId,
      'assetInstanceId': asset.id,
      'expectedVersion': expectedVersion,
      'condition': condition.name,
      'causeKeys': causes.map((cause) => cause.name).toList()..sort(),
      'basis': basis.name,
      'componentHierarchyRefJson': componentReference?.encode(),
      'reason': _validateConditionReason(reason),
      'linkedIssueIds': linkedIssueIds.toSet().toList()..sort(),
    };
  }

  Map<String, dynamic> buildRestoreAssetConditionRequest({
    required AssetInstanceRecord asset,
    required AssetOperationalConditionRecord current,
    required String reason,
    required String requestId,
  }) => <String, dynamic>{
    'requestId': requestId,
    'operation': 'RESTORE_ASSET_CONDITION',
    'assetClassId': asset.assetClassId,
    'assetInstanceId': asset.id,
    'expectedVersion': current.version,
    'reason': _validateConditionReason(reason),
  };

  Future<void> declareAssetCondition({
    required AssetInstanceRecord asset,
    required AssetOperationalCondition condition,
    required Set<AssetConditionCause> causes,
    required AssetConditionBasis basis,
    required AssetHierarchyReference? componentReference,
    required String reason,
    required List<String> linkedIssueIds,
    required AppUser actor,
    AssetOperationalConditionRecord? current,
  }) async {
    if (!actor.canDeclareAssetOperationalCondition) {
      throw const AssetHierarchyException(
        'Your role cannot declare an asset down or unfit.',
      );
    }
    await _invoke(
      buildDeclareAssetConditionRequest(
        asset: asset,
        condition: condition,
        causes: causes,
        basis: basis,
        componentReference: componentReference,
        reason: reason,
        linkedIssueIds: linkedIssueIds,
        expectedVersion: current?.version ?? 0,
        requestId: _uuid.v4(),
      ),
    );
  }

  Future<void> restoreAssetCondition({
    required AssetInstanceRecord asset,
    required AssetOperationalConditionRecord current,
    required String reason,
    required AppUser actor,
  }) async {
    if (!actor.canRestoreAssetOperationalCondition) {
      throw const AssetHierarchyException(
        'Only a Shift Supervisor, SI, or Admin can restore availability.',
      );
    }
    await _invoke(
      buildRestoreAssetConditionRequest(
        asset: asset,
        current: current,
        reason: reason,
        requestId: _uuid.v4(),
      ),
    );
  }

  Future<String> createAssetClass({
    required AssetClassDraft draft,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Asset class is not valid.');
    final assetClassId = _uuid.v4();
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_CLASS',
      'assetClassId': assetClassId,
      'reason': _validateReason(reason),
      'classDraft': _classDraftMap(normalized),
    }, actor);
    return assetClassId;
  }

  Future<void> updateAssetClass({
    required AssetClassRecord before,
    required AssetClassDraft draft,
    required AppUser actor,
    required String reason,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Asset class is not valid.');
    if (normalized.code != before.code) {
      throw const AssetHierarchyException(
        'Class code is permanent. Change the name or create a new class.',
      );
    }
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_CLASS',
      'assetClassId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'classDraft': _classDraftMap(normalized),
    }, actor);
  }

  Future<void> setAssetClassStatus({
    required AssetClassRecord before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
  }) async {
    if (before.status == status) return;
    _requireAdmin(actor);
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_CLASS_STATUS',
      'assetClassId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
    }, actor);
  }

  Future<String> createNode({
    required AssetClassRecord assetClass,
    required AssetHierarchyNodeDraft draft,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Hierarchy node is not valid.');
    final nodeId = _uuid.v4();
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_NODE',
      'assetClassId': assetClass.id,
      'expectedAssetClassVersion': assetClass.version,
      'nodeId': nodeId,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'nodeDraft': _nodeDraftMap(normalized),
    }, actor);
    return nodeId;
  }

  Future<void> updateNode({
    required AssetHierarchyNode before,
    required AssetHierarchyNodeDraft draft,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Hierarchy node is not valid.');
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_NODE',
      'assetClassId': before.assetClassId,
      'nodeId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'nodeDraft': _nodeDraftMap(normalized),
    }, actor);
  }

  Future<void> setNodeStatus({
    required AssetHierarchyNode before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
  }) async {
    if (before.status == status) return;
    _requireAdmin(actor);
    await _invokeRegistry(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_NODE_STATUS',
      'assetClassId': before.assetClassId,
      'nodeId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
    }, actor);
  }

  /// Sends already frozen acceptance data through the authenticated-origin
  /// protocol. This method never reconstructs a request from the current cover.
  Future<AssetHierarchyMutationReceipt> dispatchFrozenInnerCoverAcceptance(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) async {
    if (originActorUid.trim().isEmpty ||
        originActorUid.trim() != originActorUid ||
        request['operation'] != 'ACCEPT_INNER_COVER') {
      throw const AssetHierarchyInputRejected(
        'The saved acceptance needs review before it can be sent.',
      );
    }
    return _invoke(request, originActorUid: originActorUid);
  }

  /// Sends a previously retained lifecycle request without reconstructing it
  /// from the current profile. Acceptance has a stricter dedicated controller;
  /// all other lifecycle operations use this shared durable path.
  Future<AssetHierarchyMutationReceipt> dispatchFrozenInnerCoverLifecycle(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) async {
    if (originActorUid.trim().isEmpty ||
        originActorUid.trim() != originActorUid ||
        request['operation'] == 'ACCEPT_INNER_COVER') {
      throw const AssetHierarchyInputRejected(
        'The saved Inner Cover lifecycle request needs review before it can be sent.',
      );
    }
    return _invoke(request, originActorUid: originActorUid);
  }

  Future<AssetHierarchyMutationReceipt> dispatchFrozenAssetCondition(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) async {
    if (originActorUid.trim().isEmpty ||
        originActorUid.trim() != originActorUid ||
        !_assetConditionMutationOperations.contains(request['operation'])) {
      throw const AssetHierarchyInputRejected(
        'The saved asset-condition request needs review before it can be sent.',
      );
    }
    return _invoke(request, originActorUid: originActorUid);
  }

  Future<AssetHierarchyMutationReceipt> _invoke(
    Map<String, dynamic> request, {
    String? originActorUid,
  }) async {
    try {
      final response = await _client
          .httpsCallable(
            originActorUid == null
                ? assetHierarchyCallableName
                : assetHierarchyV2CallableName,
          )
          .call<Map<String, dynamic>>(
            originActorUid == null
                ? request
                : {
                    'protocolVersion': 2,
                    'originActorUid': originActorUid,
                    'request': request,
                  },
          );
      return AssetHierarchyMutationReceipt.fromMap(
        Map<String, dynamic>.from(response.data),
        request: request,
      );
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final map = details is Map
          ? Map<String, dynamic>.from(details)
          : const <String, dynamic>{};
      if (map['reasonCode'] == 'asset-tag-collision') {
        throw AssetTagCollisionException(
          normalizedTag: map['normalizedTag']?.toString() ?? '',
          existingNodeId: map['existingNodeId']?.toString() ?? '',
          existingNodeName:
              map['existingNodeName']?.toString() ?? 'another component',
          existingAssetClassId: map['existingAssetClassId']?.toString() ?? '',
          existingAssetClassName:
              map['existingAssetClassName']?.toString() ??
              'another asset class',
          existingPath:
              (map['existingPath'] as List?)
                  ?.map((item) => item.toString())
                  .toList() ??
              const <String>[],
          existingAssetInstanceId: map['existingAssetInstanceId']?.toString(),
          existingAssetInstanceName: map['existingAssetInstanceName']
              ?.toString(),
          existingComponentInstanceId: map['existingComponentInstanceId']
              ?.toString(),
          existingComponentVersion: map['existingComponentVersion'] is int
              ? map['existingComponentVersion'] as int
              : null,
          existingOwnershipStatus: AssetOwnershipStatus.values
              .where(
                (status) =>
                    status.name == map['existingOwnershipStatus']?.toString(),
              )
              .firstOrNull,
          existingOwnerDiscipline: map['existingOwnerDiscipline']?.toString(),
          existingAccountableRoleKeys:
              map['existingAccountableRoleKeys'] is List
              ? List<String>.unmodifiable(
                  (map['existingAccountableRoleKeys'] as List)
                      .whereType<String>(),
                )
              : const <String>[],
          transferSupported: map['transferSupported'] != false,
        );
      }
      // Only explicit pre-acceptance refusals unlock the retained inspection
      // draft. Unknown failures and historical receipt/reconciliation problems
      // keep the frozen request even when their transport code is precondition.
      const registerRefusalReasons = {
        'asset-registry-version-mismatch',
        'asset-hierarchy-version-mismatch',
        'asset-component-replaced-terminal',
        'asset-tag-transfer-owner-changed',
        'asset-instance-number-collision',
        'asset-instance-active-components',
        'asset-instance-open-condition-ticket',
        'asset-component-definition-kind-invalid',
        'asset-component-installation-future',
        'asset-component-owner-mismatch',
        'asset-component-correction-scope-invalid',
        'asset-component-replacement-definition-mismatch',
        'asset-component-installation-chronology-invalid',
        'asset-component-installation-history-malformed',
        'asset-class-legacy-role-collision',
        'asset-class-operational-role-migration-required',
        'asset-class-code-collision',
        'asset-class-active-nodes',
        'asset-class-active-instances',
        'asset-class-live-inner-covers',
        'asset-hierarchy-node-class-mismatch',
        'asset-hierarchy-node-retired',
        'asset-hierarchy-active-children',
      };
      if (assetRegistrySubmissionOperations.contains(request['operation']) &&
          registerRefusalReasons.contains(map['reasonCode'])) {
        throw AssetHierarchyCommandRefused(
          error.message ?? 'The register change was refused.',
          code: error.code,
          reasonCode: map['reasonCode'] as String,
        );
      }
      final editableAcceptanceRefusal =
          request['operation'] == 'ACCEPT_INNER_COVER' &&
          ((error.code == 'invalid-argument' &&
                  map['reasonCode'] ==
                      'invalid-inner-cover-lifecycle-request') ||
              (error.code == 'aborted' &&
                  map['reasonCode'] == 'inner-cover-version-mismatch') ||
              (error.code == 'failed-precondition' &&
                  const {
                    'inner-cover-not-awaiting-acceptance',
                    'inner-cover-acceptance-evidence-stale',
                    'inner-cover-acceptance-before-assurance-episode',
                  }.contains(map['reasonCode'])));
      if (editableAcceptanceRefusal) {
        throw AssetHierarchyCommandRefused(
          error.message ??
              'The change was refused. Review the current record and entered evidence.',
          code: error.code,
          reasonCode: map['reasonCode'] is String
              ? map['reasonCode'] as String
              : null,
        );
      }
      // These lifecycle business refusals occur after the backend has checked
      // for an accepted receipt. A transport code alone cannot establish that
      // outcome: the same code can describe failed recovery of an earlier
      // acceptance. Keep unknown/replay failures frozen, and never broaden the
      // dedicated acceptance contract above.
      const lifecycleRefusalReasons = <String, Set<String>>{
        'aborted': {
          'inner-cover-version-mismatch',
          'asset-condition-version-mismatch',
          'asset-condition-component-definition-changed',
        },
        'already-exists': {
          'inner-cover-serial-collision',
          'inner-cover-donor-part-already-consumed',
          'inner-cover-target-base-occupied',
        },
        'invalid-argument': {'inner-cover-return-condition-unexpected'},
        'failed-precondition': {
          'inner-cover-base-unavailable',
          'inner-cover-base-class-mismatch',
          'inner-cover-class-mismatch',
          'inner-cover-donor-not-salvageable',
          'inner-cover-installed-state-change',
          'inner-cover-state-transition-invalid',
          'inner-cover-return-condition-required',
          'inner-cover-return-condition-mismatch',
          'inner-cover-not-available',
          'inner-cover-reacceptance-required',
          'inner-cover-replacement-target-changed',
          'inner-cover-not-installed',
          'asset-condition-asset-class-invalid',
          'asset-condition-asset-invalid',
          'asset-condition-administratively-out-of-service',
          'asset-condition-inner-cover-still-linked',
          'asset-condition-not-active',
          'asset-condition-linked-issue-asset-mismatch',
          'asset-condition-linked-issue-deleted',
          'asset-condition-linked-issue-resolved',
          'asset-condition-linked-issue-unbound',
          'asset-condition-linked-issue-lifecycle-malformed',
          'asset-condition-linked-issue-inner-cover-malformed',
          'asset-condition-component-definition-changed',
          'asset-condition-legacy-writer-cannot-downgrade',
        },
      };
      if (request['operation'] != 'ACCEPT_INNER_COVER' &&
          lifecycleRefusalReasons[error.code]?.contains(map['reasonCode']) ==
              true) {
        throw AssetHierarchyCommandRefused(
          error.message ?? 'The hierarchy change was refused.',
          code: error.code,
          reasonCode: map['reasonCode'] is String
              ? map['reasonCode'] as String
              : null,
        );
      }
      throw AssetHierarchyException(
        error.message ?? 'The hierarchy change could not be completed.',
      );
    } on PersistedDataFormatException catch (error) {
      throw AssetHierarchyException(
        'The hierarchy service returned invalid mutation evidence: $error',
      );
    }
  }

  Map<String, dynamic> _classDraftMap(AssetClassDraft draft) =>
      <String, dynamic>{
        'code': draft.code,
        'name': draft.name,
        'majorArea': draft.majorArea,
        'shortDescription': draft.shortDescription,
        'longDescription': draft.longDescription,
        'legacyAssetTypeKey': draft.legacyAssetTypeKey,
      };

  Map<String, dynamic> _nodeDraftMap(AssetHierarchyNodeDraft draft) =>
      <String, dynamic>{
        'parentNodeId': draft.parentNodeId,
        'nodeType': draft.nodeType.name,
        'name': draft.name,
        'componentTag': draft.componentTag,
        'shortDescription': draft.shortDescription,
        'longDescription': draft.longDescription,
        'discipline': draft.discipline,
        'operatingType': draft.operatingType,
        'normalState': draft.normalState,
        'failState': draft.failState,
        'contactArrangement': draft.contactArrangement.name,
        'manufacturer': draft.manufacturer,
        'model': draft.model,
        'applicability': draft.applicability,
        'sourceReference': draft.sourceReference,
        'ownershipStatus': draft.ownershipStatus.name,
        'ownerDiscipline': draft.ownerDiscipline,
        'accountableRoleKeys': draft.accountableRoleKeys,
        'sortOrder': draft.sortOrder,
      };

  Map<String, dynamic> _assetDraftMap(AssetInstanceDraft draft) =>
      <String, dynamic>{
        'assetNumber': draft.assetNumber,
        'name': draft.name,
        'plantTag': draft.plantTag,
        'location': draft.location,
        'manufacturer': draft.manufacturer,
        'model': draft.model,
        'serialNumber': draft.serialNumber,
        'commissionedOn': draft.commissionedOn == null
            ? null
            : commandUtcMillis(draft.commissionedOn!),
        'serviceState': draft.serviceState.name,
        'ownershipStatus': draft.ownershipStatus.name,
        'ownerDiscipline': draft.ownerDiscipline,
        'accountableRoleKeys': draft.accountableRoleKeys,
      };

  Map<String, dynamic> _componentDraftMap(InstalledComponentDraft draft) =>
      <String, dynamic>{
        'definitionNodeId': draft.definitionNodeId,
        'componentTag': draft.componentTag,
        'manufacturer': draft.manufacturer,
        'model': draft.model,
        'serialNumber': draft.serialNumber,
        'installedOn': draft.installedOn == null
            ? null
            : commandUtcMillis(draft.installedOn!),
        'serviceState': draft.serviceState.name,
        'ownershipStatus': draft.ownershipStatus.name,
        'ownerDiscipline': draft.ownerDiscipline,
        'accountableRoleKeys': draft.accountableRoleKeys,
      };

  void _requireAdmin(AppUser actor) {
    if (!actor.isApproved || !actor.isAdmin) {
      throw const AssetHierarchyException(
        'Only an approved admin can change the asset hierarchy.',
      );
    }
  }

  String _validateReason(String reason) {
    final cleaned = reason.trim();
    if (cleaned.isEmpty || cleaned.length > 500) {
      throw const AssetHierarchyException(
        'Enter a change reason of no more than 500 characters.',
      );
    }
    return cleaned;
  }

  String _validateConditionReason(String reason) {
    final cleaned = reason.trim();
    if (cleaned.isEmpty || cleaned.length > 1000) {
      throw const AssetHierarchyException(
        'Enter an operational reason of no more than 1,000 characters.',
      );
    }
    return cleaned;
  }

  void _validate(List<String> errors, String message) {
    if (errors.isNotEmpty) {
      throw AssetHierarchyException(message, errors: errors);
    }
  }
}
