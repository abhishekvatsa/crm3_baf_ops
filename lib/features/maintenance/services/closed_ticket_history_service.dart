import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../providers/maintenance_provider.dart';

class ClosedTicketHistoryService {
  const ClosedTicketHistoryService(this._repository);

  final MaintenanceRepository _repository;

  Future<int> count({required AppUser? actor}) {
    _requireAuthorized(actor);
    return _repository.getClosedTicketsCount();
  }

  Future<ClosedTicketPage> loadPage({
    required AppUser? actor,
    required int limit,
    required int offset,
    ClosedTicketPageCursor? cursor,
  }) {
    _requireAuthorized(actor);
    return _repository.getClosedTicketPage(
      limit: limit,
      offset: offset,
      cursor: cursor,
    );
  }

  static void _requireAuthorized(AppUser? actor) {
    if (actor == null || !actor.canViewClosedMaintenanceTickets) {
      throw StateError(
        'Approved resolved-history access is required before reading tickets.',
      );
    }
  }
}

final closedTicketHistoryServiceProvider = Provider<ClosedTicketHistoryService>(
  (ref) => ClosedTicketHistoryService(ref.watch(maintenanceRepositoryProvider)),
);
