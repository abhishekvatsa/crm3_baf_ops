import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
// SYNC STATUS ENUM
// ─────────────────────────────────────────────────────────────

enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
}

// ─────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────

// 🔥 Centralized, single source of truth for sync UI state
final syncStatusProvider =
StateProvider<SyncStatus>((ref) => SyncStatus.idle);

// ─────────────────────────────────────────────────────────────
// OPTIONAL HELPERS (NON-BREAKING, FUTURE-SAFE)
// ─────────────────────────────────────────────────────────────

// These helpers are NOT required by current UI,
// but allow future extensions without refactoring.

extension SyncStatusX on SyncStatus {
  bool get isBusy => this == SyncStatus.syncing;

  bool get isSuccess => this == SyncStatus.success;

  bool get isFailure => this == SyncStatus.failed;

  bool get isIdle => this == SyncStatus.idle;
}