part of 'closed_tickets_screen.dart';

class _ClosedTicketsAccessState extends ConsumerState<ClosedTicketsScreen> {
  AppUser? _lastVerifiedActor;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    final access = CurrentActorAccess.resolve(actorAsync);
    final actor = access.actor;
    if (actor != null && actor.canViewClosedMaintenanceTickets) {
      // Keep the launching state alive for any open draft. A different account
      // must reopen history instead of inheriting this account's pending action.
      _lastVerifiedActor ??= actor;
    }
    final allowed =
        actor?.canViewClosedMaintenanceTickets == true &&
        actor?.uid == _lastVerifiedActor?.uid;
    final accessState = actorAsync.when(
      skipLoadingOnRefresh: false,
      skipError: false,
      loading: () => BafScreenStateScaffold.loading(
        appBarTitle: 'Closed issue history',
        appBarSubtitle: 'Resolved work and administrative closures',
        appBarIcon: Icons.inventory_2_outlined,
        accent: BafColors.maintenance,
        label: 'Checking closure-history access',
      ),
      error: (_, _) => BafScreenStateScaffold.error(
        appBarTitle: 'Closed issue history',
        appBarSubtitle: 'Resolved work and administrative closures',
        appBarIcon: Icons.inventory_2_outlined,
        accent: BafColors.maintenance,
        message: 'Could not verify closure-history access.',
      ),
      data: (actor) {
        if (actor != null && actor.uid != _lastVerifiedActor?.uid) {
          return BafScreenStateScaffold.access(
            appBarTitle: 'Closed issue history',
            appBarSubtitle: 'Resolved work and administrative closures',
            appBarIcon: Icons.inventory_2_outlined,
            accent: BafColors.maintenance,
            title: 'Account changed',
            message:
                'Return to the account that opened this history, or go back and reopen it for your current account.',
          );
        }
        if (actor == null || !actor.canViewClosedMaintenanceTickets) {
          return BafScreenStateScaffold.access(
            appBarTitle: 'Closed issue history',
            appBarSubtitle: 'Resolved work and administrative closures',
            appBarIcon: Icons.inventory_2_outlined,
            accent: BafColors.maintenance,
            title: 'History access required',
            message:
                'An approved app account is required to view closed records.',
          );
        }
        return const SizedBox.shrink();
      },
    );
    return Stack(
      children: [
        ExcludeFocus(
          excluding: !allowed,
          child: Offstage(
            offstage: !allowed,
            child: _lastVerifiedActor == null
                ? const SizedBox.shrink()
                : _ClosedTicketsBody(
                    key: ValueKey(_lastVerifiedActor!.uid),
                    actor: _lastVerifiedActor!,
                  ),
          ),
        ),
        if (!allowed) accessState,
      ],
    );
  }
}
