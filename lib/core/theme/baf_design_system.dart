// FILE: lib/core/theme/baf_design_system.dart

import 'package:flutter/material.dart';

class BafColors {
  BafColors._();

  static const navy = Color(0xFF102A36);
  static const navySoft = Color(0xFF1F5366);
  static const steel = Color(0xFF466873);
  static const background = Color(0xFFF1F4F3);
  static const card = Colors.white;
  static const surfaceMuted = Color(0xFFE8EEEC);
  static const surfaceStrong = Color(0xFFDDE6E3);
  static const border = Color(0xFFD5DEDB);
  static const textPrimary = Color(0xFF132A33);
  static const textSecondary = Color(0xFF53676D);

  static const maintenance = Color(0xFFB94718);
  static const planned = Color(0xFF176B87);
  static const directives = Color(0xFFB8323F);
  static const audit = Color(0xFF6A5188);
  static const charges = Color(0xFF087A73);
  static const assets = Color(0xFF3A6D52);
  static const admin = Color(0xFF48565D);
  static const sync = Color(0xFF2F7D4A);
  static const copper = Color(0xFFA85B2A);
  static const instrument = Color(0xFF5C5F9D);

  static const success = Color(0xFF2F7D4A);
  static const warning = Color(0xFF95580C);
  static const danger = Color(0xFFC4343D);
}

class BafRadius {
  BafRadius._();

  static const small = 6.0;
  static const medium = 8.0;
  static const large = 10.0;
  static const xLarge = 12.0;
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
      color: BafColors.navy.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: BafColors.navy.withValues(alpha: 0.055),
      blurRadius: 8,
      offset: const Offset(0, 3),
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
