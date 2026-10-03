import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/morning_review/data/morning_review_rows.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_screen.dart';
import 'package:crm3_baf_ops/features/morning_review/providers/morning_review_providers.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'initial unknown attendance never implies absence or enables Join',
    (tester) async {
      final fixture = await _mount(tester);
      expect(find.text('Attendance unverified'), findsOneWidget);
      expect(find.text('Viewing only'), findsNothing);
      expect(find.text('Join'), findsNothing);
      expect(find.text('Add contribution'), findsNothing);
      fixture.attendance.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Viewing only'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    },
  );

  testWidgets(
    'retained attendance after feed error cannot authorize contributions',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.attendance.add([fixture.participant]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsOneWidget);
      expect(find.text('Add contribution'), findsOneWidget);
      fixture.attendance.addError(StateError('server evidence unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsNothing);
      expect(find.text('Attendance unverified'), findsOneWidget);
      expect(find.text('Add contribution'), findsNothing);
      expect(find.text('Join'), findsNothing);
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Create action'), findsNothing);
      fixture.attendance.add([fixture.participant]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsOneWidget);
      expect(find.text('Create action'), findsOneWidget);
    },
  );

  testWidgets(
    'incomplete attendance cannot imply an absent actor or authorize a retained actor',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.attendance.add(MorningReviewRows([], ['malformed-participant']));
      await tester.pumpAndSettle();
      expect(find.text('Attendance unverified'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
      fixture.attendance.add(
        MorningReviewRows([fixture.participant], ['malformed-participant']),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsNothing);
      expect(find.text('Add contribution'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh invalidates previously joined evidence until the new feed arrives',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.attendance.add([fixture.participant]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsOneWidget);
      fixture.container.invalidate(
        morningReviewParticipantsProvider(fixture.session.sessionId),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Attendance recorded'), findsNothing);
      expect(find.text('Attendance unverified'), findsOneWidget);
      expect(find.text('Add contribution'), findsNothing);
      fixture.attendance.add([fixture.participant]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsOneWidget);
    },
  );
  testWidgets(
    'a failed current session feed hides retained attendance and mutation controls',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.attendance.add([fixture.participant]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsOneWidget);
      fixture.sessions.addError(StateError('session verification unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance recorded'), findsNothing);
      expect(find.text('Add contribution'), findsNothing);
      expect(
        find.textContaining('session verification unavailable'),
        findsOneWidget,
      );
    },
  );
}

class _Fixture {
  final sessions = StreamController<MorningReviewSession?>.broadcast();
  final attendance =
      StreamController<List<MorningReviewParticipant>>.broadcast();
  late ProviderContainer container;
  final session = (() {
    final source =
        jsonDecode(
              File(
                'test/fixtures/morning_review_recovery_actual_handler.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final map = source['openSession'] as Map<String, dynamic>;
    return MorningReviewSession.fromMap(map, map['sessionId'] as String);
  })();
  MorningReviewParticipant get participant => MorningReviewParticipant(
    participantId: 'participant',
    sessionId: session.sessionId,
    userUid: 'actor',
    userName: 'Actor',
    roleKeys: ['operations'],
    joinedAt: DateTime.utc(2026, 8, 31),
  );
}

Future<_Fixture> _mount(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fixture = _Fixture();
  addTearDown(fixture.attendance.close);
  addTearDown(fixture.sessions.close);
  fixture.container = ProviderContainer(
    overrides: [
      currentAppUserProvider.overrideWith(
        (ref) => Stream.value(
          AppUser(
            uid: 'actor',
            name: 'Actor',
            email: 'actor@example.invalid',
            roles: [AppRole.operations],
            isApproved: true,
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      morningReviewCommandServiceProvider.overrideWith((ref) => _NoSaved()),
      morningReviewPlantDayProvider.overrideWithValue(fixture.session.plantDay),
      currentMorningReviewSessionProvider.overrideWith((ref) async* {
        yield fixture.session;
        yield* fixture.sessions.stream;
      }),
      recentMorningReviewSessionsProvider.overrideWith(
        (ref) => Stream.value(<MorningReviewSession>[]),
      ),
      activeMorningReviewActionsProvider.overrideWith(
        (ref) => Stream.value(<MorningReviewAction>[]),
      ),
      morningReviewStandingConcernsProvider.overrideWith(
        (ref) => Stream.value(<MorningReviewStandingConcern>[]),
      ),
      allAssetInstancesProvider.overrideWith(
        (ref) => Stream.value(<AssetInstanceRecord>[]),
      ),
      morningReviewParticipantsProvider(
        fixture.session.sessionId,
      ).overrideWith((ref) => fixture.attendance.stream),
      morningReviewEntriesProvider(
        fixture.session.sessionId,
      ).overrideWith((ref) => Stream.value(<MorningReviewEntry>[])),
      morningReviewActionsProvider(
        fixture.session.sessionId,
      ).overrideWith((ref) => Stream.value(<MorningReviewAction>[])),
      morningReviewConcernChecksProvider(
        fixture.session.sessionId,
      ).overrideWith((ref) => Stream.value(<MorningReviewConcernCheck>[])),
    ],
  );
  addTearDown(fixture.container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: const MaterialApp(home: MorningReviewScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return fixture;
}

class _NoSaved extends MorningReviewCommandService {
  @override
  Future<DurableSubmission?> pendingSubmission() async => null;
  @override
  Future<DurableSubmission?> latestRefusedSubmission() async => null;
}
