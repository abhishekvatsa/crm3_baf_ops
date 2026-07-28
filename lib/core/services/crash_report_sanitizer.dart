import 'dart:convert';

import 'package:crypto/crypto.dart';

/// An exception safe for transport to Crashlytics.
///
/// The original exception is deliberately not retained. Only its source type
/// survives so reports can still be grouped without uploading its message.
final class SanitizedCrashException implements Exception {
  final String errorType;

  const SanitizedCrashException(this.errorType);

  @override
  String toString() => 'SanitizedCrashException<$errorType>';
}

/// Fail-closed conversion of diagnostic values before remote crash reporting.
abstract final class CrashReportSanitizer {
  static const int _maxStackFrames = 64;
  static const int _maxSymbolLength = 120;

  static final RegExp _safeTypePattern = RegExp(r'^[A-Za-z0-9_.$<>-]+$');
  static final RegExp _safeStackFramePattern = RegExp(
    r'^\s*#(\d+)\s+([A-Za-z0-9_.$<>-]+)\s+'
    r'\((package:[A-Za-z0-9_./-]+|dart:[A-Za-z0-9_./-]+)'
    r'(?::(\d+))?(?::(\d+))?\)\s*$',
  );

  /// Produces an exception that contains no original message or fields.
  static SanitizedCrashException error(Object error) {
    return SanitizedCrashException(_safeTypeName(error.runtimeType.toString()));
  }

  /// Retains only source-controlled package/Dart frame identities.
  ///
  /// Absolute paths, file URIs, native frames and malformed lines are replaced
  /// with a fixed marker. The original stack string is never returned.
  static StackTrace stackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) {
      return StackTrace.fromString('#0 <stack-unavailable>');
    }

    final safeFrames = <String>[];
    for (final rawLine in const LineSplitter().convert(stackTrace.toString())) {
      if (safeFrames.length >= _maxStackFrames) {
        break;
      }

      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed == '<asynchronous suspension>') {
        safeFrames.add('<asynchronous suspension>');
        continue;
      }

      final match = _safeStackFramePattern.firstMatch(trimmed);
      if (match == null) {
        safeFrames.add('#${safeFrames.length} <redacted-frame>');
        continue;
      }

      final symbol = match.group(2)!;
      final safeSymbol =
          symbol.length <= _maxSymbolLength
              ? symbol
              : symbol.substring(0, _maxSymbolLength);
      final location = match.group(3)!;
      final line = match.group(4);
      final column = match.group(5);
      final suffix =
          line == null
              ? ''
              : column == null
              ? ':$line'
              : ':$line:$column';
      safeFrames.add('#${match.group(1)} $safeSymbol ($location$suffix)');
    }

    if (safeFrames.isEmpty) {
      safeFrames.add('#0 <stack-unavailable>');
    }
    return StackTrace.fromString(safeFrames.join('\n'));
  }

  /// Converts a source event label to a deterministic opaque identifier.
  static String eventId(String message) => 'event_${_fingerprint(message)}';

  /// Converts arbitrary context to opaque transport-safe metadata.
  ///
  /// Numeric and boolean telemetry is retained. Text and object values become
  /// an opaque type-tagged fingerprint; their original representation is never
  /// returned to the reporting SDK.
  static Object contextValue(Object? value) {
    if (value == null) return '';
    if (value is bool || value is int || value is double) return value;

    final type = _safeTypeName(value.runtimeType.toString()).toLowerCase();
    return '${type}_${_fingerprint(_stableText(value))}';
  }

  /// Keeps per-user report correlation without uploading the Firebase UID.
  static String userIdentifier(String uid) => 'uid_${_fingerprint(uid)}';

  static String _safeTypeName(String value) {
    if (_safeTypePattern.hasMatch(value) && value.length <= 96) {
      return value;
    }
    return 'UnknownErrorType';
  }

  static String _stableText(Object value) {
    try {
      return value.toString();
    } catch (_) {
      return value.runtimeType.toString();
    }
  }

  static String _fingerprint(String value) {
    return sha256.convert(utf8.encode(value)).toString().substring(0, 20);
  }
}
