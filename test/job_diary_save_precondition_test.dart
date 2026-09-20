import 'package:crm3_baf_ops/features/planned_maintenance/domain/job_diary_save_precondition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('saving a diary entry that was open while the store moved on', () {
    test('an entry written elsewhere is not replaced', () {
      // The editor opened v4. Another save, or a pull adopting the server's
      // copy, stored v5 in the meantime. Writing the edit as a whole object
      // would put v4's text back under a v5 label.
      expect(
        jobDiarySaveRefusal(openedAtVersion: 4, storedVersion: 5),
        JobDiarySaveRefusal.changedElsewhere,
      );
    });

    test('an entry that is no longer there is not recreated by a save', () {
      expect(
        jobDiarySaveRefusal(openedAtVersion: 4, storedVersion: null),
        JobDiarySaveRefusal.entryRemoved,
      );
    });

    test('a withdrawn entry is not brought back by a save', () {
      expect(
        jobDiarySaveRefusal(
          openedAtVersion: 4,
          storedVersion: 4,
          storedIsDeleted: true,
        ),
        JobDiarySaveRefusal.entryRemoved,
      );
    });

    test('the entry this edit was opened against is written', () {
      expect(jobDiarySaveRefusal(openedAtVersion: 4, storedVersion: 4), isNull);
    });

    test('an older stored revision is a disagreement, not a licence', () {
      // The store going backwards means the two sides disagree about the
      // entry's history, which is not something a save may resolve silently.
      expect(
        jobDiarySaveRefusal(openedAtVersion: 5, storedVersion: 4),
        JobDiarySaveRefusal.changedElsewhere,
      );
    });

    test('every refusal says the note is still on screen', () {
      for (final refusal in JobDiarySaveRefusal.values) {
        expect(jobDiarySaveRefusalMessage(refusal), contains('still on screen'));
      }
    });
  });
}
