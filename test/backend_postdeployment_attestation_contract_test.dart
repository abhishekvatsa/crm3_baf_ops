import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _canonicalJson(dynamic value) {
  if (value is List<dynamic>) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:'
    '${_canonicalJson(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}

String _digest(Map<String, dynamic> document, String field) {
  final clone = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
  clone.remove(field);
  return sha256
      .convert(utf8.encode(_canonicalJson(clone)))
      .toString()
      .toUpperCase();
}

void _validateExactSchema(
  dynamic instance,
  Map<String, dynamic> schema, [
  String location = r'$',
]) {
  if (schema.containsKey('const')) {
    expect(instance, schema['const'], reason: '$location const mismatch');
  }

  switch (schema['type']) {
    case 'object':
      expect(instance, isA<Map<String, dynamic>>(), reason: location);
      expect(schema['additionalProperties'], isFalse, reason: location);
      final properties = schema['properties'] as Map<String, dynamic>;
      final required =
          (schema['required'] as List<dynamic>).cast<String>()..sort();
      final propertyKeys = properties.keys.toList()..sort();
      expect(required, propertyKeys, reason: '$location required mismatch');
      final instanceKeys =
          (instance as Map<String, dynamic>).keys.toList()..sort();
      expect(instanceKeys, propertyKeys, reason: '$location key mismatch');
      for (final key in propertyKeys) {
        _validateExactSchema(
          instance[key],
          properties[key] as Map<String, dynamic>,
          '$location.$key',
        );
      }
    case 'array':
      expect(instance, isA<List<dynamic>>(), reason: location);
      expect(schema.containsKey('const'), isTrue, reason: location);
    case 'string':
      expect(instance, isA<String>(), reason: location);
    case 'integer':
      expect(instance, isA<int>(), reason: location);
    case 'boolean':
      expect(instance, isA<bool>(), reason: location);
    case 'null':
      expect(instance, isNull, reason: location);
    default:
      fail('Unsupported schema type at $location: ${schema['type']}');
  }
}

void main() {
  test('all production records satisfy fully closed exact schemas', () {
    final pairs = <(String, String)>[
      (
        'release/backend-identity-deployment-attestation.prod.json',
        'release/backend-identity-deployment-attestation-v1.schema.json',
      ),
      (
        'release/backend-security-readiness.prod.json',
        'release/backend-security-readiness-v1.schema.json',
      ),
      (
        'release/backend-current-state.prod.json',
        'release/backend-current-state-v1.schema.json',
      ),
    ];

    for (final pair in pairs) {
      _validateExactSchema(_readJson(pair.$1), _readJson(pair.$2));
    }
  });

  test('canonical digests and current-state joins reproduce exactly', () {
    final authority = _readJson('release/backend-authority.prod.json');
    final attestation = _readJson(
      'release/backend-identity-deployment-attestation.prod.json',
    );
    final security = _readJson('release/backend-security-readiness.prod.json');
    final current = _readJson('release/backend-current-state.prod.json');

    expect(
      _digest(attestation, 'attestationDigest'),
      attestation['attestationDigest'],
    );
    expect(_digest(security, 'securityDigest'), security['securityDigest']);
    expect(_digest(current, 'indexDigest'), current['indexDigest']);

    expect(
      (attestation['authorityDefinition']
          as Map<String, dynamic>)['authorityDigest'],
      authority['authorityDigest'],
    );
    expect(
      (current['deploymentAttestation'] as Map<String, dynamic>)['digest'],
      attestation['attestationDigest'],
    );
    expect(
      (current['securityReadiness'] as Map<String, dynamic>)['digest'],
      security['securityDigest'],
    );
  });

  test('deployment and private source archive custody remain exact', () {
    final attestation = _readJson(
      'release/backend-identity-deployment-attestation.prod.json',
    );
    final deployment = attestation['deployment'] as Map<String, dynamic>;
    expect(
      deployment['sourceCommit'],
      '08afc4f3020359fcdfeed472d7f4ba6b01084d44',
    );
    expect(
      deployment['currentRevision'],
      'getbackendreleaseidentity-00002-wud',
    );
    expect(deployment['currentSourceGeneration'], '1782928076881189');
    expect(
      deployment['deployedArchiveSha256'],
      '692E41AAD6755B362D391736947434FD0BAFBE4F78F57C0D49056BE452FE158D',
    );
    expect(deployment['trafficPercentToCurrentRevision'], 100);

    final evidence = attestation['evidence'] as Map<String, dynamic>;
    final custody = evidence['privateArchiveCustody'] as Map<String, dynamic>;
    expect(custody['archiveIncludedInSafeEvidence'], isFalse);
    expect(custody['containsProjectEnvironmentFile'], isTrue);
    expect(custody['projectEnvironmentFilename'], '.env.crm3-baf-ops-b8638');
    expect(custody['handlingRequirement'], 'KEEP_PRIVATE_DO_NOT_UPLOAD');
  });
}
