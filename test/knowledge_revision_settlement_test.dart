import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_revision_settlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settling an atomically committed knowledge revision', () {
    test('verified target adoption is reported plainly', () async {
      final adoption = await settleCommittedKnowledgeRevision(
        adoptLocally: () async => KnowledgeRevisionAdoption.adopted,
      );
      expect(adoption, KnowledgeRevisionAdoption.adopted);
      expect(
        knowledgeRevisionAdoptionNote(adoption, 'BK-014'),
        'Saved BK-014.',
      );
    });

    test(
      'unverified target stays pending even if the pull returned normally',
      () async {
        final adoption = await settleCommittedKnowledgeRevision(
          adoptLocally: () async => KnowledgeRevisionAdoption.pending,
        );
        expect(adoption, KnowledgeRevisionAdoption.pending);
      },
    );

    test(
      'failed local readback does not report the committed change as failed',
      () async {
        await expectLater(
          settleCommittedKnowledgeRevision(
            adoptLocally: () async => throw Exception('readback failed'),
          ),
          completion(KnowledgeRevisionAdoption.pending),
        );
      },
    );

    test(
      'pending adoption explains conflict review without promising automatic recovery',
      () {
        final note = knowledgeRevisionAdoptionNote(
          KnowledgeRevisionAdoption.pending,
          'BK-014',
        );
        expect(note, startsWith('Saved BK-014.'));
        expect(note, contains('has not caught up'));
        expect(note, contains('retained local drafts'));
        expect(note, isNot(contains('next successful sync')));
      },
    );
  });
}
