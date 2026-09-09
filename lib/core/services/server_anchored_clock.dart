import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authoritative "now" for locally persisted timestamps that are later
/// compared against server timestamps.
///
/// Plant handsets are not disciplined to the backend clock. A device running
/// ahead of the server stamps local rows with instants the server will never
/// produce. During ingest that makes a *higher* server version look stale
/// against the clean local row, which blocks domain cursor completion and
/// stalls the whole pull behind it. Every persisted timestamp that participates
/// in remote-freshness arbitration must therefore come from this clock rather
/// than from [DateTime.now].
///
/// The anchor is the `serverAnchor` the backend already returns from
/// `beginGlobalPullRun`; no additional round trip is introduced. Until an
/// anchor has been observed the clock falls back to the device clock, so a
/// first-run offline write behaves exactly as it did before.
class ServerAnchoredClock {
  ServerAnchoredClock._();

  static const _offsetMicrosecondsKey = 'serverAnchoredClock.offsetMicroseconds';
  static const _measuredAtKey = 'serverAnchoredClock.measuredAtMicroseconds';

  /// An offset beyond this is treated as corrupt rather than as a real skew.
  /// Applying a wild offset would be worse than applying none, because it would
  /// place local evidence far outside any window the server can corroborate.
  static const maximumPlausibleOffset = Duration(hours: 24);

  static Duration _offset = Duration.zero;
  static bool _anchored = false;
  static DateTime Function() _deviceNow = DateTime.now;

  /// Device time shifted onto the server's timeline.
  static DateTime now() => _deviceNow().add(_offset);

  /// Whether a server anchor has been observed in this session or restored
  /// from a previous one. Callers that need to reason about evidence quality
  /// can record this alongside the timestamp.
  static bool get isAnchored => _anchored;

  /// The correction currently applied to the device clock. Positive means the
  /// device is running behind the server; negative means it is running ahead.
  static Duration get offset => _offset;

  /// Adopts a server instant as the reference point.
  ///
  /// [deviceObservedAt] is the device reading taken as close as possible to the
  /// moment [serverAnchor] arrived. The anchor was generated before the
  /// response completed its return leg, so the derived offset is slightly
  /// conservative: it biases local timestamps marginally *earlier* than true
  /// server time, which is the safe direction for freshness arbitration.
  static void anchorToServer({
    required DateTime serverAnchor,
    DateTime? deviceObservedAt,
  }) {
    final observed = (deviceObservedAt ?? _deviceNow()).toUtc();
    final candidate = serverAnchor.toUtc().difference(observed);
    if (candidate.abs() > maximumPlausibleOffset) {
      debugPrint(
        'ServerAnchoredClock: rejecting implausible offset '
        '${candidate.inSeconds}s; retaining ${_offset.inSeconds}s.',
      );
      return;
    }
    _offset = candidate;
    _anchored = true;
    _persist(candidate, observed);
  }

  /// Restores the last known offset so that a write made before the first
  /// successful pull of a session is still anchored. A plant handset is
  /// frequently offline at launch, which is exactly when an unanchored write
  /// would otherwise reintroduce the defect.
  static Future<void> restorePersistedOffset() async {
    if (_anchored) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final micros = prefs.getInt(_offsetMicrosecondsKey);
      if (micros == null) return;
      final candidate = Duration(microseconds: micros);
      if (candidate.abs() > maximumPlausibleOffset) return;
      _offset = candidate;
      _anchored = true;
    } catch (error) {
      // A preferences failure must never prevent the app from writing. An
      // unanchored clock is a degradation, not a fault.
      debugPrint('ServerAnchoredClock: offset restore skipped ($error).');
    }
  }

  static void _persist(Duration offset, DateTime measuredAt) {
    SharedPreferences.getInstance()
        .then((prefs) async {
          await prefs.setInt(_offsetMicrosecondsKey, offset.inMicroseconds);
          await prefs.setInt(
            _measuredAtKey,
            measuredAt.microsecondsSinceEpoch,
          );
        })
        .catchError((Object error) {
          debugPrint('ServerAnchoredClock: offset persist skipped ($error).');
        });
  }

  /// Test seam. Mirrors the injectable `now` used by the operations report
  /// clock so anchored behaviour can be exercised deterministically.
  @visibleForTesting
  static void overrideDeviceClock(DateTime Function() deviceNow) {
    _deviceNow = deviceNow;
  }

  @visibleForTesting
  static void reset() {
    _offset = Duration.zero;
    _anchored = false;
    _deviceNow = DateTime.now;
  }
}
