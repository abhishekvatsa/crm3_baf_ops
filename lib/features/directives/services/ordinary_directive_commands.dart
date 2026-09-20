import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/persistence/app_database.dart' as database;
import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/persistence/durable_submission_record.dart';
import '../../../core/persistence/durable_submission_review.dart';
import '../../../core/release/command_capability_service.dart';
import '../../../core/serialization/persisted_json_equality.dart';
import '../../auth/data/user_model.dart';
import '../data/operational_directive_model.dart';
import '../data/remote_operational_directive_reader.dart';

Map<String, dynamic> ordinaryDirectiveWire(OperationalDirective d) {
  final map = d.toMap();
  for (final key in [
    'createdAt',
    'updatedAt',
    'issuedAt',
    'acknowledgedAt',
    'closedAt',
    'deletedAt',
  ]) {
    if (map[key] != null) {
      map[key] = DateTime.parse(map[key] as String).toUtc().toIso8601String();
    }
  }
  return map;
}

bool sameOrdinaryDirective(OperationalDirective a, OperationalDirective b) =>
    persistedJsonEquivalent(
      jsonEncode(ordinaryDirectiveWire(a)),
      jsonEncode(ordinaryDirectiveWire(b)),
    );

class OrdinaryDirectiveMissing implements Exception {}

class OrdinaryDirectiveCommands {
  OrdinaryDirectiveCommands({
    DurableSubmissionRepository? store,
    String? Function()? actorUid,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? invoke,
    Future<Map<String, dynamic>> Function(String)? read,
    Future<void> Function(String)? capability,
    this.web = kIsWeb,
    String? projectId,
  }) : _projectId = projectId,
       _store = store,
       _actorUid = actorUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _invoke = invoke ?? _call,
       _read = read ?? _readServer,
       _capability = capability ?? _probe;
  final DurableSubmissionRepository? _store;
  DurableSubmissionRepository get store =>
      _store ?? DurableSubmissionRepository(database.isar);
  final String? Function() _actorUid;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) _invoke;
  final Future<Map<String, dynamic>> Function(String) _read;
  final Future<void> Function(String) _capability;
  final bool web;
  final String? _projectId;
  String get projectId => _projectId ?? Firebase.app().options.projectId;
  static Future<Map<String, dynamic>> _call(
    Map<String, dynamic> envelope,
  ) async =>
      (await FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('mutateAssetHierarchyV2')
              .call<Map<String, dynamic>>(envelope))
          .data;
  static Future<void> _probe(String uid) =>
      CommandCapabilityService(
        functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
      ).requireCapabilities(
        callableName: 'mutateAssetHierarchyV2',
        originActorUid: uid,
        requiredCapabilities: const {'ordinaryDirective.v1'},
      );
  static Future<Map<String, dynamic>> _readServer(String id) async {
    final snap = await FirebaseFirestore.instance
        .collection('directives')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snap.exists &&
        !snap.metadata.isFromCache &&
        !snap.metadata.hasPendingWrites) {
      throw OrdinaryDirectiveMissing();
    }
    if (!snap.exists ||
        snap.metadata.isFromCache ||
        snap.metadata.hasPendingWrites) {
      throw StateError(
        'Current directive evidence is unavailable. The saved command is retained.',
      );
    }
    return snap.data()!;
  }

  String _actor([String? origin]) {
    final uid = _actorUid();
    if (uid == null || origin != null && uid != origin) {
      throw StateError(
        'Return to the original account to confirm this directive.',
      );
    }
    return uid;
  }

  String _key(String uid, String id) => 'ordinaryDirective:$projectId:$uid:$id';
  Future<void> save({
    required AppUser actor,
    required String action,
    required OperationalDirective after,
    OperationalDirective? before,
    required String reason,
  }) async {
    _actor(actor.uid);
    if (before != null && !before.isSynced) {
      throw StateError(
        'Confirm the earlier saved directive change before making another. Your draft has not been applied.',
      );
    }
    if (reason.trim().isEmpty) throw StateError('A reason is required.');
    final id = after.firestoreId!;
    // Strict local postconditions run before anything is queued.
    readRemoteOperationalDirective(
      ordinaryDirectiveWire(after),
      documentId: id,
    );
    final request = {
      'requestId': const Uuid().v4(),
      'operation': 'APPLY_ORDINARY_DIRECTIVE',
      'directiveId': id,
      'expectedVersion': before?.version ?? 0,
      'action': action,
      'reason': reason.trim(),
      'before': before == null ? null : ordinaryDirectiveWire(before),
      'after': ordinaryDirectiveWire(after),
    };
    final envelope = {
      'protocolVersion': 2,
      'originActorUid': actor.uid,
      'request': request,
    };
    if (web) {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(actor.uid, id);
      if (prefs.containsKey(key)) {
        throw StateError(
          'A saved directive change needs confirmation. Use Check saved changes.',
        );
      }
      if (!await prefs.setString(key, jsonEncode(envelope))) {
        throw StateError('The directive could not be saved for recovery.');
      }
      await _checkWeb(key, prefs);
      return;
    }
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: request['requestId'] as String,
        actorUid: actor.uid,
        requestId: request['requestId'] as String,
        aggregateId: id,
        resourceKey: _key(actor.uid, id),
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode(envelope),
      ),
    );
    try {
      _actor(actor.uid);
      await store.isar.writeTxn(() async {
        final rows = await store.isar.operationalDirectives
            .filter()
            .firestoreIdEqualTo(id)
            .findAll();
        if (before == null
            ? rows.isNotEmpty
            : rows.length != 1 ||
                  !rows.single.isSynced ||
                  !sameOrdinaryDirective(rows.single, before)) {
          throw StateError(
            'The directive changed while saving. Review its current record; the draft was not applied.',
          );
        }
        if (rows.isNotEmpty) after.id = rows.single.id;
        after.isSynced = false;
        await store.isar.operationalDirectives.put(after);
      });
    } catch (_) {
      await store.cancelNeverSent(
        submissionId: saved.submissionId,
        actorUid: actor.uid,
      );
      rethrow;
    }
  }

  Map<String, dynamic> _request(DurableSubmission row) =>
      Map<String, dynamic>.from(
        durableSubmissionJsonObject(row.envelopeJson)['request'] as Map,
      );
  OperationalDirective _receipt(
    Map<String, dynamic> response,
    Map<String, dynamic> request,
  ) {
    if (response['ok'] != true ||
        response['operation'] != 'APPLY_ORDINARY_DIRECTIVE' ||
        response['requestId'] != request['requestId'] ||
        response['entityId'] != request['directiveId'] ||
        response['version'] != (request['expectedVersion'] as int) + 1 ||
        response['committedAt'] is! String ||
        DateTime.tryParse(response['committedAt'] as String) == null ||
        response['idempotentReplay'] is! bool) {
      throw StateError(
        'The directive receipt does not match its saved command.',
      );
    }
    final accepted = readRemoteOperationalDirective(
      Map<String, dynamic>.from(response['entity'] as Map),
      documentId: request['directiveId'] as String,
    );
    final intended = readRemoteOperationalDirective(
      Map<String, dynamic>.from(request['after'] as Map),
      documentId: request['directiveId'] as String,
    );
    if (!sameOrdinaryDirective(accepted, intended)) {
      throw StateError(
        'Accepted directive evidence differs from the original command.',
      );
    }
    return accepted;
  }

  Future<void> check(String submissionId) async {
    var row = await store.read(submissionId);
    if (row == null) throw StateError('Saved directive command is missing.');
    _actor(row.actorUid);
    if (row.resourceKey != _key(row.actorUid!, row.aggregateId)) {
      throw StateError('This saved directive belongs to another project.');
    }
    final request = _request(row);
    if (!row.state.isAccepted) {
      await _capability(row.actorUid!);
      _actor(row.actorUid);
      final claim = await store.claim(
        submissionId: row.submissionId,
        actorUid: row.actorUid!,
      );
      if (!claim.mayDispatch) {
        if (claim.submission.state.isAccepted) {
          row = claim.submission;
        } else {
          throw StateError(
            'This directive is already being checked or needs review.',
          );
        }
      } else {
        Map<String, dynamic> response;
        try {
          _actor(row.actorUid);
          response = await _invoke(
            durableSubmissionJsonObject(row.envelopeJson),
          );
          _receipt(response, request);
        } catch (error) {
          await store.recordOutcome(
            claim,
            state: DurableSubmissionState.uncertain,
            message: '$error',
            errorCode: 'directive-outcome-unconfirmed',
          );
          rethrow;
        }
        row = await store.settleAccepted(
          submissionId: row.submissionId,
          envelopeSha256: row.envelopeSha256,
          receiptJson: jsonEncode({...response, 'idempotentReplay': false}),
          validateReceipt: (saved, result) {
            _receipt(result, _request(saved));
            return true;
          },
        );
      }
    }
    _actor(row.actorUid);
    final accepted = _receipt(
      durableSubmissionJsonObject(row.receiptJson!),
      request,
    );
    final current = readRemoteOperationalDirective(
      await _read(row.aggregateId),
      documentId: row.aggregateId,
    );
    if (current.version < accepted.version ||
        current.createdByUid != accepted.createdByUid ||
        current.createdAt != accepted.createdAt ||
        current.version == accepted.version &&
            !sameOrdinaryDirective(current, accepted)) {
      throw StateError(
        'Acceptance is saved but the current directive needs review.',
      );
    }
    _actor(row.actorUid);
    await store.isar.writeTxn(() async {
      final locals = await store.isar.operationalDirectives
          .filter()
          .firestoreIdEqualTo(row!.aggregateId)
          .findAll();
      if (locals.length > 1) {
        throw StateError('Duplicate local directive identity needs review.');
      }
      if (locals.isNotEmpty) {
        final local = locals.single;
        final before = request['before'] == null
            ? null
            : readRemoteOperationalDirective(
                Map<String, dynamic>.from(request['before'] as Map),
                documentId: row.aggregateId,
              );
        if (!sameOrdinaryDirective(local, accepted) &&
            !(local.isSynced &&
                (sameOrdinaryDirective(local, current) ||
                    before != null && sameOrdinaryDirective(local, before)))) {
          throw StateError(
            'A newer local directive draft is preserved; acceptance cannot replace it.',
          );
        }
        current.id = local.id;
      }
      current.isSynced = true;
      await store.isar.operationalDirectives.put(current);
    });
    _actor(row.actorUid);
    await store.markReconciled(
      submissionId: row.submissionId,
      envelopeSha256: row.envelopeSha256,
      receiptSha256: row.receiptSha256!,
    );
  }

  Future<void> _checkWeb(String key, SharedPreferences prefs) async {
    final envelope = durableSubmissionJsonObject(prefs.getString(key)!);
    final uid = envelope['originActorUid'] as String;
    _actor(uid);
    final request = Map<String, dynamic>.from(envelope['request'] as Map);
    final receiptKey = '$key:accepted';
    Map<String, dynamic> response;
    if (prefs.containsKey(receiptKey)) {
      response = durableSubmissionJsonObject(prefs.getString(receiptKey)!);
    } else {
      await _capability(uid);
      _actor(uid);
      response = await _invoke(envelope);
      _receipt(response, request);
      if (!await prefs.setString(receiptKey, jsonEncode(response))) {
        throw StateError(
          'Acceptance received; saving its recovery receipt failed. Recheck the same saved change.',
        );
      }
    }
    final accepted = _receipt(response, request);
    _actor(uid);
    final current = readRemoteOperationalDirective(
      await _read(accepted.firestoreId!),
      documentId: accepted.firestoreId!,
    );
    if (current.createdByUid != accepted.createdByUid ||
        current.createdAt != accepted.createdAt ||
        current.version < accepted.version ||
        current.version == accepted.version &&
            !sameOrdinaryDirective(current, accepted)) {
      throw StateError(
        'Directive accepted; current evidence still needs review.',
      );
    }
    _actor(uid);
    if (!await prefs.remove(key)) {
      throw StateError('Directive confirmed but saved-change cleanup failed.');
    }
    await prefs.remove(receiptKey);
  }

  Future<bool> _adoptReviewed(DurableSubmission row) async {
    final uid = _actor(row.actorUid);
    if (row.resourceKey != _key(uid, row.aggregateId)) return false;
    final proof = durableSubmissionJsonObject(row.receiptJson!);
    validateDurableSubmissionReviewHistory(row, proof);
    final decision = Map<String, dynamic>.from(
      (proof['decisions'] as List).last as Map,
    );
    final request = _request(row);
    final draft = readRemoteOperationalDirective(
      Map<String, dynamic>.from(request['after'] as Map),
      documentId: row.aggregateId,
    );
    final locals = await store.isar.operationalDirectives
        .filter()
        .firestoreIdEqualTo(row.aggregateId)
        .findAll();
    if (locals.length != 1 ||
        locals.single.isSynced ||
        !sameOrdinaryDirective(locals.single, draft)) {
      return false;
    }
    OperationalDirective? current;
    try {
      current = readRemoteOperationalDirective(
        await _read(row.aggregateId),
        documentId: row.aggregateId,
      );
    } on OrdinaryDirectiveMissing {
      if (decision['outcome'] != 'cancelled' || request['action'] != 'create') {
        rethrow;
      }
    }
    if (decision['outcome'] == 'reviewedExisting' &&
        (current == null ||
            current.version < (decision['receiptSummary'] as Map)['version'])) {
      throw StateError(
        'The reviewed acceptance has no matching current evidence.',
      );
    }
    if (current != null &&
        (current.createdByUid != draft.createdByUid ||
            current.createdAt != draft.createdAt)) {
      throw StateError(
        'The current directive has a different creation identity.',
      );
    }
    _actor(uid);
    await store.isar.writeTxn(() async {
      final local = await store.isar.operationalDirectives.get(
        locals.single.id,
      );
      if (local == null ||
          local.isSynced ||
          !sameOrdinaryDirective(local, draft)) {
        return;
      }
      if (current == null) {
        await store.isar.operationalDirectives.delete(local.id);
      } else {
        current
          ..id = local.id
          ..isSynced = true;
        await store.isar.operationalDirectives.put(current);
      }
    });
    return true;
  }

  Future<({int succeeded, int failed})> checkAll() async {
    final uid = _actor();
    int succeeded = 0, failed = 0;
    if (web) {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (key) =>
            key.startsWith('ordinaryDirective:$projectId:$uid:') &&
            !key.endsWith(':accepted'),
      )) {
        try {
          await _checkWeb(key, prefs);
          succeeded++;
        } catch (_) {
          failed++;
        }
      }
    } else {
      for (final row in await store.listForActor(uid, includeTerminal: true)) {
        if (!row.resourceKey.startsWith('ordinaryDirective:$projectId:$uid:')) {
          continue;
        }
        if (row.protocol != 'assetHierarchy.v2' ||
            _request(row)['operation'] != 'APPLY_ORDINARY_DIRECTIVE') {
          continue;
        }
        try {
          if (row.state == DurableSubmissionState.reviewResolved) {
            if (await _adoptReviewed(row)) succeeded++;
            continue;
          }
          if (!row.state.isUnresolved) continue;
          await check(row.submissionId);
          succeeded++;
        } catch (_) {
          failed++;
        }
      }
    }
    return (succeeded: succeeded, failed: failed);
  }

  /// Browser review uses the same permanent server fence as native review.
  /// The exact original envelope and final decision are archived before clearing.
  Future<List<({String key, String title})>> webPendingForReview(
    AppUser actor,
  ) async {
    _reviewer(actor);
    final prefs = await SharedPreferences.getInstance();
    final result = <({String key, String title})>[];
    for (final key in prefs.getKeys().where(
      (key) =>
          key.startsWith('ordinaryDirective:$projectId:') &&
          !key.endsWith(':accepted'),
    )) {
      final envelope = durableSubmissionJsonObject(prefs.getString(key)!);
      final request = Map<String, dynamic>.from(envelope['request'] as Map);
      result.add((
        key: key,
        title: '${request['action']}: ${(request['after'] as Map)['title']}',
      ));
    }
    _reviewer(actor);
    return result;
  }

  void _reviewer(AppUser actor) {
    _actor(actor.uid);
    if (!web || !actor.isApproved || !actor.isAdmin) {
      throw StateError(
        'A currently approved Admin must review browser-saved changes.',
      );
    }
  }

  DurableSubmission _webReviewRow(String key, String raw) {
    final envelope = durableSubmissionJsonObject(raw),
        request = Map<String, dynamic>.from(
          durableSubmissionJsonObject(raw)['request'] as Map,
        );
    final uid = envelope['originActorUid'] as String,
        id = request['directiveId'] as String,
        requestId = request['requestId'] as String;
    if (key != _key(uid, id)) {
      throw StateError('Saved directive project identity is inconsistent.');
    }
    final at = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return DurableSubmission(
      submissionId: requestId,
      actorUid: uid,
      requestId: requestId,
      aggregateId: id,
      resourceKey: key,
      protocol: 'assetHierarchy.v2',
      envelopeJson: raw,
      displayMetadataJson: null,
      state: DurableSubmissionState.uncertain,
      attemptCount: 0,
      createdAt: at,
      updatedAt: at,
      claimToken: null,
      claimExpiresAt: null,
      nextRetryAt: null,
      receiptJson: null,
      receiptSha256: null,
      lastErrorCode: null,
      lastErrorMessage: null,
      legacySourceKey: null,
      legacySourceBase64: null,
    );
  }

  Future<Map<String, dynamic>> inspectWebReview({
    required AppUser actor,
    required String key,
    required String reason,
  }) async {
    _reviewer(actor);
    if (reason.trim().length < 10 || reason.trim().length > 1600) {
      throw StateError('Enter review notes of 10–1600 characters.');
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      throw StateError('That saved change has already been resolved.');
    }
    final row = _webReviewRow(key, raw);
    final query = {
      'schemaVersion': 1,
      'phase': 'inspect',
      'domain': 'ordinaryDirective',
      'requestId': row.requestId,
      'evidenceSha256': row.reviewEvidenceSha256,
      'originalActorUid': row.actorUid,
      'reason': reason.trim(),
    };
    _reviewer(actor);
    final result = await _invoke({
      'protocolVersion': 2,
      'originActorUid': actor.uid,
      'recovery': query,
    });
    _reviewer(actor);
    if (result['outcome'] != null) {
      validateDurableSubmissionReviewDecision(row, result);
    } else if (result['schemaVersion'] != 1 ||
        result['domain'] != 'ordinaryDirective' ||
        result['requestId'] != row.requestId ||
        result['evidenceSha256'] != row.reviewEvidenceSha256 ||
        result['originalActorUid'] != row.actorUid ||
        result['reviewerUid'] != actor.uid ||
        result['reviewToken'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(result['reviewToken'] as String) ||
        !const {
          'receiptPresent',
          'receiptAbsent',
        }.contains(result['observation'])) {
      throw StateError('Server review does not match this saved instruction.');
    }
    return {'key': key, 'raw': raw, 'query': query, 'result': result};
  }

  Future<void> finalizeWebReview({
    required AppUser actor,
    required Map<String, dynamic> inspection,
  }) async {
    _reviewer(actor);
    final key = inspection['key'] as String, raw = inspection['raw'] as String;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(key) != raw) {
      throw StateError('Saved evidence changed during review.');
    }
    final row = _webReviewRow(key, raw),
        prior = Map<String, dynamic>.from(inspection['result'] as Map);
    final decision = prior['outcome'] != null
        ? prior
        : await _invoke({
            'protocolVersion': 2,
            'originActorUid': actor.uid,
            'recovery': {
              ...Map<String, dynamic>.from(inspection['query'] as Map),
              'phase': 'finalize',
              'reviewToken': prior['reviewToken'],
            },
          });
    validateDurableSubmissionReviewDecision(row, decision);
    if (!await prefs.setString(
      'ordinaryDirectiveReview:$projectId:${row.requestId}',
      jsonEncode({
        'envelope': raw,
        'decision': decision,
        'acceptedReceipt': prefs.getString('$key:accepted'),
      }),
    )) {
      throw StateError(
        'The review is complete on the server; local evidence could not be saved. Inspect again to recover it.',
      );
    }
    _reviewer(actor);
    if (prefs.getString(key) != raw) {
      throw StateError('A different saved directive is preserved.');
    }
    if (!await prefs.remove(key)) {
      throw StateError('Review saved; browser cleanup remains pending.');
    }
    await prefs.remove('$key:accepted');
  }

  Future<Set<String>> ownedDirectiveIds() async {
    if (web) return const {};
    // Read the journal once per sync, including other actors' protected work.
    final records = await store.isar.durableSubmissionRecords.where().findAll();
    final ids = <String>{};
    for (final record in records) {
      final raw = durableSubmissionJsonObject(record.immutableJson);
      if (raw['aggregateId'] is String &&
          raw['resourceKey'] is String &&
          (raw['resourceKey'] as String).startsWith('ordinaryDirective:')) {
        ids.add(raw['aggregateId'] as String);
      }
    }
    return ids;
  }

  Future<bool> owns(String id) async =>
      (await ownedDirectiveIds()).contains(id);
}
