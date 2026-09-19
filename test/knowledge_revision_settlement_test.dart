import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_revision_settlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settling a knowledge revision that is already committed', () {
    test('the audit is recorded before this device catches up', () async {
      final order = <String>[];

      await settleCommittedKnowledgeRevision(
        recordAudit: () async => order.add('audit'),
        adoptLocally: () async => order.add('adopt'),
      );

      expect(order, <String>['audit', 'adopt']);
    });

    test('a failed local adoption still leaves the change audited', () async {
      var audited = false;

      final adoption = await settleCommittedKnowledgeRevision(
        recordAudit: () async => audited = true,
        adoptLocally: () async => throw Exception('pull failed'),
      );

      // The rule in cloud has changed. An account of who changed it and why
      // must exist whether or not this device managed to read it back.
      expect(audited, isTrue);
      expect(adoption, KnowledgeRevisionAdoption.pending);
    });

    test('a failed local adoption is not reported as a failed change',
        () async {
      await expectLater(
        settleCommittedKnowledgeRevision(
          recordAudit: () async {},
          adoptLocally: () async => throw Exception('pull failed'),
        ),
        completion(KnowledgeRevisionAdoption.pending),
      );
    });

    test('a settled revision this device holds is reported plainly', () async {
      final adoption = await settleCommittedKnowledgeRevision(
        recordAudit: () async {},
        adoptLocally: () async {},
      );

      expect(adoption, KnowledgeRevisionAdoption.adopted);
      expect(knowledgeRevisionAdoptionNote(adoption, 'BK-014'), 'Saved BK-014.');
    });

    test('a pending adoption says so without claiming a failure', () {
      final note = knowledgeRevisionAdoptionNote(
        KnowledgeRevisionAdoption.pending,
        'BK-014',
      );

      expect(note, startsWith('Saved BK-014.'));
      expect(note, contains('has not caught up'));
      expect(note.toLowerCase(), isNot(contains('failed')));
    });
  });
}
