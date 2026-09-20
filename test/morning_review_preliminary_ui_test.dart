import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_agenda_view.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_editors.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_action_correction_editor.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/morning_review_recovery_actual_handler.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  testWidgets(
    'first standing concern is available even with no safety agenda or concerns',
    (tester) async {
      final map = {
        ...fixture['openSession'] as Map<String, dynamic>,
        'sourceFacts': <dynamic>[],
        'sourceFactCount': 0,
      };
      var added = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MorningReviewAgendaView(
              session: MorningReviewSession.fromMap(
                map,
                map['sessionId'] as String,
              ),
              joined: true,
              busy: false,
              entries: const [],
              concerns: const [],
              checks: const [],
              onAddEntry: null,
              onAddConcern: () => added++,
              onCheckConcern: null,
              onResolveConcern: null,
              onAddAddendum: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.byIcon(Icons.push_pin_outlined);
      expect(add, findsOneWidget);
      await tester.ensureVisible(add);
      await tester.tap(add);
      expect(added, 1);
    },
  );

  testWidgets(
    'a daily safety check requires an explicit outcome instead of defaulting to complied',
    (tester) async {
      MorningReviewConcernCheckInput? result;
      final concern = MorningReviewStandingConcern(
        concernId: 'valves',
        title: 'Valve position',
        detail: 'Check operating bases',
        criticality: MorningReviewConcernCriticality.safety,
        status: MorningReviewConcernStatus.active,
        version: 1,
        createdAt: DateTime.utc(2026),
        createdByName: 'Supervisor',
        resolvedAt: null,
        resolvedByName: null,
        resolutionReason: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMorningReviewConcernCheckEditor(
                    context,
                    concern: concern,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Base 7 is still awaiting verification',
      );
      await tester.tap(find.text('Choose a check outcome'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Exception'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record check'));
      await tester.pumpAndSettle();
      expect(result!.state, MorningReviewConcernCheckState.exception);
    },
  );

  testWidgets(
    'correction editor requires a reason and offers reopen for a terminal action',
    (tester) async {
      Map<String, String>? result;
      final actionMap = fixture['cancelledAction'] as Map<String, dynamic>;
      final action = MorningReviewAction.fromMap(
        actionMap,
        actionMap['actionId'] as String,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMorningReviewActionCorrectionEditor(
                    context,
                    action: action,
                    guard: (child) => child,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('A reason is required'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reopen action').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Cancellation selected by mistake',
      );
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();
      expect(result, {
        'kind': 'reopen',
        'reason': 'Cancellation selected by mistake',
      });
    },
  );
}
