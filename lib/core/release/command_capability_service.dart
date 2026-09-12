import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef CommandCapabilityInvoker =
    Future<Object?> Function(String callableName, Map<String, Object?> data);

class CommandCapabilityException implements Exception {
  final String code;
  final String message;
  const CommandCapabilityException(this.code, this.message);

  @override
  String toString() => message;
}

class CommandCapabilities {
  final String callableName;
  final String capabilityRevision;
  final Set<String> capabilities;

  const CommandCapabilities._(
    this.callableName,
    this.capabilityRevision,
    this.capabilities,
  );

  factory CommandCapabilities.parse(Object? raw, String expectedCallable) {
    const keys = <String>{
      'schemaVersion',
      'callableName',
      'protocolVersion',
      'capabilityRevision',
      'capabilities',
    };
    if (raw is! Map ||
        raw.length != keys.length ||
        raw.keys.any((key) => !keys.contains(key)) ||
        raw['schemaVersion'] != 1 ||
        raw['protocolVersion'] != 2 ||
        raw['callableName'] != expectedCallable ||
        raw['capabilityRevision'] is! String ||
        (raw['capabilityRevision'] as String).trim().isEmpty ||
        raw['capabilities'] is! List) {
      throw const FormatException('The server capability response is invalid.');
    }
    final values = raw['capabilities'] as List;
    if (values.any(
      (value) => value is! String || value.isEmpty || value != value.trim(),
    )) {
      throw const FormatException('The server capability list is invalid.');
    }
    final capabilities = values.cast<String>().toSet();
    if (capabilities.length != values.length) {
      throw const FormatException('The server capability list is duplicated.');
    }
    return CommandCapabilities._(
      expectedCallable,
      raw['capabilityRevision'] as String,
      Set.unmodifiable(capabilities),
    );
  }
}

/// Fresh probes run on the exact executable endpoint that will receive the
/// saved command. Release labels and cached account state are not authority.
class CommandCapabilityService {
  final FirebaseFunctions? functions;
  final String? Function()? currentActorUid;
  final CommandCapabilityInvoker? invoke;

  const CommandCapabilityService({
    this.functions,
    this.currentActorUid,
    this.invoke,
  });

  String? get _actorUid => currentActorUid == null
      ? FirebaseAuth.instance.currentUser?.uid
      : currentActorUid!();

  void _requireOrigin(String originActorUid) {
    if (originActorUid.isEmpty ||
        originActorUid != originActorUid.trim() ||
        _actorUid != originActorUid) {
      throw const CommandCapabilityException(
        'origin-account-mismatch',
        'Sign in with the account that saved this request before continuing.',
      );
    }
  }

  Future<CommandCapabilities> requireCapabilities({
    required String callableName,
    required String originActorUid,
    required Set<String> requiredCapabilities,
  }) async {
    if (!const <String>{
      'mutateAssetHierarchyV2',
      'executeMaintenanceWorkflowCommandV2',
      'mutateChargeAbnormalityV2',
      'assignPublishedTemplateVersionV2',
    }.contains(callableName)) {
      throw const CommandCapabilityException(
        'unsupported-command-endpoint',
        'This saved request needs a supported server action.',
      );
    }
    _requireOrigin(originActorUid);
    final probe = <String, Object?>{
      'protocolVersion': 2,
      'originActorUid': originActorUid,
      'probe': 'capabilities',
    };
    try {
      final Object? response;
      if (invoke != null) {
        response = await invoke!(callableName, probe);
      } else {
        final client =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');
        response = (await client.httpsCallable(callableName).call(probe)).data;
      }
      _requireOrigin(originActorUid);
      final result = CommandCapabilities.parse(response, callableName);
      if (!result.capabilities.containsAll(requiredCapabilities)) {
        throw const CommandCapabilityException(
          'command-capability-unavailable',
          'This server does not support this saved action yet. Keep it pending until the update is ready.',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw CommandCapabilityException(
        error.code,
        error.code == 'not-found' || error.code == 'unimplemented'
            ? 'This server does not support this saved action yet. Keep it pending until the update is ready.'
            : 'Server support for this action could not be checked. Keep the saved request and try again.',
      );
    } on FormatException catch (error) {
      throw CommandCapabilityException(
        'invalid-capability-response',
        error.message,
      );
    }
  }
}
