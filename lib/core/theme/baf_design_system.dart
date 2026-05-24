// FILE: lib/core/theme/baf_design_system.dart

import 'package:flutter/material.dart';

class BafColors {
  BafColors._();

  static const navy = Color(0xFF0B1F3A);
  static const navySoft = Color(0xFF1B3A6B);
  static const background = Color(0xFFF6F8FB);
  static const card = Colors.white;
  static const border = Color(0xFFE4EAF2);
  static const textPrimary = Color(0xFF0B1F3A);
  static const textSecondary = Color(0xFF52667A);

  static const maintenance = Color(0xFFF97316);
  static const planned = Color(0xFF1D74B8);
  static const directives = Color(0xFFD62828);
  static const audit = Color(0xFF5B3FA3);
  static const charges = Color(0xFF0F8B8D);
  static const assets = Color(0xFF1B4F72);
  static const admin = Color(0xFF374151);
  static const sync = Color(0xFF2E7D32);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD62828);
}

class BafRadius {
  BafRadius._();

  static const small = 10.0;
  static const medium = 14.0;
  static const large = 20.0;
  static const xLarge = 26.0;
}

class BafSpacing {
  BafSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

class BafShadows {
  BafShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.035),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

class ModuleVisual {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const ModuleVisual({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class BafModules {
  BafModules._();

  static const maintenance = ModuleVisual(
    title: 'Maintenance',
    description: 'Corrective work & breakdown management',
    icon: Icons.build_rounded,
    color: BafColors.maintenance,
  );

  static const planned = ModuleVisual(
    title: 'Planned Maintenance',
    description: 'Preventive maintenance & job plans',
    icon: Icons.event_note_rounded,
    color: BafColors.planned,
  );

  static const directives = ModuleVisual(
    title: 'Directives',
    description: 'Policies, procedures and instructions',
    icon: Icons.assignment_late_rounded,
    color: BafColors.directives,
  );

  static const audit = ModuleVisual(
    title: 'Audit',
    description: 'Traceability and action history',
    icon: Icons.verified_user_rounded,
    color: BafColors.audit,
  );

  static const charges = ModuleVisual(
    title: 'Charges',
    description: 'People, teams and responsibility',
    icon: Icons.engineering_rounded,
    color: BafColors.charges,
  );

  static const assets = ModuleVisual(
    title: 'Assets',
    description: 'Equipment, locations and asset context',
    icon: Icons.precision_manufacturing_rounded,
    color: BafColors.assets,
  );

  static const admin = ModuleVisual(
    title: 'Admin',
    description: 'Users, roles, settings and data control',
    icon: Icons.storage_rounded,
    color: BafColors.admin,
  );

  static const sync = ModuleVisual(
    title: 'Sync',
    description: 'Offline reliability and data sync',
    icon: Icons.cloud_sync_rounded,
    color: BafColors.sync,
  );
}