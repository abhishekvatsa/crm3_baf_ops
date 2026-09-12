import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../persistence/durable_submission_repository.dart';

final durableSubmissionRepositoryProvider = Provider<DurableSubmissionRepository>((
  ref,
) {
  final isar = Isar.getInstance();
  if (isar == null || !isar.isOpen) {
    throw const DurableSubmissionException(
      'storage-unavailable',
      'Saved submissions could not be opened. Nothing was sent. Restart the app and try again.',
    );
  }
  return DurableSubmissionRepository(isar);
});
