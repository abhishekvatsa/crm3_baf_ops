part of 'ticket_screen.dart';

class _TicketCardMenuAction {
  const _TicketCardMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

List<_TicketCardMenuAction> _ticketCardSecondaryActions({
  required VoidCallback onViewDetails,
  required bool canRefreshServer,
  required VoidCallback onRefreshServer,
  required VoidCallback? onViewEventLinks,
  required VoidCallback? onOpenCoordination,
  required bool canManageLanes,
  required VoidCallback onManageLanes,
  required bool canRepairLaneData,
  required VoidCallback onRepairLaneData,
}) => <_TicketCardMenuAction>[
  _TicketCardMenuAction(
    label: 'View complete record',
    icon: Icons.article_outlined,
    onSelected: onViewDetails,
  ),
  if (canRefreshServer)
    _TicketCardMenuAction(
      label: 'Refresh this issue from server',
      icon: Icons.cloud_sync_rounded,
      onSelected: onRefreshServer,
    ),
  if (onViewEventLinks != null)
    _TicketCardMenuAction(
      label: 'Linked operational events',
      icon: Icons.link_rounded,
      onSelected: onViewEventLinks,
    ),
  if (onOpenCoordination != null)
    _TicketCardMenuAction(
      label: 'Open Operations coordination',
      icon: Icons.handshake_outlined,
      onSelected: onOpenCoordination,
    ),
  if (canManageLanes)
    _TicketCardMenuAction(
      label: 'Manage accountable lanes',
      icon: Icons.account_tree_rounded,
      onSelected: onManageLanes,
    ),
  if (canRepairLaneData)
    _TicketCardMenuAction(
      label: 'Repair issue from server',
      icon: Icons.build_circle_outlined,
      onSelected: onRepairLaneData,
    ),
];
