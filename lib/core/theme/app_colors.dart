import 'package:flutter/material.dart';

import 'baf_design_system.dart';

class AppColors {
  static const navy = BafColors.graphite;

  // ── Department / Agency Colors ────────────────────────────────────────────
  static Color agencyColor(String agency) {
    switch (agency) {
      case 'electrical':
        return BafColors.warning;
      case 'mechanical':
        return BafColors.cobalt;
      case 'instrumentation':
        return BafColors.instrument;
      case 'refractory':
        return BafColors.maintenance;
      case 'emd':
        return BafColors.charges;
      case 'operations':
        return BafColors.assets;
      case 'shiftInCharge':
        return BafColors.audit;
      default:
        return BafColors.admin;
    }
  }

  // ── Ticket Status Colors ──────────────────────────────────────────────────
  static Color statusColor(bool isResolved) {
    return isResolved ? BafColors.success : BafColors.warning;
  }

  static Color statusBackground(bool isResolved) {
    return isResolved
        ? BafColors.success.withValues(alpha: 0.08)
        : BafColors.warning.withValues(alpha: 0.08);
  }
}
