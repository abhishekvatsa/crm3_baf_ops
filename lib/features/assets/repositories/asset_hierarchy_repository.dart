import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../auth/data/user_model.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_registry_model.dart';

const assetHierarchyCallableName = 'mutateAssetHierarchy';
const assetHierarchyCallableRegion = 'asia-south1';

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
    this.existingOwnershipStatus,
    this.existingOwnerDiscipline,
    this.existingAccountableRoleKeys = const <String>[],
    this.transferSupported = true,
  }) : super('Tag $normalizedTag already belongs to $existingNodeName.');
}

class AssetHierarchyRepository {
  static const assetClassesCollection = 'asset_classes';
  static const hierarchyNodesCollection = 'asset_hierarchy_nodes';
  static const assetInstancesCollection = 'asset_instances';
  static const componentInstancesCollection = 'asset_component_instances';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final Uuid _uuid;

  AssetHierarchyRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    Uuid uuid = const Uuid(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions,
       _uuid = uuid;

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

  Stream<List<AssetClassRecord>> watchAssetClasses() {
    return _classes.snapshots().map((snapshot) {
      final records =
          snapshot.docs
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
    return _nodes
        .where('assetClassId', isEqualTo: assetClassId)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .map((doc) => AssetHierarchyNode.fromMap(doc.data(), doc.id))
                  .toList();
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

  Stream<List<InstalledComponentRecord>> watchInstalledComponents(
    String assetInstanceId,
  ) {
    return _componentInstances
        .where('assetInstanceId', isEqualTo: assetInstanceId)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .map(
                    (doc) =>
                        InstalledComponentRecord.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort(
                  (left, right) => left.definitionName.toLowerCase().compareTo(
                    right.definitionName.toLowerCase(),
                  ),
                );
          return List<InstalledComponentRecord>.unmodifiable(records);
        });
  }

  Future<InstalledComponentRecord?> findActiveInstalledComponentByTag(
    String rawTag,
  ) async {
    final normalized = normalizeAssetComponentTag(rawTag);
    if (normalized.isEmpty) return null;
    final claimId = sha256.convert(utf8.encode(normalized)).toString();
    final claim =
        await _firestore.collection('asset_tag_claims').doc(claimId).get();
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
    final component =
        await _componentInstances.doc(claimRecord.componentInstanceId).get();
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_ASSET_INSTANCE',
      'assetClassId': assetClass.id,
      'assetInstanceId': assetInstanceId,
      'expectedAssetClassVersion': assetClass.version,
      'reason': _validateReason(reason),
      'assetDraft': _assetDraftMap(normalized),
    });
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_ASSET_INSTANCE',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'assetDraft': _assetDraftMap(normalized),
    });
  }

  Future<void> setAssetInstanceStatus({
    required AssetInstanceRecord before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
  }) async {
    if (before.status == status) return;
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_ASSET_INSTANCE_STATUS',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
    });
  }

  Future<String> createInstalledComponent({
    required AssetInstanceRecord asset,
    required InstalledComponentDraft draft,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Installed component is not valid.');
    final componentInstanceId = _uuid.v4();
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_COMPONENT_INSTANCE',
      'assetClassId': asset.assetClassId,
      'assetInstanceId': asset.id,
      'componentInstanceId': componentInstanceId,
      'expectedAssetInstanceVersion': asset.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'expectedTagOwnerComponentId': expectedTagOwnerComponentId,
      'componentDraft': _componentDraftMap(normalized),
    });
    return componentInstanceId;
  }

  Future<void> updateInstalledComponent({
    required InstalledComponentRecord before,
    required InstalledComponentDraft draft,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
  }) async {
    _requireAdmin(actor);
    final normalized = draft.normalized();
    _validate(normalized.validate(), 'Installed component is not valid.');
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_COMPONENT_INSTANCE',
      'assetClassId': before.assetClassId,
      'assetInstanceId': before.assetInstanceId,
      'componentInstanceId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'expectedTagOwnerComponentId': expectedTagOwnerComponentId,
      'componentDraft': _componentDraftMap(normalized),
    });
  }

  Future<void> setInstalledComponentStatus({
    required InstalledComponentRecord before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
    bool allowTagTransfer = false,
    String? expectedTagOwnerComponentId,
  }) async {
    if (before.status == status) return;
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
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
    });
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_CLASS',
      'assetClassId': assetClassId,
      'reason': _validateReason(reason),
      'classDraft': _classDraftMap(normalized),
    });
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_CLASS',
      'assetClassId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'classDraft': _classDraftMap(normalized),
    });
  }

  Future<void> setAssetClassStatus({
    required AssetClassRecord before,
    required AssetHierarchyStatus status,
    required AppUser actor,
    required String reason,
  }) async {
    if (before.status == status) return;
    _requireAdmin(actor);
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_CLASS_STATUS',
      'assetClassId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
    });
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'CREATE_NODE',
      'assetClassId': assetClass.id,
      'expectedAssetClassVersion': assetClass.version,
      'nodeId': nodeId,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'nodeDraft': _nodeDraftMap(normalized),
    });
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'UPDATE_NODE',
      'assetClassId': before.assetClassId,
      'nodeId': before.id,
      'expectedVersion': before.version,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
      'nodeDraft': _nodeDraftMap(normalized),
    });
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
    await _invoke(<String, dynamic>{
      'requestId': _uuid.v4(),
      'operation': 'SET_NODE_STATUS',
      'assetClassId': before.assetClassId,
      'nodeId': before.id,
      'expectedVersion': before.version,
      'status': status.name,
      'reason': _validateReason(reason),
      'allowTagTransfer': allowTagTransfer,
    });
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> request) async {
    try {
      final response = await _client
          .httpsCallable(assetHierarchyCallableName)
          .call<Map<String, dynamic>>(request);
      return Map<String, dynamic>.from(response.data);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final map =
          details is Map
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
          existingAssetInstanceName:
              map['existingAssetInstanceName']?.toString(),
          existingComponentInstanceId:
              map['existingComponentInstanceId']?.toString(),
          existingOwnershipStatus:
              AssetOwnershipStatus.values
                  .where(
                    (status) =>
                        status.name ==
                        map['existingOwnershipStatus']?.toString(),
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
      throw AssetHierarchyException(
        error.message ?? 'The hierarchy change could not be completed.',
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
        'commissionedOn': draft.commissionedOn?.toUtc().toIso8601String(),
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
        'installedOn': draft.installedOn?.toUtc().toIso8601String(),
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
    if (cleaned.length < 8 || cleaned.length > 500) {
      throw const AssetHierarchyException(
        'Enter a change reason between 8 and 500 characters.',
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
