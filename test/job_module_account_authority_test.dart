import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/providers/audit_provider.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_module_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/widgets/action_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

AppUser _actor({
  String uid = 'editor',
  bool approved = true,
  bool admin = true,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.test',
  roles: [admin ? AppRole.admin : AppRole.operations],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

JobExecution _parent() => JobExecution()
  ..id = 7
  ..firestoreId = 'job-7'
  ..templateFirestoreId = 'template-7'
  ..assetType = AssetType.base
  ..assetNumber = 7
  ..createdAt = DateTime.utc(2026, 9, 12)
  ..updatedAt = DateTime.utc(2026, 9, 12);

JobModuleInstance _module() => JobModuleInstance()
  ..id = 9
  ..firestoreId = 'module-9'
  ..jobExecutionFirestoreId = 'job-7'
  ..jobExecutionLocalId = 7
  ..moduleTitle = 'Seal inspection'
  ..moduleSnapshotJson = '{}'
  ..fieldDefinitionsJson = '[]'
  ..discipline = JobModuleDiscipline.mechanical
  ..createdAt = DateTime.utc(2026, 9, 12)
  ..updatedAt = DateTime.utc(2026, 9, 12)
  ..status = JobModuleStatus.draftSaved
  ..version = 4
  ..isSynced = true;

ComponentAction _action() => ComponentAction(
  id: 'action-1',
  asset: 'Base 7',
  component: 'Seal',
  actionType: ActionType.inspection,
  remarks: 'returned work',
  performedBy: 'editor',
  createdAt: DateTime.utc(2026, 9, 12, 10),
);

class _NoRemoteAudit extends AuditRepository {
  @override
  Future<void> log(AuditEvent event, {bool syncToRemote = true}) async {}
}

// These adapters retain the actual native transaction and write. Only the
// timing of a live account-stream update after that write is controlled.
class _AfterPutIsar implements Isar {
  _AfterPutIsar(this.native, this.afterPut);
  final Isar native;
  final Future<void> Function() afterPut;
  @override
  IsarCollection<T> collection<T>() => T == JobModuleInstance
      ? _AfterPutCollection(native.collection<JobModuleInstance>(), afterPut)
            as IsarCollection<T>
      : native.collection<T>();
  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) =>
      native.writeTxn(callback, silent: silent);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AfterPutCollection implements IsarCollection<JobModuleInstance> {
  _AfterPutCollection(this.native, this.afterPut);
  final IsarCollection<JobModuleInstance> native;
  final Future<void> Function() afterPut;
  @override
  Future<JobModuleInstance?> get(Id id) => native.get(id);
  @override
  Future<Id> put(JobModuleInstance row) async {
    final id = await native.put(row);
    await afterPut();
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyHierarchy extends Fake implements AssetHierarchyRepository {
  @override
  Stream<List<AssetClassRecord>> watchAssetClasses() => Stream.value([]);
}

class _SavingRepository extends Fake implements JobModuleRepository {
  int saves = 0;
  Completer<void>? pending;
  JobModuleInstance? saved;
  @override
  Future<void> saveModule(
    JobModuleInstance module, {
    AppUser? actor,
    AuditContext? auditContext,
    JobModuleSaveBaseline? expectedBaseline,
    String? recoveredConflictId,
  }) async {
    saves++;
    saved = copyJobModuleForEditing(module);
    await pending?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('actual native module provider authority', () {
    setUpAll(initializeTestIsarCore);
    late Directory directory;
    late Isar native;
    late StreamController<AppUser?> accounts;
    late ProviderContainer container;
    late IsarJobModuleRepository repository;
    final original = _actor();

    Future<void> emit(AppUser? account) async {
      accounts.add(account);
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('module_authority_');
      native = await Isar.open(
        [JobExecutionSchema, JobModuleInstanceSchema, AuditEventSchema],
        directory: directory.path,
        name: 'module_authority',
        inspector: false,
      );
      isar = native;
      await native.writeTxn(() async {
        await native.jobExecutions.put(_parent());
        await native.jobModuleInstances.put(_module());
      });
      accounts = StreamController<AppUser?>.broadcast();
      container = ProviderContainer(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => accounts.stream),
          auditRepositoryProvider.overrideWithValue(_NoRemoteAudit()),
        ],
      );
      container.listen(currentAppUserProvider, (_, _) {});
      accounts.add(original);
      await container.read(currentAppUserProvider.future);
      // Do not replace the repository provider or inject verifyActor: the
      // production composition itself must supply every authority check.
      repository = container.read(isarJobModuleRepoProvider);
    });

    tearDown(() async {
      container.dispose();
      await accounts.close();
      isar = native;
      await native.close(deleteFromDisk: true);
      directory.deleteSync(recursive: true);
    });

    test(
      'the original approved account can save through production wiring',
      () async {
        final row = (await native.jobModuleInstances.get(9))!;
        final baseline = JobModuleSaveBaseline.capture(row);
        row.draftNote = 'authorized work';
        await repository.saveModule(
          row,
          actor: original,
          expectedBaseline: baseline,
        );
        expect(
          (await native.jobModuleInstances.get(9))!.draftNote,
          'authorized work',
        );
        expect(row.version, 5);
      },
    );

    for (final mode in [
      'different account',
      'approval revoked',
      'same UID role lost',
      'signed out',
      'account error',
      'account loading',
    ]) {
      test(
        '$mode refuses a captured actor without changing native work',
        () async {
          final row = (await native.jobModuleInstances.get(9))!;
          final before = jobModuleLocalSnapshot(row);
          final baseline = JobModuleSaveBaseline.capture(row);
          row.draftNote = 'stale actor work';
          switch (mode) {
            case 'different account':
              await emit(_actor(uid: 'other'));
            case 'approval revoked':
              await emit(_actor(approved: false));
            case 'same UID role lost':
              await emit(_actor(admin: false));
            case 'signed out':
              await emit(null);
            case 'account error':
              accounts.addError(StateError('Account could not be verified'));
              await Future<void>.delayed(Duration.zero);
            case 'account loading':
              container.invalidate(currentAppUserProvider);
              expect(container.read(currentAppUserProvider).isLoading, isTrue);
          }
          await expectLater(
            repository.saveModule(
              row,
              actor: original,
              expectedBaseline: baseline,
            ),
            throwsStateError,
          );
          expect(
            jobModuleLocalSnapshot((await native.jobModuleInstances.get(9))!),
            before,
          );
          expect(await native.auditEvents.count(), 0);
        },
      );
    }

    for (final changed in [
      _actor(uid: 'other'),
      _actor(approved: false),
      _actor(admin: false),
    ]) {
      test(
        'native put rolls back when ${changed.uid}/${changed.isApproved}/${changed.roles} changes mid-transaction',
        () async {
          final row = (await native.jobModuleInstances.get(9))!;
          final before = jobModuleLocalSnapshot(row);
          final baseline = JobModuleSaveBaseline.capture(row);
          row.draftNote = 'must roll back';
          var puts = 0;
          isar = _AfterPutIsar(native, () async {
            puts++;
            await emit(changed);
          });
          await expectLater(
            repository.saveModule(
              row,
              actor: original,
              expectedBaseline: baseline,
            ),
            throwsStateError,
          );
          expect(
            puts,
            1,
            reason:
                'Authority changes after the real native write, before commit.',
          );
          expect(
            jobModuleLocalSnapshot((await native.jobModuleInstances.get(9))!),
            before,
          );
          expect(await native.auditEvents.count(), 0);
        },
      );
    }
  });

  group('actual module work sheets', () {
    late StreamController<AppUser?> accounts;
    late _SavingRepository repository;
    Future<void> open(WidgetTester tester, {bool progress = false}) async {
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      accounts = StreamController<AppUser?>.broadcast();
      repository = _SavingRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => accounts.stream),
            jobModuleRepositoryProvider.overrideWithValue(repository),
            assetHierarchyRepositoryProvider.overrideWithValue(
              _EmptyHierarchy(),
            ),
          ],
          child: MaterialApp(
            home: JobModuleDetailScreen(
              execution: _parent(),
              module: _module(),
            ),
          ),
        ),
      );
      accounts.add(_actor());
      await tester.pumpAndSettle();
      final opener = find.text(
        progress ? 'Save Progress' : 'Add component work',
      );
      await tester.scrollUntilVisible(
        opener,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      if (progress) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await tester.tap(opener);
      await tester.pumpAndSettle();
      expect(
        progress
            ? find.text('Save module progress')
            : find.byType(ActionBottomSheet),
        findsOneWidget,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await accounts.close();
      });
    }

    Finder progressField(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    Finder progressSaveButton() => find
        .ancestor(
          of: find.text('Save Progress').last,
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        )
        .first;

    testWidgets(
      'progress entries hide on account loss and restore before an authorized save',
      (tester) async {
        await open(tester, progress: true);
        final note = progressField('Progress note');
        final pending = progressField('Pending issue / blocker pointer');
        await tester.enterText(note, 'Original progress retained');
        await tester.enterText(pending, 'Original pending work retained');
        await tester.tap(find.byType(CheckboxListTile).last);
        await tester.pumpAndSettle();
        for (final mode in [
          'other',
          'unapproved',
          'role lost',
          'signed out',
          'error',
        ]) {
          switch (mode) {
            case 'other':
              accounts.add(_actor(uid: 'other'));
            case 'unapproved':
              accounts.add(_actor(approved: false));
            case 'role lost':
              accounts.add(_actor(admin: false));
            case 'signed out':
              accounts.add(null);
            case 'error':
              accounts.addError(StateError('Account verification failed'));
          }
          await tester.pumpAndSettle();
          expect(note, findsNothing, reason: mode);
          expect(pending, findsNothing, reason: mode);
          expect(
            find.text('Original progress retained'),
            findsNothing,
            reason: mode,
          );
          expect(
            find.text('Original pending work retained'),
            findsNothing,
            reason: mode,
          );
          expect(find.text('Save module progress'), findsNothing, reason: mode);
          expect(
            find.text('Account verification required'),
            findsOneWidget,
            reason: mode,
          );
          expect(repository.saves, 0);
          accounts.add(_actor());
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(note).controller!.text,
            'Original progress retained',
          );
          expect(
            tester.widget<TextField>(pending).controller!.text,
            'Original pending work retained',
          );
          expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile).last)
                .value,
            isTrue,
          );
        }
        await tester.ensureVisible(progressSaveButton());
        await tester.tap(progressSaveButton());
        await tester.pumpAndSettle();
        expect(repository.saves, 1);
        expect(repository.saved!.draftNote, 'Original progress retained');
        expect(
          repository.saved!.pendingIssue,
          'Original pending work retained',
        );
        expect(repository.saved!.requiresFollowUp, isTrue);
        expect(repository.saved!.updatedByUid, 'editor');
        expect(find.text('Module progress saved'), findsOneWidget);
      },
    );

    testWidgets(
      'a late progress callback cannot save under a changed account',
      (tester) async {
        await open(tester, progress: true);
        await tester.enterText(
          progressField('Progress note'),
          'Late progress result',
        );
        final submit = tester
            .widget<FilledButton>(progressSaveButton())
            .onPressed!;
        accounts.add(_actor(uid: 'other'));
        await tester.pumpAndSettle();
        expect(find.text('Save module progress'), findsNothing);
        submit();
        await tester.pumpAndSettle();
        expect(repository.saves, 0);
        expect(find.text('Module progress saved'), findsNothing);
      },
    );

    testWidgets(
      'account loss during awaited progress save prevents adoption and success',
      (tester) async {
        await open(tester, progress: true);
        await tester.enterText(
          progressField('Progress note'),
          'Late progress result',
        );
        repository.pending = Completer<void>();
        await tester.ensureVisible(progressSaveButton());
        await tester.tap(progressSaveButton());
        await tester.pump(const Duration(milliseconds: 400));
        expect(repository.saves, 1);
        accounts.add(_actor(admin: false));
        await tester.pump(const Duration(milliseconds: 100));
        repository.pending!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Module progress saved'), findsNothing);
        expect(find.text('Late progress result'), findsNothing);
      },
    );

    testWidgets(
      'account switch and permission loss hide editable work and preserve it for origin',
      (tester) async {
        await open(tester);
        final notes = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Issue / observation',
        );
        await tester.ensureVisible(notes);
        await tester.enterText(notes, 'Original private work');
        for (final changed in [
          _actor(uid: 'other'),
          _actor(approved: false),
          _actor(admin: false),
        ]) {
          accounts.add(changed);
          await tester.pumpAndSettle();
          expect(find.byType(ActionBottomSheet), findsNothing);
          expect(find.text('Original private work'), findsNothing);
          expect(find.text('Save Action'), findsNothing);
          expect(find.text('Account verification required'), findsOneWidget);
          expect(repository.saves, 0);
          accounts.add(_actor());
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(notes).controller!.text,
            'Original private work',
          );
        }
      },
    );

    testWidgets('a late returned action cannot save under a changed account', (
      tester,
    ) async {
      await open(tester);
      final routeContext = tester.element(find.byType(ActionBottomSheet));
      accounts.add(_actor(uid: 'other'));
      await tester.pumpAndSettle();
      expect(find.byType(ActionBottomSheet), findsNothing);
      // A callback already holding the old route can still finish after the
      // live guard hides that route's form. The caller must check again.
      Navigator.of(routeContext).pop(_action());
      await tester.pumpAndSettle();
      expect(repository.saves, 0);
      expect(find.text('Component work action saved'), findsNothing);
    });

    testWidgets(
      'an account change during awaited save never adopts or reports old-account success',
      (tester) async {
        await open(tester);
        repository.pending = Completer<void>();
        Navigator.of(
          tester.element(find.byType(ActionBottomSheet)),
        ).pop(_action());
        await tester.pump(const Duration(milliseconds: 400));
        expect(repository.saves, 1);
        accounts.add(_actor(admin: false));
        await tester.pump(const Duration(milliseconds: 100));
        repository.pending!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Component work action saved'), findsNothing);
        expect(find.text('returned work'), findsNothing);
      },
    );
  });
}
