import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../assets/data/asset_hierarchy_model.dart';

enum ComponentIntakeState { unidentified, unlisted, registered, wholeAsset }

extension ComponentIntakeLabel on ComponentIntakeState {
  String get label => switch (this) {
    ComponentIntakeState.unidentified => 'Not yet identified',
    ComponentIntakeState.unlisted => 'Known but not registered',
    ComponentIntakeState.registered => 'Registered component',
    ComponentIntakeState.wholeAsset => 'Whole asset',
  };
}

class MaintenanceComponentIdentification {
  const MaintenanceComponentIdentification({
    required this.version,
    required this.originalTicketVersion,
    required this.targetReferenceJson,
    required this.basis,
    required this.identifiedAt,
    required this.identifiedByUid,
    required this.identifiedByName,
  });

  final int version;
  final int originalTicketVersion;
  final String targetReferenceJson;
  final String basis;
  final DateTime identifiedAt;
  final String identifiedByUid;
  final String identifiedByName;

  AssetHierarchyReference get target => AssetHierarchyReference.decode(
    targetReferenceJson,
    source: 'maintenance component identification',
  );
  String get component => target.nodeName;

  factory MaintenanceComponentIdentification.fromMap(Map<String, dynamic> map) {
    const source = 'maintenance component identification';
    if (map['schemaVersion'] != 1) {
      throw const FormatException(
        'Unsupported component identification schema.',
      );
    }
    final result = MaintenanceComponentIdentification(
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      originalTicketVersion: readRequiredPersistedInt(
        map['originalTicketVersion'],
        field: 'originalTicketVersion',
        source: source,
        minimum: 1,
      ),
      targetReferenceJson: readRequiredPersistedString(
        map['targetReferenceJson'],
        field: 'targetReferenceJson',
        source: source,
      ),
      basis: readRequiredPersistedString(
        map['basis'],
        field: 'basis',
        source: source,
      ),
      identifiedAt: readRequiredPersistedDateTime(
        map['identifiedAt'],
        field: 'identifiedAt',
        source: source,
      ),
      identifiedByUid: readRequiredPersistedString(
        map['identifiedByUid'],
        field: 'identifiedByUid',
        source: source,
      ),
      identifiedByName: readRequiredPersistedString(
        map['identifiedByName'],
        field: 'identifiedByName',
        source: source,
      ),
    );
    if (result.version != 1 ||
        result.basis.length > 2000 ||
        !{
          AssetHierarchyReferenceScope.componentDefinitionOnAsset,
          AssetHierarchyReferenceScope.installedComponent,
        }.contains(result.target.scope)) {
      throw const FormatException(
        'Component identification must name a registered component.',
      );
    }
    return result;
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'version': version,
    'originalTicketVersion': originalTicketVersion,
    'targetReferenceJson': targetReferenceJson,
    'basis': basis,
    'identifiedAt': identifiedAt.toUtc().toIso8601String(),
    'identifiedByUid': identifiedByUid,
    'identifiedByName': identifiedByName,
  };
}

Map<String, dynamic> maintenanceComponentContext(String? metadata) {
  if (metadata == null || metadata.trim().isEmpty) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(metadata);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};
  final value = decoded['componentContext'];
  if (value == null) return const {};
  if (value is! Map) {
    throw const FormatException('Malformed component context.');
  }
  return Map<String, dynamic>.from(value);
}

String mergeMaintenanceComponentContext(
  String? metadata, {
  required ComponentIntakeState? intakeState,
  required MaintenanceComponentIdentification? identification,
}) {
  final root = <String, dynamic>{};
  if (metadata != null && metadata.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is Map) {
        root.addAll(Map<String, dynamic>.from(decoded));
      } else {
        root['legacyMetadata'] = metadata;
      }
    } on FormatException {
      root['legacyMetadata'] = metadata;
    }
  }
  if (intakeState == null && identification == null) {
    root.remove('componentContext');
  } else {
    root['componentContext'] = {
      'intakeState': intakeState?.name,
      if (identification != null) 'identification': identification.toMap(),
    };
  }
  return jsonEncode(root);
}

String? mergeRemoteMaintenanceComponentContext(
  String? metadata,
  Map<String, dynamic> record,
) {
  final state = record['componentIntakeState'] == null
      ? null
      : readRequiredPersistedEnum(
          ComponentIntakeState.values,
          record['componentIntakeState'],
          field: 'componentIntakeState',
        );
  final raw = record['componentIdentification'];
  if (raw != null && raw is! Map) {
    throw const FormatException('Malformed component identification.');
  }
  final identification = raw == null
      ? null
      : MaintenanceComponentIdentification.fromMap(
          Map<String, dynamic>.from(raw),
        );
  if (state == null &&
      identification == null &&
      maintenanceComponentContext(metadata).isEmpty) {
    return metadata;
  }
  if (identification != null) {
    final original = AssetHierarchyReference.decode(
      record['assetHierarchyRefJson'] as String,
      source: 'original maintenance component report',
    );
    final legacyBlank =
        state == null &&
        (record['component'] == null ||
            (record['component'] is String &&
                (record['component'] as String).trim().isEmpty)) &&
        (record['tag'] == null ||
            (record['tag'] is String &&
                (record['tag'] as String).trim().isEmpty));
    if ((!legacyBlank &&
            !{
              ComponentIntakeState.unidentified,
              ComponentIntakeState.unlisted,
            }.contains(state)) ||
        original.scope != AssetHierarchyReferenceScope.physicalAsset ||
        identification.target.assetInstanceId != original.assetInstanceId ||
        identification.target.assetClassId != original.assetClassId ||
        identification.target.assetNumber != record['assetNumber']) {
      throw const FormatException(
        'Component identification differs from the original physical asset.',
      );
    }
  }
  return mergeMaintenanceComponentContext(
    metadata,
    intakeState: state,
    identification: identification,
  );
}
