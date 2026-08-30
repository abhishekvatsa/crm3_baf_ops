import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';

class CriticalAlarmStaleNotice extends StatelessWidget {
  const CriticalAlarmStaleNotice({
    super.key,
    required this.count,
    required this.lastVerifiedAt,
  });

  final int count;
  final DateTime? lastVerifiedAt;

  @override
  Widget build(BuildContext context) {
    final verifiedLabel =
        lastVerifiedAt == null
            ? 'Last verification time unavailable.'
            : 'Last server verification: '
                '${DateFormat('dd MMM yyyy, HH:mm').format(lastVerifiedAt!.toLocal())}.';
    return Container(
      key: const Key('critical-alarm-stale-feed-notice'),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.09),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: BafColors.warning),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Not live: showing $count last-known active '
              '${count == 1 ? 'alarm' : 'alarms'}. $verifiedLabel Follow the '
              'plant emergency procedure and retry the live check.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
