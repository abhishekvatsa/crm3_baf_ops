import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

const String globalPullServerUpdatedAtField = '_globalPullServerUpdatedAt';
const String globalPullProtocolFingerprint =
    'cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321';
const String globalPullWriterVersion = 'global-pull-server-stamp-v1';
const int globalPullProtocolVersion = 1;
const String globalPullCallableRegion = 'asia-south1';
const String globalPullBeginCallableName = 'beginGlobalPullRun';

enum GlobalPullDomain {
  abnormalityTypes('abnormality_types'),
  chargeAbnormalities('charge_abnormalities'),
  directives('directives'),
  jobDiaryEntries('job_diary_entries'),
  jobExecutions('job_executions'),
  jobModules('job_modules'),
  jobTemplates('job_templates'),
  knowledgeBase('knowledge_base'),
  maintenanceRecords('maintenance_records'),
  templatePackages('template_packages'),
  templatePublishAudits('template_publish_audits'),
  templateVersions('template_versions');

  final String wireName;

  const GlobalPullDomain(this.wireName);

  static GlobalPullDomain fromWireName(String value) {
    return values.firstWhere(
      (domain) => domain.wireName == value,
      orElse:
          () =>
              throw const GlobalPullProtocolException(
                'The global pull domain is unknown.',
                reasonCode: 'unknown-domain',
              ),
    );
  }
}

const List<String> globalPullProtocolCollections = <String>[
  'abnormality_types',
  'charge_abnormalities',
  'directives',
  'job_diary_entries',
  'job_executions',
  'job_modules',
  'job_templates',
  'knowledge_base',
  'maintenance_records',
  'template_packages',
  'template_publish_audits',
  'template_versions',
];

class GlobalPullProtocolException implements Exception {
  final String message;
  final String reasonCode;

  const GlobalPullProtocolException(this.message, {required this.reasonCode});

  @override
  String toString() =>
      'GlobalPullProtocolException(reason=$reasonCode, message=$message)';
}

class GlobalPullRunAuthority {
  static const Set<String> _exactKeys = <String>{
    'actorUid',
    'authorityDigest',
    'protocolVersion',
    'protocolFingerprint',
    'writerVersion',
    'serverStampField',
    'collections',
    'activatedAt',
    'serverAnchor',
  };

  final String actorUid;
  final String authorityDigest;
  final DateTime activatedAt;
  final DateTime serverAnchor;

  const GlobalPullRunAuthority({
    required this.actorUid,
    required this.authorityDigest,
    required this.activatedAt,
    required this.serverAnchor,
  });

  factory GlobalPullRunAuthority.fromCallableData(
    Object? value, {
    required String expectedUid,
  }) {
    if (value is! Map) {
      throw const GlobalPullProtocolException(
        'The global pull authority response is not an object.',
        reasonCode: 'authority-not-object',
      );
    }
    final data = Map<String, Object?>.from(value);
    if (data.keys.toSet().difference(_exactKeys).isNotEmpty ||
        _exactKeys.difference(data.keys.toSet()).isNotEmpty) {
      throw const GlobalPullProtocolException(
        'The global pull authority response has an unsupported shape.',
        reasonCode: 'authority-invalid-shape',
      );
    }

    if (data['actorUid'] != expectedUid) {
      throw const GlobalPullProtocolException(
        'The global pull authority response belongs to another actor.',
        reasonCode: 'authority-actor-mismatch',
      );
    }
    final authorityDigest = data['authorityDigest'];
    if (authorityDigest is! String ||
        !RegExp(r'^auth1-sha256:[0-9a-f]{64}$').hasMatch(authorityDigest)) {
      throw const GlobalPullProtocolException(
        'The global pull authority digest is invalid.',
        reasonCode: 'authority-digest-invalid',
      );
    }
    if (data['protocolVersion'] != globalPullProtocolVersion ||
        data['protocolFingerprint'] != globalPullProtocolFingerprint ||
        data['writerVersion'] != globalPullWriterVersion ||
        data['serverStampField'] != globalPullServerUpdatedAtField) {
      throw const GlobalPullProtocolException(
        'The backend global pull protocol is incompatible with this client.',
        reasonCode: 'authority-protocol-mismatch',
      );
    }

    final collections = data['collections'];
    if (collections is! List ||
        collections.length != globalPullProtocolCollections.length ||
        !Iterable<int>.generate(collections.length).every(
          (index) => collections[index] == globalPullProtocolCollections[index],
        )) {
      throw const GlobalPullProtocolException(
        'The backend global pull collection set is incompatible.',
        reasonCode: 'authority-collection-set-mismatch',
      );
    }

    final activatedAt = _parseUtcInstant(
      data['activatedAt'],
      reasonCode: 'authority-activated-at-invalid',
    );
    final serverAnchor = _parseUtcInstant(
      data['serverAnchor'],
      reasonCode: 'authority-server-anchor-invalid',
    );
    if (serverAnchor.isBefore(activatedAt)) {
      throw const GlobalPullProtocolException(
        'The global pull server anchor predates protocol activation.',
        reasonCode: 'authority-server-anchor-before-activation',
      );
    }

    return GlobalPullRunAuthority(
      actorUid: expectedUid,
      authorityDigest: authorityDigest,
      activatedAt: activatedAt,
      serverAnchor: serverAnchor,
    );
  }

  static DateTime _parseUtcInstant(
    Object? value, {
    required String reasonCode,
  }) {
    if (value is! String) {
      throw GlobalPullProtocolException(
        'The global pull authority timestamp is not a string.',
        reasonCode: reasonCode,
      );
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !value.endsWith('Z')) {
      throw GlobalPullProtocolException(
        'The global pull authority timestamp is not a canonical UTC instant.',
        reasonCode: reasonCode,
      );
    }
    return parsed.toUtc();
  }
}

abstract interface class GlobalPullAuthorityReader {
  Future<GlobalPullRunAuthority> beginRun({required String expectedUid});
}

class FirebaseGlobalPullAuthorityReader implements GlobalPullAuthorityReader {
  final FirebaseFunctions? functions;

  const FirebaseGlobalPullAuthorityReader({this.functions});

  FirebaseFunctions get _client =>
      functions ??
      FirebaseFunctions.instanceFor(region: globalPullCallableRegion);

  @override
  Future<GlobalPullRunAuthority> beginRun({required String expectedUid}) async {
    final result =
        await _client.httpsCallable(globalPullBeginCallableName).call();
    return GlobalPullRunAuthority.fromCallableData(
      result.data,
      expectedUid: expectedUid,
    );
  }
}

Query<Map<String, dynamic>> globalPullServerWindowQuery(
  CollectionReference<Map<String, dynamic>> collection, {
  DateTime? afterInclusive,
  required DateTime throughInclusive,
}) {
  var query = collection
      .where(
        globalPullServerUpdatedAtField,
        isLessThanOrEqualTo: Timestamp.fromDate(throughInclusive.toUtc()),
      )
      .orderBy(globalPullServerUpdatedAtField);
  if (afterInclusive != null) {
    query = query.where(
      globalPullServerUpdatedAtField,
      isGreaterThanOrEqualTo: Timestamp.fromDate(afterInclusive.toUtc()),
    );
  }
  return query;
}

DateTime globalPullServerTimestampFromDocument(
  DocumentSnapshot<Map<String, dynamic>> document,
) {
  final value = document.data()?[globalPullServerUpdatedAtField];
  if (value is! Timestamp) {
    throw const GlobalPullProtocolException(
      'A global pull document has no valid server-authored timestamp.',
      reasonCode: 'document-server-timestamp-invalid',
    );
  }
  return value.toDate().toUtc();
}
