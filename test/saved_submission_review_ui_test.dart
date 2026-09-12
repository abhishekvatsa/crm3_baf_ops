import 'dart:async';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/saved_submission_review_service.dart';
import 'package:crm3_baf_ops/features/admin/presentation/saved_submission_review_screen.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

DurableSubmission _row() => DurableSubmission(
  submissionId: 'saved',
  actorUid: 'admin',
  requestId: 'saved',
  aggregateId: 'saved',
  resourceKey: 'morningReview:admin',
  protocol: 'assetHierarchy.v2',
  envelopeJson: '{}',
  displayMetadataJson: null,
  state: DurableSubmissionState.uncertain,
  attemptCount: 1,
  createdAt: DateTime.utc(2026, 9, 13),
  updatedAt: DateTime.utc(2026, 9, 13),
  claimToken: null,
  claimExpiresAt: null,
  nextRetryAt: null,
  receiptJson: null,
  receiptSha256: null,
  lastErrorCode: null,
  lastErrorMessage: 'Saved for review',
  legacySourceKey: null,
  legacySourceBase64: null,
);

class _Review extends Fake implements SavedSubmissionReviewService {
  int inspections = 0;
  int finalizations = 0;
  bool present = true;
  @override
  Future<List<DurableSubmission>> list() async => [_row()];
  @override
  Future<SavedSubmissionReviewInspection> inspect(
    DurableSubmission row,
    String reason,
  ) async {
    inspections++;
    return SavedSubmissionReviewInspection(
      row: row,
      reason: reason,
      reviewerUid: 'admin',
      response: {
        'observation': present ? 'receiptPresent' : 'receiptAbsent',
        'receiptSummary': present
            ? {'result': 'PRIVATE BUSINESS RESULT'}
            : null,
      },
    );
  }

  @override
  Future<DurableSubmission> finalize(
    SavedSubmissionReviewInspection inspection,
  ) async {
    finalizations++;
    return inspection.row;
  }
}

void main() {
  late StreamController<AppUser?> accounts;
  late ProviderContainer container;
  late _Review service;
  AppUser actor(String uid, {bool admin = true}) => AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.test',
    isApproved: true,
    roles: [admin ? AppRole.admin : AppRole.operations],
    createdAt: DateTime.utc(2026),
  );
  setUp(() async {
    accounts = StreamController<AppUser?>();
    service = _Review();
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => accounts.stream),
        firebaseAuthProvider.overrideWithValue(_Auth()),
        savedSubmissionReviewServiceProvider.overrideWithValue(service),
      ],
    );
    container.listen(currentAppUserProvider, (_, _) {});
    accounts.add(actor('admin'));
    await container.read(currentAppUserProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await accounts.close();
  });
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SavedSubmissionReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> inspect(WidgetTester tester) async {
    await show(tester);
    await tester.tap(find.text('Morning Review'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review this request'));
    await tester.tap(find.text('Review this request'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Checked the original business records.',
    );
    await tester.tap(find.text('Check server'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'server inspection does not close a hold until explicit review confirmation',
    (tester) async {
      await inspect(tester);
      expect(service.inspections, 1);
      expect(service.finalizations, 0);
      expect(find.textContaining('PRIVATE BUSINESS RESULT'), findsOneWidget);
      await tester.tap(find.text('Record review and close hold'));
      await tester.pumpAndSettle();
      expect(service.finalizations, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'receipt absence explains expired evidence and keeping hold performs no finalization',
    (tester) async {
      service.present = false;
      await inspect(tester);
      expect(find.textContaining('does not prove'), findsOneWidget);
      await tester.tap(find.text('Keep hold'));
      await tester.pumpAndSettle();
      expect(service.finalizations, 0);
    },
  );
  testWidgets(
    'account error hides open review result and prevents confirmation',
    (tester) async {
      await inspect(tester);
      accounts.addError(StateError('authority unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE BUSINESS RESULT'), findsNothing);
      expect(find.text('Record review and close hold'), findsNothing);
      expect(find.text('Account verification changed'), findsOneWidget);
      expect(service.finalizations, 0);
    },
  );
  testWidgets('another account cannot see the pending review or confirm it', (
    tester,
  ) async {
    await inspect(tester);
    accounts.add(actor('other'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE BUSINESS RESULT'), findsNothing);
    expect(find.text('Record review and close hold'), findsNothing);
    expect(service.finalizations, 0);
  });
}
