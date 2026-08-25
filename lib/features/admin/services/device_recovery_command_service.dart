import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../assets/repositories/asset_hierarchy_repository.dart';
import '../../auth/data/user_model.dart';

const deviceRecoveryListOperation = 'DEVICE_RECOVERY_LIST';
const deviceRecoveryRequestOperation = 'DEVICE_RECOVERY_REQUEST';
const deviceRecoveryPollOperation = 'DEVICE_RECOVERY_POLL';
const deviceRecoveryClaimOperation = 'DEVICE_RECOVERY_CLAIM';
const deviceRecoveryCompleteOperation = 'DEVICE_RECOVERY_COMPLETE';
const deviceRecoveryFailOperation = 'DEVICE_RECOVERY_FAIL';
const deviceRecoveryCancelOperation = 'DEVICE_RECOVERY_CANCEL';

final _installationIdentity = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class DeviceRecoveryException implements Exception {
  const DeviceRecoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceRecoveryInstallation {
  const DeviceRecoveryInstallation({
    required this.installationId,
    required this.platform,
    required this.updatedAt,
    required this.recoveryStatus,
    required this.recoveryRequestId,
    required this.recoveryUpdatedAt,
  });

  final String installationId;
  final String platform;
  final String updatedAt;
  final String recoveryStatus;
  final String? recoveryRequestId;
  final String? recoveryUpdatedAt;

  String get shortIdentity => installationId.substring(0, 8).toUpperCase();

  factory DeviceRecoveryInstallation.fromResponse(Object? raw) {
    if (raw is! Map) {
      throw const DeviceRecoveryException(
        'The server returned an invalid registered-device record.',
      );
    }
    final map = Map<String, Object?>.from(raw);
    final identity = map['installationId'];
    final platform = map['platform'];
    final updatedAt = map['updatedAt'];
    final status = map['recoveryStatus'];
    final requestId = map['recoveryRequestId'];
    final recoveryUpdatedAt = map['recoveryUpdatedAt'];
    if (identity is! String ||
        !_installationIdentity.hasMatch(identity) ||
        platform is! String ||
        platform.isEmpty ||
        updatedAt is! String ||
        updatedAt.isEmpty ||
        status is! String ||
        !const {
          'none',
          'pending',
          'in_progress',
          'completed',
          'failed',
          'cancelled',
        }.contains(status) ||
        (requestId != null &&
            (requestId is! String ||
                !_installationIdentity.hasMatch(requestId))) ||
        (recoveryUpdatedAt != null && recoveryUpdatedAt is! String)) {
      throw const DeviceRecoveryException(
        'The server returned malformed registered-device evidence.',
      );
    }
    return DeviceRecoveryInstallation(
      installationId: identity,
      platform: platform,
      updatedAt: updatedAt,
      recoveryStatus: status,
      recoveryRequestId: requestId as String?,
      recoveryUpdatedAt: recoveryUpdatedAt as String?,
    );
  }
}

class DeviceRecoveryRequest {
  const DeviceRecoveryRequest({
    required this.requestId,
    required this.targetUid,
    required this.installationId,
    required this.requestedByUid,
    required this.requestedByName,
    required this.reason,
    required this.requestedAt,
    required this.expiresAt,
  });

  final String requestId;
  final String targetUid;
  final String installationId;
  final String requestedByUid;
  final String requestedByName;
  final String reason;
  final String requestedAt;
  final String expiresAt;

  factory DeviceRecoveryRequest.fromResponse(
    Object? raw, {
    required String expectedUid,
    required String expectedInstallationId,
  }) {
    if (raw is! Map) {
      throw const DeviceRecoveryException(
        'The pending administrator recovery request is malformed.',
      );
    }
    final map = Map<String, Object?>.from(raw);
    final requestId = map['requestId'];
    final requestedByUid = map['requestedByUid'];
    final requestedByName = map['requestedByName'];
    final reason = map['reason'];
    final requestedAt = map['requestedAt'];
    final expiresAt = map['expiresAt'];
    if (requestId is! String ||
        !_installationIdentity.hasMatch(requestId) ||
        map['targetUid'] != expectedUid ||
        map['installationId'] != expectedInstallationId ||
        !const {'pending', 'in_progress'}.contains(map['status']) ||
        requestedByUid is! String ||
        requestedByUid.isEmpty ||
        requestedByName is! String ||
        requestedByName.isEmpty ||
        reason is! String ||
        reason.trim().length < 12 ||
        requestedAt is! String ||
        requestedAt.isEmpty ||
        expiresAt is! String ||
        expiresAt.isEmpty) {
      throw const DeviceRecoveryException(
        'The administrator recovery request is not valid for this phone.',
      );
    }
    return DeviceRecoveryRequest(
      requestId: requestId,
      targetUid: expectedUid,
      installationId: expectedInstallationId,
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
      reason: reason,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );
  }
}

typedef DeviceRecoveryInvoker =
    Future<Map<String, dynamic>> Function(Map<String, Object?> payload);

class DeviceRecoveryCommandService {
  DeviceRecoveryCommandService({
    DeviceRecoveryInvoker? invoke,
    String? Function()? authenticatedUidLookup,
    Uuid uuid = const Uuid(),
  }) : _invoke = invoke ?? _invokeProduction,
       _authenticatedUidLookup =
           authenticatedUidLookup ??
           (() => FirebaseAuth.instance.currentUser?.uid),
       _uuid = uuid;

  final DeviceRecoveryInvoker _invoke;
  final String? Function() _authenticatedUidLookup;
  final Uuid _uuid;

  static Future<Map<String, dynamic>> _invokeProduction(
    Map<String, Object?> payload,
  ) async {
    final result = await FirebaseFunctions.instanceFor(
          region: assetHierarchyCallableRegion,
        )
        .httpsCallable(assetHierarchyCallableName)
        .call<Map<String, dynamic>>(payload);
    return result.data;
  }

  void _requireActor(AppUser? actor, {required bool admin}) {
    if (actor == null ||
        !actor.isApproved ||
        _authenticatedUidLookup() != actor.uid ||
        (admin && !actor.isAdmin)) {
      throw DeviceRecoveryException(
        admin
            ? 'Fresh administrator authority is required for device recovery.'
            : 'The approved signed-in account changed during device recovery.',
      );
    }
  }

  void _requireRequestOwner(AppUser? actor, DeviceRecoveryRequest request) {
    _requireActor(actor, admin: false);
    if (actor!.uid != request.targetUid) {
      throw const DeviceRecoveryException(
        'The recovery request belongs to another signed-in account.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final response = await _invoke(<String, Object?>{
      'operation': operation,
      ...payload,
    });
    if (response['ok'] != true || response['operation'] != operation) {
      throw const DeviceRecoveryException(
        'The server returned an invalid device-recovery response.',
      );
    }
    return response;
  }

  Future<List<DeviceRecoveryInstallation>> listInstallations({
    required AppUser? actor,
    required String targetUid,
  }) async {
    _requireActor(actor, admin: true);
    final response = await _request(deviceRecoveryListOperation, {
      'targetUid': targetUid,
    });
    final raw = response['installations'];
    if (response['targetUid'] != targetUid || raw is! List || raw.length > 8) {
      throw const DeviceRecoveryException(
        'The server returned an invalid or unbounded device inventory.',
      );
    }
    return raw
        .map(DeviceRecoveryInstallation.fromResponse)
        .toList(growable: false);
  }

  Future<String> requestReset({
    required AppUser? actor,
    required String targetUid,
    required String installationId,
    required String reason,
    String? requestId,
  }) async {
    _requireActor(actor, admin: true);
    final identity = requestId ?? _uuid.v4();
    final response = await _request(deviceRecoveryRequestOperation, {
      'requestId': identity,
      'targetUid': targetUid,
      'installationId': installationId,
      'reason': reason.trim(),
    });
    if (response['requestId'] != identity ||
        response['targetUid'] != targetUid ||
        response['installationId'] != installationId ||
        response['status'] != 'pending') {
      throw const DeviceRecoveryException(
        'The server did not confirm the selected device reset.',
      );
    }
    return identity;
  }

  Future<DeviceRecoveryRequest?> pollPending({
    required AppUser? actor,
    required String installationId,
  }) async {
    _requireActor(actor, admin: false);
    final response = await _request(deviceRecoveryPollOperation, {
      'installationId': installationId,
    });
    if (response['installationId'] != installationId) {
      throw const DeviceRecoveryException(
        'The server returned a recovery request for another installation.',
      );
    }
    final pending = response['request'];
    return pending == null
        ? null
        : DeviceRecoveryRequest.fromResponse(
          pending,
          expectedUid: actor!.uid,
          expectedInstallationId: installationId,
        );
  }

  Future<void> completeReset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
    required int backupFileCount,
    required int clearedCursorCount,
    required int backedUpUnsyncedRows,
  }) async {
    _requireRequestOwner(actor, request);
    final response = await _request(deviceRecoveryCompleteOperation, {
      'requestId': request.requestId,
      'installationId': request.installationId,
      'backupFileCount': backupFileCount,
      'clearedCursorCount': clearedCursorCount,
      'backedUpUnsyncedRows': backedUpUnsyncedRows,
    });
    _verifyCompletion(response, request, 'completed');
  }

  Future<void> claimReset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
  }) async {
    _requireRequestOwner(actor, request);
    final response = await _request(deviceRecoveryClaimOperation, {
      'requestId': request.requestId,
      'installationId': request.installationId,
    });
    if (response['targetUid'] != request.targetUid) {
      throw const DeviceRecoveryException(
        'The server returned a recovery claim for another account.',
      );
    }
    _verifyCompletion(response, request, 'in_progress');
  }

  Future<void> failReset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
    required String failureCode,
  }) async {
    _requireRequestOwner(actor, request);
    final response = await _request(deviceRecoveryFailOperation, {
      'requestId': request.requestId,
      'installationId': request.installationId,
      'failureCode': failureCode,
    });
    _verifyCompletion(response, request, 'failed');
  }

  Future<void> cancelReset({
    required AppUser? actor,
    required String requestId,
    required String targetUid,
    required String installationId,
    required String reason,
  }) async {
    _requireActor(actor, admin: true);
    final response = await _request(deviceRecoveryCancelOperation, {
      'requestId': requestId,
      'targetUid': targetUid,
      'installationId': installationId,
      'reason': reason.trim(),
    });
    if (response['requestId'] != requestId ||
        response['targetUid'] != targetUid ||
        response['installationId'] != installationId ||
        response['status'] != 'cancelled') {
      throw const DeviceRecoveryException(
        'The server did not confirm cancellation of the selected reset.',
      );
    }
  }

  void _verifyCompletion(
    Map<String, dynamic> response,
    DeviceRecoveryRequest request,
    String expectedStatus,
  ) {
    if (response['requestId'] != request.requestId ||
        response['installationId'] != request.installationId ||
        response['status'] != expectedStatus) {
      throw const DeviceRecoveryException(
        'The server did not acknowledge the exact phone recovery request.',
      );
    }
  }
}

final deviceRecoveryCommandServiceProvider =
    Provider<DeviceRecoveryCommandService>(
      (ref) => DeviceRecoveryCommandService(),
    );
