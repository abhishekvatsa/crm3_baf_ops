import 'dart:convert';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_governance_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_import_journal.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/knowledge_import_recovery_panel.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/knowledge_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/repositories/knowledge_import_journal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'journal reconstruction preserves immutable reviewed drafts and every outcome',
    () async {
      final journal = KnowledgeImportJournalRepository();
      final intent = await journal.retain(_intent());
      final changed = intent.rows.single.draft..taskText = 'Later editor draft';
      expect(changed.taskText, isNot(intent.rows.single.draft.taskText));
      await journal.recordOutcome(
        _outcome(intent, KnowledgeImportOutcomeState.pending),
      );
      await journal.recordOutcome(
        _outcome(
          intent,
          KnowledgeImportOutcomeState.accepted,
          id: 'outcome-accepted',
        ),
      );
      final restarted =
          (await KnowledgeImportJournalRepository().readAll()).single;
      expect(
        restarted.intent.rows.single.draft.taskText,
        'Reviewed import instruction',
      );
      expect(
        restarted.outcomes.values.single.state,
        KnowledgeImportOutcomeState.accepted,
      );
      expect(restarted.needsRecovery, isTrue);
      expect((await SharedPreferences.getInstance()).getKeys(), hasLength(3));
    },
  );

  test(
    'corrupt retained evidence stays stored and blocks an additional import',
    () async {
      final journal = KnowledgeImportJournalRepository();
      await journal.retain(_intent());
      final preferences = await SharedPreferences.getInstance();
      final key = preferences.getKeys().single;
      await preferences.setString(key, '{broken');
      await expectLater(journal.readAll(), throwsStateError);
      await expectLater(
        journal.retain(_intent(id: 'second-import-id')),
        throwsStateError,
      );
      expect(preferences.getString(key), '{broken');
      expect(preferences.getKeys(), hasLength(1));
    },
  );

  test(
    'outcome cannot attach to a different request, row, or version',
    () async {
      final journal = KnowledgeImportJournalRepository();
      final intent = await journal.retain(_intent());
      for (final change in [
        {'importId': 'another-import-id'},
        {'rowCode': 'OTHER-ROW'},
        {'versionAfter': 2},
      ]) {
        final map = {
          ..._outcome(intent, KnowledgeImportOutcomeState.pending).toMap(),
          ...change,
        };
        await expectLater(
          journal.recordOutcome(KnowledgeImportOutcome.decode(jsonEncode(map))),
          throwsStateError,
        );
      }
      expect((await SharedPreferences.getInstance()).getKeys(), hasLength(1));
    },
  );

  test('malformed retained request fields fail closed', () {
    final original = _intent().toMap();
    for (final change in [
      {'schemaVersion': 2},
      {'actorUid': ''},
      {'requestId': 'bad/id'},
      {'rows': []},
      {'extra': true},
      {
        'rows': [original['rows'][0], original['rows'][0]],
      },
    ]) {
      expect(
        () =>
            KnowledgeImportIntent.decode(jsonEncode({...original, ...change})),
        throwsA(isA<FormatException>()),
      );
    }
  });

  for (final firstState in [
    KnowledgeImportOutcomeState.accepted,
    KnowledgeImportOutcomeState.rejected,
  ]) {
    test('contradictory outcomes fail closed with $firstState first', () async {
      final journal = KnowledgeImportJournalRepository();
      final intent = await journal.retain(_intent());
      await journal.recordOutcome(
        _outcome(intent, firstState, id: 'a-outcome-identity'),
      );
      await journal.recordOutcome(
        _outcome(
          intent,
          firstState == KnowledgeImportOutcomeState.accepted
              ? KnowledgeImportOutcomeState.rejected
              : KnowledgeImportOutcomeState.accepted,
          id: 'z-outcome-identity',
        ),
      );
      await _tieOutcomeJournalTimes();
      await expectLater(journal.readAll(), throwsStateError);
      expect((await SharedPreferences.getInstance()).getKeys(), hasLength(3));
    });
  }

  for (final rejectedFirst in [true, false]) {
    test(
      'rejected outcome stays terminal with pending, order=$rejectedFirst',
      () async {
        final journal = KnowledgeImportJournalRepository();
        final intent = await journal.retain(_intent());
        await journal.recordOutcome(
          _outcome(
            intent,
            KnowledgeImportOutcomeState.rejected,
            id: rejectedFirst ? 'a-outcome-identity' : 'z-outcome-identity',
          ),
        );
        await journal.recordOutcome(
          _outcome(
            intent,
            KnowledgeImportOutcomeState.pending,
            id: rejectedFirst ? 'z-outcome-identity' : 'a-outcome-identity',
          ),
        );
        await _tieOutcomeJournalTimes();
        expect(
          (await journal.readAll()).single.outcomes.values.single.state,
          KnowledgeImportOutcomeState.rejected,
        );
      },
    );
  }

  testWidgets(
    'restart panel shows exact per-row state and resumes with original account',
    (tester) async {
      final intent = KnowledgeImportIntent.decode(
        jsonEncode(_intent().toMap()),
      );
      final controller = _Controller();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_actor('original-admin')),
            ),
            knowledgeImportRecoveryProvider.overrideWith(
              (ref) async => [KnowledgeImportRecovery(intent, {})],
            ),
            knowledgeGovernanceControllerProvider.overrideWithValue(controller),
          ],
          child: const MaterialApp(
            home: Scaffold(body: KnowledgeImportRecoveryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved imports: 1 need review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 rows · Original administrator'));
      await tester.pumpAndSettle();
      expect(
        find.text('Not confirmed. Original reviewed content is saved.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Resume saved import'));
      await tester.tap(find.text('Resume saved import'));
      await tester.pumpAndSettle();
      expect(controller.importId, intent.requestId);
      expect(controller.actorUid, intent.actorUid);
    },
  );

  testWidgets(
    'another administrator sees retained evidence but has no resume action',
    (tester) async {
      final intent = KnowledgeImportIntent.decode(
        jsonEncode(_intent().toMap()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_actor('other-admin')),
            ),
            knowledgeImportRecoveryProvider.overrideWith(
              (ref) async => [KnowledgeImportRecovery(intent, {})],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: KnowledgeImportRecoveryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved imports: 1 need review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 rows · Original administrator'));
      await tester.pumpAndSettle();
      expect(find.text('Resume saved import'), findsNothing);
      expect(
        find.textContaining('Sign in as Original administrator'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _tieOutcomeJournalTimes() async {
  final preferences = await SharedPreferences.getInstance();
  for (final key in preferences.getKeys()) {
    final envelope =
        jsonDecode(preferences.getString(key)!) as Map<String, dynamic>;
    if ((envelope['record'] as Map)['importId'] == null) continue;
    envelope['savedAtMicros'] = 1000000;
    await preferences.setString(key, jsonEncode(envelope));
  }
}

KnowledgeImportIntent _intent({String id = 'original-import-id'}) {
  final row = BafKnowledgeRow.fromEntry(
    BafKnowledgeLayer.entries.first,
    actorUid: 'original-admin',
    actorName: 'Original administrator',
    now: DateTime.utc(2026),
    changeSummary: 'Original reviewed source',
  );
  final draft = KnowledgeRowDraft.fromRow(row)
    ..taskText = 'Reviewed import instruction'
    ..changeSummary = 'Reviewed controlled import';
  return KnowledgeImportIntent(
    requestId: id,
    actorUid: 'original-admin',
    actorName: 'Original administrator',
    rows: [
      KnowledgeImportRowIntent(
        rowCode: row.rowCode,
        draftJson: jsonEncode(draft.toEntryMap()),
        reason: draft.changeSummary,
        beforeJson: null,
      ),
    ],
  );
}

KnowledgeImportOutcome _outcome(
  KnowledgeImportIntent intent,
  KnowledgeImportOutcomeState state, {
  String id = 'pending-outcome-id',
}) => KnowledgeImportOutcome(
  requestId: id,
  importId: intent.requestId,
  rowCode: intent.rows.single.rowCode,
  versionAfter: 1,
  state: state,
  adopted: false,
  message: 'Retained row outcome',
);

AppUser _actor(String uid) => AppUser(
  uid: uid,
  name: 'Administrator',
  email: '$uid@test.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _Controller extends Fake implements KnowledgeGovernanceController {
  String? importId;
  String? actorUid;
  @override
  Future<KnowledgeGovernanceImportApplyResult> resumeImport({
    required String importId,
    required AppUser actor,
  }) async {
    this.importId = importId;
    actorUid = actor.uid;
    return const KnowledgeGovernanceImportApplyResult(
      applied: 0,
      rejectedAtSave: 0,
      writes: [],
      errors: [],
    );
  }
}
