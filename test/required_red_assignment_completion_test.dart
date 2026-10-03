import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/required_red_journey.dart'
    show
        waitRequiredRedAutomaticReturn,
        returnRequiredRedHome,
        writeRequiredRedRelayControlBody;

// This is a real Navigator/Material route regression for the two asynchronous
// boundaries in PublishedTemplateAssignmentScreen._submit: server observation
// may precede controller.check/local adoption, then Navigator.pop animates.
// The gate is a host-only timing fixture, not business/server acceptance.
void main() {
  _relayFramingTests();
  testWidgets(
    'RED waits past server observation, local reply and route disposal',
    (tester) async {
      final fixture = await _show(tester);
      await tester.tap(find.text('Assign Published Job'));
      await tester.pump();
      expect(fixture.state.serverObserved, isTrue);
      expect(find.text('Work overview'), findsNothing);
      expect(fixture.pops, isEmpty);
      final timer = Timer(
        const Duration(milliseconds: 600),
        () => fixture.reply.complete(),
      );
      addTearDown(timer.cancel);

      await waitRequiredRedAutomaticReturn(tester, fixture.route);

      expect(fixture.state.disposed, isTrue);
      expect(fixture.pops, [fixture.route]);
      expect(find.text('Work overview'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RED observes an already self-popping route without extra Back', (
    tester,
  ) async {
    final fixture = await _show(tester);
    await tester.tap(find.text('Assign Published Job'));
    fixture.reply.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.route.isCurrent, isFalse);
    expect(fixture.state.disposed, isFalse);
    expect(fixture.route.animation!.status, AnimationStatus.reverse);

    await waitRequiredRedAutomaticReturn(tester, fixture.route);

    expect(fixture.state.disposed, isTrue);
    expect(fixture.pops, [fixture.route]);
    expect(find.text('Work overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RED accepts a route already completely returned after the tap', (
    tester,
  ) async {
    final fixture = await _show(tester);
    await tester.tap(find.text('Assign Published Job'));
    fixture.reply.complete();
    await tester.pumpAndSettle();
    expect(fixture.state.disposed, isTrue);

    await waitRequiredRedAutomaticReturn(tester, fixture.route, maxPumps: 2);

    expect(fixture.pops, [fixture.route]);
    expect(find.text('Work overview'), findsOneWidget);
  });

  testWidgets('RED Home rechecks automatic return during Back preflight', (
    tester,
  ) async {
    final fixture = await _show(tester);
    await tester.tap(find.text('Assign Published Job'));
    await tester.pump();
    final timer = Timer(
      const Duration(milliseconds: 100),
      () => fixture.reply.complete(),
    );
    addTearDown(timer.cancel);
    await returnRequiredRedHome(tester, find.text('Work overview'));
    expect(fixture.state.disposed, isTrue);
    expect(fixture.pops, [fixture.route]);
    expect(find.text('Work overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RED Home waits through slow reverse without destination Back', (
    tester,
  ) async {
    final fixture = await _show(tester);
    await tester.tap(find.text('Assign Published Job'));
    fixture.reply.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.route.animation!.status, AnimationStatus.reverse);
    await returnRequiredRedHome(tester, find.text('Work overview'));
    expect(fixture.state.disposed, isTrue);
    expect(fixture.pops, [fixture.route]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RED Home uses one real Back gesture for a stable child route', (
    tester,
  ) async {
    final fixture = await _show(tester);
    await returnRequiredRedHome(tester, find.text('Work overview'));
    expect(fixture.state.disposed, isTrue);
    expect(fixture.pops, [fixture.route]);
    expect(find.text('Work overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RED Home never taps a retained Back under a modal overlay', (
    tester,
  ) async {
    final fixture = await _show(tester);
    final context = tester.element(find.byType(_Assignment));
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(content: Text('Pending review')),
      ),
    );
    await tester.pumpAndSettle();
    Object? failure;
    try {
      await returnRequiredRedHome(
        tester,
        find.text('Work overview'),
        maxPumps: 4,
      );
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<TestFailure>());
    expect(fixture.pops, isEmpty);
    expect(find.text('Pending review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('RED Home fails bounded if the current route refuses Back', (
    tester,
  ) async {
    final fixture = await _show(tester, preventPop: true);
    Object? failure;
    try {
      await returnRequiredRedHome(
        tester,
        find.text('Work overview'),
        maxPumps: 4,
        popPumps: 4,
      );
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<TestFailure>());
    expect(fixture.pops, isEmpty);
    expect(fixture.backAttempts, 1);
    expect(fixture.state.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final refused in [false, true]) {
    testWidgets(
      'RED fails bounded when assignment has not returned: refused=$refused',
      (tester) async {
        final fixture = await _show(tester);
        await tester.tap(find.text('Assign Published Job'));
        if (refused) fixture.reply.completeError(StateError('Refused'));
        await tester.pump();
        Object? failure;
        try {
          await waitRequiredRedAutomaticReturn(
            tester,
            fixture.route,
            maxPumps: 4,
          );
        } catch (error) {
          failure = error;
        }
        expect(
          failure,
          isA<TestFailure>().having(
            (value) => value.message,
            'message',
            contains('finish leaving'),
          ),
        );
        expect(fixture.pops, isEmpty);
        expect(fixture.state.disposed, isFalse);
        expect(find.text('Work overview'), findsNothing);
        expect(
          find.text(refused ? 'Assignment refused' : 'Awaiting local reply'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        if (!refused) fixture.reply.complete();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<_Fixture> _show(WidgetTester tester, {bool preventPop = false}) async {
  final fixture = _Fixture(preventPop);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [_Pops(fixture.pops)],
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Work overview')),
          body: TextButton(
            onPressed: () => Navigator.of(context).push(fixture.route),
            child: const Text('Open assignment'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open assignment'));
  await tester.pumpAndSettle();
  fixture.state = tester.state<_AssignmentState>(find.byType(_Assignment));
  return fixture;
}

class _Fixture {
  _Fixture(this.preventPop);
  final bool preventPop;
  var backAttempts = 0;
  final reply = Completer<void>();
  final pops = <Route<dynamic>>[];
  late final route = _SlowReturnRoute(
    builder: (_) => PopScope<void>(
      canPop: !preventPop,
      onPopInvokedWithResult: (didPop, result) => backAttempts++,
      child: _Assignment(reply),
    ),
  );
  late _AssignmentState state;
}

class _SlowReturnRoute extends MaterialPageRoute<void> {
  _SlowReturnRoute({required super.builder});
  @override
  Duration get reverseTransitionDuration => const Duration(seconds: 2);
}

class _Pops extends NavigatorObserver {
  _Pops(this.pops);
  final List<Route<dynamic>> pops;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops.add(route);
    super.didPop(route, previousRoute);
  }
}

class _Assignment extends StatefulWidget {
  const _Assignment(this.reply);
  final Completer<void> reply;
  @override
  State<_Assignment> createState() => _AssignmentState();
}

class _AssignmentState extends State<_Assignment> {
  bool serverObserved = false;
  bool disposed = false;
  String? status;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      serverObserved = true;
      status = 'Awaiting local reply';
    });
    try {
      await widget.reply.future;
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => status = 'Assignment refused');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assign planned work')),
    body: Column(
      children: [
        if (status != null) Text(status!),
        FilledButton(
          onPressed: serverObserved ? null : submit,
          child: const Text('Assign Published Job'),
        ),
      ],
    ),
  );
}

// Real dart:io requests reach the checked-in Python HTTP handler on an ephemeral
// loopback port. Receipt priming is an explicit synthetic protocol fixture only;
// no Functions, Android, Firebase credentials or business acceptance is involved.
void _relayFramingTests() {
  const identity = <String, Object?>{
    'project': 'demo-crm3-ci-journeys',
    'workflowId': 'red_aaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'complianceId': 'red_aaaaaaaaaaaaaaaaaaaaaaaaaaaa_preparation',
    'actorUid': 'demo-operations',
  };
  test(
    'RED control sends bounded UTF-8 bytes for real arm and release',
    () async {
      final fixture = await _RelayFramingFixture.start();
      addTearDown(fixture.close);
      expect((await fixture.control('arm', identity))['status'], 200);
      final armed = await fixture.command('snapshot');
      expect(
        armed['headers']['length'],
        '${utf8.encode(jsonEncode(identity)).length}',
      );
      expect(armed['headers']['transferEncoding'], isNull);
      expect(armed['lastArmBody'], identity);
      expect(armed['state']['phase'], 'armed');
      expect(
        (await fixture.command('primeSyntheticReceipt'))['phase'],
        'withheld',
      );
      expect(
        (await fixture.control('release', {
          'commandId': 'framing-command-1',
        }))['status'],
        200,
      );
      final released = await fixture.command('snapshot');
      expect(released['state']['phase'], 'released');
      expect(released['headers']['transferEncoding'], isNull);
      expect(
        (await fixture.control('arm', identity))['status'],
        400,
        reason: 'Exact framing does not permit re-arming a used relay.',
      );
    },
  );
  test(
    'RED UTF-8 byte length survives Unicode before identity refusal',
    () async {
      final fixture = await _RelayFramingFixture.start();
      addTearDown(fixture.close);
      final unicode = {...identity, 'actorUid': 'opérations-已检查'};
      final encoded = jsonEncode(unicode);
      expect(utf8.encode(encoded).length, greaterThan(encoded.length));
      expect((await fixture.control('arm', unicode))['status'], 400);
      final observed = await fixture.command('snapshot');
      expect(observed['headers']['length'], '${utf8.encode(encoded).length}');
      expect(observed['headers']['transferEncoding'], isNull);
      expect(
        observed['lastArmBody'],
        unicode,
        reason:
            'The real parser received all bytes; exact identity still rejects Unicode.',
      );
      expect(observed['state']['phase'], 'idle');
    },
  );
  test(
    'real relay keeps rejecting absent invalid and chunked framing',
    () async {
      final fixture = await _RelayFramingFixture.start();
      addTearDown(fixture.close);
      for (final headers in <String>[
        '',
        'Content-Length: nope\r\n',
        'Content-Length: -1\r\n',
        'Content-Length: 0\r\n',
        'Content-Length: 2097153\r\n',
        'Transfer-Encoding: chunked\r\n',
        'Content-Length: 2\r\nTransfer-Encoding: chunked\r\n',
      ]) {
        final response = await fixture.raw(headers);
        expect(response, startsWith('HTTP/1.1 400'), reason: headers);
        final state = await fixture.command('snapshot');
        expect(state['state']['phase'], 'idle');
        expect(
          state['lastArmBody'],
          isNull,
          reason: 'Rejected framing must not enter the identity/state handler.',
        );
      }
    },
  );
}

// A real client for the fixed loopback fixture only; no global HTTP override.
class _LoopbackHttpFactory extends HttpOverrides {}

class _RelayFramingFixture {
  _RelayFramingFixture(this.process, this.lines, this.port);
  final Process process;
  final StreamIterator<String> lines;
  final int port;
  static Future<_RelayFramingFixture> start() async {
    final process = await Process.start(
      Platform.isWindows ? 'python' : 'python3',
      ['-B', '-X', 'utf8', '-u', '-c', _relayFramingPython],
      workingDirectory: Directory.current.path,
    );
    process.stderr.drain<void>();
    final lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    if (!await lines.moveNext().timeout(const Duration(seconds: 10))) {
      throw StateError('The loopback protocol fixture did not start.');
    }
    final ready = jsonDecode(lines.current) as Map<String, dynamic>;
    return _RelayFramingFixture(process, lines, ready['port'] as int);
  }

  Future<Map<String, dynamic>> command(String name) async {
    process.stdin.writeln(name);
    await process.stdin.flush();
    if (!await lines.moveNext().timeout(const Duration(seconds: 5))) {
      throw StateError('The loopback protocol fixture ended before $name.');
    }
    return jsonDecode(lines.current) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> control(
    String action,
    Map<String, Object?> body,
  ) async {
    final client = _LoopbackHttpFactory().createHttpClient(null)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/__required_red/$action'),
      );
      request.followRedirects = false;
      writeRequiredRedRelayControlBody(request, body);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final payload = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 5));
      return {'status': response.statusCode, 'body': jsonDecode(payload)};
    } finally {
      client.close(force: true);
    }
  }

  Future<String> raw(String headers) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 5),
    );
    try {
      socket.write(
        'POST /__required_red/arm HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nConnection: close\r\n$headers\r\n{}',
      );
      await socket.flush();
      return await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
    } finally {
      socket.destroy();
    }
  }

  Future<void> close() async {
    await command('stop');
    await process.stdin.close();
    expect(await process.exitCode.timeout(const Duration(seconds: 5)), 0);
    await lines.cancel();
  }
}

const _relayFramingPython = r'''
import json, sys, threading
from http.server import ThreadingHTTPServer
from pathlib import Path
sys.path.insert(0, str(Path.cwd() / 'tools' / 'testing'))
from required_red_transport_relay import Handler, ReceiptLoss, TARGET
class ObservedLoss(ReceiptLoss):
    last_arm = None
    def arm(self, value):
        self.last_arm = value
        return super().arm(value)
class ObservedHandler(Handler):
    loss = ObservedLoss()
    seen = None
    def do_POST(self):
        type(self).seen = {'length': self.headers.get('Content-Length'),
                          'transferEncoding': self.headers.get('Transfer-Encoding')}
        super().do_POST()
server = ThreadingHTTPServer(('127.0.0.1', 0), ObservedHandler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
print(json.dumps({'port': server.server_port}), flush=True)
for line in sys.stdin:
    command = line.strip()
    loss = ObservedHandler.loss
    if command == 'snapshot':
        value = {'headers': ObservedHandler.seen, 'lastArmBody': loss.last_arm,
                 'state': loss.status()}
    elif command == 'primeSyntheticReceipt':
        state = loss.status()
        envelope = {'data': {'protocolVersion': 2, 'originActorUid': state['actorUid'],
            'command': {'commandId': 'framing-command-1', 'commandType': 'acknowledgeCompliance',
            'aggregateId': state['workflowId'], 'expectedVersion': 1,
            'payload': {'complianceId': state['complianceId'], 'expectedComplianceVersion': 1}}}}
        assert loss.inspect(TARGET, json.dumps(envelope).encode()) == 'capture'
        result = {'commandId': 'framing-command-1', 'resultKey': 'compliance-acknowledged',
            'aggregateVersion': 2, 'appliedAt': '2026-10-03T00:00:00.123Z',
            'result': {'complianceId': state['complianceId']}}
        assert loss.accepted(200, json.dumps({'result': result}).encode())
        value = loss.status()
    elif command == 'stop':
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)
        print(json.dumps({'stopped': True}), flush=True)
        break
    else:
        raise ValueError('Unknown fixture command')
    print(json.dumps(value, ensure_ascii=False), flush=True)
''';
