import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/frequent_issue_definition.dart';
import '../repositories/frequent_issue_repository.dart';

final frequentIssueRepositoryProvider = Provider<FrequentIssueRepository>((
  ref,
) {
  return FrequentIssueRepository();
});

final frequentIssueDefinitionsProvider =
    StreamProvider<List<FrequentIssueDefinition>>((ref) {
      return ref.watch(frequentIssueRepositoryProvider).watchDefinitions();
    });
