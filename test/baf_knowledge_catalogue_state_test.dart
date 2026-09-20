import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading an empty active knowledge catalogue', () {
    test('a device that has never held a catalogue gets the baseline', () {
      expect(
        bafKnowledgeCatalogueState(storedRowCount: 0, activeRowCount: 0),
        BafKnowledgeCatalogueState.neverInitialised,
      );
    });

    test('a catalogue whose rows were all withdrawn stays empty', () {
      // The rows are still there; every one of them has been retired or
      // archived. Handing back the embedded baseline would put a withdrawn
      // rule in front of someone as current guidance.
      expect(
        bafKnowledgeCatalogueState(storedRowCount: 42, activeRowCount: 0),
        BafKnowledgeCatalogueState.governedEmpty,
      );
    });

    test('one withdrawn row is enough to say the catalogue existed', () {
      expect(
        bafKnowledgeCatalogueState(storedRowCount: 1, activeRowCount: 0),
        BafKnowledgeCatalogueState.governedEmpty,
      );
    });

    test('an active row is a populated catalogue however many are retired', () {
      expect(
        bafKnowledgeCatalogueState(storedRowCount: 42, activeRowCount: 1),
        BafKnowledgeCatalogueState.populated,
      );
    });

    test('a withdrawn catalogue describes itself rather than a fallback', () {
      final meta = BafKnowledgeMatrixMeta.governedEmpty();

      expect(meta.isStaticFallback, isFalse);
      expect(meta.cloudUnavailable, isFalse);
      expect(meta.knowledgeRowCount, 0);
      expect(meta.note, contains('withdrawn by governance'));
    });
  });
}
