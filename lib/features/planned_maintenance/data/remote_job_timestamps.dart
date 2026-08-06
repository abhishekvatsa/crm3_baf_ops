import '../../../core/serialization/persisted_data_reader.dart';

class RemoteJobTemplateTimestamps {
  const RemoteJobTemplateTimestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

RemoteJobTemplateTimestamps readRemoteJobTemplateTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteJobTemplateTimestamps(
    createdAt: readRequiredPersistedDateTime(
      map['createdAt'],
      field: 'createdAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}

class RemoteJobExecutionTimestamps {
  const RemoteJobExecutionTimestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.cancelledAt,
    required this.laneSetFinalizedAt,
    required this.completedAt,
    required this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;
  final DateTime? laneSetFinalizedAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;
}

RemoteJobExecutionTimestamps readRemoteJobExecutionTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteJobExecutionTimestamps(
    createdAt: readRequiredPersistedDateTime(
      map['createdAt'],
      field: 'createdAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    cancelledAt: readOptionalPersistedDateTime(
      map['cancelledAt'],
      field: 'cancelledAt',
      source: source,
    ),
    laneSetFinalizedAt: readOptionalPersistedDateTime(
      map['laneSetFinalizedAt'],
      field: 'laneSetFinalizedAt',
      source: source,
    ),
    completedAt: readOptionalPersistedDateTime(
      map['completedAt'],
      field: 'completedAt',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}

class RemoteJobDiaryTimestamps {
  const RemoteJobDiaryTimestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

RemoteJobDiaryTimestamps readRemoteJobDiaryTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteJobDiaryTimestamps(
    createdAt: readRequiredPersistedDateTime(
      map['createdAt'],
      field: 'createdAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}

class RemoteJobModuleTimestamps {
  const RemoteJobModuleTimestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.addedAt,
    required this.submittedAt,
    required this.acceptedAt,
    required this.reopenedAt,
    required this.notApplicableAt,
    required this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? addedAt;
  final DateTime? submittedAt;
  final DateTime? acceptedAt;
  final DateTime? reopenedAt;
  final DateTime? notApplicableAt;
  final DateTime? deletedAt;
}

RemoteJobModuleTimestamps readRemoteJobModuleTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteJobModuleTimestamps(
    createdAt: readRequiredPersistedDateTime(
      map['createdAt'],
      field: 'createdAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    addedAt: readOptionalPersistedDateTime(
      map['addedAt'],
      field: 'addedAt',
      source: source,
    ),
    submittedAt: readOptionalPersistedDateTime(
      map['submittedAt'],
      field: 'submittedAt',
      source: source,
    ),
    acceptedAt: readOptionalPersistedDateTime(
      map['acceptedAt'],
      field: 'acceptedAt',
      source: source,
    ),
    reopenedAt: readOptionalPersistedDateTime(
      map['reopenedAt'],
      field: 'reopenedAt',
      source: source,
    ),
    notApplicableAt: readOptionalPersistedDateTime(
      map['notApplicableAt'],
      field: 'notApplicableAt',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}
