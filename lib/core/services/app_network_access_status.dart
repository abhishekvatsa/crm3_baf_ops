import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Android currently permits this application's own network use.
///
/// A connectivity check answers a different question: it reports whether the
/// device has a network. On 2026-09-09 it answered yes for ninety minutes
/// while every request from this application's UID was refused with
/// `BLOCKED_REASON_APP_BACKGROUND`, so the app told the operator that
/// synchronization had failed. It had not failed; it had not been permitted to
/// run. Those two need different words in front of a person deciding whether
/// their work is safe.
enum AppNetworkAccess {
  /// The platform permits this application to use the network.
  allowed,

  /// A network exists, but this application's UID may not use it. Ordinarily
  /// because the app is in the background and not exempt.
  blocked,

  /// There is no usable network at all.
  noNetwork,

  /// The platform exposes no per-UID blocked signal here, so nothing may be
  /// claimed either way.
  unknown;

  static AppNetworkAccess fromWireName(Object? value) {
    return switch (value) {
      'allowed' => AppNetworkAccess.allowed,
      'blocked' => AppNetworkAccess.blocked,
      'noNetwork' => AppNetworkAccess.noNetwork,
      _ => AppNetworkAccess.unknown,
    };
  }

  /// Whether a synchronization attempt is expected to be refused before it
  /// reaches the network.
  bool get willRefuseRequests => this == AppNetworkAccess.blocked;

  /// What to tell an operator, or null when the platform said nothing useful
  /// and the caller should keep its existing wording.
  ///
  /// The blocked wording deliberately does not say the work is lost or that
  /// anything failed, because neither is true: it is waiting.
  String? get operatorExplanation => switch (this) {
    AppNetworkAccess.blocked =>
      'Android has paused background use of the network for this app. '
          'Saved work will be sent when the app is opened.',
    AppNetworkAccess.noNetwork => 'No network connection.',
    AppNetworkAccess.allowed => null,
    AppNetworkAccess.unknown => null,
  };
}

/// Streams the platform's per-UID network blocked status.
///
/// Only Android reports this. Every other platform yields [unknown] once, so
/// callers keep whatever wording they already use rather than inventing a
/// state the platform never confirmed.
class AppNetworkAccessStatus {
  AppNetworkAccessStatus({EventChannel? channel, TargetPlatform? platform})
    : _channel = channel ?? const EventChannel(_channelName),
      _platform = platform;

  static const String _channelName =
      'in.co.sail.bsl.crm3.bafops/network_access';

  final EventChannel _channel;
  final TargetPlatform? _platform;

  Stream<AppNetworkAccess>? _stream;

  bool get _isSupported {
    if (kIsWeb) return false;
    return (_platform ?? defaultTargetPlatform) == TargetPlatform.android;
  }

  Stream<AppNetworkAccess> watch() {
    if (!_isSupported) {
      return Stream<AppNetworkAccess>.value(AppNetworkAccess.unknown);
    }
    return _stream ??= _channel
        .receiveBroadcastStream()
        .map(AppNetworkAccess.fromWireName)
        // A channel failure must not be reported as a block, and must not
        // leave the last value standing either: swallowing the error would
        // keep showing "blocked" long after the platform stopped saying so.
        // Fall back to unknown, which claims nothing.
        .transform(
          StreamTransformer<AppNetworkAccess, AppNetworkAccess>.fromHandlers(
            handleError: (Object _, StackTrace __, EventSink<AppNetworkAccess> sink) {
              sink.add(AppNetworkAccess.unknown);
            },
          ),
        )
        .asBroadcastStream();
  }
}

/// Live per-UID network permission for the running app.
///
/// Yields [AppNetworkAccess.unknown] until the platform reports, so callers
/// never show a blocked explanation the platform has not confirmed.
final appNetworkAccessProvider = StreamProvider<AppNetworkAccess>((ref) {
  return AppNetworkAccessStatus().watch();
});
