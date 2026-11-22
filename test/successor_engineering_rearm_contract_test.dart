import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

/// Release evidence is read as untyped JSON, so a missing or reshaped section
/// must fail as a governed verdict naming what was expected. A raw cast reports
/// only `type 'Null' is not a subtype of type 'List<dynamic>'`, which stops the
/// surrounding plane from being validated at all instead of failing it loudly.
List<Map<String, dynamic>> _objects(dynamic value, {String? field}) {
  if (value is! List) {
    throw StateError(
      'Expected a list of evidence objects'
      '${field == null ? '' : ' at $field'}, found ${value.runtimeType}.',
    );
  }
  return value
      .map(
        (entry) => entry is Map
            ? entry.cast<String, dynamic>()
            : throw StateError(
                'Expected an evidence object'
                '${field == null ? '' : ' in $field'}, '
                'found ${entry.runtimeType}.',
              ),
      )
      .toList(growable: false);
}

List<String> _strings(dynamic value, {String? field}) {
  if (value is! List) {
    throw StateError(
      'Expected a list of strings'
      '${field == null ? '' : ' at $field'}, found ${value.runtimeType}.',
    );
  }
  return value.cast<String>();
}

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

String _packageVersion() {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  return match!.group(1)!;
}

int _currentIsarSchemaVersion() {
  final match = RegExp(r'static const int currentSchemaVersion\s*=\s*(\d+)\s*;')
      .firstMatch(
        File('lib/core/services/isar_schema_migration.dart').readAsStringSync(),
      );
  if (match == null) {
    throw StateError('Unable to resolve the governed Isar schema version.');
  }
  return int.parse(match.group(1)!);
}

String _gitTreeObjectId(String commit, String path, {String root = '.'}) {
  final result = Process.runSync('git', <String>[
    'rev-parse',
    '--verify',
    '$commit:$path',
  ], workingDirectory: root);
  final tree = (result.stdout as String).trim().toLowerCase();
  if (result.exitCode != 0 ||
      !RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(tree)) {
    throw StateError('Unable to resolve Git tree for $commit:$path.');
  }
  return tree;
}

const _approvedArtifactExactSourcePaths = <String>[
  '.firebaserc',
  '.github/workflows/production-artifact.yml',
  '.metadata',
  '.npmrc',
  'analysis_options.yaml',
  'android',
  'assets',
  'firebase.json',
  'firestore.indexes.json',
  'firestore.rules',
  'functions',
  'integration_test',
  'jest.config.js',
  'lib',
  'package.json',
  'package-lock.json',
  'pubspec.lock',
  'release/approvals/linux-isar-community-core-authority.json',
  'release/github-actions-pins.json',
  'release_gate.ps1',
  'test',
  'tool',
  'tooling',
  'tools/release',
];

String _gitFileText(String commit, String path, {String root = '.'}) {
  final result = Process.runSync('git', <String>[
    'show',
    '$commit:$path',
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    throw StateError('Unable to read Git file for $commit:$path.');
  }
  return (result.stdout as String).replaceAll('\r\n', '\n');
}

const _business31ReplayRecord =
    'release/evidence/build31-business-private-replay.json';

/// Business31 selection, decided exactly as the policy gate and the canonical
/// audit decide it: an explicit replay pointer, or a business client or
/// runtime route.
bool _business31Selected(Map<String, dynamic> policy) {
  if (policy.containsKey('businessBackendPrivateReplay')) {
    return true;
  }
  for (final name in const <String>[
    'clientBackendCompatibility',
    'runtimeBackendPrivateReplay',
  ]) {
    final value = policy[name];
    if (value is Map &&
        <dynamic>[value['profile'], value['file']].any(
          (field) =>
              field is String && field.toLowerCase().contains('business'),
        )) {
      return true;
    }
  }
  return false;
}

typedef _SourceIntegration = ({String verifier, Map<String, String> files});

/// Business31 binds its artifact baseline to the recorded M, and the hosted
/// verifier admits only enrolled integration files equal to V. This returns
/// the exact replay record's sourceIntegration (`file -> 'mode oid'`) and V,
/// or null when the record does not apply. It mirrors the policy gate, which
/// additionally binds the same map to the authenticated replay measurement,
/// and the canonical audit.
_SourceIntegration? _business31SourceIntegration(
  Map<String, dynamic> policy,
  String baselineCommit, {
  String root = '.',
}) {
  final pointer = policy['businessBackendPrivateReplay'];
  if (pointer is! Map ||
      pointer['profile'] != 'build31-exact-business-backend-v2' ||
      pointer['file'] != _business31ReplayRecord) {
    return null;
  }
  final List<int> bytes;
  final Object? record;
  try {
    bytes = File('$root/$_business31ReplayRecord').readAsBytesSync();
    record = jsonDecode(utf8.decode(bytes));
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
  if (record is! Map ||
      sha256.convert(bytes).toString().toUpperCase() != pointer['sha256']) {
    return null;
  }
  final source = record['source'];
  final verifier = record['verifier'];
  final integration = record['sourceIntegration'];
  final verifierCommit = verifier is Map ? verifier['commit'] : null;
  if (record['schemaVersion'] != 3 ||
      record['documentType'] != 'build31-business-backend-private-replay' ||
      record['profile'] != 'build31-exact-business-backend-v2' ||
      source is! Map ||
      baselineCommit.isEmpty ||
      source['commit'] != baselineCommit ||
      verifierCommit is! String ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(verifierCommit) ||
      verifierCommit == source['commit'] ||
      integration is! Map ||
      integration.isEmpty ||
      integration.length > 256) {
    return null;
  }
  final files = <String, String>{};
  for (final MapEntry(:key, :value) in integration.entries) {
    if (key is! String ||
        !RegExp(r'^[A-Za-z0-9_+./-]+$').hasMatch(key) ||
        value is! Map ||
        value.length != 3 ||
        value['mode'] != '100644' ||
        value['oid'] is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(value['oid'] as String) ||
        value['sha256'] is! String ||
        !RegExp(r'^[A-F0-9]{64}$').hasMatch(value['sha256'] as String)) {
      return null;
    }
    files[key] = '${value['mode']} ${value['oid']}';
  }
  final ancestry = Process.runSync('git', <String>[
    'merge-base',
    '--is-ancestor',
    verifierCommit,
    'HEAD',
  ], workingDirectory: root);
  if (ancestry.exitCode != 0) {
    return null;
  }
  return (verifier: verifierCommit, files: files);
}

List<String>? _gitOutputLines(List<String> arguments, String root) {
  final result = Process.runSync('git', arguments, workingDirectory: root);
  if (result.exitCode != 0) {
    return null;
  }
  return const LineSplitter().convert(result.stdout as String);
}

final _gitRawChange = RegExp(
  r'^:([0-7]{6}) ([0-7]{6}) [0-9a-f]{40} ([0-9a-f]{40}) ([AM])\t(.+)$',
);
final _gitLsTreeBlob = RegExp(r'^([0-7]{6}) blob ([0-9a-f]{40})\t(.+)$');

/// A drifted approved path is admitted only when every file that differs from
/// the baseline under it is an added or modified regular file whose exact mode
/// and blob equal both its sourceIntegration entry and V's own blob.
List<String>? _approvedArtifactIntegratedFiles(
  String baselineCommit,
  String path,
  _SourceIntegration integration, {
  String root = '.',
}) {
  final changes = _gitOutputLines(<String>[
    'diff-tree',
    '-r',
    '--no-renames',
    '--no-commit-id',
    '--raw',
    '--no-abbrev',
    baselineCommit,
    'HEAD',
    '--',
    path,
  ], root);
  final listing = _gitOutputLines(<String>[
    'ls-tree',
    '-r',
    '--full-tree',
    integration.verifier,
    '--',
    path,
  ], root);
  if (changes == null || changes.isEmpty || listing == null) {
    return null;
  }
  final verifierObjects = <String, String>{};
  for (final line in listing) {
    final match = _gitLsTreeBlob.firstMatch(line);
    if (match != null) {
      verifierObjects[match.group(3)!] = '${match.group(1)} ${match.group(2)}';
    }
  }
  final files = <String>[];
  for (final line in changes) {
    final match = _gitRawChange.firstMatch(line);
    if (match == null) {
      return null;
    }
    final file = match.group(5)!;
    final identity = '${match.group(2)} ${match.group(3)}';
    if ((match.group(4) == 'M' && match.group(1) != '100644') ||
        match.group(2) != '100644' ||
        integration.files[file] != identity ||
        verifierObjects[file] != identity) {
      return null;
    }
    files.add(file);
  }
  return files;
}

String? _normalizedArtifactPubspec(String text, {String? expectedVersion}) {
  final pattern = RegExp(r'^version:[ \t]*(\S+)[ \t]*$', multiLine: true);
  final matches = pattern.allMatches(text).toList(growable: false);
  if (matches.length != 1) {
    throw StateError('Artifact pubspec must have one version declaration.');
  }
  if (expectedVersion != null && matches.single.group(1) != expectedVersion) {
    return null;
  }
  return text.replaceFirst(pattern, 'version: <governed-artifact-version>');
}

bool _approvedArtifactSourceMatches(
  String baselineCommit,
  String expectedPackageVersion, {
  _SourceIntegration? integration,
  String root = '.',
}) {
  final exactPathsMatch = _approvedArtifactExactSourcePaths.every(
    (path) =>
        _gitTreeObjectId(baselineCommit, path, root: root) ==
            _gitTreeObjectId('HEAD', path, root: root) ||
        (integration != null &&
            _approvedArtifactIntegratedFiles(
                  baselineCommit,
                  path,
                  integration,
                  root: root,
                ) !=
                null),
  );
  final baselinePubspec = _normalizedArtifactPubspec(
    _gitFileText(baselineCommit, 'pubspec.yaml', root: root),
  );
  final currentPubspec = _normalizedArtifactPubspec(
    _gitFileText('HEAD', 'pubspec.yaml', root: root),
    expectedVersion: expectedPackageVersion,
  );
  return exactPathsMatch &&
      currentPubspec != null &&
      baselinePubspec == currentPubspec;
}

const _promotedApplicationSourcePaths = <String>[
  'android',
  'assets',
  'lib',
  'pubspec.yaml',
  'pubspec.lock',
];

bool _promotedApplicationSourceMatches(String promotedCommit) =>
    _promotedApplicationSourcePaths.every(
      (path) =>
          _gitTreeObjectId(promotedCommit, path) ==
          _gitTreeObjectId('HEAD', path),
    );

bool _currentSourceRuntimeAuthority({
  required bool artifactPilotApproved,
  required bool backendMatchesDeployed,
  required bool applicationMatchesPromotedArtifact,
}) =>
    artifactPilotApproved &&
    backendMatchesDeployed &&
    applicationMatchesPromotedArtifact;

({bool candidate, bool finalized}) _pilotApplicability(
  Map<String, dynamic> policy,
) {
  final candidateBuild = (policy['release'] as Map)['buildNumber'];
  final finalization = policy['finalization'] as Map;
  final pending = finalization['status'] == 'pending-source-authorized';
  final finalized = pending
      ? finalization['priorCompletedBuild'] as Map
      : finalization;
  final finalizedBuild = finalized['buildNumber'] ?? candidateBuild;
  final promotion = policy['postBuildPromotion'] as Map;
  final distribution = policy['distribution'] as Map;
  final promotionFile = promotion['promotionReceiptFile'] as String;
  final proof = _readObject(promotionFile);
  final granted = proof['promotion'] as Map;
  final admitted = (proof['admittedEvidence'] as Map)['governedBuild'] as Map;
  final finalizedApproved =
      finalized['controlledPilotApproved'] == true &&
      promotion['controlledPilotApproved'] == true &&
      promotion['buildNumber'] == finalizedBuild &&
      distribution['approved'] == true &&
      distribution['approvedBuildNumber'] == finalizedBuild &&
      distribution['promotionReceiptFile'] == promotionFile &&
      distribution['promotionReceiptSha256'] ==
          promotion['promotionReceiptSha256'] &&
      _sha256(promotionFile) == promotion['promotionReceiptSha256'] &&
      granted['pilotHandoutAuthorized'] == true &&
      granted['authorizedBuildNumber'] == finalizedBuild &&
      admitted['buildNumber'] == finalizedBuild &&
      admitted['finalizationReceipt'] == finalized['completionReceiptFile'] &&
      admitted['finalizationReceiptSha256'] ==
          finalized['completionReceiptSha256'] &&
      _sha256(finalized['completionReceiptFile'] as String) ==
          finalized['completionReceiptSha256'];
  return (
    candidate:
        !pending &&
        finalizedApproved &&
        candidateBuild == finalizedBuild &&
        distribution['appliesToCurrentCandidate'] == true,
    finalized: finalizedApproved,
  );
}

bool _artifactConstructionAuthority({
  required bool pendingSourceAuthorization,
  required bool backendMatchesDeployed,
  required bool artifactSourceMatchesApproval,
}) =>
    pendingSourceAuthorization &&
    backendMatchesDeployed &&
    artifactSourceMatchesApproval;

String _functionDeploymentStatus(String deployedTree, String currentTree) =>
    deployedTree == currentTree
    ? 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK'
    : 'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';

String _firestoreRelationship({
  required bool rulesChanged,
  required bool indexesChanged,
}) {
  if (!rulesChanged && !indexesChanged) {
    return 'EXACT_SOURCE_RULES_AND_INDEXES_DEPLOYED_AND_VERIFIED';
  }
  if (rulesChanged && indexesChanged) {
    return 'RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
  }
  return rulesChanged
      ? 'RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
      : 'RULES_MATCH_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
}

String _firestoreDeploymentStatus({
  required bool rulesChanged,
  required bool indexesChanged,
}) {
  if (!rulesChanged && !indexesChanged) {
    return 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK';
  }
  if (rulesChanged && indexesChanged) {
    return 'SOURCE_RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
  }
  return rulesChanged
      ? 'SOURCE_RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
      : 'SOURCE_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
}

/// Exercises the existing source, scoped-IAM and Rules validators with actual
/// retained records. Negative cases alter only an in-memory copy in the child;
/// neither production receipts nor repository files are rewritten.
Map<String, dynamic> _backendEvidenceProbe(
  String receiptFile, {
  String mutation = 'none',
  int? expectedBuildNumber,
}) {
  final result = Process.runSync('node', <String>[
    '-e',
    r'''
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=process.argv[1],input=JSON.parse(process.argv[2]);
const load=file=>JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));
const receipt=load(input.receiptFile),approval=load(receipt.approvalAuthority.file);
const fleetTool=require(path.join(root,'tools/release/deploymentFleetContract.js'));
const seals=require(path.join(root,'tools/release/collectProductionGlobalPullBackend.js'));
const fleet=fleetTool.readDeploymentFleetContract(root,receipt.sourceAuthority.commit);
const bound=ref=>{const bytes=fs.readFileSync(path.join(root,ref.file));assert.equal(crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase(),ref.physicalSha256);return JSON.parse(bytes);};
let stage='fixture';
try {
 if(input.mutation==='count')receipt.deployment.functionCount++;
 if(input.mutation==='hidden-iam')receipt.controlBoundary.iamMutated=false;
 if(input.mutation==='unapproved-iam')delete approval.approvedDeployment.newCallableInvokerPolicies;
 if(input.mutation==='legacy-iam-write')receipt.controlBoundary.iamMutated=true;
 if(input.mutation==='iam-proof-hash')receipt.deployment.newCallableInvokerIamEvidence.physicalSha256='A'.repeat(64);
 if(input.mutation==='unapproved-rules')approval.approvedDeployment.firestoreRulesMutationAuthorized=false;
 if(input.mutation==='hidden-rules')receipt.controlBoundary.securityRulesMutated=false;
 if(input.mutation==='reconciliation-hash')receipt.firestoreDeployment.rulesReconciliationEvidence.physicalSha256='A'.repeat(64);
 if(input.mutation==='mixed-rules')receipt.firestoreDeployment.rulesDeploymentEvidence=receipt.firestoreDeployment.rulesReconciliationEvidence;
 if(input.mutation==='missing-reconciliation')delete receipt.firestoreDeployment.rulesReconciliationEvidence;
 stage='fleet-counts';
 assert.equal(fleetTool.deploymentCountsMatch(fleet,receipt.deployment),true,'Deployment counts differ from exact source policy');
 for(const kind of ['functionFleet','iamDependencies']){
  const child=bound(receipt.cleanMainLiveReadbacks[kind]);
  const records=child.outputs.functions;
  if(input.mutation==='names'&&kind==='functionFleet')records[0].name='unexpectedSameCountFunction';
  stage=`${kind}-names`;
  assert.equal(fleetTool.measuredFunctionNamesMatch(fleet,records),true,'Measured names differ from exact source policy');
 }
 stage='iam';
 const iam=require(path.join(root,'tools/release/scopedCallableInvokerIam.js')).validateDeploymentIamBoundary({repoRoot:root,approval,approvalSha256:receipt.approvalAuthority.sha256,receipt});
 stage='rules-approval';
 const successorDecision=approval.approvedDeployment.firestoreRulesMutationAuthorized===true
  ?require(path.join(root,'tools/release/stagedPromotionSourceAuthority.js')).verifySuccessorDelegatedDecision({repoRoot:root,approval,approvalAuthority:receipt.approvalAuthority,sourceAuthority:receipt.sourceAuthority,expectedBuildNumber:input.expectedBuildNumber??undefined}):null;
 stage='rules';
 const rules=require(path.join(root,'tools/release/reviewedFirestoreRulesDeployment.js')).validateRulesDeploymentBoundary({repoRoot:root,approval,receipt,successorDecision});
 stage='linked-controls';
 let publicSchema=null,controlSchema=null;
 if(receipt.deployment.newCallableInvokerIamEvidence){
  const publication=bound(receipt.deployment.newCallableInvokerIamEvidence),controls=bound(receipt.deployment.controlComparison);
  seals.verifyReceiptSeal(controls,'linked backend controls');
  assert.equal(publication.controls.receiptSha256,controls.receiptSha256);
  assert.equal(controls.sourceCommit,receipt.sourceAuthority.commit);
  assert.equal(controls.approvalSha256,receipt.approvalAuthority.sha256);
  if(publication.schemaVersion===3){
   assert.equal(controls.schemaVersion,2);assert.equal(controls.controlMode,'observed-cloud-run-http-controls-v1');
   assert.equal(controls.observedAtUtc,publication.observedAtUtc);
   assert.deepEqual(controls.verificationAuthority,publication.verificationAuthority);
   assert.equal(Object.hasOwn(controls,'existingFunctionEnvironmentVariablesUnchanged'),false);
   for(const field of ['existingProjectEnvironmentVariablesUnchanged','reservedHttpSignatureMetadataValidated','newFunctionEffectiveInstanceCapsValidated'])assert.equal(controls[field],true);
  }else{assert.equal(publication.schemaVersion,2);assert.equal(controls.schemaVersion,1);assert.equal(controls.existingFunctionEnvironmentVariablesUnchanged,true);}
  publicSchema=publication.schemaVersion;controlSchema=controls.schemaVersion;
 }
 process.stdout.write(JSON.stringify({ok:true,fleet,iamDecision:iam.decision,rulesDecision:rules.decision,publicSchema,controlSchema}));
}catch(error){process.stdout.write(JSON.stringify({ok:false,stage,reason:error.message}));}
''',
    Directory.current.path,
    jsonEncode(<String, dynamic>{
      'receiptFile': receiptFile,
      'mutation': mutation,
      'expectedBuildNumber': expectedBuildNumber,
    }),
  ]);
  if (result.exitCode != 0) {
    throw StateError('Backend evidence verifier failed: ${result.stderr}');
  }
  return (jsonDecode(result.stdout as String) as Map).cast<String, dynamic>();
}

String _backendExecutionEvidenceShape(Map<String, dynamic> closure) {
  final deployment = (closure['deployment'] as Map).cast<String, dynamic>();
  final external = closure['privacySafeExternalEvidence'];
  final iamEvidence = deployment['newCallableInvokerIamEvidence'];
  final iamMutated =
      (closure['controlBoundary'] as Map?)?['iamMutated'] == true;
  final firestore = (closure['firestoreDeployment'] as Map?)
      ?.cast<String, dynamic>();
  // New-callable IAM evidence is carried exactly when IAM was mutated. A
  // current-scoped deployment that adds no callables carries none, and one
  // that mutated IAM without publishing the evidence is not a valid layout.
  final current = iamMutated ? iamEvidence is Map : iamEvidence == null;
  if (external is Map && iamEvidence is! Map) {
    final enumerated = external.containsKey('receipts');
    final bound = external.containsKey('byteComparisonLog');
    if (enumerated != bound) return enumerated ? 'enumerated' : 'bound';
  } else if (!closure.containsKey('privacySafeExternalEvidence') &&
      current &&
      deployment['cohorts'] is List &&
      deployment['controlComparison'] is Map &&
      deployment['deployedCodeByteComparison'] is Map &&
      firestore != null) {
    if (firestore['rulesDeploymentEvidence'] is Map &&
        !firestore.containsKey('rulesReconciliationEvidence')) {
      return 'current-scoped';
    }
    if (firestore['rulesReconciliationEvidence'] is Map &&
        !firestore.containsKey('rulesDeploymentEvidence')) {
      return 'current-reconciled';
    }
  }
  throw StateError(
    'Expected exactly one complete historical or current backend evidence layout.',
  );
}

void _expectBackendExecutionEvidence(Map<String, dynamic> closure) {
  final deployment = (closure['deployment'] as Map).cast<String, dynamic>();
  final shape = _backendExecutionEvidenceShape(closure);
  final external = (closure['privacySafeExternalEvidence'] as Map?)
      ?.cast<String, dynamic>();
  if (external != null) expect(external['folderName'], isA<String>());
  if (shape == 'enumerated') {
    final receipts = _objects(
      external!['receipts'],
      field: 'privacySafeExternalEvidence.receipts',
    );
    final files = receipts.map((row) => row['file']);
    expect(files.toSet().length, receipts.length);
    expect(
      files,
      containsAll(<String>[
        '01-preflight.json',
        '02-provisioned.json',
        '03-callables.json',
        '04-events.json',
        '05-scheduler-preflight.json',
        '06-fleet.json',
        '07-lr03-lr06-prefinal.json',
        '08-final.json',
        '09-lr03-lr06-final.json',
      ]),
    );
    for (final receipt in receipts) {
      expect(receipt['sha256'], matches(RegExp(r'^[0-9A-F]{64}$')));
    }
    return;
  }
  if (shape == 'bound') {
    for (final name in <String>[
      'byteComparisonLog',
      'expectedBuiltSourceInventory',
      'executionAid',
    ]) {
      final item = (external![name] as Map).cast<String, dynamic>();
      expect(item['file'], isNotEmpty);
      expect(item['sha256'], matches(RegExp(r'^[0-9A-F]{64}$')));
    }
  }
  final cohorts = _objects(deployment['cohorts'], field: 'deployment.cohorts');
  expect(
    cohorts.map((row) => row['phase']),
    unorderedEquals(<String>['callables', 'events', 'fleet']),
  );
  final controls = (deployment['controlComparison'] as Map)
      .cast<String, dynamic>();
  final code = (deployment['deployedCodeByteComparison'] as Map)
      .cast<String, dynamic>();
  final links = <Map<String, dynamic>>[...cohorts, controls, code];
  if (shape == 'current-scoped' || shape == 'current-reconciled') {
    final iamEvidence = deployment['newCallableInvokerIamEvidence'];
    expect(
      iamEvidence is Map,
      (closure['controlBoundary'] as Map?)?['iamMutated'] == true,
      reason:
          'new-callable IAM evidence must be present exactly when IAM was mutated',
    );
    if (iamEvidence is Map) {
      links.add(iamEvidence.cast<String, dynamic>());
    }
    final rulesPointer =
        ((closure['firestoreDeployment'] as Map)[shape == 'current-scoped'
                    ? 'rulesDeploymentEvidence'
                    : 'rulesReconciliationEvidence']
                as Map)
            .cast<String, dynamic>();
    links.add(rulesPointer);
    if (shape == 'current-reconciled') {
      final reconciliation = _readObject(rulesPointer['file'] as String);
      expect(
        reconciliation['decision'],
        'PASS_APPROVED_RULES_OBSERVED_STATE_RECONCILED',
      );
      final failedPointer = (reconciliation['failedCommand'] as Map)
          .cast<String, dynamic>();
      links.add(failedPointer);
      final failed = _readObject(failedPointer['file'] as String);
      // Reconciliation preserves the actual failed CLI outcome; it never
      // converts a failed attempt into a successful deployment command.
      expect(failed['decision'], 'ACTUAL_RULES_CLI_RELEASE_CONFLICT');
      expect(failed['exitCode'], 1);
      for (final field in <String>[
        'cliResult',
        'beforeReadback',
        'measurements',
        'processResult',
      ]) {
        links.add((failed[field] as Map).cast<String, dynamic>());
      }
    }
    links.add(
      (code['expectedBuiltSourceInventory'] as Map).cast<String, dynamic>(),
    );
    links.add(
      (code['localSourceVerificationBuild'] as Map).cast<String, dynamic>(),
    );
  }
  for (final linked in links) {
    final file = linked['file'] as String;
    expect(
      File(file).existsSync(),
      isTrue,
      reason: '$file is referenced but absent.',
    );
    expect(
      _sha256(file),
      linked['physicalSha256'],
      reason: '$file hash differs.',
    );
  }
  // The sealed comparator cannot pass a real redeploy, because its control
  // view keeps Cloud Run buildConfig fields that change on every legitimate
  // deployment. Builds 29 and 30 retain their reviewed preservation outcomes
  // and the full shared authority check above revalidates their approvals.
  expect(
    controls['decision'],
    anyOf(
      'PASS_BACKEND_PRE_POST_CONTROL_COMPARISON',
      'PASS_EXISTING_19_BACKEND_CONTROLS_PRESERVED_WITH_ADJUDICATED_DEPLOYMENT_METADATA',
      'PASS_EXISTING_19_BACKEND_CONTROLS_PRESERVED',
    ),
  );
  expect(code['decision'], 'PASS_DEPLOYED_CODE_ARCHIVES_EXACT_BUILT_SOURCE');
  expect(code['allArchiveMembersMatchExactBuiltSource'], isTrue);
  expect(code['functionCount'], deployment['functionCount']);
}

/// Business31 publishes only custody envelopes of the recorded M; the private
/// replay that proves the deployment is authenticated by the policy gate's
/// recorded route. Bind every public pointer exactly as its public binding does.
void _expectBusiness31PublicBackend({
  required Map<String, dynamic> policy,
  required Map<String, dynamic> deployed,
  required Map<String, dynamic> closure,
  required Map<String, dynamic> approval,
}) {
  final pointer = (policy['businessBackendPrivateReplay'] as Map)
      .cast<String, dynamic>();
  expect(pointer['file'], _business31ReplayRecord);
  expect(
    pointer['profile'],
    anyOf(
      'build31-exact-business-backend-v1',
      'build31-exact-business-backend-v2',
    ),
  );
  expect(_sha256(_business31ReplayRecord), pointer['sha256']);
  final descriptor = _readObject(_business31ReplayRecord);
  final source = (descriptor['source'] as Map).cast<String, dynamic>();
  final finalization = (policy['finalization'] as Map).cast<String, dynamic>();
  final closurePointer = (descriptor['closurePointer'] as Map)
      .cast<String, dynamic>();
  final approvalPointer = (descriptor['approvalPointer'] as Map)
      .cast<String, dynamic>();
  expect(closurePointer['file'], deployed['functionFleetEvidenceFile']);
  expect(
    closurePointer['file'],
    finalization['exactFunctionFleetDeploymentReceiptFile'],
  );
  expect(closurePointer['sha256'], deployed['functionFleetEvidenceSha256']);
  expect(
    closurePointer['sha256'],
    finalization['exactFunctionFleetDeploymentReceiptSha256'],
  );
  expect(_sha256(closurePointer['file'] as String), closurePointer['sha256']);
  expect(approvalPointer['file'], deployed['deploymentApprovalFile']);
  expect(approvalPointer['sha256'], deployed['deploymentApprovalSha256']);
  expect(_sha256(approvalPointer['file'] as String), approvalPointer['sha256']);
  expect(closure.keys.toSet(), <String>{
    'schemaVersion',
    'documentType',
    'recordKind',
    'source',
    'recordedAtUtc',
    'privateRecord',
  });
  for (final (envelope, kind) in <(Map<String, dynamic>, String)>[
    (closure, 'closure'),
    (approval, 'decision'),
  ]) {
    expect(envelope['schemaVersion'], 1);
    expect(envelope['documentType'], 'build31-business-private-record-custody');
    expect(envelope['recordKind'], kind);
    expect(envelope['source'], source);
  }
  expect(source['commit'], deployed['functionFleetSourceCommit']);
  expect(
    _gitTreeObjectId(source['commit'] as String, 'functions'),
    source['functionsTree'],
  );
  final sourceTree = Process.runSync('git', <String>[
    'rev-parse',
    '--verify',
    '${source['commit']}^{tree}',
  ]);
  expect(sourceTree.exitCode, 0);
  expect((sourceTree.stdout as String).trim(), source['tree']);
  final client = (policy['clientBackendCompatibility'] as Map)
      .cast<String, dynamic>();
  expect(
    client['file'],
    'release/approvals/build31-business-client-compatibility-approval.json',
  );
  expect(_sha256(client['file'] as String), client['sha256']);
}

void main() {
  test(
    'pending successor keeps prior pilot proof in its own release plane',
    () {
      final historicalPolicy =
          jsonDecode(
                _gitFileText(
                  '1e6c7c2c34d0e127dfd18d247b05ee752b4895a3',
                  'release/production-release-policy.json',
                ),
              )
              as Map<String, dynamic>;
      expect((historicalPolicy['release'] as Map)['buildNumber'], 27);
      expect(_pilotApplicability(historicalPolicy), (
        candidate: true,
        finalized: true,
      ));
      final pendingPolicy =
          jsonDecode(jsonEncode(historicalPolicy)) as Map<String, dynamic>;
      (pendingPolicy['release'] as Map)['buildNumber'] = 28;
      pendingPolicy['finalization'] = <String, dynamic>{
        'status': 'pending-source-authorized',
        'controlledPilotApproved': false,
        'priorCompletedBuild': <String, dynamic>{
          ...(historicalPolicy['finalization'] as Map).cast<String, dynamic>(),
          'buildNumber': 27,
        },
      };
      (pendingPolicy['distribution'] as Map)['appliesToCurrentCandidate'] =
          false;
      expect(_pilotApplicability(pendingPolicy), (
        candidate: false,
        finalized: true,
      ));
      // Neither a wrongly copied candidate flag nor an unrelated promotion can
      // move the retained Build 27 authority to the new candidate.
      (pendingPolicy['finalization'] as Map)['controlledPilotApproved'] = true;
      expect(_pilotApplicability(pendingPolicy), (
        candidate: false,
        finalized: true,
      ));
      (pendingPolicy['postBuildPromotion'] as Map)['buildNumber'] = 28;
      expect(_pilotApplicability(pendingPolicy), (
        candidate: false,
        finalized: false,
      ));
    },
  );

  test(
    'historical 15-function closure layouts retain their original controls',
    () {
      for (final entry in <String, String>{
        'release/evidence/build27-backend-deployment-closure.json':
            'enumerated',
        'release/evidence/build28-backend-deployment-closure.json': 'bound',
      }.entries) {
        final closure = _readObject(entry.key);
        final proof = _backendEvidenceProbe(entry.key);
        expect(proof['ok'], isTrue, reason: proof['reason'] as String?);
        expect(proof['fleet']['functionCount'], 15);
        expect(proof['iamDecision'], 'PASS_NO_IAM_MUTATION');
        expect(proof['rulesDecision'], 'PASS_NO_RULES_MUTATION');
        expect(_backendExecutionEvidenceShape(closure), entry.value);
        _expectBackendExecutionEvidence(closure);
      }
    },
  );
  const currentClosure =
      'release/evidence/build28-current-source-backend-deployment-closure.json';
  test('current 19-function closure proves scoped IAM and reviewed Rules', () {
    final proof = _backendEvidenceProbe(currentClosure);
    expect(proof['ok'], isTrue, reason: proof['reason'] as String?);
    expect(proof['fleet']['functionCount'], 19);
    expect(proof['iamDecision'], 'PASS_NEW_CALLABLE_INVOKER_IAM_ONLY');
    expect(proof['rulesDecision'], 'PASS_REVIEWED_RULES_ONLY_DEPLOYMENT');
    expect(proof['publicSchema'], 3);
    expect(proof['controlSchema'], 2);
    final closure = _readObject(currentClosure);
    expect(_backendExecutionEvidenceShape(closure), 'current-scoped');
    _expectBackendExecutionEvidence(closure);
  });
  for (final entry in <String, (String, String)>{
    'count': (
      'fleet-counts',
      'Deployment counts differ from exact source policy',
    ),
    'names': (
      'functionFleet-names',
      'Measured names differ from exact source policy',
    ),
    'hidden-iam': (
      'iam',
      'new IAM creation must be explicitly declared and approved',
    ),
    'unapproved-iam': (
      'iam',
      'new IAM creation must be explicitly declared and approved',
    ),
    'iam-proof-hash': ('iam', 'proof physical digest differs'),
    'unapproved-rules': (
      'rules',
      'unchanged Rules path cannot hide a mutation/proof',
    ),
    'hidden-rules': (
      'rules',
      'only an explicitly approved successor Rules-only mutation is admitted',
    ),
  }.entries) {
    final mutation = entry.key;
    final (expectedStage, expectedReason) = entry.value;
    test(
      'shared backend proof refuses $mutation without changing receipts',
      () {
        final before = _sha256(currentClosure);
        final verdict = _backendEvidenceProbe(
          currentClosure,
          mutation: mutation,
        );
        expect(verdict['ok'], isFalse);
        expect(verdict['stage'], expectedStage);
        expect(verdict['reason'], contains(expectedReason));
        expect(_sha256(currentClosure), before);
      },
    );
  }
  test('historical closure cannot acquire unscoped IAM mutation authority', () {
    final verdict = _backendEvidenceProbe(
      'release/evidence/build28-backend-deployment-closure.json',
      mutation: 'legacy-iam-write',
    );
    expect(verdict['ok'], isFalse);
    expect(verdict['stage'], 'iam');
    expect(verdict['reason'], contains('unscoped IAM mutation is prohibited'));
  });
  const reconciledClosure =
      'release/evidence/build30-current-source-backend-deployment-closure.json';
  test(
    'Build 30 reconciles the failed Rules command with immutable authority',
    () {
      final proof = _backendEvidenceProbe(
        reconciledClosure,
        expectedBuildNumber: 30,
      );
      expect(proof['ok'], isTrue, reason: proof['reason'] as String?);
      expect(proof['fleet']['functionCount'], 19);
      expect(proof['iamDecision'], 'PASS_NO_IAM_MUTATION');
      expect(
        proof['rulesDecision'],
        'PASS_REVIEWED_RULES_OBSERVED_STATE_RECONCILIATION',
      );
      final closure = _readObject(reconciledClosure);
      expect(_backendExecutionEvidenceShape(closure), 'current-reconciled');
      _expectBackendExecutionEvidence(closure);
    },
  );
  for (final entry in <String, String>{
    'reconciliation-hash': 'physical evidence hash differs',
    'mixed-rules': 'command and reconciliation evidence are mutually exclusive',
    'missing-reconciliation': 'unapproved command evidence path',
    'unapproved-rules': 'unchanged Rules path cannot hide a mutation/proof',
  }.entries) {
    test('reconciled Rules proof refuses ${entry.key}', () {
      final before = _sha256(reconciledClosure);
      final verdict = _backendEvidenceProbe(
        reconciledClosure,
        mutation: entry.key,
        expectedBuildNumber: 30,
      );
      expect(verdict['ok'], isFalse);
      expect(verdict['stage'], 'rules');
      expect(verdict['reason'], contains(entry.value));
      expect(_sha256(reconciledClosure), before);
    });
  }
  test('missing or mixed external evidence layouts fail closed', () {
    final current = _readObject(currentClosure);
    (current['deployment'] as Map).remove('newCallableInvokerIamEvidence');
    expect(() => _backendExecutionEvidenceShape(current), throwsStateError);
    final mixed = _readObject(currentClosure);
    mixed['privacySafeExternalEvidence'] = <String, dynamic>{
      'receipts': <dynamic>[],
    };
    expect(() => _backendExecutionEvidenceShape(mixed), throwsStateError);
    final legacy = _readObject(
      'release/evidence/build27-backend-deployment-closure.json',
    );
    (legacy['privacySafeExternalEvidence'] as Map)['byteComparisonLog'] =
        <String, dynamic>{};
    expect(() => _backendExecutionEvidenceShape(legacy), throwsStateError);
    for (final key in <String>[
      'rulesDeploymentEvidence',
      'rulesReconciliationEvidence',
    ]) {
      final reconciled = _readObject(reconciledClosure);
      final firestore = reconciled['firestoreDeployment'] as Map;
      if (key == 'rulesReconciliationEvidence') {
        firestore.remove(key);
      } else {
        // Even a null duplicate must not disguise mixed acceptance methods.
        firestore[key] = null;
      }
      expect(
        () => _backendExecutionEvidenceShape(reconciled),
        throwsStateError,
      );
    }
  });
  test('backend source-drift expectations cover every parity branch', () {
    expect(
      _functionDeploymentStatus('a' * 40, 'a' * 40),
      'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    );
    expect(
      _functionDeploymentStatus('a' * 40, 'b' * 40),
      'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreRelationship(rulesChanged: false, indexesChanged: false),
      'EXACT_SOURCE_RULES_AND_INDEXES_DEPLOYED_AND_VERIFIED',
    );
    expect(
      _firestoreRelationship(rulesChanged: true, indexesChanged: false),
      'RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreRelationship(rulesChanged: false, indexesChanged: true),
      'RULES_MATCH_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreRelationship(rulesChanged: true, indexesChanged: true),
      'RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreDeploymentStatus(rulesChanged: true, indexesChanged: false),
      'SOURCE_RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreDeploymentStatus(rulesChanged: false, indexesChanged: true),
      'SOURCE_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreDeploymentStatus(rulesChanged: true, indexesChanged: true),
      'SOURCE_RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    for (final pending in <bool>[false, true]) {
      for (final backend in <bool>[false, true]) {
        for (final source in <bool>[false, true]) {
          expect(
            _artifactConstructionAuthority(
              pendingSourceAuthorization: pending,
              backendMatchesDeployed: backend,
              artifactSourceMatchesApproval: source,
            ),
            pending && backend && source,
          );
        }
      }
    }
  });

  test('business31 artifact source admits only exact enrolled integration', () {
    // The same admit/refuse cases tools/release/business31ArtifactSource.test.cjs
    // runs against the policy gate's and the canonical audit's copies.
    final root = Directory.systemTemp
        .createTempSync('b31-artifact-source-')
        .path;
    try {
      String git(List<String> arguments) {
        final result = Process.runSync('git', <String>[
          '-c',
          'user.name=Build31 fixture',
          '-c',
          'user.email=fixture@invalid',
          '-c',
          'core.autocrlf=false',
          '-c',
          'commit.gpgsign=false',
          ...arguments,
        ], workingDirectory: root);
        if (result.exitCode != 0) {
          throw StateError('git ${arguments.first} failed: ${result.stderr}');
        }
        return (result.stdout as String).trim();
      }

      void write(String path, String text) {
        File('$root/$path')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(text);
      }

      const version = '1.0.0-rc.21+31';
      git(<String>['init', '-q']);
      for (final path in _approvedArtifactExactSourcePaths) {
        write(
          path.split('/').last.contains('.') ? path : '$path/kept.txt',
          'baseline $path\n',
        );
      }
      write('android/removable.txt', 'baseline android member\n');
      write('pubspec.yaml', 'name: fixture\nversion: 1.0.0-rc.20+30\n');
      git(<String>['add', '-A']);
      git(<String>['commit', '-q', '-m', 'M']);
      final m = git(<String>['rev-parse', 'HEAD']);
      write('tools/release/integrated.cjs', 'verifier change\n');
      write('test/integrated_test.dart', 'verifier test\n');
      git(<String>['add', '-A']);
      git(<String>['commit', '-q', '-m', 'V']);
      final v = git(<String>['rev-parse', 'HEAD']);
      git(<String>['checkout', '-q', '-b', 'sibling', m]);
      write('tools/release/integrated.cjs', 'verifier change\n');
      write('test/integrated_test.dart', 'verifier test\n');
      git(<String>['add', '-A']);
      git(<String>['commit', '-q', '-m', 'unrelated V']);
      final sibling = git(<String>['rev-parse', 'HEAD']);

      Map<String, String> entry(String commit, String file) => <String, String>{
        'mode': '100644',
        'oid': git(<String>['rev-parse', '$commit:$file']),
        'sha256': sha256
            .convert(utf8.encode('${git(<String>['show', '$commit:$file'])}\n'))
            .toString()
            .toUpperCase(),
      };
      Map<String, dynamic> record({
        String? verifier,
        String? source,
      }) => <String, dynamic>{
        'schemaVersion': 3,
        'documentType': 'build31-business-backend-private-replay',
        'profile': 'build31-exact-business-backend-v2',
        'verifier': <String, String>{'commit': verifier ?? v},
        'source': <String, String>{'commit': source ?? m},
        'sourceIntegration': <String, dynamic>{
          'test/integrated_test.dart': entry(v, 'test/integrated_test.dart'),
          'tools/release/integrated.cjs': entry(
            v,
            'tools/release/integrated.cjs',
          ),
        },
      };
      // Builds candidate S on V with the replay record and the Build 31
      // version, and returns the policy pointer to that record.
      Map<String, dynamic> candidate({
        void Function()? change,
        void Function()? afterAdd,
        Map<String, dynamic>? replay,
      }) {
        git(<String>['checkout', '-q', '-f', '-B', 'candidate', v]);
        git(<String>['clean', '-q', '-f', '-d']);
        write('pubspec.yaml', 'name: fixture\nversion: $version\n');
        change?.call();
        final bytes = utf8.encode(
          '${const JsonEncoder.withIndent('  ').convert(replay ?? record())}\n',
        );
        File('$root/$_business31ReplayRecord')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        git(<String>['add', '-A']);
        afterAdd?.call();
        git(<String>['commit', '-q', '-m', 'S']);
        return <String, dynamic>{
          'businessBackendPrivateReplay': <String, dynamic>{
            'profile': 'build31-exact-business-backend-v2',
            'file': _business31ReplayRecord,
            'sha256': sha256.convert(bytes).toString().toUpperCase(),
          },
        };
      }

      bool admitted(Map<String, dynamic> policy) =>
          _approvedArtifactSourceMatches(
            m,
            version,
            integration: _business31SourceIntegration(policy, m, root: root),
            root: root,
          );

      final exact = candidate();
      expect(_approvedArtifactSourceMatches(m, version, root: root), isFalse);
      expect(admitted(exact), isTrue);
      final integration = _business31SourceIntegration(exact, m, root: root)!;
      expect(integration.verifier, v);
      expect(
        _approvedArtifactIntegratedFiles(m, 'test', integration, root: root),
        <String>['test/integrated_test.dart'],
      );
      final wrongPointer = candidate();
      (wrongPointer['businessBackendPrivateReplay'] as Map)['sha256'] =
          'F' * 64;
      final refusals = <String, Map<String, dynamic> Function()>{
        'record bytes differ from the pointer': () => wrongPointer,
        'integration file changed after V': () => candidate(
          change: () => write('tools/release/integrated.cjs', 'candidate\n'),
        ),
        'record admits the candidate blob instead of V': () {
          write('tools/release/integrated.cjs', 'candidate\n');
          final hashed = record();
          return candidate(
            change: () => write('tools/release/integrated.cjs', 'candidate\n'),
            replay: hashed
              ..['sourceIntegration']['tools/release/integrated.cjs'] =
                  <String, String>{
                    'mode': '100644',
                    'oid': git(<String>[
                      'hash-object',
                      'tools/release/integrated.cjs',
                    ]),
                    'sha256': 'A' * 64,
                  },
          );
        },
        'unlisted file under an integrated path': () =>
            candidate(change: () => write('tools/release/unlisted.cjs', 'x\n')),
        'drift in another approved path': () =>
            candidate(change: () => write('lib/unlisted.dart', 'x\n')),
        'deleted approved file': () => candidate(
          change: () => File('$root/android/removable.txt').deleteSync(),
        ),
        'integrated file mode change': () => candidate(
          afterAdd: () => git(<String>[
            'update-index',
            '--chmod=+x',
            'tools/release/integrated.cjs',
          ]),
        ),
        'non-version pubspec change': () => candidate(
          change: () => write(
            'pubspec.yaml',
            'name: fixture\nversion: $version\nextra: true\n',
          ),
        ),
        'verifier is not an ancestor': () =>
            candidate(replay: record(verifier: sibling)),
        'record names another baseline': () =>
            candidate(replay: record(source: v)),
        'record is not the successor descriptor': () =>
            candidate(replay: record()..['schemaVersion'] = 2),
      };
      for (final MapEntry(:key, :value) in refusals.entries) {
        expect(admitted(value()), isFalse, reason: key);
      }
    } finally {
      try {
        Directory(root).deleteSync(recursive: true);
      } on FileSystemException {
        // Windows keeps Git objects read-only; the fixture is temporary.
      }
    }
  });

  test(
    'successor engineering is re-armed without changing Build 11 authority',
    () {
      final ledger = _readObject('governance/programme-ledger.json');
      final sealedDecision = (ledger['programmeDecision'] as Map)
          .cast<String, dynamic>();
      final successorDecision = (ledger['successorEngineeringDecision'] as Map)
          .cast<String, dynamic>();
      final authority = _readObject(
        'governance/successor-engineering-rearm-2026-08-16.json',
      );

      expect(
        sealedDecision['decisionScope'],
        'SEALED_BUILD11_STAGE2D_PROGRAMME',
      );
      expect(
        sealedDecision['pilotHandout'],
        'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
      );
      expect(sealedDecision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');
      expect(successorDecision['status'], 'RE_ARMED_SOURCE_AND_CI');
      expect(successorDecision['releaseAuthority'], 'NONE_SOURCE_AND_CI_ONLY');
      expect(successorDecision['sealedBuild11AuthorityChanged'], isFalse);
      expect(authority['status'], 'ACTIVE_SOURCE_AND_CI_ONLY');
      expect(
        _strings(authority['notAuthorized']),
        containsAll(<String>[
          'production Firebase deployment',
          'App Check or Play Integrity activation',
          'reuse of the Build 11 package identity',
          'unrestricted distribution',
        ]),
      );
    },
  );

  test('post-codegen custody is derived from current generated source', () {
    final workflow = File(
      '.github/workflows/release-gate.yml',
    ).readAsStringSync();
    final audit = File(
      'tools/v4/v4_2_r1_canonical_audit.py',
    ).readAsStringSync();
    const generator =
        'dart run build_runner build --delete-conflicting-outputs';
    const canonicalAudit =
        'python3 tools/v4/v4_2_r1_canonical_audit.py --phase post-codegen';

    expect(workflow, contains(generator));
    expect(
      workflow.indexOf(generator),
      lessThan(workflow.indexOf(canonicalAudit)),
    );
    expect(audit, contains('git_tracked_files("HEAD", "lib")'));
    expect(audit, contains('ROOT.glob("lib/**/*.g.dart")'));
    expect(
      audit,
      contains(
        'Current generated bindings reproduce tracked source in post-codegen phase',
      ),
    );
  });

  test('current index derives each release plane from live authority records', () {
    final state = _readObject('release/current-successor-state.json');
    final planes = (state['authorityPlanes'] as Map).cast<String, dynamic>();
    final currentSource = (planes['currentSource'] as Map)
        .cast<String, dynamic>();
    final currentFirestoreSource =
        (currentSource['firestoreRulesAndIndexes'] as Map)
            .cast<String, dynamic>();
    final artifact = (planes['latestFinalizedArtifact'] as Map)
        .cast<String, dynamic>();
    final deployed = (planes['deployedBackend'] as Map).cast<String, dynamic>();
    final pilot = (planes['controlledPilot'] as Map).cast<String, dynamic>();
    final next = (planes['nextCandidate'] as Map).cast<String, dynamic>();
    final policy = _readObject('release/production-release-policy.json');
    final release = (policy['release'] as Map).cast<String, dynamic>();
    final finalization = (policy['finalization'] as Map)
        .cast<String, dynamic>();
    final priorFinalization = (finalization['priorCompletedBuild'] as Map)
        .cast<String, dynamic>();
    final pendingConstruction =
        finalization['status'] == 'pending-source-authorized';
    final finalizedAuthority = pendingConstruction
        ? priorFinalization
        : finalization;
    final runtimeValidationPassed =
        finalizedAuthority['runtimeValidationPassed'] == true;
    final candidateBuildNumber = release['buildNumber'] as int;
    final finalizedBuildNumber =
        finalizedAuthority['buildNumber'] as int? ?? candidateBuildNumber;
    final historicalFirestoreAuthority =
        (finalization['exactFirestoreRulesIndexesLiveReadback'] as Map)
            .cast<String, dynamic>();
    final promotion = (policy['postBuildPromotion'] as Map)
        .cast<String, dynamic>();
    final distribution = (policy['distribution'] as Map)
        .cast<String, dynamic>();
    final pilotApplicability = _pilotApplicability(policy);
    final controlledPilotApproved = pilotApplicability.candidate;
    final finalizedPilotApproved = pilotApplicability.finalized;
    final ledger = _readObject('release/build-number-ledger.json');
    final ledgerEntries = _objects(ledger['entries']);
    final latestLedgerEntry = ledgerEntries.last;
    final latestFinalizedLedgerEntry = ledgerEntries
        .where((entry) => entry['buildNumber'] == artifact['buildNumber'])
        .single;
    final receipt = _readObject(
      finalizedAuthority['completionReceiptFile'] as String,
    );
    final receiptRelease = (receipt['release'] as Map).cast<String, dynamic>();
    final receiptSourceAuthority = (receipt['sourceAuthority'] as Map)
        .cast<String, dynamic>();
    final liveBackend = _readObject(
      deployed['functionFleetEvidenceFile'] as String,
    );
    // Business31 publishes only its custody envelopes; the recorded private
    // replay is authenticated by the policy gate. Its Rules/index plane is the
    // policy's source-specific readback, exactly as in the policy gate and the
    // canonical audit. Every other route keeps its clean-main receipt planes.
    final business31 = _business31Selected(policy);
    final cleanMainLiveReadbacks = business31
        ? null
        : (liveBackend['cleanMainLiveReadbacks'] as Map)
              .cast<String, dynamic>();
    final functionReadbackAuthority = cleanMainLiveReadbacks == null
        ? null
        : (cleanMainLiveReadbacks['functionFleet'] as Map)
              .cast<String, dynamic>();
    final iamReadbackAuthority = cleanMainLiveReadbacks == null
        ? null
        : (cleanMainLiveReadbacks['iamDependencies'] as Map)
              .cast<String, dynamic>();
    final firestoreAuthority = cleanMainLiveReadbacks == null
        ? <String, dynamic>{
            ...historicalFirestoreAuthority,
            'file': historicalFirestoreAuthority['receiptFile'],
            'physicalSha256': historicalFirestoreAuthority['receiptFileSha256'],
            'canonicalReceiptSha256':
                historicalFirestoreAuthority['receiptCanonicalSha256'],
          }
        : (cleanMainLiveReadbacks['firestoreRulesAndIndexes'] as Map)
              .cast<String, dynamic>();
    final rulesReadback = _readObject(
      deployed['rulesAndIndexesEvidenceFile'] as String,
    );
    final rulesReadbackSource = (rulesReadback['source'] as Map)
        .cast<String, dynamic>();
    final rulesReadbackBefore = (rulesReadbackSource['before'] as Map)
        .cast<String, dynamic>();
    final historicalRulesHold = _readObject(
      'release/evidence/build15-firestore-rules-readback-hold.json',
    );
    final nextApproval = _readObject(
      (policy['versionPolicy'] as Map)['sourceDocumentFile'] as String,
    );
    final nextEnvironment = _readObject(
      ((policy['github'] as Map)['environmentReviewControl']
              as Map)['approvalReceiptFile']
          as String,
    );
    final requiredSource = (nextApproval['requiredSource'] as Map)
        .cast<String, dynamic>();
    final deploymentApproval = _readObject(
      deployed['deploymentApprovalFile'] as String,
    );
    final nextApprovalBuild = (nextApproval['nextBuild'] as Map)
        .cast<String, dynamic>();
    final backendSourceCommit = business31
        ? (liveBackend['source'] as Map)['commit'] as String
        : (liveBackend['sourceAuthority'] as Map)['commit'] as String;
    final rulesReadbackOutputs = (rulesReadback['outputs'] as Map)
        .cast<String, dynamic>();
    final verifiedRules = (rulesReadbackOutputs['rules'] as Map)
        .cast<String, dynamic>();
    final verifiedIndexes = (rulesReadbackOutputs['indexes'] as Map)
        .cast<String, dynamic>();
    final historicalHoldBoundary =
        (historicalRulesHold['releaseBoundary'] as Map).cast<String, dynamic>();
    final predecessor =
        (requiredSource['predecessorFinalizationReceipt'] as Map)
            .cast<String, dynamic>();
    final environmentScope = (nextEnvironment['scope'] as Map)
        .cast<String, dynamic>();
    final environmentEvidence = (nextEnvironment['liveStateEvidence'] as Map)
        .cast<String, dynamic>();
    final deployedFunctionsTree = _gitTreeObjectId(
      backendSourceCommit,
      'functions',
    );
    final currentFunctionsTree = _gitTreeObjectId('HEAD', 'functions');
    final expectedFunctionDeployment = _functionDeploymentStatus(
      deployedFunctionsTree,
      currentFunctionsTree,
    );
    final functionsMatchDeployed =
        expectedFunctionDeployment ==
        'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK';
    final sourceIndexProbe = Process.runSync('node', <String>[
      'tools/release/collectFirestoreRulesIndexesReadback.js',
      '--source-index-set',
      'firestore.indexes.json',
    ]);
    expect(sourceIndexProbe.exitCode, 0);
    final sourceIndexBinding =
        (jsonDecode(sourceIndexProbe.stdout as String) as Map)
            .cast<String, dynamic>();
    final currentRulesSha = _sha256('firestore.rules');
    final rulesChanged = currentRulesSha != firestoreAuthority['rulesSha256'];
    final indexesChanged =
        sourceIndexBinding['count'] != firestoreAuthority['indexCount'] ||
        sourceIndexBinding['indexSetSha256'] !=
            firestoreAuthority['indexSetSha256'] ||
        sourceIndexBinding['sourceFileSha256'] !=
            verifiedIndexes['sourceFileSha256'] ||
        sourceIndexBinding['fieldOverrideCount'] !=
            verifiedIndexes['sourceFieldOverrideCount'] ||
        sourceIndexBinding['fieldOverrideSetSha256'] !=
            verifiedIndexes['sourceFieldOverrideSha256'];
    final firestoreMatchesDeployed = !rulesChanged && !indexesChanged;
    final backendMatchesDeployed =
        functionsMatchDeployed && firestoreMatchesDeployed;
    final sourceBaseline = (nextApproval['sourceBaseline'] as Map)
        .cast<String, dynamic>();
    final candidateSourceMatchesApproval = _approvedArtifactSourceMatches(
      sourceBaseline['commit'] as String,
      '${release['versionName']}+$candidateBuildNumber',
      integration: business31
          ? _business31SourceIntegration(
              policy,
              sourceBaseline['commit'] as String,
            )
          : null,
    );
    final finalizedArtifactSourceMatches =
        !pendingConstruction &&
        _approvedArtifactSourceMatches(
          receiptSourceAuthority['commit'] as String,
          '${release['versionName']}+$candidateBuildNumber',
        );
    final currentSourceRuntimeAuthority = _currentSourceRuntimeAuthority(
      artifactPilotApproved: controlledPilotApproved,
      backendMatchesDeployed: backendMatchesDeployed,
      applicationMatchesPromotedArtifact: _promotedApplicationSourceMatches(
        receiptSourceAuthority['commit'] as String,
      ),
    );
    final functionReadback = functionReadbackAuthority == null
        ? null
        : _readObject(functionReadbackAuthority['file'] as String);
    final iamReadback = iamReadbackAuthority == null
        ? null
        : _readObject(iamReadbackAuthority['file'] as String);
    if (!business31) {
      // Business31 keeps its approval chronology inside the recorded private
      // replay, which the policy gate authenticates; the envelopes carry none.
      final backendApprovedAt = DateTime.parse(
        deploymentApproval['approvedAtUtc'] as String,
      );
      for (final capturedAt in <String>[
        functionReadback!['capturedAtUtc'] as String,
        iamReadback!['capturedAtUtc'] as String,
        rulesReadback['capturedAtUtc'] as String,
        liveBackend['recordedAtUtc'] as String,
      ]) {
        expect(DateTime.parse(capturedAt).isBefore(backendApprovedAt), isFalse);
      }
    }
    final expectedFirestoreRelationship = _firestoreRelationship(
      rulesChanged: rulesChanged,
      indexesChanged: indexesChanged,
    );
    final expectedFirestoreDeployment = _firestoreDeploymentStatus(
      rulesChanged: rulesChanged,
      indexesChanged: indexesChanged,
    );
    final expectedBackendStatus = backendMatchesDeployed
        ? 'EXACT_SOURCE_BACKEND_DEPLOYED_AND_VERIFIED'
        : 'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';

    expect(state['schemaVersion'], 2);
    expect(
      state['status'],
      pendingConstruction
          ? !backendMatchesDeployed
                ? 'BUILD${candidateBuildNumber}_SOURCE_AUTHORIZED_'
                      'BACKEND_PENDING_GOVERNED_DEPLOYMENT'
                : !candidateSourceMatchesApproval
                ? 'BUILD${candidateBuildNumber}_SOURCE_SUCCESSOR_'
                      'BACKEND_READY_AWAITING_ARTIFACT_SOURCE_REBIND'
                : 'BUILD${candidateBuildNumber}_SOURCE_AUTHORIZED_'
                      'BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION'
          : backendMatchesDeployed
          ? runtimeValidationPassed
                ? controlledPilotApproved
                      ? 'BUILD${candidateBuildNumber}_FINALIZED_BACKEND_READY_'
                            'DEVICE_ACCEPTED_STAGED_PILOT_AUTHORIZED_'
                            'AWAITING_MUTATING_FLOW_AND_HANDOUT_RECEIPTS'
                      : 'BUILD${candidateBuildNumber}_FINALIZED_BACKEND_READY_'
                            'DEVICE_ACCEPTED_AWAITING_MUTATING_FLOW_AND_'
                            'PILOT_DECISIONS'
                : 'BUILD${candidateBuildNumber}_FINALIZED_BACKEND_READY_'
                      'AWAITING_DEVICE_AND_PILOT_DECISIONS'
          : runtimeValidationPassed
          ? 'BUILD${candidateBuildNumber}_FINALIZED_SOURCE_SUCCESSOR_'
                'AWAITING_GOVERNED_BACKEND_DEPLOYMENT_MUTATING_FLOW_AND_'
                'PILOT_DECISIONS'
          : 'BUILD${candidateBuildNumber}_FINALIZED_SOURCE_SUCCESSOR_'
                'AWAITING_GOVERNED_BACKEND_DEPLOYMENT_DEVICE_AND_'
                'PILOT_DECISIONS',
    );
    expect(currentSource['reference'], 'refs/heads/main');
    expect(currentSource['packageVersion'], _packageVersion());
    expect(
      currentSource['relationshipToLatestFinalizedArtifact'],
      pendingConstruction || !finalizedArtifactSourceMatches
          ? 'BUILD${candidateBuildNumber}_SOURCE_SUCCESSOR_OF_'
                'FINALIZED_BUILD$finalizedBuildNumber'
          : 'BUILD${candidateBuildNumber}_SOURCE_CONTAINS_'
                'FINALIZED_BUILD$finalizedBuildNumber',
    );
    expect(currentSource['sourceAndCiAuthority'], isTrue);
    expect(
      currentSource['artifactConstructionAuthority'],
      _artifactConstructionAuthority(
        pendingSourceAuthorization: pendingConstruction,
        backendMatchesDeployed: backendMatchesDeployed,
        artifactSourceMatchesApproval: candidateSourceMatchesApproval,
      ),
    );
    expect(currentSource['deploymentAuthority'], isFalse);
    expect(
      currentSource['distributionAuthority'],
      currentSourceRuntimeAuthority,
    );
    expect(currentSource['sameBuildNumberReuseProhibited'], isTrue);
    expect(currentSource['backendDeploymentStatus'], expectedBackendStatus);
    expect(
      currentSource['productionRuntimeUseAuthorized'],
      currentSourceRuntimeAuthority,
    );

    expect(artifact['buildNumber'], finalizedBuildNumber);
    expect(artifact['buildNumber'], latestFinalizedLedgerEntry['buildNumber']);
    expect(artifact['buildNumber'], receiptRelease['buildNumber']);
    expect(
      artifact['version'],
      '${latestFinalizedLedgerEntry['versionName']}+$finalizedBuildNumber',
    );
    expect(artifact['sourceCommit'], finalizedAuthority['sourceCommit']);
    expect(release['buildNumber'], latestLedgerEntry['buildNumber']);
    expect(
      latestLedgerEntry['status'],
      pendingConstruction
          ? 'source-reserved-awaiting-remote-consumption'
          : 'remote-consumed-artifact-built-finalized-non-distributable',
    );
    if (!pendingConstruction) {
      expect(latestLedgerEntry['githubRunId'], finalization['githubRunId']);
      expect(
        latestLedgerEntry['governedPackageSha256'],
        finalization['governedPackageSha256'],
      );
    }
    final artifactIsAncestor = Process.runSync('git', <String>[
      'merge-base',
      '--is-ancestor',
      artifact['sourceCommit'] as String,
      'HEAD',
    ]);
    expect(
      artifactIsAncestor.exitCode,
      0,
      reason: 'Current source must descend from the finalized artifact.',
    );
    expect(
      artifact['status'],
      finalizedPilotApproved
          ? 'COMPLETED_STAGED_CONTROLLED_PILOT_AUTHORIZED'
          : 'COMPLETED_NON_DISTRIBUTABLE',
    );
    expect(
      artifact['completionReceiptFile'],
      finalizedAuthority['completionReceiptFile'],
    );
    expect(
      artifact['completionReceiptSha256'],
      finalizedAuthority['completionReceiptSha256'],
    );
    expect(
      _sha256(artifact['completionReceiptFile'] as String),
      artifact['completionReceiptSha256'],
    );
    expect(
      artifact['runtimeValidation'],
      runtimeValidationPassed
          ? 'PASSED_EXACT_BUILD${finalizedBuildNumber}_PHYSICAL_IN_PLACE_'
                'AUTHENTICATED_READ_ONLY_SURFACES'
          : 'NOT_ADJUDICATED_FOR_EXACT_BUILD$finalizedBuildNumber',
    );
    if (runtimeValidationPassed) {
      expect(
        artifact['deviceAcceptanceReceiptFile'],
        finalizedAuthority['deviceAcceptanceReceiptFile'],
      );
      expect(
        artifact['deviceAcceptanceReceiptSha256'],
        finalizedAuthority['deviceAcceptanceReceiptSha256'],
      );
      expect(
        _sha256(artifact['deviceAcceptanceReceiptFile'] as String),
        artifact['deviceAcceptanceReceiptSha256'],
      );
      expect(
        artifact['fullBusinessFlowValidation'],
        'MUTATING_FLOWS_NOT_ADJUDICATED',
      );
    }
    expect(
      artifact['pilotPromotion'],
      finalizedPilotApproved
          ? 'AUTHORIZED_STAGED_EXACT_BUILD${finalizedBuildNumber}_UP_TO_25'
          : 'NOT_AUTHORIZED',
    );
    if (finalizedPilotApproved) {
      expect(
        artifact['pilotPromotionReceiptFile'],
        promotion['promotionReceiptFile'],
      );
      expect(
        artifact['pilotPromotionReceiptSha256'],
        promotion['promotionReceiptSha256'],
      );
      expect(
        _sha256(artifact['pilotPromotionReceiptFile'] as String),
        artifact['pilotPromotionReceiptSha256'],
      );
    }
    expect(artifact['unrestrictedDistribution'], 'NOT_AUTHORIZED');

    expect(
      finalization['exactFunctionFleetDeploymentReceiptFile'],
      requiredSource['exactFunctionFleetDeploymentReceiptFile'],
    );
    expect(
      _sha256(
        finalization['exactFunctionFleetDeploymentReceiptFile'] as String,
      ),
      requiredSource['exactFunctionFleetDeploymentReceiptSha256'],
    );
    expect(
      _sha256(deployed['functionFleetEvidenceFile'] as String),
      deployed['functionFleetEvidenceSha256'],
    );
    expect(
      deployed['functionFleetReadbackDecision'],
      'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    );
    expect(
      deployed['rulesAndIndexesReadbackDecision'],
      'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK',
    );
    expect(
      deployed['currentSourceFunctionDeployment'],
      expectedFunctionDeployment,
    );
    expect(
      deployed['currentSourceRulesAndIndexesDeployment'],
      expectedFirestoreDeployment,
    );
    if (business31) {
      _expectBusiness31PublicBackend(
        policy: policy,
        deployed: deployed,
        closure: liveBackend,
        approval: deploymentApproval,
      );
    } else {
      final backendAuthority = (liveBackend['sourceAuthority'] as Map)
          .cast<String, dynamic>();
      final backendDeployment = (liveBackend['deployment'] as Map)
          .cast<String, dynamic>();
      final backendBoundary = (liveBackend['controlBoundary'] as Map)
          .cast<String, dynamic>();
      expect(
        liveBackend['decision'],
        deployed['functionFleetReadbackDecision'],
      );
      expect(backendAuthority['commit'], deployed['functionFleetSourceCommit']);
      expect(
        _gitTreeObjectId(backendAuthority['commit'] as String, 'functions'),
        backendAuthority['functionsGitObjectId'],
      );
      expect(
        backendAuthority['pullRequestNumber'],
        (deploymentApproval['sourceAuthority'] as Map)['pullRequestNumber'],
      );
      final approvalAuthority = (liveBackend['approvalAuthority'] as Map)
          .cast<String, dynamic>();
      expect(deployed['deploymentApprovalFile'], approvalAuthority['file']);
      expect(
        _sha256(deployed['deploymentApprovalFile'] as String),
        approvalAuthority['sha256'],
      );
      expect(deploymentApproval['approved'], isTrue);
      expect(
        (deploymentApproval['sourceAuthority'] as Map)['commit'],
        backendAuthority['commit'],
      );
      final backendProof = _backendEvidenceProbe(
        deployed['functionFleetEvidenceFile'] as String,
        expectedBuildNumber: release['buildNumber'] as int,
      );
      expect(
        backendProof['ok'],
        isTrue,
        reason: backendProof['reason'] as String?,
      );
      final fleet = (backendProof['fleet'] as Map).cast<String, dynamic>();
      for (final field in <String>[
        'functionCount',
        'callableCount',
        'eventAndProtocolTriggerCount',
        'schedulerCount',
      ]) {
        expect(backendDeployment[field], fleet[field]);
      }
      for (final readback in <Map<String, dynamic>>[
        functionReadback!,
        iamReadback!,
      ]) {
        final names = _objects(
          (readback['outputs'] as Map)['functions'],
        ).map((row) => row['name']);
        expect(names, unorderedEquals(_strings(fleet['functionNames'])));
      }
      // Re-adjudicate all live approval, immutable custody, scoped IAM, Rules and
      // readback evidence using the existing shared authority verifier.
      final authorityCheck = Process.runSync('node', <String>[
        'tools/release/clientBackendCompatibility31.js',
        Directory.current.path,
        'release/production-release-policy.json',
      ]);
      expect(
        authorityCheck.exitCode,
        0,
        reason: authorityCheck.stderr as String,
      );
      expect(
        (jsonDecode(authorityCheck.stdout as String) as Map)['ok'],
        isTrue,
      );
      expect(backendDeployment['allFunctionsExactSourceVerified'], isTrue);
      expect(backendDeployment['existingIamPreservationEnforced'], isTrue);
      expect(
        backendProof['iamDecision'],
        backendBoundary['iamMutated'] == true
            ? 'PASS_NEW_CALLABLE_INVOKER_IAM_ONLY'
            : 'PASS_NO_IAM_MUTATION',
      );
      expect(backendBoundary['productionBusinessDataMutated'], isFalse);
      expect(backendBoundary['distributionPerformed'], isFalse);
      _expectBackendExecutionEvidence(liveBackend);
      expect(
        _sha256(functionReadbackAuthority!['file'] as String),
        functionReadbackAuthority['physicalSha256'],
      );
      expect(
        (functionReadback['receiptSha256'] as String).toUpperCase(),
        functionReadbackAuthority['canonicalReceiptSha256'],
      );
      expect(
        _sha256(iamReadbackAuthority!['file'] as String),
        iamReadbackAuthority['physicalSha256'],
      );
      expect(
        (iamReadback['receiptSha256'] as String).toUpperCase(),
        iamReadbackAuthority['canonicalReceiptSha256'],
      );
    }
    expect(
      rulesReadback['decision'],
      deployed['rulesAndIndexesReadbackDecision'],
    );
    expect(firestoreAuthority['file'], deployed['rulesAndIndexesEvidenceFile']);
    expect(
      _sha256(deployed['rulesAndIndexesEvidenceFile'] as String),
      firestoreAuthority['physicalSha256'],
    );
    expect(
      (rulesReadback['receiptSha256'] as String).toUpperCase(),
      firestoreAuthority['canonicalReceiptSha256'],
    );
    expect(
      deployed['rulesAndIndexesSourceCommit'],
      firestoreAuthority['sourceCommit'],
    );
    expect(
      deployed['rulesAndIndexesSourceCommit'],
      rulesReadbackBefore['commit'],
    );
    expect(verifiedRules['sourceSha256'], firestoreAuthority['rulesSha256']);
    expect(currentFirestoreSource['rulesSha256'], currentRulesSha);
    expect(verifiedRules['activeSha256'], verifiedRules['sourceSha256']);
    expect(verifiedRules['byteExact'], isTrue);
    expect(verifiedIndexes['sourceCount'], firestoreAuthority['indexCount']);
    expect(verifiedIndexes['apiCount'], verifiedIndexes['sourceCount']);
    expect(verifiedIndexes['apiReadyCount'], verifiedIndexes['sourceCount']);
    expect(verifiedIndexes['allApiIndexesReady'], isTrue);
    expect(
      verifiedIndexes['sourceSetSha256'],
      firestoreAuthority['indexSetSha256'],
    );
    expect(
      historicalFirestoreAuthority['receiptFile'],
      requiredSource['exactFirestoreRulesReceiptFile'],
    );
    expect(sourceIndexBinding['count'], currentFirestoreSource['indexCount']);
    expect(
      sourceIndexBinding['indexSetSha256'],
      currentFirestoreSource['indexSetSha256'],
    );
    expect(
      sourceIndexBinding['sourceFileSha256'],
      currentFirestoreSource['indexFileSha256'],
    );
    expect(
      sourceIndexBinding['fieldOverrideCount'],
      currentFirestoreSource['fieldOverrideCount'],
    );
    expect(
      sourceIndexBinding['fieldOverrideSetSha256'],
      currentFirestoreSource['fieldOverrideSetSha256'],
    );
    expect(
      currentFirestoreSource['relationshipToDeployedBackend'],
      expectedFirestoreRelationship,
    );
    expect(
      currentFirestoreSource['productionDeploymentPerformed'],
      firestoreMatchesDeployed,
    );
    expect(
      currentFirestoreSource['productionRuntimeUseAuthorized'],
      firestoreMatchesDeployed,
    );
    expect(
      historicalRulesHold['decision'],
      'HOLD_BUILD15_EXACT_FIRESTORE_RULES_READBACK',
    );
    expect(
      historicalHoldBoundary['build15ConstructionAuthorizedByThisEvidence'],
      isFalse,
    );
    expect(
      historicalHoldBoundary['productionRulesDeploymentApprovedByThisEvidence'],
      isFalse,
    );
    expect(historicalHoldBoundary['pilotPromotionApproved'], isFalse);
    expect(predecessor['buildNumber'], priorFinalization['buildNumber']);
    expect(predecessor['file'], priorFinalization['completionReceiptFile']);
    expect(predecessor['sha256'], priorFinalization['completionReceiptSha256']);
    expect(nextApproval['approved'], isTrue);
    expect(nextApprovalBuild['buildNumber'], candidateBuildNumber);
    expect(nextApproval['distributionApproved'], isFalse);
    expect(nextEnvironment['approved'], isTrue);
    expect(environmentScope['buildNumber'], nextApprovalBuild['buildNumber']);
    expect(environmentEvidence['requiredReviewerRulePresent'], isTrue);
    expect(environmentEvidence['secretValuesInspected'], isFalse);
    expect(
      (environmentEvidence['requiredReviewer'] as Map)['login'],
      'abhishekvatsa',
    );
    expect(pilot['buildNumber'], promotion['buildNumber']);
    expect(pilot['buildNumber'], policy['distribution']['approvedBuildNumber']);
    expect(pilot['handoutPerformed'], isFalse);
    expect(pilot['appliesToCurrentSource'], currentSourceRuntimeAuthority);
    expect(pilot['maximumApprovedUsers'], distribution['maximumApprovedUsers']);
    expect(pilot['canaryUserCeiling'], distribution['canaryUserCeiling']);
    expect(
      pilot['canaryPhysicalDeviceCeiling'],
      distribution['canaryPhysicalDeviceCeiling'],
    );
    expect(pilot['appliesToBuild14'], isFalse);
    expect(pilot['appliesToBuild15'], isFalse);
    expect(pilot['appliesToBuild16'], isFalse);
    expect(pilot['appliesToBuild17'], isFalse);
    expect(
      pilot['appliesToBuild$candidateBuildNumber'],
      controlledPilotApproved,
    );
    expect(
      next['minimumBuildNumber'],
      candidateBuildNumber + (pendingConstruction ? 0 : 1),
    );
    expect(
      next['status'],
      pendingConstruction
          ? !backendMatchesDeployed
                ? 'SOURCE_AUTHORIZED_AWAITING_GOVERNED_BACKEND_DEPLOYMENT'
                : !candidateSourceMatchesApproval
                ? 'SOURCE_SUCCESSOR_AWAITING_BUILD${candidateBuildNumber}_'
                      'ARTIFACT_SOURCE_REBIND'
                : 'SOURCE_AUTHORIZED_AWAITING_SIGNED_'
                      'BUILD${candidateBuildNumber}_CONSTRUCTION'
          : 'AWAITING_FRESH_GOVERNED_BUILD${candidateBuildNumber + 1}_'
                'APPROVAL',
    );
    expect(next.containsKey('versionApprovalFile'), pendingConstruction);
    expect(next.containsKey('environmentApprovalFile'), pendingConstruction);
    expect(
      next['constructionRequiresFreshGovernedApproval'],
      !pendingConstruction,
    );
    expect(next['deviceValidationRequiresExactNewArtifact'], isTrue);
    expect(next['pilotPromotionRequiresSeparateDecision'], isTrue);
    expect(state['localStore']['schemaVersion'], _currentIsarSchemaVersion());
    expect(state['appCheck']['mutatingCallableSourceDefault'], isFalse);

    final readme = File('README.md').readAsStringSync();
    expect(
      readme,
      contains('Build $candidateBuildNumber (`${_packageVersion()}`)'),
    );
    expect(readme, isNot(contains('Build 12 is source authorized')));
  });

  test('Build 16 phone smoke never implies migration or pilot authority', () {
    final build17Approval = _readObject(
      'release/approvals/build-number-17-successor-approval.json',
    );
    final build16Authority = (build17Approval['preservedCompletedBuild'] as Map)
        .cast<String, dynamic>();
    final receipt = _readObject(
      build16Authority['completionReceiptFile'] as String,
    );
    final smoke = _readObject(
      'release/evidence/build-16-device-installation-smoke.json',
    );
    final governedPackage = (receipt['governedPackage'] as Map)
        .cast<String, dynamic>();
    final physical = (smoke['physicalDevice'] as Map).cast<String, dynamic>();
    final emulator = (smoke['emulator'] as Map).cast<String, dynamic>();
    final boundary = (smoke['boundary'] as Map).cast<String, dynamic>();
    final releaseBoundary = (receipt['releaseBoundary'] as Map)
        .cast<String, dynamic>();

    expect(build16Authority['status'], 'completed-non-distributable');
    expect(build16Authority['buildNumber'], 16);
    expect(
      _sha256(build16Authority['completionReceiptFile'] as String),
      build16Authority['completionReceiptSha256'],
    );
    expect(
      _sha256('release/evidence/build-16-device-installation-smoke.json'),
      'FBAAFB5EBFC68F630C5576D41362EC50F4A502FADE65511A98A7F279BCD63BB0',
    );
    expect(smoke['status'], 'passed-to-authentication-boundary');
    expect(
      (smoke['release'] as Map)['apkSha256'],
      governedPackage['apkSha256'],
    );
    expect(physical['installedVersionCode'], 16);
    expect(physical['installationMode'], 'fresh-install');
    expect(physical['applicationDataCleared'], isFalse);
    expect(physical['deviceSerialRecorded'], isFalse);
    expect(physical['authenticatedBusinessFlowValidationCompleted'], isFalse);
    expect(
      emulator['upgradeResult'],
      'blocked-existing-installation-signer-mismatch',
    );
    expect(emulator['existingInstallationPreserved'], isTrue);
    expect(emulator['applicationUninstalled'], isFalse);
    expect(emulator['applicationDataCleared'], isFalse);
    expect(boundary.values, everyElement(isFalse));
    expect(build16Authority['runtimeValidationPassed'], isFalse);
    expect(releaseBoundary['controlledPilotApproved'], isFalse);
  });

  test('historical Build 12 deployment record remains exact', () {
    final deployment = _readObject(
      'release/build12-live-deployment-authority.json',
    );
    final approval = _readObject(
      'release/approvals/build12-backend-rules-indexes-deployment-authorization.json',
    );
    final source = (deployment['source'] as Map).cast<String, dynamic>();
    final boundary = (deployment['authorityBoundary'] as Map)
        .cast<String, dynamic>();

    expect(
      deployment['status'],
      'PASS_BUILD12_BACKEND_RULES_INDEXES_IAM_DEPLOYED_EXACT',
    );
    expect(approval['approved'], isTrue);
    expect(approval['approvalReference'], 'BAF-FIREBASE-DEPLOY-012');
    expect(
      (deployment['authorization'] as Map)['recordSha256'],
      _sha256(
        'release/approvals/build12-backend-rules-indexes-deployment-authorization.json',
      ),
    );
    expect(
      source['finalizationReceiptSha256'],
      _sha256('release/evidence/build-12-finalization-closure.json'),
    );
    expect(boundary['backendDeploymentProved'], isTrue);
    expect(boundary['rulesAndIndexesDeploymentProved'], isTrue);
    expect(boundary['runtimeIamProved'], isTrue);
    expect(boundary['productionSignedClientConstructed'], isTrue);
    expect(boundary['deviceUpgradeProved'], isTrue);
    expect(
      boundary['postAssetPopulationLiveWorkflowValidationProved'],
      isFalse,
    );
    expect(boundary['pilotHandoutAuthorized'], isFalse);
  });

  test('legacy receipt labels resolve to exact predecessor evidence', () {
    final registry = _readObject(
      'release/predecessor-finalization-receipt-bindings.json',
    );
    final legacy = (registry['legacyFieldNames'] as Map)
        .cast<String, dynamic>();
    final future = (registry['futureFieldContract'] as Map)
        .cast<String, dynamic>();
    final bindings = _objects(registry['compatibilityBindings']);

    expect(registry['schemaVersion'], 1);
    expect(registry['historicalApprovalFilesImmutable'], isTrue);
    expect(legacy['file'], 'build11FinalizationReceiptFile');
    expect(legacy['sha256'], 'build11FinalizationReceiptSha256');
    expect(future['object'], 'predecessorFinalizationReceipt');
    expect(future['legacyAliasPermittedOnlyWhenRegisteredHere'], isTrue);
    expect(
      bindings.map((entry) => entry['successorBuildNumber']),
      orderedEquals(<int>[12, 13, 14]),
    );

    for (final binding in bindings) {
      final approvalPath = binding['approvalFile'] as String;
      final receiptPath = binding['receiptFile'] as String;
      final approval = _readObject(approvalPath);
      final requiredSource = (approval['requiredSource'] as Map)
          .cast<String, dynamic>();
      final preserved = (approval['preservedCompletedBuild'] as Map)
          .cast<String, dynamic>();
      final receipt = _readObject(receiptPath);
      final receiptRelease = (receipt['release'] as Map)
          .cast<String, dynamic>();

      expect(_sha256(approvalPath), binding['approvalSha256']);
      expect(_sha256(receiptPath), binding['receiptSha256']);
      expect(
        binding['successorBuildNumber'],
        (binding['predecessorBuildNumber'] as int) + 1,
      );
      expect(
        (approval['nextBuild'] as Map)['buildNumber'],
        binding['successorBuildNumber'],
      );
      expect(preserved['buildNumber'], binding['predecessorBuildNumber']);
      expect(requiredSource[legacy['file']], binding['receiptFile']);
      expect(requiredSource[legacy['sha256']], binding['receiptSha256']);
      expect(receiptRelease['buildNumber'], binding['predecessorBuildNumber']);
    }

    final verifier = File(
      'tools/release/Test-ProductionReleasePolicy.ps1',
    ).readAsStringSync();
    expect(verifier, contains('predecessorFinalizationReceipt'));
    expect(
      verifier,
      contains(
        'Legacy predecessor receipt alias is not explicitly registered.',
      ),
    );
    expect(
      verifier,
      contains(
        'Resolved predecessor finalization receipt differs from authority.',
      ),
    );
  });
}
