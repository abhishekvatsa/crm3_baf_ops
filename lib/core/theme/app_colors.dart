import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const navy = Color(0xFF1B3A6B);

  // ── Department / Agency Colors ────────────────────────────────────────────
  static Color agencyColor(String agency) {
    switch (agency) {
      case 'electrical':      return Colors.amber.shade700;
      case 'mechanical':      return Colors.blue.shade700;
      case 'instrumentation': return Colors.purple.shade600;
      case 'refractory':      return Colors.red.shade700;
      case 'emd':             return Colors.teal.shade600;
      case 'operations':      return Colors.green.shade700;
      case 'shiftInCharge':   return Colors.indigo.shade600;
      default:                return Colors.grey.shade600;
    }
  }

  // ── Ticket Status Colors ──────────────────────────────────────────────────
  static Color statusColor(bool isResolved) {
    return isResolved ? Colors.green.shade700 : Colors.orange.shade700;
  }

  static Color statusBackground(bool isResolved) {
    return isResolved ? Colors.green.shade50 : Colors.orange.shade50;
  }
}