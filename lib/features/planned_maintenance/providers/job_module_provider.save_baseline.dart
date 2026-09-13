part of 'job_module_provider.dart';

/// A frozen native read preimage. Capture before the editor opens, never from
/// its already modified candidate. Comparing the full persisted projection
/// also detects contradictory same-version adoption.
class JobModuleSaveBaseline {
  final int localId;
  final int version;
  final String preimageJson;

  JobModuleSaveBaseline.capture(JobModuleInstance module)
    : localId = module.id,
      version = module.version,
      preimageJson = jsonEncode(jobModuleLocalSnapshot(module));

  JobModuleSaveBaseline.fromSnapshot(Map<String, dynamic> snapshot)
    : localId = snapshot['id'] as int,
      version = snapshot['version'] as int,
      preimageJson = jsonEncode(snapshot);

  bool matches(JobModuleInstance current) =>
      localId == current.id &&
      version == current.version &&
      preimageJson == jsonEncode(jobModuleLocalSnapshot(current));
}
