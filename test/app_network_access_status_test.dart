import 'dart:io';

import 'package:crm3_baf_ops/core/services/app_network_access_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// On 2026-09-09 the app reported that synchronization had failed while a
/// healthy Wi-Fi network was connected. It had not failed: Android was
/// refusing this UID's requests with BLOCKED_REASON_APP_BACKGROUND because
/// the app had been in the background for over an hour. The existing
/// connectivity listener could not tell the two apart, and the operator was
/// left believing their work was lost.
///
/// These tests hold the new signal to distinguishing them, and to staying
/// silent when the platform has not actually said anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'in.co.sail.bsl.crm3.bafops/network_access';

  group('wire decoding', () {
    test('maps every status the platform reports', () {
      expect(
        AppNetworkAccess.fromWireName('allowed'),
        AppNetworkAccess.allowed,
      );
      expect(
        AppNetworkAccess.fromWireName('blocked'),
        AppNetworkAccess.blocked,
      );
      expect(
        AppNetworkAccess.fromWireName('noNetwork'),
        AppNetworkAccess.noNetwork,
      );
    });

    test('an unrecognised value is unknown, never allowed or blocked', () {
      // Guessing either way would put an unproven claim in front of an
      // operator deciding whether their work is safe.
      expect(AppNetworkAccess.fromWireName(null), AppNetworkAccess.unknown);
      expect(AppNetworkAccess.fromWireName('future'), AppNetworkAccess.unknown);
      expect(AppNetworkAccess.fromWireName(7), AppNetworkAccess.unknown);
    });
  });

  group('operator wording', () {
    test('blocked explains the pause without claiming loss or failure', () {
      final message = AppNetworkAccess.blocked.operatorExplanation!;

      expect(message, contains('Android has paused'));
      expect(message, contains('will be sent'));
      // The incident's actual harm was the word "failed" in front of work
      // that was intact and waiting.
      expect(message.toLowerCase(), isNot(contains('failed')));
      expect(message.toLowerCase(), isNot(contains('lost')));
    });

    test('a missing network is not described as a block', () {
      expect(
        AppNetworkAccess.noNetwork.operatorExplanation,
        'No network connection.',
      );
    });

    test('allowed and unknown contribute no wording of their own', () {
      expect(AppNetworkAccess.allowed.operatorExplanation, isNull);
      expect(AppNetworkAccess.unknown.operatorExplanation, isNull);
    });

    test('only blocked predicts that requests will be refused', () {
      expect(AppNetworkAccess.blocked.willRefuseRequests, isTrue);
      expect(AppNetworkAccess.allowed.willRefuseRequests, isFalse);
      expect(AppNetworkAccess.noNetwork.willRefuseRequests, isFalse);
      expect(AppNetworkAccess.unknown.willRefuseRequests, isFalse);
    });
  });

  group('the indicator explains the pause instead of reporting a fault', () {
    late String source;

    setUpAll(() {
      source =
          File(
            'lib/core/widgets/sync_status_indicator.dart',
          ).readAsStringSync();
    });

    test('a blocked state is labelled as paused, not as an issue', () {
      expect(source, contains("label: 'Paused by Android'"));
      expect(source, contains('networkAccess.willRefuseRequests'));
    });

    test('the pause is decided before the failure label', () {
      // Otherwise a refused request still reads as a red fault.
      expect(
        source.indexOf('networkAccess.willRefuseRequests'),
        lessThan(source.indexOf("label: 'Sync issue'")),
      );
    });

    test('conflicts still outrank the pause', () {
      // A resumed network does not resolve a data disagreement.
      expect(
        source.indexOf('conflictCount > 0'),
        lessThan(source.indexOf('networkAccess.willRefuseRequests')),
      );
    });

    test('the detail sheet carries the full explanation', () {
      expect(source, contains('networkAccessExplanation'));
      expect(source, contains('appNetworkAccessProvider'));
    });
  });

  group('platform stream', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .setMockStreamHandler(const EventChannel(channelName), null);
    });

    test('reports the sequence the platform emits', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel(channelName),
            _ScriptedStreamHandler(<String>['blocked', 'allowed']),
          );

      final statuses =
          await AppNetworkAccessStatus(
            platform: TargetPlatform.android,
          ).watch().take(2).toList();

      expect(statuses, <AppNetworkAccess>[
        AppNetworkAccess.blocked,
        AppNetworkAccess.allowed,
      ]);
    });

    test('non-Android platforms claim nothing', () async {
      final status =
          await AppNetworkAccessStatus(
            platform: TargetPlatform.iOS,
          ).watch().first;

      expect(status, AppNetworkAccess.unknown);
    });
  });
}

class _ScriptedStreamHandler extends MockStreamHandler {
  _ScriptedStreamHandler(this.events);

  final List<String> events;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink sink) {
    for (final event in events) {
      sink.success(event);
    }
  }

  @override
  void onCancel(Object? arguments) {}
}
