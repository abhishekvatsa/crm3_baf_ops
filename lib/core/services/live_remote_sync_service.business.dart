part of 'live_remote_sync_service.dart';

enum _LiveBusinessMirrorKind {
  directive,
  jobExecution,
  jobModule,
  jobDiary,
  abnormalityType,
  chargeAbnormality,
  jobTemplate,
  templatePackage,
  templateVersion,
  templatePublishAudit,
  knowledgeRow,
}

class _LiveBusinessListenerSpec {
  final _LiveBusinessMirrorKind kind;
  final String collectionPath;
  final Query<Map<String, dynamic>> query;
  final bool reconcileActive;

  const _LiveBusinessListenerSpec({
    required this.kind,
    required this.collectionPath,
    required this.query,
    this.reconcileActive = false,
  });

  String get label => 'business_${kind.name}';
}

class _LiveBusinessAdapter {
  final Future<dynamic> Function(Isar, String) find;
  final Future<List<dynamic>> Function(Isar)? activeRows;
  final Future<void> Function(Isar, dynamic) put;
  final Future<void> Function(Isar, int) delete;
  final dynamic Function(Map<String, dynamic>, String) decode;
  final String? Function(dynamic) documentId;

  const _LiveBusinessAdapter({
    required this.find,
    required this.activeRows,
    required this.put,
    required this.delete,
    required this.decode,
    required this.documentId,
  });

  static _LiveBusinessAdapter typed<T>({
    required IsarCollection<T> Function(Isar) collection,
    required Future<T?> Function(Isar, String) find,
    required T Function(Map<String, dynamic>, String) decode,
    required String? Function(T) documentId,
    Future<List<T>> Function(Isar)? activeRows,
  }) {
    return _LiveBusinessAdapter(
      find: (database, identifier) => find(database, identifier),
      activeRows:
          activeRows == null
              ? null
              : (database) async => await activeRows(database),
      put:
          (database, record) =>
              collection(database).put(record as T).then<void>((_) {}),
      delete:
          (database, identifier) =>
              collection(database).delete(identifier).then<void>((_) {}),
      decode: (data, identifier) => decode(data, identifier),
      documentId: (record) => documentId(record as T),
    );
  }
}

extension _LiveBusinessMirror on LiveRemoteSyncService {
  List<_LiveBusinessListenerSpec> _businessListenerSpecs() {
    final firestore = FirebaseFirestore.instance;
    return <_LiveBusinessListenerSpec>[
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.directive,
        collectionPath: 'directives',
        query: firestore
            .collection('directives')
            .where('status', whereIn: const ['open', 'acknowledged']),
        reconcileActive: true,
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.jobExecution,
        collectionPath: 'job_executions',
        query: firestore
            .collection('job_executions')
            .where('isCompleted', isEqualTo: false),
        reconcileActive: true,
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.jobModule,
        collectionPath: 'job_modules',
        query: firestore
            .collection('job_modules')
            .where(
              'status',
              whereIn: const [
                'notStarted',
                'inProgress',
                'draftSaved',
                'submitted',
                'reopened',
              ],
            ),
        reconcileActive: true,
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.jobDiary,
        collectionPath: 'job_diary_entries',
        query: firestore
            .collection('job_diary_entries')
            .orderBy('updatedAt', descending: true)
            .limit(100),
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.abnormalityType,
        collectionPath: 'abnormality_types',
        query: firestore
            .collection('abnormality_types')
            .where('isActive', isEqualTo: true),
        reconcileActive: true,
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.chargeAbnormality,
        collectionPath: 'charge_abnormalities',
        query: firestore
            .collection('charge_abnormalities')
            .orderBy('updatedAt', descending: true)
            .limit(100),
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.jobTemplate,
        collectionPath: 'job_templates',
        query: firestore
            .collection('job_templates')
            .where('isActive', isEqualTo: true),
        reconcileActive: true,
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.templatePackage,
        collectionPath: 'template_packages',
        query: firestore
            .collection('template_packages')
            .where('isDeleted', isEqualTo: false),
        reconcileActive: true,
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.templateVersion,
        collectionPath: 'template_versions',
        query: firestore
            .collection('template_versions')
            .orderBy('updatedAt', descending: true)
            .limit(100),
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.templatePublishAudit,
        collectionPath: 'template_publish_audits',
        query: firestore
            .collection('template_publish_audits')
            .orderBy('updatedAt', descending: true)
            .limit(100),
      ),
      _LiveBusinessListenerSpec(
        kind: _LiveBusinessMirrorKind.knowledgeRow,
        collectionPath: 'knowledge_base',
        query: firestore
            .collection('knowledge_base')
            .orderBy('updatedAt', descending: true)
            .limit(50),
      ),
    ];
  }

  void _startBusinessListener(_LiveBusinessListenerSpec spec) {
    final subscription = spec.query
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) => _handleBusinessSnapshot(spec, snapshot),
          onError:
              (Object error, StackTrace stackTrace) => _recordBusinessError(
                kind: spec.kind,
                documentId: '*',
                error: error,
                stackTrace: stackTrace,
              ),
        );
    _maintenanceSubs.add(subscription);
  }

  void _handleBusinessSnapshot(
    _LiveBusinessListenerSpec spec,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.listening,
        lastEventAt: DateTime.now(),
        clearLastError: true,
      ),
    );

    for (final change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          unawaited(_applyBusinessDocument(spec.kind, change.doc));
          break;
        case DocumentChangeType.removed:
          _setHealth(
            _health.copyWith(removedEventCount: _health.removedEventCount + 1),
          );
          unawaited(
            _applyRemovedBusinessDocument(spec.kind, change.doc.reference),
          );
          break;
      }
    }

    if (spec.reconcileActive &&
        !snapshot.metadata.isFromCache &&
        !snapshot.metadata.hasPendingWrites &&
        _reconciledBusinessKinds.add(spec.kind)) {
      unawaited(
        _reconcileInitiallyActiveBusiness(
          spec,
          snapshot.docs.map((document) => document.id).toSet(),
        ),
      );
    }
  }

  Future<void> _reconcileInitiallyActiveBusiness(
    _LiveBusinessListenerSpec spec,
    Set<String> activeRemoteIds,
  ) async {
    try {
      final adapter = _businessAdapter(spec.kind);
      final activeRows = adapter.activeRows;
      if (activeRows == null) {
        _businessReconciliationFailures.remove(spec.kind);
        _businessReconciliationRetries.remove(spec.kind)?.cancel();
        return;
      }
      for (final record in await activeRows(_isar)) {
        final identifier = adapter.documentId(record)?.trim();
        if (record.isSynced != true ||
            identifier == null ||
            identifier.isEmpty ||
            activeRemoteIds.contains(identifier)) {
          continue;
        }
        await _applyRemovedBusinessDocument(
          spec.kind,
          FirebaseFirestore.instance
              .collection(spec.collectionPath)
              .doc(identifier),
          propagateFailure: true,
        );
      }
      _businessReconciliationFailures.remove(spec.kind);
      _businessReconciliationRetries.remove(spec.kind)?.cancel();
    } catch (error, stackTrace) {
      _reconciledBusinessKinds.remove(spec.kind);
      _recordBusinessError(
        kind: spec.kind,
        documentId: '*',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleBusinessReconciliationRetry(spec, activeRemoteIds);
    }
  }

  void _scheduleBusinessReconciliationRetry(
    _LiveBusinessListenerSpec spec,
    Set<String> activeRemoteIds,
  ) {
    if (!_maintenanceStarted || _pausedForLifecycle) {
      return;
    }

    final failures = (_businessReconciliationFailures[spec.kind] ?? 0) + 1;
    _businessReconciliationFailures[spec.kind] = failures;
    final delay = liveWorkflowProjectionReconciliationRetryDelay(failures);
    if (delay == null) {
      return;
    }

    final expectedRemoteIds = Set<String>.unmodifiable(activeRemoteIds);
    _businessReconciliationRetries.remove(spec.kind)?.cancel();
    _businessReconciliationRetries[spec.kind] = Timer(delay, () {
      _businessReconciliationRetries.remove(spec.kind);
      if (!_maintenanceStarted ||
          _pausedForLifecycle ||
          !_reconciledBusinessKinds.add(spec.kind)) {
        return;
      }
      unawaited(_reconcileInitiallyActiveBusiness(spec, expectedRemoteIds));
    });
  }

  Future<void> _applyRemovedBusinessDocument(
    _LiveBusinessMirrorKind kind,
    DocumentReference<Map<String, dynamic>> reference, {
    bool propagateFailure = false,
  }) async {
    try {
      final remote = await reference.get(
        const GetOptions(source: Source.server),
      );
      if (remote.exists) {
        await _applyBusinessDocument(
          kind,
          remote,
          propagateFailure: propagateFailure,
        );
        return;
      }

      final adapter = _businessAdapter(kind);
      await _isar.writeTxn(() async {
        final local = await adapter.find(_isar, reference.id);
        if (local != null && local.isSynced == true) {
          await adapter.delete(_isar, local.id as int);
        }
      });
    } catch (error, stackTrace) {
      if (propagateFailure) rethrow;
      _recordBusinessError(
        kind: kind,
        documentId: reference.id,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _applyBusinessDocument(
    _LiveBusinessMirrorKind kind,
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool propagateFailure = false,
  }) async {
    final data = snapshot.data();
    if (data == null || snapshot.metadata.hasPendingWrites) return;

    try {
      final adapter = _businessAdapter(kind);
      final remote = adapter.decode(data, snapshot.id);
      var applied = false;
      var protectedUnsynced = false;
      await _isar.writeTxn(() async {
        final local = await adapter.find(_isar, snapshot.id);
        if (local == null) {
          if (remote.isDeleted == true) return;
          remote.isSynced = true;
          await adapter.put(_isar, remote);
          applied = true;
          return;
        }
        if (local.isSynced != true) {
          protectedUnsynced = true;
          return;
        }
        if (!_isRemoteNewerByPolicy(local, remote)) return;

        remote.id = local.id;
        remote.isSynced = true;
        await adapter.put(_isar, remote);
        applied = true;
      });

      if (applied) {
        _setHealth(
          _health.copyWith(
            maintenanceState: LiveRemoteSyncConnectionState.listening,
            lastAppliedAt: DateTime.now(),
            appliedCount: _health.appliedCount + 1,
            clearLastError: true,
          ),
        );
      } else if (protectedUnsynced) {
        _setHealth(
          _health.copyWith(
            skippedUnsyncedLocalCount: _health.skippedUnsyncedLocalCount + 1,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (propagateFailure) rethrow;
      _recordBusinessError(
        kind: kind,
        documentId: snapshot.id,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  _LiveBusinessAdapter _businessAdapter(_LiveBusinessMirrorKind kind) {
    switch (kind) {
      case _LiveBusinessMirrorKind.directive:
        return _LiveBusinessAdapter.typed<OperationalDirective>(
          collection: (database) => database.operationalDirectives,
          find:
              (database, identifier) =>
                  database.operationalDirectives
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          activeRows:
              (database) =>
                  database.operationalDirectives
                      .filter()
                      .isActiveEqualTo(true)
                      .and()
                      .isDeletedEqualTo(false)
                      .findAll(),
          decode:
              (data, identifier) =>
                  readRemoteOperationalDirective(data, documentId: identifier),
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.jobExecution:
        return _LiveBusinessAdapter.typed<JobExecution>(
          collection: (database) => database.jobExecutions,
          find:
              (database, identifier) =>
                  database.jobExecutions
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          activeRows:
              (database) =>
                  database.jobExecutions
                      .filter()
                      .isCompletedEqualTo(false)
                      .and()
                      .isCancelledEqualTo(false)
                      .and()
                      .isDeletedEqualTo(false)
                      .findAll(),
          decode: JobExecution.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.jobModule:
        return _LiveBusinessAdapter.typed<JobModuleInstance>(
          collection: (database) => database.jobModuleInstances,
          find:
              (database, identifier) =>
                  database.jobModuleInstances
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          activeRows: (database) async {
            final records = await database.jobModuleInstances.where().findAll();
            return records
                .where(
                  (record) =>
                      !record.isDeleted &&
                      record.status != JobModuleStatus.accepted &&
                      record.status != JobModuleStatus.notApplicable,
                )
                .toList(growable: false);
          },
          decode: JobModuleInstance.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.jobDiary:
        return _LiveBusinessAdapter.typed<JobDiaryEntry>(
          collection: (database) => database.jobDiaryEntrys,
          find:
              (database, identifier) =>
                  database.jobDiaryEntrys
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          decode: JobDiaryEntry.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.abnormalityType:
        return _LiveBusinessAdapter.typed<AbnormalityType>(
          collection: (database) => database.abnormalityTypes,
          find:
              (database, identifier) =>
                  database.abnormalityTypes
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          activeRows:
              (database) =>
                  database.abnormalityTypes
                      .filter()
                      .isActiveEqualTo(true)
                      .and()
                      .isDeletedEqualTo(false)
                      .findAll(),
          decode: AbnormalityType.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.chargeAbnormality:
        return _LiveBusinessAdapter.typed<ChargeAbnormality>(
          collection: (database) => database.chargeAbnormalitys,
          find:
              (database, identifier) =>
                  database.chargeAbnormalitys
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          decode: ChargeAbnormality.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.jobTemplate:
        return _LiveBusinessAdapter.typed<JobTemplate>(
          collection: (database) => database.jobTemplates,
          find:
              (database, identifier) =>
                  database.jobTemplates
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          activeRows:
              (database) =>
                  database.jobTemplates
                      .filter()
                      .isActiveEqualTo(true)
                      .and()
                      .isDeletedEqualTo(false)
                      .findAll(),
          decode: JobTemplate.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.templatePackage:
        return _LiveBusinessAdapter.typed<TemplatePackage>(
          collection: (database) => database.templatePackages,
          find:
              (database, identifier) =>
                  database.templatePackages
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          activeRows:
              (database) =>
                  database.templatePackages
                      .filter()
                      .isDeletedEqualTo(false)
                      .findAll(),
          decode: TemplatePackage.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.templateVersion:
        return _LiveBusinessAdapter.typed<TemplateVersion>(
          collection: (database) => database.templateVersions,
          find:
              (database, identifier) =>
                  database.templateVersions
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          decode: TemplateVersion.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.templatePublishAudit:
        return _LiveBusinessAdapter.typed<TemplatePublishAudit>(
          collection: (database) => database.templatePublishAudits,
          find:
              (database, identifier) =>
                  database.templatePublishAudits
                      .filter()
                      .firestoreIdEqualTo(identifier)
                      .findFirst(),
          decode: TemplatePublishAudit.fromMap,
          documentId: (record) => record.firestoreId,
        );
      case _LiveBusinessMirrorKind.knowledgeRow:
        return _LiveBusinessAdapter.typed<BafKnowledgeRow>(
          collection: (database) => database.bafKnowledgeRows,
          find:
              (database, identifier) =>
                  database.bafKnowledgeRows
                      .filter()
                      .rowCodeEqualTo(identifier)
                      .findFirst(),
          decode: BafKnowledgeRow.fromCloudMap,
          documentId: (record) => record.rowCode,
        );
    }
  }

  void _recordBusinessError({
    required _LiveBusinessMirrorKind kind,
    required String documentId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.warning(
      'Failed to apply live operational record',
      error: error,
      stackTrace: stackTrace,
      context: {
        'app_area': 'live_remote_sync',
        'entity_type': kind.name,
        'document_id': documentId,
      },
    );
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.error,
        lastError: '$error',
      ),
    );
  }
}
