import 'dart:convert';

/// Compares persisted JSON by value so map insertion order cannot create a
/// false synchronization conflict.
bool persistedJsonEquivalent(String? left, String? right) {
  if (left == null && right == null) return true;
  if (left == null || right == null) return false;

  try {
    return _jsonValueEquivalent(jsonDecode(left), jsonDecode(right));
  } on FormatException {
    return false;
  }
}

bool _jsonValueEquivalent(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_jsonValueEquivalent(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    if (left.length != right.length ||
        !left.keys.toSet().containsAll(right.keys)) {
      return false;
    }
    for (final key in left.keys) {
      if (!_jsonValueEquivalent(left[key], right[key])) return false;
    }
    return true;
  }
  return false;
}
