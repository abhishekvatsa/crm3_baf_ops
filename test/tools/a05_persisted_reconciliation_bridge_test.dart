import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/v4/a05_persisted_reconciliation_bridge.dart';

void main() {
  test(
    'correction evidence reaches the app decoder and malformed rows remain blocked',
    () {
      final correction = <String, Object?>{
        'schemaVersion': 1,
        'version': 1,
        'correctionId': 'correction-1',
        'correctsEventId': 'event-a',
        'expectedCurrentEventId': 'event-a',
        'assetInstanceId': 'furnace-a',
        'burnerPosition': 1,
        'recordedActionPerformedAt': '2026-09-18T10:00:00.000Z',
        'correctedActionPerformedAt': <String, Object?>{
          '__a05FirestoreType': 'timestamp',
          'seconds':
              DateTime.utc(2026, 9, 17, 10).millisecondsSinceEpoch ~/ 1000,
          'nanoseconds': 0,
        },
        'correctedAt': '2026-09-20T10:00:00.000Z',
        'reason': 'Correct the recorded physical time.',
        'correctedByUid': 'reviewer-a',
        'correctedByName': 'Reviewer A',
        'supersedesCorrectionId': null,
      };
      final result = reconcileA05Envelope({
        'records': [
          {
            'collection': 'burner_block_lifecycle_corrections',
            'subjectPseudonym': 'valid-subject',
            'documentId': 'correction-1',
            'data': correction,
          },
          {
            'collection': 'burner_block_lifecycle_corrections',
            'subjectPseudonym': 'invalid-subject',
            'documentId': 'correction-1',
            'data': {...correction, 'correctedByUid': null},
          },
        ],
      });
      expect(
        result['supportedCollections'],
        contains('burner_block_lifecycle_corrections'),
      );
      expect(result['results'], [
        {
          'collection': 'burner_block_lifecycle_corrections',
          'subjectPseudonym': 'valid-subject',
          'result': 'PASS',
        },
        {
          'collection': 'burner_block_lifecycle_corrections',
          'subjectPseudonym': 'invalid-subject',
          'result': 'FAIL',
          'errorType': 'PERSISTED_DATA_FORMAT',
          'field': 'correctedByUid',
        },
      ]);
      expect(jsonEncode(result), isNot(contains('reviewer-a')));
      expect(jsonEncode(result), isNot(contains('furnace-a')));
    },
  );

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
