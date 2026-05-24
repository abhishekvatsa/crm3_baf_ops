// FILE: lib/core/providers/refresh_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment this counter to trigger a refresh on any screen that watches it.
/// For example, after closing a ticket, increment to make Closed Tickets screen reload.
final refreshClosedTicketsProvider = StateProvider<int>((ref) => 0);