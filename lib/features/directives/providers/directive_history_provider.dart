import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/operational_directive_model.dart';
import 'operational_directive_provider.dart';

// History is loaded only when requested by this screen. Home counts and the
// canonical open-directive stream remain independent of the display limit.
final directiveHistoryProvider =
    StreamProvider.autoDispose<List<OperationalDirective>>((ref) {
      final actor = ref.watch(currentAppUserProvider).asData?.value;
      if (actor == null || !actor.isApproved) return Stream.value(const []);
      final repo = ref.watch(directiveRepositoryProvider);
      if (repo is! IsarDirectiveRepository) return repo.watchAllDirectives();
      final incomplete =
          ref.watch(directiveReadHealthProvider(actor.uid)).asData?.value ??
          true;
      return repo.watchAllDirectives().map(
        (rows) => DirectivePopulation(
          DecodedSnapshotBatch(
            records: rows,
            rejectedDocumentIds: const [],
            isFromCache: incomplete,
          ),
        ),
      );
    });
