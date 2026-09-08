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

enum _RemoteMirrorApplyOutcome {
  applied,
  unchanged,
  staleRemoteSkipped,
  cleanLocalReconciliationRequired,
  localDirtyPreserved,
  duplicateLocalIdentity,
}

class _RemoteMirrorApplyReceipt {
  const _RemoteMirrorApplyReceipt(this.outcome, {this.duplicateCount = 0});

  final _RemoteMirrorApplyOutcome outcome;
  final int duplicateCount;
}

_RemoteMirrorApplyReceipt _remoteMirrorReceiptFromRecord<T extends Object>(
  RemoteRecordApplyResult<T> result,
) {
  switch (result.outcome) {
    case RemoteRecordApplyOutcome.inserted:
    case RemoteRecordApplyOutcome.updated:
      return const _RemoteMirrorApplyReceipt(_RemoteMirrorApplyOutcome.applied);
    case RemoteRecordApplyOutcome.unchanged:
      return const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.unchanged,
      );
    case RemoteRecordApplyOutcome.staleRemoteSkipped:
      return const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.staleRemoteSkipped,
      );
    case RemoteRecordApplyOutcome.cleanLocalReconciliationRequired:
      return const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.cleanLocalReconciliationRequired,
      );
    case RemoteRecordApplyOutcome.localDirtyPreserved:
      return const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.localDirtyPreserved,
      );
    case RemoteRecordApplyOutcome.duplicateLocalIdentity:
      return _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.duplicateLocalIdentity,
        duplicateCount: result.duplicateCount,
      );
  }
}

_RemoteMirrorApplyReceipt _remoteMirrorReceiptFromTombstone(
  RemoteTombstoneApplyResult result,
) {
  switch (result.outcome) {
    case RemoteTombstoneApplyOutcome.applied:
      return const _RemoteMirrorApplyReceipt(_RemoteMirrorApplyOutcome.applied);
    case RemoteTombstoneApplyOutcome.localDirtyPreserved:
      return const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.localDirtyPreserved,
      );
    case RemoteTombstoneApplyOutcome.localMissing:
    case RemoteTombstoneApplyOutcome.alreadyDeleted:
    case RemoteTombstoneApplyOutcome.notDeletedRemote:
      return const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.unchanged,
      );
  }
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
  final Future<List<dynamic>> Function(Isar, String) matches;
  final Future<List<dynamic>> Function(Isar)? activeRows;
  final Future<void> Function(Isar, dynamic) put;
  final Future<void> Function(Isar, int) delete;
  final dynamic Function(Map<String, dynamic>, String) decode;
  final String? Function(dynamic) documentId;
  final Future<_RemoteMirrorApplyReceipt> Function(dynamic)? applyRemote;

  const _LiveBusinessAdapter({
    required this.matches,
    required this.activeRows,
    required this.put,
    required this.delete,
    required this.decode,
    required this.documentId,
    required this.applyRemote,
  });

  static _LiveBusinessAdapter typed<T extends Object>({
    required IsarCollection<T> Function(Isar) collection,
    required Future<List<T>> Function(Isar, String) matches,
    required T Function(Map<String, dynamic>, String) decode,
    required String? Function(T) documentId,
    Future<List<T>> Function(Isar)? activeRows,
    Future<RemoteRecordApplyResult<T>> Function(T)? applyRecord,
    Future<RemoteTombstoneApplyResult> Function(T)? applyTombstone,
  }) {
    assert((applyRecord == null) == (applyTombstone == null));
    return _LiveBusinessAdapter(
      matches: (database, identifier) => matches(database, identifier),
      activeRows: activeRows == null
          ? null
          : (database) async => await activeRows(database),
      put: (database, record) =>
          collection(database).put(record as T).then<void>((_) {}),
      delete: (database, identifier) =>
          collection(database).delete(identifier).then<void>((_) {}),
      decode: (data, identifier) => decode(data, identifier),
      documentId: (record) => documentId(record as T),
      applyRemote: applyRecord == null
          ? null
          : (record) async {
              final typedRecord = record as T;
              if ((typedRecord as dynamic).isDeleted == true) {
                return _remoteMirrorReceiptFromTombstone(
                  await applyTombstone!(typedRecord),
                );
              }
              return _remoteMirrorReceiptFromRecord(
                await applyRecord(typedRecord),
              );
            },
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

  void _startBusinessListener(_LiveBusinessListenerSpec spec, int generation) {
    final subscription = spec.query
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) => _handleBusinessSnapshot(spec, snapshot, generation),
          onError: (Object error, StackTrace stackTrace) {
            if (!_acceptsLiveWork(generation)) return;
            _recordBusinessError(
              kind: spec.kind,
              documentId: '*',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
    _maintenanceSubs.add(subscription);
  }

  void _handleBusinessSnapshot(
    _LiveBusinessListenerSpec spec,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int generation,
  ) {
    if (!_acceptsLiveWork(generation)) return;
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
          unawaited(
            _applyBusinessDocument(
              spec.kind,
              change.doc,
              generation: generation,
            ),
          );
          break;
        case DocumentChangeType.removed:
          _setHealth(
            _health.copyWith(removedEventCount: _health.removedEventCount + 1),
          );
          unawaited(
            _applyRemovedBusinessDocument(
              spec.kind,
              change.doc.reference,
              generation: generation,
            ),
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
          generation,
        ),
      );
    }
  }

  Future<void> _reconcileInitiallyActiveBusiness(
    _LiveBusinessListenerSpec spec,
    Set<String> activeRemoteIds,
    int generation,
  ) async {
    if (!_acceptsLiveWork(generation)) return;
    try {
      final adapter = _businessAdapter(spec.kind);
      final activeRows = adapter.activeRows;
      if (activeRows == null) {
        _businessReconciliationFailures.remove(spec.kind);
        _businessReconciliationRetries.remove(spec.kind)?.cancel();
        return;
      }
      final records = await activeRows(_isar);
      if (!_acceptsLiveWork(generation)) return;
      for (final record in records) {
        if (!_acceptsLiveWork(generation)) return;
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
          generation: generation,
          propagateFailure: true,
        );
      }
      if (!_acceptsLiveWork(generation)) return;
      _businessReconciliationFailures.remove(spec.kind);
      _businessReconciliationRetries.remove(spec.kind)?.cancel();
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      _reconciledBusinessKinds.remove(spec.kind);
      _recordBusinessError(
        kind: spec.kind,
        documentId: '*',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleBusinessReconciliationRetry(spec, activeRemoteIds, generation);
    }
  }

  void _scheduleBusinessReconciliationRetry(
    _LiveBusinessListenerSpec spec,
    Set<String> activeRemoteIds,
    int generation,
  ) {
    if (!_acceptsLiveWork(generation)) {
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
      if (!_acceptsLiveWork(generation) ||
          !_reconciledBusinessKinds.add(spec.kind)) {
        return;
      }
      unawaited(
        _reconcileInitiallyActiveBusiness(spec, expectedRemoteIds, generation),
      );
    });
  }

  Future<void> _applyRemovedBusinessDocument(
    _LiveBusinessMirrorKind kind,
    DocumentReference<Map<String, dynamic>> reference, {
    required int generation,
    bool propagateFailure = false,
  }) async {
    if (!_acceptsLiveWork(generation)) return;
    try {
      final remote = await reference.get(
        const GetOptions(source: Source.server),
      );
      if (!_acceptsLiveWork(generation)) return;
      if (remote.exists) {
        await _applyBusinessDocument(
          kind,
          remote,
          generation: generation,
          propagateFailure: propagateFailure,
        );
        return;
      }

      final adapter = _businessAdapter(kind);
      await _isar.writeTxn(() async {
        if (!_acceptsLiveWork(generation)) return;
        final locals = await adapter.matches(_isar, reference.id);
        for (final local in locals) {
          if (local.isSynced == true) {
            await adapter.delete(_isar, local.id as int);
          }
        }
      });
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
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
    required int generation,
    bool propagateFailure = false,
  }) async {
    if (!_acceptsLiveWork(generation)) return;
    final data = snapshot.data();
    if (data == null || snapshot.metadata.hasPendingWrites) return;

    try {
      final adapter = _businessAdapter(kind);
      final remote = adapter.decode(data, snapshot.id);
      final receipt = adapter.applyRemote == null
          ? await _applyKnowledgeDocument(
              adapter,
              remote,
              snapshot.id,
              generation,
            )
          : await adapter.applyRemote!(remote);

      if (!_acceptsLiveWork(generation)) return;
      if (_trackCleanLocalReconciliation(
        '${kind.name}/${snapshot.id}',
        receipt,
        remoteVersion: remote.version as int,
        propagateFailure: propagateFailure,
      )) {
        return;
      }
      if (receipt.outcome == _RemoteMirrorApplyOutcome.duplicateLocalIdentity) {
        throw StateError(
          'Live ${kind.name} mirror found ${receipt.duplicateCount} local rows '
          'for remote identity ${snapshot.id}.',
        );
      }
      if (receipt.outcome == _RemoteMirrorApplyOutcome.applied) {
        _setHealth(
          _health.copyWith(
            maintenanceState: LiveRemoteSyncConnectionState.listening,
            lastAppliedAt: DateTime.now(),
            appliedCount: _health.appliedCount + 1,
            clearLastError: true,
          ),
        );
      } else if (receipt.outcome ==
          _RemoteMirrorApplyOutcome.localDirtyPreserved) {
        _setHealth(
          _health.copyWith(
            skippedUnsyncedLocalCount: _health.skippedUnsyncedLocalCount + 1,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      if (propagateFailure) rethrow;
      _recordBusinessError(
        kind: kind,
        documentId: snapshot.id,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<_RemoteMirrorApplyReceipt> _applyKnowledgeDocument(
    _LiveBusinessAdapter adapter,
    dynamic remote,
    String documentId,
    int generation,
  ) async {
    var receipt = const _RemoteMirrorApplyReceipt(
      _RemoteMirrorApplyOutcome.unchanged,
    );
    await _isar.writeTxn(() async {
      if (!_acceptsLiveWork(generation)) return;
      final locals = await adapter.matches(_isar, documentId);
      if (locals.length > 1) {
        receipt = _RemoteMirrorApplyReceipt(
          _RemoteMirrorApplyOutcome.duplicateLocalIdentity,
          duplicateCount: locals.length,
        );
        return;
      }
      if (locals.isEmpty) {
        if (remote.isDeleted == true) return;
        remote.isSynced = true;
        await adapter.put(_isar, remote);
        receipt = const _RemoteMirrorApplyReceipt(
          _RemoteMirrorApplyOutcome.applied,
        );
        return;
      }

      final local = locals.single;
      if (local.isSynced != true) {
        receipt = const _RemoteMirrorApplyReceipt(
          _RemoteMirrorApplyOutcome.localDirtyPreserved,
        );
        return;
      }
      if (!_isRemoteNewerByPolicy(local, remote)) return;

      remote.id = local.id;
      remote.isSynced = true;
      await adapter.put(_isar, remote);
      receipt = const _RemoteMirrorApplyReceipt(
        _RemoteMirrorApplyOutcome.applied,
      );
    });
    return receipt;
  }

  _LiveBusinessAdapter _businessAdapter(_LiveBusinessMirrorKind kind) {
    switch (kind) {
      case _LiveBusinessMirrorKind.directive:
        return _LiveBusinessAdapter.typed<OperationalDirective>(
          collection: (database) => database.operationalDirectives,
          matches: (database, identifier) => database.operationalDirectives
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          activeRows: (database) => database.operationalDirectives
              .filter()
              .isActiveEqualTo(true)
              .and()
              .isDeletedEqualTo(false)
              .findAll(),
          decode: (data, identifier) =>
              readRemoteOperationalDirective(data, documentId: identifier),
          documentId: (record) => record.firestoreId,
          applyRecord: _directiveRepository.applyDirectiveFromRemote,
          applyTombstone:
              _directiveRepository.applyTombstoneFromDirectiveRemote,
        );
      case _LiveBusinessMirrorKind.jobExecution:
        return _LiveBusinessAdapter.typed<JobExecution>(
          collection: (database) => database.jobExecutions,
          matches: (database, identifier) => database.jobExecutions
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          activeRows: (database) => database.jobExecutions
              .filter()
              .isCompletedEqualTo(false)
              .and()
              .isCancelledEqualTo(false)
              .and()
              .isDeletedEqualTo(false)
              .findAll(),
          decode: JobExecution.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _plannedRepository.applyExecutionFromRemote,
          applyTombstone: _plannedRepository.applyTombstoneFromExecutionRemote,
        );
      case _LiveBusinessMirrorKind.jobModule:
        return _LiveBusinessAdapter.typed<JobModuleInstance>(
          collection: (database) => database.jobModuleInstances,
          matches: (database, identifier) => database.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
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
          applyRecord: _jobModuleRepository.applyModuleFromRemote,
          applyTombstone: _jobModuleRepository.applyTombstoneFromRemote,
        );
      case _LiveBusinessMirrorKind.jobDiary:
        return _LiveBusinessAdapter.typed<JobDiaryEntry>(
          collection: (database) => database.jobDiaryEntrys,
          matches: (database, identifier) => database.jobDiaryEntrys
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          decode: JobDiaryEntry.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _jobDiaryRepository.applyEntryFromRemote,
          applyTombstone: _jobDiaryRepository.applyTombstoneFromRemote,
        );
      case _LiveBusinessMirrorKind.abnormalityType:
        return _LiveBusinessAdapter.typed<AbnormalityType>(
          collection: (database) => database.abnormalityTypes,
          matches: (database, identifier) => database.abnormalityTypes
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          activeRows: (database) => database.abnormalityTypes
              .filter()
              .isActiveEqualTo(true)
              .and()
              .isDeletedEqualTo(false)
              .findAll(),
          decode: AbnormalityType.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _abnormalityRepository.applyTypeFromRemote,
          applyTombstone: _abnormalityRepository.applyTombstoneFromTypeRemote,
        );
      case _LiveBusinessMirrorKind.chargeAbnormality:
        return _LiveBusinessAdapter.typed<ChargeAbnormality>(
          collection: (database) => database.chargeAbnormalitys,
          matches: (database, identifier) => database.chargeAbnormalitys
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          decode: ChargeAbnormality.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _abnormalityRepository.applyAbnormalityFromRemote,
          applyTombstone:
              _abnormalityRepository.applyTombstoneFromAbnormalityRemote,
        );
      case _LiveBusinessMirrorKind.jobTemplate:
        return _LiveBusinessAdapter.typed<JobTemplate>(
          collection: (database) => database.jobTemplates,
          matches: (database, identifier) => database.jobTemplates
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          activeRows: (database) => database.jobTemplates
              .filter()
              .isActiveEqualTo(true)
              .and()
              .isDeletedEqualTo(false)
              .findAll(),
          decode: JobTemplate.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _plannedRepository.applyTemplateFromRemote,
          applyTombstone: _plannedRepository.applyTombstoneFromTemplateRemote,
        );
      case _LiveBusinessMirrorKind.templatePackage:
        return _LiveBusinessAdapter.typed<TemplatePackage>(
          collection: (database) => database.templatePackages,
          matches: (database, identifier) => database.templatePackages
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          activeRows: (database) => database.templatePackages
              .filter()
              .isDeletedEqualTo(false)
              .findAll(),
          decode: TemplatePackage.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _templateGovernanceRepository.applyPackageFromRemote,
          applyTombstone:
              _templateGovernanceRepository.applyTombstoneFromPackageRemote,
        );
      case _LiveBusinessMirrorKind.templateVersion:
        return _LiveBusinessAdapter.typed<TemplateVersion>(
          collection: (database) => database.templateVersions,
          matches: (database, identifier) => database.templateVersions
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          decode: TemplateVersion.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _templateGovernanceRepository.applyVersionFromRemote,
          applyTombstone:
              _templateGovernanceRepository.applyTombstoneFromVersionRemote,
        );
      case _LiveBusinessMirrorKind.templatePublishAudit:
        return _LiveBusinessAdapter.typed<TemplatePublishAudit>(
          collection: (database) => database.templatePublishAudits,
          matches: (database, identifier) => database.templatePublishAudits
              .filter()
              .firestoreIdEqualTo(identifier)
              .findAll(),
          decode: TemplatePublishAudit.fromMap,
          documentId: (record) => record.firestoreId,
          applyRecord: _templateGovernanceRepository.applyAuditFromRemote,
          applyTombstone:
              _templateGovernanceRepository.applyTombstoneFromAuditRemote,
        );
      case _LiveBusinessMirrorKind.knowledgeRow:
        return _LiveBusinessAdapter.typed<BafKnowledgeRow>(
          collection: (database) => database.bafKnowledgeRows,
          matches: (database, identifier) => database.bafKnowledgeRows
              .filter()
              .rowCodeEqualTo(identifier)
              .findAll(),
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
