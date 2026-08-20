import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/frequent_issue_definition.dart';

class FrequentIssueRepository {
  FrequentIssueRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<FrequentIssueDefinition>> watchDefinitions() => _firestore
      .collection('frequent_issue_definitions')
      .snapshots()
      .map((snapshot) {
        final values = snapshot.docs
          .map(
            (document) =>
                FrequentIssueDefinition.fromMap(document.data(), document.id),
          )
          .toList(growable: false)..sort((left, right) {
          final status = left.status.index.compareTo(right.status.index);
          if (status != 0) return status;
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        });
        return List<FrequentIssueDefinition>.unmodifiable(values);
      });
}
