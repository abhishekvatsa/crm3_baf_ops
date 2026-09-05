import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_agenda_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('agenda remains usable on a narrow phone and filters matters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final openFact = _fact(
      id: 'maintenance_records/open-clamp',
      title: 'Hydraulic clamp remains unavailable',
      status: 'open',
    );
    final resolvedFact = _fact(
      id: 'maintenance_records/resolved-seal',
      title: 'Draft seal repair verified',
      status: 'resolved',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.2)),
              child: child!,
            ),
        home: Scaffold(
          body: MorningReviewAgendaView(
            session: _session([openFact, resolvedFact]),
            joined: true,
            busy: false,
            entries: [
              _entry(
                id: 'open-update',
                text:
                    'Mechanical inspection continues while the spare clamp is prepared.',
                references: [openFact.factId],
              ),
              _entry(
                id: 'resolved-update',
                text: 'The seal repair was checked and accepted in the room.',
                references: [resolvedFact.factId],
              ),
            ],
            concerns: const [],
            checks: const [],
            onAddEntry: (_) {},
            onAddConcern: null,
            onCheckConcern: null,
            onResolveConcern: null,
            onAddAddendum: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hydraulic clamp remains unavailable'), findsOneWidget);
    expect(find.text('Draft seal repair verified'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final resolvedFilter = find.byKey(
      const ValueKey('morning-review-filter-resolved'),
    );
    await tester.ensureVisible(resolvedFilter);
    await tester.pumpAndSettle();
    await tester.tap(resolvedFilter);
    await tester.pumpAndSettle();

    expect(find.text('Hydraulic clamp remains unavailable'), findsNothing);
    expect(find.text('Draft seal repair verified'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

MorningReviewSession _session(List<MorningReviewSourceFact> facts) {
  final now = DateTime.utc(2026, 9, 5, 3, 30);
  return MorningReviewSession(
    sessionId: '2026-09-05',
    plantDay: '2026-09-05',
    status: MorningReviewStatus.open,
    version: 1,
    openedAt: now,
    openedByUid: 'facilitator-1',
    openedByName: 'Facilitator One',
    facilitatorUid: 'facilitator-1',
    facilitatorName: 'Facilitator One',
    facilitatorRoleKeys: const ['admin'],
    facilitatorHistory: const [],
    sourceCapturedAt: now,
    sourceFacts: facts,
    sourceFactDigest: 'morningreviewsource1-sha256:${'a' * 64}',
    sourceCaptureState: MorningReviewSourceCaptureState.complete,
    sourceCollectionsAtLimit: const [],
    finalizedAt: null,
    finalizedByUid: null,
    finalizedByName: null,
    finalSummary: null,
    documentDigest: null,
    updatedAt: now,
    updatedByUid: 'facilitator-1',
    updatedByName: 'Facilitator One',
    expiresAt: now.add(const Duration(days: 14)),
    lastMutationId: 'mutation-1',
  );
}

MorningReviewSourceFact _fact({
  required String id,
  required String title,
  required String status,
}) => MorningReviewSourceFact(
  factId: id,
  section: MorningReviewSection.base,
  sourceType: 'maintenanceIssue',
  sourceCollection: 'maintenance_records',
  sourceDocumentId: id.split('/').last,
  title: title,
  summary:
      '$title with a deliberately detailed description for narrow-screen wrapping.',
  status: status,
  assetClassId: 'base-class',
  assetClassName: 'Base',
  assetInstanceId: 'base-113',
  assetNumber: '113',
  observedAt: DateTime.utc(2026, 9, 5, 2, 45),
);

MorningReviewEntry _entry({
  required String id,
  required String text,
  required List<String> references,
}) => MorningReviewEntry(
  entryId: id,
  sessionId: '2026-09-05',
  section: MorningReviewSection.base,
  kind: MorningReviewEntryKind.currentCompliance,
  text: text,
  assetClassId: 'base-class',
  assetClassName: 'Base',
  assetInstanceId: 'base-113',
  assetNumber: '113',
  sourceReferences: references,
  authorUid: 'operator-1',
  authorName: 'Operator One',
  authorRoleKeys: const ['operations'],
  createdAt: DateTime.utc(2026, 9, 5, 3, 35),
  addendumReason: null,
);
