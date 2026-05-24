// FILE: lib/core/providers/sync_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prevents multiple sync triggers on app startup.
final syncOnceProvider = StateProvider<bool>((ref) => false);