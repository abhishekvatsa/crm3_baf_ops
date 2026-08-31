import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../serialization/persisted_data_reader.dart';
import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/audit/models/audit_event_model.dart';
import '../../features/auth/data/user_model.dart';
import '../../features/directives/data/operational_directive_model.dart';
import '../../features/directives/data/remote_operational_directive_reader.dart';
import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/maintenance/data/remote_maintenance_reader.dart';
import '../../features/maintenance_workflow/domain/workflow_command_contract.dart';
import '../../features/planned_maintenance/data/baf_knowledge_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';

class LocalSyncRecoveryRemoteDocument {
  final bool exists;
  final Map<String, dynamic>? data;

  const LocalSyncRecoveryRemoteDocument.missing() : exists = false, data = null;

  const LocalSyncRecoveryRemoteDocument.existing(this.data) : exists = true;
}

typedef LocalSyncRecoveryRemoteReader =
    Future<LocalSyncRecoveryRemoteDocument> Function(
      String collection,
      String documentId,
    );

class AuthoritativePurgeManifest {
  final String collectionId;
  final String documentId;
  final int sourceVersion;

  const AuthoritativePurgeManifest({
    required this.collectionId,
    required this.documentId,
    required this.sourceVersion,
  });

  factory AuthoritativePurgeManifest.fromRemote(
    Map<String, dynamic> data, {
    required String manifestId,
  }) {
    final keys = data.keys.toSet();
    const expectedKeys = <String>{
      'schemaVersion',
      'sourceCollection',
      'sourceDocumentId',
      'sourceVersion',
      'purgedAt',
    };
    final collection = data['sourceCollection'];
    final document = data['sourceDocumentId'];
    final version = data['sourceVersion'];
    if (!keys.containsAll(expectedKeys) ||
        keys.length != expectedKeys.length ||
        data['schemaVersion'] != 1 ||
        collection is! String ||
        !_purgeManifestEntityTypes.containsKey(collection) ||
        document is! String ||
        document.trim().isEmpty ||
        version is! int ||
        version < 1 ||
        manifestId != authoritativePurgeManifestId(collection, document)) {
      throw const FormatException('Malformed authoritative purge manifest.');
    }
    readRequiredPersistedDateTime(
      data['purgedAt'],
      field: 'purgedAt',
      source: 'authoritative purge manifest',
    );
    return AuthoritativePurgeManifest(
      collectionId: collection,
      documentId: document,
      sourceVersion: version,
    );
  }
}

typedef LocalSyncRecoveryPurgeManifestReader =
    Future<List<AuthoritativePurgeManifest>> Function(
      List<LocalPurgeCandidate> candidates,
    );

class LocalPurgeCandidate {
  final String collectionId;
  final String documentId;

  const LocalPurgeCandidate({
    required this.collectionId,
    required this.documentId,
  });
}

class LocalPurgeReconciliationResult {
  final int removed;
  final int alreadyAbsent;
  final int preserved;
  final List<String> errors;

  const LocalPurgeReconciliationResult({
    this.removed = 0,
    this.alreadyAbsent = 0,
    this.preserved = 0,
    this.errors = const <String>[],
  });
}

const _purgeManifestEntityTypes = <String, String>{
  'maintenance_records': 'maintenance_ticket',
  'directives': 'directive',
  'job_templates': 'job_template',
};

String authoritativePurgeManifestId(String collectionId, String documentId) =>
    'purge_${sha256.convert(utf8.encode('$collectionId/$documentId'))}';

class LocalSyncRecoveryResult {
  final int restoredFromServer;
  final int removedLocalOnly;
  final int preservedOtherUser;
  final int preservedUnsupported;
  final int preservedFailed;
  final List<String> errors;

  const LocalSyncRecoveryResult({
    this.restoredFromServer = 0,
    this.removedLocalOnly = 0,
    this.preservedOtherUser = 0,
    this.preservedUnsupported = 0,
    this.preservedFailed = 0,
    this.errors = const <String>[],
  });

  int get recoveredCount => restoredFromServer + removedLocalOnly;
  int get preservedCount =>
      preservedOtherUser + preservedUnsupported + preservedFailed;
}

class LocalSyncRecoveryService {
  LocalSyncRecoveryService({
    Isar? Function()? databaseLookup,
    String? Function()? authenticatedUidLookup,
    LocalSyncRecoveryRemoteReader? remoteReader,
    LocalSyncRecoveryPurgeManifestReader? purgeManifestReader,
  }) : _databaseLookup = databaseLookup ?? Isar.getInstance,
       _authenticatedUidLookup =
           authenticatedUidLookup ??
           (() => FirebaseAuth.instance.currentUser?.uid),
       _remoteReader = remoteReader ?? _readAuthoritativeRemote,
       _purgeManifestReader =
           purgeManifestReader ?? _readAuthoritativePurgeManifests;

  final Isar? Function() _databaseLookup;
  final String? Function() _authenticatedUidLookup;
  final LocalSyncRecoveryRemoteReader _remoteReader;
  final LocalSyncRecoveryPurgeManifestReader _purgeManifestReader;

  static Future<LocalSyncRecoveryRemoteDocument> _readAuthoritativeRemote(
    String collection,
    String documentId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .doc(documentId)
        .get(const GetOptions(source: Source.server));
    return snapshot.exists
        ? LocalSyncRecoveryRemoteDocument.existing(snapshot.data())
        : const LocalSyncRecoveryRemoteDocument.missing();
  }

  static Future<List<AuthoritativePurgeManifest>>
  _readAuthoritativePurgeManifests(List<LocalPurgeCandidate> candidates) async {
    final manifests = <AuthoritativePurgeManifest>[];
    for (final candidate in candidates) {
      final document = await FirebaseFirestore.instance
          .collection('pilot_record_purge_manifests')
          .doc(
            authoritativePurgeManifestId(
              candidate.collectionId,
              candidate.documentId,
            ),
          )
          .get(const GetOptions(source: Source.server));
      if (document.exists && document.data() != null) {
        manifests.add(
          AuthoritativePurgeManifest.fromRemote(
            document.data()!,
            manifestId: document.id,
          ),
        );
      }
    }
    return List<AuthoritativePurgeManifest>.unmodifiable(manifests);
  }

  Future<LocalSyncRecoveryResult> discardOwnRejectedChanges({
    required AppUser? actor,
  }) async {
    if (actor == null || !actor.isApproved || actor.uid.trim().isEmpty) {
      throw StateError(
        'An approved signed-in user is required for local recovery.',
      );
    }
    if (_authenticatedUidLookup() != actor.uid) {
      throw StateError('The signed-in account changed before local recovery.');
    }
    if (kIsWeb) {
      throw StateError(
        'Local recovery is available only on an installed device.',
      );
    }
    final database = _databaseLookup();
    if (database == null) {
      throw StateError('The local device database is not available.');
    }

    final rejections =
        await database.syncRejections
            .filter()
            .isResolvedEqualTo(false)
            .and()
            .isLikelyPermanentEqualTo(true)
            .sortByLastSeenAtDesc()
            .limit(200)
            .findAll();

    var restored = 0;
    var removed = 0;
    var otherUser = 0;
    var unsupported = 0;
    var failed = 0;
    final errors = <String>[];

    for (final rejection in rejections) {
      if (rejection.originatingUid?.trim() != actor.uid) {
        otherUser++;
        continue;
      }
      final adapter = _adapterFor(rejection.entityType);
      if (adapter == null) {
        unsupported++;
        continue;
      }

      try {
        final local = await adapter.find(database, rejection);
        if (local == null || local.isSynced == true) {
          failed++;
          continue;
        }
        final ownerUid = adapter.ownerUid(local)?.trim();
        if (ownerUid == null || ownerUid.isEmpty || ownerUid != actor.uid) {
          otherUser++;
          continue;
        }

        final remoteId = _clean(
          rejection.firestoreId ?? adapter.remoteDocumentId(local),
        );
        final remote =
            remoteId == null
                ? const LocalSyncRecoveryRemoteDocument.missing()
                : await _remoteReader(adapter.collectionPath, remoteId);

        final authoritative =
            remote.exists
                ? adapter.decode(
                  remote.data ??
                      (throw StateError(
                        'The server returned an empty authoritative record.',
                      )),
                  remoteId!,
                )
                : null;

        if (authoritative == null &&
            await _hasDependentLocalRecords(
              database,
              entityType: rejection.entityType,
              remoteId: remoteId,
              localId: local.id as int,
            )) {
          failed++;
          errors.add('${rejection.shortLabel}: dependent local records exist');
          continue;
        }

        if (_authenticatedUidLookup() != actor.uid) {
          throw StateError(
            'The signed-in account changed during local recovery.',
          );
        }
        final expectedId = local.id as int;
        final expectedVersion = local.version as int;
        final expectedUpdatedAt = local.updatedAt as DateTime;
        var changed = false;

        await database.writeTxn(() async {
          final currentRejection = await database.syncRejections.get(
            rejection.id,
          );
          if (currentRejection == null ||
              currentRejection.isResolved ||
              !currentRejection.isLikelyPermanent) {
            return;
          }
          final current = await adapter.find(database, currentRejection);
          if (current == null ||
              current.id != expectedId ||
              current.isSynced == true ||
              current.version != expectedVersion ||
              current.updatedAt != expectedUpdatedAt ||
              adapter.ownerUid(current)?.trim() != actor.uid ||
              _authenticatedUidLookup() != actor.uid) {
            return;
          }

          if (authoritative != null) {
            authoritative
              ..id = expectedId
              ..isSynced = true;
            await adapter.put(database, authoritative);
          } else {
            await adapter.delete(database, expectedId);
          }

          currentRejection.markResolved(
            resolvedByUid: actor.uid,
            resolvedByName: actor.name,
            notes:
                authoritative == null
                    ? 'User discarded an owned rejected local-only record; no server record existed.'
                    : 'User discarded an owned rejected local edit and restored authoritative server data.',
          );
          await database.syncRejections.put(currentRejection);
          changed = true;
        });

        if (!changed) {
          failed++;
        } else if (authoritative == null) {
          removed++;
        } else {
          restored++;
        }
      } catch (error) {
        failed++;
        errors.add('${rejection.shortLabel}: $error');
      }
    }

    return LocalSyncRecoveryResult(
      restoredFromServer: restored,
      removedLocalOnly: removed,
      preservedOtherUser: otherUser,
      preservedUnsupported: unsupported,
      preservedFailed: failed,
      errors: List<String>.unmodifiable(errors),
    );
  }

  Future<bool> removeAuthoritativelyPurgedTombstone({
    required AppUser? actor,
    required WorkflowCommandReceipt receipt,
    required String collectionId,
    required String documentId,
  }) async {
    if (actor == null || !actor.isApproved || !actor.isAdmin) {
      throw StateError('Fresh Admin authority is required for local cleanup.');
    }
    if (_authenticatedUidLookup() != actor.uid) {
      throw StateError('The signed-in account changed before local cleanup.');
    }
    const entityTypes = <String, String>{
      'maintenance_records': 'maintenance_ticket',
      'directives': 'directive',
      'job_templates': 'job_template',
    };
    final entityType = entityTypes[collectionId];
    final result = receipt.result;
    if (entityType == null ||
        receipt.resultKey != 'pilot-record-permanently-removed' ||
        result.length != 4 ||
        result['collectionId'] != collectionId ||
        result['documentId'] != documentId ||
        result['purgeReceiptId'] is! String ||
        !RegExp(
          r'^purge_[0-9a-f]{64}$',
        ).hasMatch(result['purgeReceiptId'] as String) ||
        result['sourceDigest'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(result['sourceDigest'] as String) ||
        receipt.aggregateVersion < 1) {
      throw const FormatException('Malformed pilot purge command receipt.');
    }
    if (kIsWeb) return true;
    final database = _databaseLookup();
    if (database == null) {
      throw StateError('The local device database is not available.');
    }
    final adapter = _adapterFor(entityType)!;
    final local = await adapter.findByRemoteId(database, documentId);
    if (local == null) return true;
    if (local.isSynced != true ||
        local.isDeleted != true ||
        local.version != receipt.aggregateVersion ||
        await _hasDependentLocalRecords(
          database,
          entityType: entityType,
          remoteId: documentId,
          localId: local.id as int,
        )) {
      return false;
    }

    final expectedId = local.id as int;
    final expectedUpdatedAt = local.updatedAt as DateTime;
    var removed = false;
    await database.writeTxn(() async {
      final current = await adapter.findByRemoteId(database, documentId);
      if (current == null) {
        removed = true;
        return;
      }
      if (current.id != expectedId ||
          current.isSynced != true ||
          current.isDeleted != true ||
          current.version != receipt.aggregateVersion ||
          current.updatedAt != expectedUpdatedAt ||
          _authenticatedUidLookup() != actor.uid) {
        return;
      }
      await adapter.delete(database, expectedId);
      removed = true;
    });
    return removed;
  }

  Future<LocalPurgeReconciliationResult>
  reconcileAuthoritativelyPurgedTombstones({required AppUser? actor}) async {
    if (actor == null || !actor.isApproved || actor.uid.trim().isEmpty) {
      return const LocalPurgeReconciliationResult();
    }
    if (_authenticatedUidLookup() != actor.uid) {
      throw StateError(
        'The signed-in account changed before purge reconciliation.',
      );
    }
    if (kIsWeb) return const LocalPurgeReconciliationResult();
    final database = _databaseLookup();
    if (database == null) {
      throw StateError('The local device database is not available.');
    }

    final candidates = await _localPurgeCandidates(database);
    if (candidates.isEmpty) return const LocalPurgeReconciliationResult();
    final manifests = await _purgeManifestReader(candidates);
    var removed = 0;
    var alreadyAbsent = 0;
    var preserved = candidates.length - manifests.length;
    final errors = <String>[];

    for (final manifest in manifests) {
      final entityType = _purgeManifestEntityTypes[manifest.collectionId];
      if (entityType == null) {
        preserved++;
        continue;
      }
      final adapter = _adapterFor(entityType);
      if (adapter == null) {
        preserved++;
        continue;
      }
      try {
        final local = await adapter.findByRemoteId(
          database,
          manifest.documentId,
        );
        if (local == null) {
          alreadyAbsent++;
          continue;
        }
        if (local.isSynced != true ||
            local.isDeleted != true ||
            local.version != manifest.sourceVersion) {
          preserved++;
          continue;
        }

        final expectedId = local.id as int;
        final expectedUpdatedAt = local.updatedAt as DateTime;
        var changed = false;
        await database.writeTxn(() async {
          final current = await adapter.findByRemoteId(
            database,
            manifest.documentId,
          );
          if (current == null) {
            changed = true;
            return;
          }
          if (current.id != expectedId ||
              current.isSynced != true ||
              current.isDeleted != true ||
              current.version != manifest.sourceVersion ||
              current.updatedAt != expectedUpdatedAt ||
              _authenticatedUidLookup() != actor.uid ||
              await _hasDependentLocalRecords(
                database,
                entityType: entityType,
                remoteId: manifest.documentId,
                localId: expectedId,
              )) {
            return;
          }
          await adapter.delete(database, expectedId);
          changed = true;
        });
        if (changed) {
          removed++;
        } else {
          preserved++;
        }
      } catch (error) {
        preserved++;
        errors.add('${manifest.collectionId}/${manifest.documentId}: $error');
      }
    }

    return LocalPurgeReconciliationResult(
      removed: removed,
      alreadyAbsent: alreadyAbsent,
      preserved: preserved,
      errors: List<String>.unmodifiable(errors),
    );
  }

  Future<List<LocalPurgeCandidate>> _localPurgeCandidates(Isar database) async {
    final tickets =
        await database.maintenanceRecords
            .filter()
            .isDeletedEqualTo(true)
            .and()
            .isSyncedEqualTo(true)
            .findAll();
    final directives =
        await database.operationalDirectives
            .filter()
            .isDeletedEqualTo(true)
            .and()
            .isSyncedEqualTo(true)
            .findAll();
    final templates =
        await database.jobTemplates
            .filter()
            .isDeletedEqualTo(true)
            .and()
            .isSyncedEqualTo(true)
            .findAll();
    final candidates = <LocalPurgeCandidate>[];
    void add(String collectionId, String? documentId) {
      final normalized = documentId?.trim();
      if (normalized == null || normalized.isEmpty) return;
      candidates.add(
        LocalPurgeCandidate(collectionId: collectionId, documentId: normalized),
      );
    }

    for (final record in tickets) {
      add('maintenance_records', record.firestoreId);
    }
    for (final record in directives) {
      add('directives', record.firestoreId);
    }
    for (final record in templates) {
      add('job_templates', record.firestoreId);
    }
    return List<LocalPurgeCandidate>.unmodifiable(candidates);
  }

  Future<bool> _hasDependentLocalRecords(
    Isar database, {
    required String entityType,
    required String? remoteId,
    required int localId,
  }) async {
    if (remoteId == null) {
      if (entityType != 'job_execution') return false;
      final module =
          await database.jobModuleInstances
              .filter()
              .jobExecutionLocalIdEqualTo(localId)
              .findFirst();
      final diary =
          await database.jobDiaryEntrys
              .filter()
              .jobExecutionLocalIdEqualTo(localId)
              .findFirst();
      return module != null || diary != null;
    }

    switch (entityType) {
      case 'maintenance_ticket':
        return await database.operationalDirectives
                    .filter()
                    .linkedMaintenanceFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.chargeAbnormalitys
                    .filter()
                    .linkedTicketFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null;
      case 'job_execution':
        return await database.jobModuleInstances
                    .filter()
                    .jobExecutionFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.jobDiaryEntrys
                    .filter()
                    .jobExecutionFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.operationalDirectives
                    .filter()
                    .linkedExecutionFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.chargeAbnormalitys
                    .filter()
                    .linkedExecutionFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null;
      case 'job_template':
        return await database.jobExecutions
                    .filter()
                    .templateFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.jobModuleInstances
                    .filter()
                    .templateFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.jobDiaryEntrys
                    .filter()
                    .templateFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null;
      case 'template_package':
        return await database.templateVersions
                    .filter()
                    .packageFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.templatePublishAudits
                    .filter()
                    .packageFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null;
      case 'template_version':
        return await database.jobExecutions
                    .filter()
                    .templateVersionIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.jobModuleInstances
                    .filter()
                    .templateVersionIdEqualTo(remoteId)
                    .findFirst() !=
                null ||
            await database.templatePublishAudits
                    .filter()
                    .versionFirestoreIdEqualTo(remoteId)
                    .findFirst() !=
                null;
      case 'abnormality_type':
        return await database.chargeAbnormalitys
                .filter()
                .abnormalityTypeIdEqualTo(remoteId)
                .findFirst() !=
            null;
      default:
        return false;
    }
  }

  _LocalRecoveryAdapter? _adapterFor(String entityType) => switch (entityType) {
    'maintenance_ticket' => _LocalRecoveryAdapter.typed<MaintenanceRecord>(
      collectionPath: 'maintenance_records',
      collection: (database) => database.maintenanceRecords,
      findByRemoteId:
          (database, id) =>
              database.maintenanceRecords
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: (data, id) => readRemoteMaintenanceRecord(data, documentId: id),
      ownerUid:
          (record) =>
              record.deletedByUid ??
              (record.isResolved ? record.closedByUid : null) ??
              record.reopenedByUid ??
              record.acknowledgedByUid ??
              record.loggedByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'job_template' => _LocalRecoveryAdapter.typed<JobTemplate>(
      collectionPath: 'job_templates',
      collection: (database) => database.jobTemplates,
      findByRemoteId:
          (database, id) =>
              database.jobTemplates.filter().firestoreIdEqualTo(id).findFirst(),
      decode: JobTemplate.fromMap,
      ownerUid: (record) => record.deletedByUid ?? record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'job_execution' => _LocalRecoveryAdapter.typed<JobExecution>(
      collectionPath: 'job_executions',
      collection: (database) => database.jobExecutions,
      findByRemoteId:
          (database, id) =>
              database.jobExecutions
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: JobExecution.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ??
              record.cancelledByUid ??
              record.completedByUid ??
              record.assignedByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'job_diary_entry' => _LocalRecoveryAdapter.typed<JobDiaryEntry>(
      collectionPath: 'job_diary_entries',
      collection: (database) => database.jobDiaryEntrys,
      findByRemoteId:
          (database, id) =>
              database.jobDiaryEntrys
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: JobDiaryEntry.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ?? record.updatedByUid ?? record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'job_module' => _LocalRecoveryAdapter.typed<JobModuleInstance>(
      collectionPath: 'job_modules',
      collection: (database) => database.jobModuleInstances,
      findByRemoteId:
          (database, id) =>
              database.jobModuleInstances
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: JobModuleInstance.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ?? record.updatedByUid ?? record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'directive' => _LocalRecoveryAdapter.typed<OperationalDirective>(
      collectionPath: 'directives',
      collection: (database) => database.operationalDirectives,
      findByRemoteId:
          (database, id) =>
              database.operationalDirectives
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode:
          (data, id) => readRemoteOperationalDirective(data, documentId: id),
      ownerUid:
          (record) =>
              record.deletedByUid ??
              record.closedByUid ??
              record.acknowledgedByUid ??
              record.issuedByUid ??
              record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'abnormality_type' => _LocalRecoveryAdapter.typed<AbnormalityType>(
      collectionPath: 'abnormality_types',
      collection: (database) => database.abnormalityTypes,
      findByRemoteId:
          (database, id) =>
              database.abnormalityTypes
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: AbnormalityType.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ??
              record.lastEditedByUid ??
              record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'charge_abnormality' => _LocalRecoveryAdapter.typed<ChargeAbnormality>(
      collectionPath: 'charge_abnormalities',
      collection: (database) => database.chargeAbnormalitys,
      findByRemoteId:
          (database, id) =>
              database.chargeAbnormalitys
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: ChargeAbnormality.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ?? record.updatedByUid ?? record.loggedByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'template_package' => _LocalRecoveryAdapter.typed<TemplatePackage>(
      collectionPath: 'template_packages',
      collection: (database) => database.templatePackages,
      findByRemoteId:
          (database, id) =>
              database.templatePackages
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: TemplatePackage.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ?? record.updatedByUid ?? record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'template_version' => _LocalRecoveryAdapter.typed<TemplateVersion>(
      collectionPath: 'template_versions',
      collection: (database) => database.templateVersions,
      findByRemoteId:
          (database, id) =>
              database.templateVersions
                  .filter()
                  .firestoreIdEqualTo(id)
                  .findFirst(),
      decode: TemplateVersion.fromMap,
      ownerUid:
          (record) =>
              record.deletedByUid ?? record.updatedByUid ?? record.createdByUid,
      remoteDocumentId: (record) => record.firestoreId,
    ),
    'baf_knowledge_row' => _LocalRecoveryAdapter.typed<BafKnowledgeRow>(
      collectionPath: 'knowledge_base',
      collection: (database) => database.bafKnowledgeRows,
      findByRemoteId:
          (database, id) =>
              database.bafKnowledgeRows.filter().rowCodeEqualTo(id).findFirst(),
      decode: BafKnowledgeRow.fromCloudMap,
      ownerUid: (record) => record.updatedByUid,
      remoteDocumentId: (record) => record.rowCode,
    ),
    _ => null,
  };
}

class _LocalRecoveryAdapter {
  final String collectionPath;
  final Future<dynamic> Function(Isar, SyncRejection) find;
  final Future<dynamic> Function(Isar, String) findByRemoteId;
  final Future<void> Function(Isar, dynamic) put;
  final Future<void> Function(Isar, int) delete;
  final dynamic Function(Map<String, dynamic>, String) decode;
  final String? Function(dynamic) ownerUid;
  final String? Function(dynamic) remoteDocumentId;

  const _LocalRecoveryAdapter({
    required this.collectionPath,
    required this.find,
    required this.findByRemoteId,
    required this.put,
    required this.delete,
    required this.decode,
    required this.ownerUid,
    required this.remoteDocumentId,
  });

  static _LocalRecoveryAdapter typed<T>({
    required String collectionPath,
    required IsarCollection<T> Function(Isar) collection,
    required Future<T?> Function(Isar, String) findByRemoteId,
    required T Function(Map<String, dynamic>, String) decode,
    required String? Function(T) ownerUid,
    required String? Function(T) remoteDocumentId,
  }) {
    return _LocalRecoveryAdapter(
      collectionPath: collectionPath,
      find: (database, rejection) async {
        final identifier = rejection.entityId.trim();
        if (identifier.startsWith('local:')) {
          final localId = int.tryParse(identifier.substring('local:'.length));
          return localId == null ? null : collection(database).get(localId);
        }
        final remoteId = _clean(rejection.firestoreId ?? identifier);
        return remoteId == null ? null : findByRemoteId(database, remoteId);
      },
      findByRemoteId:
          (database, remoteId) => findByRemoteId(database, remoteId),
      put: (database, record) async {
        await collection(database).put(record as T);
      },
      delete: (database, localId) async {
        await collection(database).delete(localId);
      },
      decode: (data, documentId) => decode(data, documentId),
      ownerUid: (record) => ownerUid(record as T),
      remoteDocumentId: (record) => remoteDocumentId(record as T),
    );
  }
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

final localSyncRecoveryServiceProvider = Provider<LocalSyncRecoveryService>(
  (ref) => LocalSyncRecoveryService(),
);
