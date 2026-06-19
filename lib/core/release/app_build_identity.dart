class AppBuildIdentity {
  final String appVersion;
  final String buildNumber;
  final String gitCommit;
  final String releaseTag;
  final String releaseChannel;
  final String ciRunId;
  final String buildTimestampUtc;
  final String releaseId;
  final String expectedBackendReleaseId;
  final String sourceArchiveSha256;

  const AppBuildIdentity({
    required this.appVersion,
    required this.buildNumber,
    required this.gitCommit,
    required this.releaseTag,
    required this.releaseChannel,
    required this.ciRunId,
    required this.buildTimestampUtc,
    required this.releaseId,
    required this.expectedBackendReleaseId,
    required this.sourceArchiveSha256,
  });

  static const current = AppBuildIdentity(
    appVersion: String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '0.0.0-dev',
    ),
    buildNumber: String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '0'),
    gitCommit: String.fromEnvironment(
      'GIT_COMMIT',
      defaultValue: 'unidentified',
    ),
    releaseTag: String.fromEnvironment('RELEASE_TAG', defaultValue: 'untagged'),
    releaseChannel: String.fromEnvironment(
      'RELEASE_CHANNEL',
      defaultValue: 'development',
    ),
    ciRunId: String.fromEnvironment('CI_RUN_ID', defaultValue: 'local'),
    buildTimestampUtc: String.fromEnvironment(
      'BUILD_TIMESTAMP_UTC',
      defaultValue: 'unavailable',
    ),
    releaseId: String.fromEnvironment(
      'RELEASE_ID',
      defaultValue: 'unidentified',
    ),
    expectedBackendReleaseId: String.fromEnvironment(
      'EXPECTED_BACKEND_RELEASE_ID',
      defaultValue: 'unidentified',
    ),
    sourceArchiveSha256: String.fromEnvironment(
      'SOURCE_ARCHIVE_SHA256',
      defaultValue: 'unavailable',
    ),
  );

  bool get isSourceIdentified =>
      _identified(gitCommit) && _identified(releaseId);

  bool get isVersioned => appVersion != '0.0.0-dev' && buildNumber != '0';

  bool get isReleaseCandidateIdentified => isSourceIdentified && isVersioned;

  bool get expectsBackendParity => _identified(expectedBackendReleaseId);

  String get versionLabel => '$appVersion+$buildNumber';

  String get sourceLabel => '$gitCommit · $releaseTag · $releaseChannel';

  Map<String, Object?> toMap() => <String, Object?>{
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'versionLabel': versionLabel,
    'gitCommit': gitCommit,
    'releaseTag': releaseTag,
    'releaseChannel': releaseChannel,
    'ciRunId': ciRunId,
    'buildTimestampUtc': buildTimestampUtc,
    'releaseId': releaseId,
    'expectedBackendReleaseId': expectedBackendReleaseId,
    'sourceArchiveSha256': sourceArchiveSha256,
    'isSourceIdentified': isSourceIdentified,
    'isVersioned': isVersioned,
    'isReleaseCandidateIdentified': isReleaseCandidateIdentified,
  };

  String toDiagnosticsText() => <String>[
    'appVersion: $appVersion',
    'buildNumber: $buildNumber',
    'gitCommit: $gitCommit',
    'releaseTag: $releaseTag',
    'releaseChannel: $releaseChannel',
    'ciRunId: $ciRunId',
    'buildTimestampUtc: $buildTimestampUtc',
    'releaseId: $releaseId',
    'expectedBackendReleaseId: $expectedBackendReleaseId',
    'sourceArchiveSha256: $sourceArchiveSha256',
  ].join('\n');
}

bool _identified(String value) {
  final cleaned = value.trim().toLowerCase();
  return cleaned.isNotEmpty &&
      cleaned != 'unidentified' &&
      cleaned != 'unavailable' &&
      cleaned != 'unknown';
}
