import 'dart:math' as math;

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  return (math.max(firstLuminance, secondLuminance) + 0.05) /
      (math.min(firstLuminance, secondLuminance) + 0.05);
}

void main() {
  const semanticForegrounds = <String, Color>{
    'navy': BafColors.navy,
    'navySoft': BafColors.navySoft,
    'textPrimary': BafColors.textPrimary,
    'textSecondary': BafColors.textSecondary,
    'maintenance': BafColors.maintenance,
    'planned': BafColors.planned,
    'directives': BafColors.directives,
    'audit': BafColors.audit,
    'charges': BafColors.charges,
    'assets': BafColors.assets,
    'admin': BafColors.admin,
    'sync': BafColors.sync,
    'success': BafColors.success,
    'warning': BafColors.warning,
    'danger': BafColors.danger,
  };

  test('semantic foreground colors meet WCAG AA on light surfaces', () {
    for (final entry in semanticForegrounds.entries) {
      expect(
        contrastRatio(entry.value, BafColors.card),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} must remain readable on cards',
      );
      expect(
        contrastRatio(entry.value, BafColors.background),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} must remain readable on the app background',
      );
    }
  });

  test('module and status colors support white foreground actions', () {
    const filledActionColors = <String, Color>{
      'maintenance': BafColors.maintenance,
      'planned': BafColors.planned,
      'directives': BafColors.directives,
      'audit': BafColors.audit,
      'charges': BafColors.charges,
      'assets': BafColors.assets,
      'admin': BafColors.admin,
      'sync': BafColors.sync,
      'instrument': BafColors.instrument,
      'success': BafColors.success,
      'warning': BafColors.warning,
      'danger': BafColors.danger,
    };
    for (final entry in filledActionColors.entries) {
      expect(
        contrastRatio(entry.value, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} must support white action text and icons',
      );
    }
  });
}
