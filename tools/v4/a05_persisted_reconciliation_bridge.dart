import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';

const _supportedCollections = <String>{
  'asset_classes',
  'asset_component_instances',
  'asset_hierarchy_nodes',
  'asset_instances',
  'asset_tag_claims',
  'audit_logs',
  'maintenance_records',
};

Future<void> main() async {
  try {
    final input = jsonDecode(await stdin.transform(utf8.decoder).join());
    stdout.write(jsonEncode(reconcileA05Envelope(input)));
  } catch (_) {
    stderr.write('A-05 reconciliation bridge rejected its input.');
    exitCode = 64;
  }
}

Map<String, Object?> reconcileA05Envelope(dynamic input) {
  if (input is! Map || input['records'] is! List) {
    throw const FormatException('invalid bridge envelope');
  }
  final results = <Map<String, Object?>>[];
  for (final rawRecord in input['records'] as List<dynamic>) {
    results.add(_reconcileRecord(rawRecord));
  }
  return <String, Object?>{
    'schemaVersion': 1,
    'supportedCollections': _supportedCollections.toList()..sort(),
    'results': results,
  };
}

Map<String, Object?> _reconcileRecord(dynamic rawRecord) {
  String? pseudonym;
  String? collection;
  try {
    if (rawRecord is! Map) throw const FormatException('record must be a map');
    pseudonym = _requiredString(rawRecord['subjectPseudonym']);
    collection = _requiredString(rawRecord['collection']);
    final documentId = _requiredString(rawRecord['documentId']);
    final restored = _restoreFirestoreValue(rawRecord['data']);
    if (restored is! Map) throw const FormatException('data must be a map');
    final data = Map<String, dynamic>.from(restored);

    switch (collection) {
      case 'asset_classes':
        AssetClassRecord.fromMap(data, documentId);
      case 'asset_hierarchy_nodes':
        AssetHierarchyNode.fromMap(data, documentId);
      case 'asset_instances':
        AssetInstanceRecord.fromMap(data, documentId);
      case 'asset_component_instances':
        InstalledComponentRecord.fromMap(data, documentId);
      case 'asset_tag_claims':
        AssetTagClaimRecord.fromMap(data, documentId);
      case 'audit_logs':
        decodePersistedAuditEvent(data, documentId: documentId);
      case 'maintenance_records':
        readRemoteMaintenanceRecord(data, documentId: documentId);
      default:
        throw UnsupportedError('unsupported collection');
    }
    return <String, Object?>{
      'collection': collection,
      'subjectPseudonym': pseudonym,
      'result': 'PASS',
    };
  } catch (error) {
    return <String, Object?>{
      if (collection != null) 'collection': collection,
      if (pseudonym != null) 'subjectPseudonym': pseudonym,
      'result': 'FAIL',
      'errorType': switch (error) {
        PersistedDataFormatException() => 'PERSISTED_DATA_FORMAT',
        UnsupportedError() => 'UNSUPPORTED_COLLECTION',
        _ => 'DECODER_REJECTION',
      },
      if (error is PersistedDataFormatException) 'field': error.fieldName,
    };
  }
}

dynamic _restoreFirestoreValue(dynamic value) {
  if (value is List) return value.map(_restoreFirestoreValue).toList();
  if (value is! Map) return value;
  if (value['__a05FirestoreType'] == 'timestamp') {
    final seconds = value['seconds'];
    final nanoseconds = value['nanoseconds'];
    if (seconds is! int || nanoseconds is! int) {
      throw const FormatException('invalid timestamp transport');
    }
    return Timestamp(seconds, nanoseconds);
  }
  if (value['__a05FirestoreType'] == 'nonFiniteNumber') {
    return switch (value['value']) {
      'NaN' => double.nan,
      'Infinity' => double.infinity,
      '-Infinity' => double.negativeInfinity,
      _ => throw const FormatException('invalid non-finite transport'),
    };
  }
  return Map<String, dynamic>.fromEntries(
    value.entries.map(
      (entry) => MapEntry(
        _requiredString(entry.key),
        _restoreFirestoreValue(entry.value),
      ),
    ),
  );
}

String _requiredString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  throw const FormatException('required string missing');
}
