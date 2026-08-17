import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart';

final _root = Directory.current;
final _manifestFile = File(
  '${_root.path}${Platform.pathSeparator}governance${Platform.pathSeparator}a04-persisted-schema-v1.json',
);
final _a05ManifestFile = File(
  '${_root.path}${Platform.pathSeparator}governance${Platform.pathSeparator}a05-persisted-decoder-surface-v1.json',
);

const _nestedPersistedClasses = <String>{
  'ComponentAction',
  'FieldResponse',
  'TemplateField',
};
const _nestedDynamicFields = <String>{
  'extensions',
  'meta',
  'validation',
  'value',
};

void main(List<String> arguments) {
  final fields = _discoverFields();
  final a05 = jsonDecode(_a05ManifestFile.readAsStringSync()) as Map;
  final inherited =
      (a05['surfaces'] as List)
          .cast<Map>()
          .map(
            (surface) => <String, Object?>{
              'id': surface['id'] as String,
              'file': surface['file'] as String,
              'classification': surface['classification'] as String,
              'authorityBoundary': surface['authorityBoundary'] as String,
              'malformedDisposition': surface['malformedDisposition'] as String,
              'compatibility': surface['compatibility'] as String,
              'regression': surface['regression'] as String,
            },
          )
          .toList()
        ..sort(
          (left, right) =>
              (left['id']! as String).compareTo(right['id']! as String),
        );

  final stable = <String, Object?>{
    'fields': fields,
    'inheritedDecoderSurfaces': inherited,
    'a05ManifestSha256': _sha256File(_a05ManifestFile),
  };
  final digest =
      sha256.convert(utf8.encode(jsonEncode(stable))).toString().toUpperCase();

  if (arguments.contains('--write-manifest')) {
    final manifest = <String, Object?>{
      'schemaVersion': 1,
      'findingId': 'A-04',
      'title': 'Persisted dynamic-map and JSON schema inventory',
      'inventoryDigest': digest,
      'a05DecoderManifest': _relative(_a05ManifestFile.path),
      'a05ManifestSha256': stable['a05ManifestSha256'],
      'decision':
          'Every source-declared persisted JSON field and nested dynamic value is schema-bearing. Root persisted maps inherit the complete strict A-05 decoder inventory. No unregistered extension key is accepted.',
      'fields': fields,
      'inheritedDecoderSurfaces': inherited,
      'extensionPolicy': <String, Object?>{
        'maximumEntries': 8,
        'maximumEncodedBytes': 8192,
        'registeredFields': <String, Object?>{},
        'authorityOrBusinessInvariantFieldsAllowed': false,
        'unknownPresentDisposition': 'FAIL_CLOSED_PENDING_REPAIR',
        'legacyAbsentSchemaVersion':
            'Read as version 0 and canonicalized to schemaVersion 1 on the next governed write.',
      },
      'supportedLocalGenerationDisposition': <String, Object?>{
        'fixture': 'test/70k_isar_populated_migration_fixture_test.dart',
        'compatibleLegacyPayloads':
            'Strictly decode without mutation; nested version 0 payloads canonicalize only on a governed write.',
        'incompatiblePayloads':
            'Preserve raw bytes and block authoritative use pending repair; never silently rewrite.',
      },
      'regressions': <String>[
        'test/a04_persisted_schema_contract_test.dart',
        'test/a05_component_action_integrity_test.dart',
        'test/a05_response_payload_integrity_test.dart',
        'test/a05_template_composer_integrity_test.dart',
        'test/70k_isar_populated_migration_fixture_test.dart',
      ],
    };
    _manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
  }

  final failures = _verify(
    fields,
    inherited,
    digest,
    stable['a05ManifestSha256']! as String,
  );
  final report = <String, Object?>{
    'findingId': 'A-04',
    'gitHead': _gitHead(),
    'fieldCount': fields.length,
    'jsonStringFieldCount':
        fields.where((field) => field['kind'] == 'JSON_STRING').length,
    'dynamicValueFieldCount':
        fields.where((field) => field['kind'] == 'DYNAMIC_JSON_VALUE').length,
    'extensionBagCount':
        fields
            .where(
              (field) =>
                  field['classification'] == 'BOUNDED_REGISTERED_EXTENSION_BAG',
            )
            .length,
    'registeredExtensionFieldCount': 0,
    'inheritedDecoderSurfaceCount': inherited.length,
    'inventoryDigest': digest,
    'result': failures.isEmpty ? 'PASS' : 'FAIL',
    'failures': failures,
  };
  if (arguments.contains('--discover')) report['fields'] = fields;
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  if (failures.isNotEmpty) exitCode = 1;
}

List<Map<String, Object?>> _discoverFields() {
  final fields = <Map<String, Object?>>[];
  final files =
      Directory('${_root.path}${Platform.pathSeparator}lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final result = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      throwIfDiagnostics: false,
    );
    for (final declaration
        in result.unit.declarations.whereType<ClassDeclaration>()) {
      final className = declaration.name.lexeme;
      final annotations =
          declaration.metadata.map((item) => item.name.name).toSet();
      final persistedClass =
          annotations.contains('Collection') ||
          annotations.contains('collection') ||
          annotations.contains('embedded') ||
          _nestedPersistedClasses.contains(className);
      if (!persistedClass) continue;

      for (final member in declaration.members.whereType<FieldDeclaration>()) {
        if (member.isStatic) continue;
        final type = member.fields.type?.toSource() ?? '';
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final isJsonString =
              type.startsWith('String') &&
              fieldName.toLowerCase().contains('json');
          final isNestedDynamic =
              _nestedPersistedClasses.contains(className) &&
              _nestedDynamicFields.contains(fieldName);
          if (!isJsonString && !isNestedDynamic) continue;
          fields.add(
            _fieldPolicy(
              path: _relative(file.path),
              className: className,
              fieldName: fieldName,
              type: type,
              kind: isJsonString ? 'JSON_STRING' : 'DYNAMIC_JSON_VALUE',
            ),
          );
        }
      }
    }
  }
  fields.sort(
    (left, right) => (left['id']! as String).compareTo(right['id']! as String),
  );
  return fields;
}

Map<String, Object?> _fieldPolicy({
  required String path,
  required String className,
  required String fieldName,
  required String type,
  required String kind,
}) {
  final policy = _policyId(className, fieldName);
  final extension = fieldName == 'extensions';
  return <String, Object?>{
    'id': '$path::$className::$fieldName',
    'path': path,
    'class': className,
    'field': fieldName,
    'declaredType': type,
    'kind': kind,
    'classification':
        extension
            ? 'BOUNDED_REGISTERED_EXTENSION_BAG'
            : 'SCHEMA_BEARING_PAYLOAD',
    'policy': policy,
    'decoderContract': _decoderContract(policy),
    'malformedPresentDisposition': 'FAIL_CLOSED_PENDING_REPAIR',
    'compatibility':
        extension
            ? 'No historical unknown key is authority. Unregistered present keys require governed repair.'
            : 'Documented absent legacy shape only; present malformed or unsupported versions fail closed.',
    'regression': _regressionFor(path, fieldName),
  };
}

String _policyId(String className, String fieldName) {
  if (fieldName == 'extensions') return 'registered-extension-bag-v1';
  if (fieldName == 'value') return 'bounded-response-json-union-v1';
  if (fieldName == 'validation' || fieldName == 'validationJson') {
    return 'template-field-validation-v1';
  }
  if (fieldName == 'meta') return 'template-field-authoring-meta-v1';
  if (fieldName == 'beforeJson' || fieldName == 'afterJson') {
    return 'immutable-audit-object-v1';
  }
  if (fieldName == 'rawJson') return 'knowledge-source-snapshot-v1';
  if (fieldName == 'affectedAssetsJson') return 'affected-asset-list-v1';
  if (fieldName == 'assetHierarchyRefJson') {
    return 'asset-hierarchy-reference-v2';
  }
  if (fieldName == 'actionsJson') return 'component-action-list-v1';
  if (fieldName == 'responsesJson') return 'field-response-list-v1';
  if (fieldName == 'fieldsJson' || fieldName == 'fieldDefinitionsJson') {
    return 'field-definition-list-v1';
  }
  if (fieldName == 'resolutionHistoryJson') {
    return 'maintenance-resolution-history-v1';
  }
  if (fieldName == 'activeExecutionIdsJson' || fieldName == 'actorRolesJson') {
    return 'strict-string-list-v1';
  }
  if (fieldName == 'moduleSnapshotsJson' || fieldName == 'checklistJson') {
    return 'template-snapshot-list-v1';
  }
  if (fieldName == 'jobTemplateSnapshotJson' ||
      fieldName == 'moduleSnapshotJson' ||
      fieldName == 'payloadSnapshotJson' ||
      fieldName == 'payloadJson' ||
      fieldName == 'receiptJson' ||
      fieldName == 'resultJson' ||
      fieldName == 'lineageJson' ||
      fieldName == 'lineageSummaryJson' ||
      fieldName == 'pairedEquipmentJson') {
    return 'strict-typed-json-object-v1';
  }
  if (fieldName == 'safetyGatePolicyJson') {
    return 'safety-gate-policy-object-v1';
  }
  if (fieldName == 'metadataJson') {
    return className == 'MaintenanceRecord'
        ? 'maintenance-metadata-envelope-v1'
        : 'bounded-metadata-object-v1';
  }
  return 'strict-typed-json-payload-v1';
}

String _decoderContract(String policy) {
  if (policy == 'registered-extension-bag-v1') {
    return 'readBoundedPersistedExtensionBag plus an explicit field/type registry; current registry is empty.';
  }
  if (policy == 'bounded-response-json-union-v1') {
    return 'FieldResponse schemaVersion plus readBoundedPersistedJsonValue.';
  }
  if (policy == 'component-action-list-v1') {
    return 'ComponentAction schemaVersion and strict typed field decoder.';
  }
  if (policy == 'field-response-list-v1') {
    return 'FieldResponse schemaVersion and bounded JSON value decoder.';
  }
  if (policy == 'template-field-validation-v1' ||
      policy == 'template-field-authoring-meta-v1' ||
      policy == 'field-definition-list-v1') {
    return 'TemplateField schemaVersion, typed aliases and bounded JSON-object readers.';
  }
  return 'Owning typed A-05 decoder surface and strict persisted-data reader; malformed present values are never defaulted.';
}

String _regressionFor(String path, String fieldName) {
  if (path.endsWith('component_action_model.dart') ||
      fieldName == 'actionsJson') {
    return 'test/a05_component_action_integrity_test.dart';
  }
  if (fieldName == 'responsesJson' || fieldName == 'value') {
    return 'test/a05_response_payload_integrity_test.dart';
  }
  if (path.endsWith('job_template_model.dart')) {
    return 'test/a05_template_composer_integrity_test.dart';
  }
  return 'test/a04_persisted_schema_contract_test.dart';
}

List<String> _verify(
  List<Map<String, Object?>> fields,
  List<Map<String, Object?>> inherited,
  String digest,
  String a05Sha,
) {
  final failures = <String>[];
  if (!_manifestFile.existsSync()) return ['A-04 manifest is missing'];
  final manifest = jsonDecode(_manifestFile.readAsStringSync()) as Map;
  if (manifest['schemaVersion'] != 1 || manifest['findingId'] != 'A-04') {
    failures.add('manifest identity is invalid');
  }
  if (manifest['inventoryDigest'] != digest) {
    failures.add('inventory digest drift');
  }
  if (manifest['a05ManifestSha256'] != a05Sha) {
    failures.add('inherited A-05 decoder manifest drift');
  }
  final expectedFields = jsonEncode(manifest['fields']);
  if (expectedFields != jsonEncode(fields)) failures.add('field policy drift');
  final expectedInherited = jsonEncode(manifest['inheritedDecoderSurfaces']);
  if (expectedInherited != jsonEncode(inherited)) {
    failures.add('inherited decoder surface drift');
  }
  final extension = manifest['extensionPolicy'] as Map?;
  if (extension == null ||
      extension['authorityOrBusinessInvariantFieldsAllowed'] != false ||
      (extension['registeredFields'] as Map?)?.isNotEmpty == true) {
    failures.add('extension-bag authority boundary is not fail closed');
  }

  final reader =
      File(
        '${_root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}core${Platform.pathSeparator}serialization${Platform.pathSeparator}persisted_data_reader.dart',
      ).readAsStringSync();
  for (final marker in const <String>[
    'readBoundedPersistedExtensionBag(',
    'validateBoundedPersistedExtensionBag(',
    'readPersistedPayloadSchemaVersion(',
    'readBoundedPersistedJsonValue(',
  ]) {
    if (!reader.contains(marker)) failures.add('missing strict reader $marker');
  }
  for (final path in const <String>[
    'lib/features/planned_maintenance/models/component_action_model.dart',
    'lib/features/planned_maintenance/data/job_template_model.dart',
  ]) {
    final source =
        File(
          '${_root.path}${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}',
        ).readAsStringSync();
    if (!source.contains('_allowedExtensions')) {
      failures.add('$path has no registered extension policy');
    }
  }
  return failures;
}

String _sha256File(File file) =>
    sha256.convert(file.readAsBytesSync()).toString().toUpperCase();

String _relative(String path) => path
    .substring(_root.path.length + 1)
    .replaceAll(Platform.pathSeparator, '/');

String _gitHead() {
  final result = Process.runSync('git', const [
    'rev-parse',
    'HEAD',
  ], workingDirectory: _root.path);
  return result.exitCode == 0 ? (result.stdout as String).trim() : 'UNKNOWN';
}
