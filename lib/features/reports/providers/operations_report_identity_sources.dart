part of 'operations_report_provider.dart';

// Owns actor-scoped observation and exact native-source reads for report
// identity joins. Period selection and report aggregation remain in the root;
// repositories retain persistence ownership.

typedef _ReportIdentityScope = ({
  String actorUid,
  OperationsReportPeriodScope period,
  String executionIds,
  String ticketIds,
});
typedef _ReportIdentitySources = ({
  List<JobExecution> executions,
  List<MaintenanceRecord> tickets,
});

final operationsReportExecutionIdentityChangesProvider = StreamProvider
    .autoDispose
    .family<List<JobExecution>, String>((ref, actorUid) {
      _requireReportActorUid(actorUid);
      // Web period queries exclude old completed/cancelled jobs. Observe their
      // changes too, without adding them to the report's period population.
      return ref.watch(plannedRepositoryProvider).watchAllExecutions();
    });

final operationsReportIdentitySourcesProvider = FutureProvider.autoDispose
    .family<_ReportIdentitySources, _ReportIdentityScope>((ref, scope) async {
      _requireReportActorUid(scope.actorUid);
      final executionIds = (jsonDecode(scope.executionIds) as List)
          .cast<String>();
      final ticketIds = (jsonDecode(scope.ticketIds) as List).cast<String>();
      final plannedRepository = executionIds.isEmpty
          ? null
          : ref.watch(plannedRepositoryProvider);
      final maintenanceRepository = ticketIds.isEmpty
          ? null
          : ref.watch(maintenanceRepositoryProvider);
      Future<List<JobExecution>>? executionObserverReady;
      // The source IDs alone are not a freshness key. The separate execution
      // observer covers historical records outside the web date-window queries.
      if (executionIds.isNotEmpty) {
        final observer = operationsReportExecutionIdentityChangesProvider(
          scope.actorUid,
        );
        final changes = ref.watch(observer);
        if (changes.hasError) {
          Error.throwWithStackTrace(
            changes.error!,
            changes.stackTrace ?? StackTrace.current,
          );
        }
        if (changes.isLoading) {
          executionObserverReady = ref.watch(observer.future);
        }
      }
      if (ticketIds.isNotEmpty) {
        // Maintenance period streams derive from the uncapped ticket watch on
        // both repositories, including updates outside the selected period.
        ref.watch(operationsReportTicketsProvider(scope.period));
      }
      if (executionObserverReady != null) await executionObserverReady;
      final executionRead = executionIds.isEmpty
          ? Future.value(<JobExecution>[])
          : plannedRepository!.getExecutionsByFirestoreIds(executionIds);
      final ticketRead = ticketIds.isEmpty
          ? Future.value(<MaintenanceRecord>[])
          : maintenanceRepository!.getTicketsByFirestoreIds(ticketIds);
      final sources = await Future.wait<Object>([executionRead, ticketRead]);
      return (
        executions: sources[0] as List<JobExecution>,
        tickets: sources[1] as List<MaintenanceRecord>,
      );
    });
