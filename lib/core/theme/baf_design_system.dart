// FILE: lib/core/theme/baf_design_system.dart

import 'package:flutter/material.dart';

class BafBrand {
  BafBrand._();

  static const productName = 'CRM-III BAF Ops';
  static const plantName = 'SAIL Bokaro Steel Plant';
  static const makerName = 'A ManMithas Productions';
  static const makerLabel = 'A MANMITHAS PRODUCTIONS';
  static const markAsset = 'assets/brand/manmithas_mark.png';
}

class BafColors {
  BafColors._();

  static const graphite = Color(0xFF172128);
  static const graphiteSoft = Color(0xFF26343C);
  static const teal = Color(0xFF0E7A7E);
  static const cobalt = Color(0xFF3267B1);
  static const ember = Color(0xFFC84C36);

  // Compatibility aliases retained for feature modules using the earlier
  // design-system vocabulary.
  static const navy = graphite;
  static const navySoft = teal;
  static const steel = Color(0xFF60737C);
  static const copper = ember;

  static const background = Color(0xFFF5F7F8);
  static const card = Colors.white;
  static const surfaceMuted = Color(0xFFEDF1F3);
  static const surfaceStrong = Color(0xFFE3EAED);
  static const border = Color(0xFFD8E0E3);
  static const borderStrong = Color(0xFFBBC8CD);
  static const textPrimary = Color(0xFF18242B);
  static const textSecondary = Color(0xFF5A6A71);
  static const textTertiary = Color(0xFF7B8A90);

  static const maintenance = Color(0xFFB74632);
  static const planned = cobalt;
  static const directives = Color(0xFFA43E55);
  static const audit = Color(0xFF67579B);
  static const charges = Color(0xFF0B7C75);
  static const assets = Color(0xFF3D7458);
  static const admin = Color(0xFF53636B);
  static const sync = Color(0xFF2F7A4D);
  static const instrument = Color(0xFF5964A7);

  static const success = Color(0xFF2F7A4D);
  static const warning = Color(0xFF985C0A);
  static const danger = Color(0xFFBE3F4C);
  static const info = cobalt;
}

class BafRadius {
  BafRadius._();

  static const small = 6.0;
  static const medium = 8.0;
  static const large = 8.0;
  static const xLarge = 8.0;
}

class BafSpacing {
  BafSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class BafShadows {
  BafShadows._();

  static List<BoxShadow> soft = [
    const BoxShadow(
      color: Color(0x140F1E24),
      blurRadius: 18,
      offset: Offset(0, 7),
    ),
  ];

  static List<BoxShadow> subtle = [
    const BoxShadow(
      color: Color(0x0D0F1E24),
      blurRadius: 9,
      offset: Offset(0, 3),
    ),
  ];
}

class BafAppTheme {
  BafAppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: BafColors.teal,
      onPrimary: Colors.white,
      secondary: BafColors.cobalt,
      onSecondary: Colors.white,
      error: BafColors.danger,
      onError: Colors.white,
      surface: BafColors.card,
      onSurface: BafColors.textPrimary,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: BafColors.background,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
        headlineSmall: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        titleSmall: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        bodyLarge: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 13,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: BafColors.textSecondary,
          fontSize: 12,
          height: 1.35,
        ),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x140F1E24),
        centerTitle: false,
        toolbarHeight: 60,
        titleSpacing: BafSpacing.lg,
        shape: Border(bottom: BorderSide(color: BafColors.border)),
        titleTextStyle: TextStyle(
          color: BafColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BafColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.md,
          vertical: BafSpacing.md,
        ),
        labelStyle: const TextStyle(color: BafColors.textSecondary),
        hintStyle: const TextStyle(color: BafColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: BafSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: BafSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: BafColors.textPrimary,
          side: const BorderSide(color: BafColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BafColors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: BafColors.textSecondary,
          minimumSize: const Size.square(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: BafColors.card,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
        ),
        indicatorColor: BafColors.teal.withValues(alpha: 0.11),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color:
                states.contains(WidgetState.selected)
                    ? BafColors.graphite
                    : BafColors.textSecondary,
            fontSize: 11,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? BafColors.teal
                    : BafColors.textSecondary,
            size: 23,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: BafColors.card,
        indicatorColor: Color(0x1C0E7A7E),
        selectedIconTheme: IconThemeData(color: BafColors.teal),
        unselectedIconTheme: IconThemeData(color: BafColors.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: BafColors.graphite,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: BafColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: BafColors.card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          side: const BorderSide(color: BafColors.border),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BafColors.textSecondary,
        textColor: BafColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: BafSpacing.md),
        minTileHeight: 52,
      ),
      dividerTheme: const DividerThemeData(
        color: BafColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BafColors.surfaceMuted,
        selectedColor: BafColors.teal.withValues(alpha: 0.12),
        side: const BorderSide(color: BafColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.small),
        ),
        labelStyle: const TextStyle(
          color: BafColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        dividerColor: BafColors.border,
        indicatorColor: BafColors.teal,
        labelColor: BafColors.textPrimary,
        unselectedLabelColor: BafColors.textSecondary,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BafColors.graphite,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BafColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BafColors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BafRadius.medium),
          ),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: BafColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BafRadius.medium)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BafColors.teal,
        linearTrackColor: BafColors.surfaceStrong,
        circularTrackColor: BafColors.surfaceStrong,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 1,
        backgroundColor: BafColors.ember,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BafRadius.medium)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? BafColors.teal
                    : BafColors.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? BafColors.teal.withValues(alpha: 0.1)
                    : BafColors.card,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: BafColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : BafColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? BafColors.teal
                  : BafColors.surfaceStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? BafColors.teal
                  : Colors.transparent,
        ),
        side: const BorderSide(color: BafColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? BafColors.teal
                  : BafColors.textTertiary,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: BafColors.graphite,
          borderRadius: BorderRadius.circular(BafRadius.small),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 450),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
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
