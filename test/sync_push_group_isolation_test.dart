import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_push_snapshot.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an early batch failure preserves order and attempts independent pushes',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('unreadable ticket batch');
      await rig.service.syncAll();
      expect(rig.visits, _allStages);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastFailureDetails.single.entityType, 'maintenance');
      expect(
        rig.service.lastFailureDetails.single.message,
        contains('unreadable ticket batch'),
      );
      expect(
        rig.service.lastSuccessCount,
        1,
        reason: 'audit is still attempted',
      );
    },
  );

  for (final failed in ['templates', 'versions', 'packages']) {
    test('$failed failure holds dependent publication work only', () async {
      final rig = _Rig()..failures[failed] = StateError('batch unavailable');
      await rig.service.syncAll();
      final failedIndex = _allStages.indexOf(failed);
      expect(rig.visits, [
        ..._allStages.take(failedIndex + 1),
        ..._allStages.skip(_allStages.indexOf('knowledge')),
      ]);
      expect(rig.service.lastFailureCount, 1);
    });
  }

  for (final failed in ['executions', 'diary', 'modules']) {
    test('$failed batch failure never submits dependent job closure', () async {
      final rig = _Rig()..failures[failed] = StateError('batch unavailable');
      await rig.service.syncAll();
      final failedIndex = _allStages.indexOf(failed);
      expect(rig.visits, [
        ..._allStages.take(failedIndex + 1),
        ..._allStages.skip(_allStages.indexOf('directives')),
      ]);
      expect(rig.service.lastFailureCount, 1);
    });
  }

  test('a caught per-record module failure also prevents closure', () async {
    final rig = _Rig()..badModule = true;
    await rig.service.syncAll();
    expect(rig.visits, _allStages.where((stage) => stage != 'closures'));
    expect(rig.service.lastFailureCount, 1);
    expect(rig.service.lastFailureDetails.single.entityType, 'job_module');
  });

  test(
    'a caught per-record type failure holds dependent events but runs audit',
    () async {
      final rig = _Rig()..badType = true;
      await rig.service.syncAll();
      expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastSuccessCount, 1);
    },
  );

  test(
    'unrelated failures aggregate without hiding successful independent work',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('tickets failed')
        ..failures['directives'] = StateError('directives failed')
        ..failures['types'] = StateError('types failed');
      await rig.service.syncAll();
      expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
      expect(rig.service.lastFailureCount, 3);
      expect(rig.service.lastFailureDetails, hasLength(3));
      expect(rig.service.lastSuccessCount, 1);
    },
  );

  test(
    'an isolated audit failure leaves prior successful pushes counted',
    () async {
      final rig = _Rig()..failures['audit'] = StateError('audit failed');
      await rig.service.syncAll();
      expect(rig.visits, _allStages);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastFailureDetails.single.entityType, 'audit_event');
    },
  );

  for (final error in <Object>[
    const SyncRunAborted('account changed'),
    IsarError('local database is closed'),
    FirebaseAuthException(code: 'unauthenticated'),
  ]) {
    test(
      'fatal ${error.runtimeType} inside a caught domain stops the run',
      () async {
        final rig = _Rig()..failures['knowledge'] = error;
        await expectLater(
          rig.service.syncAll(),
          throwsA(anyOf(isA<SyncRunAborted>(), isA<IsarError>())),
        );
        expect(
          rig.visits,
          _allStages.take(_allStages.indexOf('knowledge') + 1),
        );
        expect(rig.service.lastFailureDetails, isEmpty);
        rig.failures.clear();
        rig.visits.clear();
        await rig.service.syncAll();
        expect(
          rig.visits,
          _allStages,
          reason: 'fatal cleanup must release the run lock',
        );
      },
    );
  }

  test(
    'account switch after an awaited read stops before the next domain',
    () async {
      final rig = _Rig();
      rig.onVisit = (stage) {
        if (stage == 'tickets') rig.auth.actor = null;
      };
      await expectLater(rig.service.syncAll(), throwsA(isA<SyncRunAborted>()));
      expect(rig.visits, ['tickets']);
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  test(
    'session guard invalidation in row read prevents remote write and audit',
    () async {
      final rig = _Rig()..badType = true;
      var current = true;
      final guard = SyncRunGuard(() {
        if (!current) throw const SyncRunAborted('authority changed');
      });
      rig.onVisit = (stage) {
        if (stage == 'types') current = false;
      };
      await expectLater(
        rig.service.syncAll(runGuard: guard),
        throwsA(isA<SyncRunAborted>()),
      );
      expect(rig.visits, _allStages.take(_allStages.indexOf('types') + 1));
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  test(
    'later independent type rows are actually written and acknowledged',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('ticket batch unreadable')
        ..pushType = true;
      await rig.service.syncAll();
      expect(rig.typeWriteCalls, 1);
      expect(rig.typesMarked, 1);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastSuccessCount, 2);
    },
  );

  test('a remote lookup failure holds events and continues audit', () async {
    final rig = _Rig()
      ..pushType = true
      ..typeReadError = StateError('remote type batch unavailable');
    await rig.service.syncAll();
    expect(rig.typeWriteCalls, 0);
    expect(rig.typesMarked, 0);
    expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
    expect(rig.service.lastFailureCount, 1);
  });

  test(
    'unauthenticated row write stops retries, acknowledgement and later domains',
    () async {
      final rig = _Rig()
        ..pushType = true
        ..typeWriteError = FirebaseAuthException(code: 'unauthenticated');
      await expectLater(rig.service.syncAll(), throwsA(isA<SyncRunAborted>()));
      expect(rig.typeWriteCalls, 1);
      expect(rig.typesMarked, 0);
      expect(rig.visits, _allStages.take(_allStages.indexOf('types') + 1));
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  testWidgets('an account change during retry delay prevents a second write', (
    tester,
  ) async {
    final rig = _Rig()
      ..pushType = true
      ..typeWriteError = StateError('temporary write failure');
    final completion = expectLater(
      rig.service.syncAll(),
      throwsA(isA<SyncRunAborted>()),
    );
    await tester.pump();
    expect(rig.typeWriteCalls, 1);
    rig.auth.actor = null;
    await tester.pump(const Duration(seconds: 3));
    await completion;
    expect(rig.typeWriteCalls, 1);
    expect(rig.typesMarked, 0);
    expect(rig.visits, isNot(contains('audit')));
  });

  test(
    'a row failure in version publication prevents package pointer and audit',
    () async {
      final rig = _Rig()..badVersion = true;
      await rig.service.syncAll();
      expect(
        rig.visits,
        _allStages.where(
          (stage) => !['packages', 'publishAudits'].contains(stage),
        ),
      );
      expect(rig.service.lastFailureCount, 1);
      expect(
        rig.service.lastFailureDetails.single.entityType,
        'template_version',
      );
    },
  );

  test(
    'a preserved prerequisite conflict also holds dependent event pushes',
    () async {
      final rig = _Rig()
        ..pushType = true
        ..newerRemoteType = true;
      await rig.service.syncAll();
      expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
      expect(rig.typeWriteCalls, 0);
      expect(rig.typesMarked, 0);
      expect(rig.service.lastConflictCount, 1);
    },
  );
}

const _allStages = [
  'tickets',
  'templates',
  'versions',
  'packages',
  'publishAudits',
  'knowledge',
  'executions',
  'diary',
  'modules',
  'closures',
  'directives',
  'types',
  'abnormalities',
  'audit',
];

class _Rig {
  final visits = <String>[];
  final failures = <String, Object>{};
  void Function(String)? onVisit;
  bool badModule = false;
  bool badType = false;
  bool badVersion = false;
  bool newerRemoteType = false;
  bool pushType = false;
  Object? typeReadError;
  Object? typeWriteError;
  int typeWriteCalls = 0;
  int typesMarked = 0;
  late final auth = _Auth();
  late final service = SyncService(
    maintenanceRepo: _Maintenance(this),
    firestoreMaintenance: _Maintenance(this),
    plannedRepo: _Planned(this),
    firestorePlanned: _Planned(this),
    serverCompletion: _Completion(),
    jobDiaryRepo: _Diary(this),
    firestoreJobDiary: _Diary(this),
    jobModuleRepo: _Modules(this),
    firestoreJobModule: _Modules(this),
    templateGovernanceRepo: _Governance(this),
    firestoreTemplateGovernance: _Governance(this),
    directiveRepo: _Directives(this),
    firestoreDirective: _Directives(this),
    abnormalityRepo: _Abnormalities(this),
    firestoreAbnormality: _Abnormalities(this),
    knowledgeRepo: _Knowledge(this),
    auditRepository: _Audit(this),
    auth: auth,
    rejectionOwnerUidLookup: () => auth.currentUser?.uid,
  );

  void visit(String stage) {
    visits.add(stage);
    onVisit?.call(stage);
    final error = failures[stage];
    if (error != null) throw error;
  }
}

class _Maintenance extends MaintenanceRepository {
  _Maintenance(this.rig);
  final _Rig rig;
  @override
  Future<List<MaintenanceRecord>> getUnsyncedTickets() async {
    rig.visit('tickets');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Planned extends PlannedMaintenanceRepository {
  _Planned(this.rig);
  final _Rig rig;
  @override
  Future<List<JobTemplate>> getUnsyncedTemplates() async {
    rig.visit('templates');
    return [];
  }

  @override
  Future<List<JobExecution>> getUnsyncedExecutions() async {
    rig.visit(rig.visits.contains('executions') ? 'closures' : 'executions');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Governance extends TemplateGovernanceRepository {
  _Governance(this.rig);
  final _Rig rig;
  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async {
    rig.visit('versions');
    return rig.badVersion
        ? [
            TemplateVersion()
              ..id = 5
              ..updatedAt = DateTime.utc(2026, 9, 27),
          ]
        : [];
  }

  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async => [];

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async {
    rig.visit('packages');
    return [];
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async {
    rig.visit('publishAudits');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Diary extends JobDiaryRepository {
  _Diary(this.rig);
  final _Rig rig;
  @override
  Future<List<JobDiaryEntry>> getUnsyncedEntries() async {
    rig.visit('diary');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Modules extends JobModuleRepository {
  _Modules(this.rig);
  final _Rig rig;
  @override
  Future<List<JobModuleInstance>> getUnsyncedModules() async {
    rig.visit('modules');
    return rig.badModule
        ? [
            JobModuleInstance()
              ..id = 9
              ..updatedAt = DateTime.utc(2026, 9, 27),
          ]
        : [];
  }

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Directives extends DirectiveRepository {
  _Directives(this.rig);
  final _Rig rig;
  @override
  Future<List<OperationalDirective>> getUnsyncedDirectives() async {
    rig.visit('directives');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Abnormalities extends AbnormalityRepository {
  _Abnormalities(this.rig);
  final _Rig rig;
  @override
  Future<List<AbnormalityType>> getUnsyncedTypes() async {
    rig.visit('types');
    return rig.badType || rig.pushType
        ? [
            AbnormalityType()
              ..id = 7
              ..firestoreId = rig.pushType ? 'type-7' : null
              ..code = 'TYPE7'
              ..title = 'Test type'
              ..createdAt = DateTime.utc(2026, 9, 27)
              ..updatedAt = DateTime.utc(2026, 9, 27),
          ]
        : [];
  }

  @override
  Future<List<AbnormalityType>> getTypesByFirestoreIds(List<String> ids) async {
    if (rig.typeReadError != null) throw rig.typeReadError!;
    if (rig.newerRemoteType) {
      return [
        AbnormalityType()
          ..firestoreId = 'type-7'
          ..version = 2
          ..code = 'TYPE7'
          ..title = 'Test type'
          ..createdAt = DateTime.utc(2026, 9, 27)
          ..updatedAt = DateTime.utc(2026, 9, 27),
      ];
    }
    return [];
  }

  @override
  Future<void> batchUpsertTypes(List<AbnormalityType> records) async {
    rig.typeWriteCalls++;
    if (rig.typeWriteError != null) throw rig.typeWriteError!;
  }

  @override
  Future<void> markTypesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    rig.typesMarked += snapshots.length;
  }

  @override
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities() async {
    rig.visit('abnormalities');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Knowledge implements BafKnowledgeRepository {
  _Knowledge(this.rig);
  final _Rig rig;
  @override
  Future<int> syncUnsyncedToCloud({SyncRunGuard? runGuard}) async {
    rig.visit('knowledge');
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audit extends AuditRepository {
  _Audit(this.rig);
  final _Rig rig;
  @override
  Future<void> log(
    AuditEvent event, {
    bool syncToRemote = true,
    SyncRunGuard? runGuard,
  }) async {
    runGuard?.checkCurrent();
  }

  @override
  Future<AuditSyncResult> syncPendingAuditEvents({
    int batchSize = 450,
    SyncRunGuard? runGuard,
  }) async {
    rig.visit('audit');
    return const AuditSyncResult(
      attempted: 1,
      synced: 1,
      failed: 0,
      batchFailureCount: 0,
    );
  }
}

class _Completion implements PlannedJobServerCompletionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends Fake implements FirebaseAuth {
  User? actor = _User();
  @override
  User? get currentUser => actor;
}

class _User extends Fake implements User {
  @override
  String get uid => 'actor';
  @override
  String? get displayName => 'Actor';
  @override
  String? get email => null;
}
