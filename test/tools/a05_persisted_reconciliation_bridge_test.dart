import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/v4/a05_persisted_reconciliation_bridge.dart';

void main() {
  final bridgeUrl = Platform.environment['A05_BRIDGE_URL'] ?? '';
  final bridgeToken = Platform.environment['A05_BRIDGE_TOKEN'] ?? '';
  test(
    'reconciles an in-memory production envelope through app readers',
    () async {
      final client = HttpClient();
      try {
        final inputRequest = await client.getUrl(Uri.parse('$bridgeUrl/input'));
        inputRequest.headers.set('authorization', 'Bearer $bridgeToken');
        final inputResponse = await inputRequest.close();
        if (inputResponse.statusCode != HttpStatus.ok) {
          throw StateError('bridge input rejected');
        }
        final input = jsonDecode(
          await inputResponse.transform(utf8.decoder).join(),
        );
        final output = reconcileA05Envelope(input);

        final outputRequest = await client.postUrl(
          Uri.parse('$bridgeUrl/output'),
        );
        outputRequest.headers
          ..set('authorization', 'Bearer $bridgeToken')
          ..contentType = ContentType.json;
        outputRequest.write(jsonEncode(output));
        final outputResponse = await outputRequest.close();
        await outputResponse.drain<void>();
        if (outputResponse.statusCode != HttpStatus.noContent) {
          throw StateError('bridge output rejected');
        }
      } finally {
        client.close(force: true);
      }
    },
    skip: bridgeUrl.isEmpty || bridgeToken.isEmpty,
  );
}
