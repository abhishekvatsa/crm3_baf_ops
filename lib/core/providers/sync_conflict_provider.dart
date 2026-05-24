// FILE: lib/core/providers/sync_conflict_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the count of conflicts detected during the last sync.
/// Resets to 0 after being displayed to the user.
final syncConflictProvider = StateProvider<int>((ref) => 0);