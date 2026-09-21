import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/request_identity_journal.dart';
import '../domain/knowledge_import_journal.dart';

/// Original requests and each observed outcome occupy immutable journal slots.
/// A failed outcome write leaves the original request available for audit lookup.
class KnowledgeImportJournalRepository {
  KnowledgeImportJournalRepository({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesLoader;
  static Future<void> _tail = Future.value();
  final _intents = RequestIdentityJournal<KnowledgeImportIntent>(
    legacyKey: 'PENDING_KNOWLEDGE_IMPORT::v1',
    decode: KnowledgeImportIntent.decode,
    requestIdOf: (value) => value.requestId,
  );
  final _outcomes = RequestIdentityJournal<KnowledgeImportOutcome>(
    legacyKey: 'KNOWLEDGE_IMPORT_OUTCOMES::v1',
    decode: KnowledgeImportOutcome.decode,
    requestIdOf: (value) => value.requestId,
  );

  Future<T> _serial<T>(Future<T> Function(SharedPreferences) work) {
    final next = _tail.then((_) async {
      final preferences = await _preferencesLoader();
      await preferences.reload();
      return work(preferences);
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<KnowledgeImportIntent> retain(
    KnowledgeImportIntent intent,
  ) => _serial((preferences) async {
    // Decode all existing evidence before adding anything; damaged evidence is
    // visible and retained instead of silently replaced by another import.
    _intents.readAll(preferences);
    _outcomes.readAll(preferences);
    return _intents.append(preferences, intent.toMap());
  });

  Future<void> recordOutcome(KnowledgeImportOutcome outcome) => _serial((
    preferences,
  ) async {
    final request = _intents
        .readAll(preferences)
        .map((entry) => entry.value)
        .where((entry) => entry.requestId == outcome.importId)
        .firstOrNull;
    final row = request?.rows
        .where((row) => row.rowCode == outcome.rowCode)
        .firstOrNull;
    if (row == null || row.versionAfter != outcome.versionAfter) {
      throw StateError(
        'Outcome does not match a saved import row. Evidence was preserved.',
      );
    }
    await _outcomes.append(preferences, outcome.toMap());
  });

  Future<List<KnowledgeImportRecovery>> readAll() => _serial((
    preferences,
  ) async {
    final requests = _intents.readAll(preferences);
    final outcomes = _outcomes.readAll(preferences);
    final byId = {
      for (final request in requests) request.value.requestId: request.value,
    };
    final byRequest = <String, Map<String, KnowledgeImportOutcome>>{};
    for (final record in outcomes) {
      final outcome = record.value;
      final row = byId[outcome.importId]?.rows
          .where((row) => row.rowCode == outcome.rowCode)
          .firstOrNull;
      if (row == null || row.versionAfter != outcome.versionAfter) {
        throw StateError(
          'Saved import outcome has no matching original request. Evidence was preserved.',
        );
      }
      final rows = byRequest.putIfAbsent(outcome.importId, () => {});
      final prior = rows[outcome.rowCode];
      if (prior != null &&
          prior.state != KnowledgeImportOutcomeState.pending &&
          outcome.state != KnowledgeImportOutcomeState.pending &&
          prior.state != outcome.state) {
        throw StateError(
          'Saved import outcomes conflict. Evidence was preserved.',
        );
      }
      // Definitive outcomes cannot be reopened by a transient result, even
      // when journal timestamps tie and request identity determines the order.
      if (prior?.state == KnowledgeImportOutcomeState.rejected) continue;
      if (prior?.state == KnowledgeImportOutcomeState.accepted) {
        if (outcome.state != KnowledgeImportOutcomeState.accepted ||
            prior!.adopted) {
          continue;
        }
      }
      rows[outcome.rowCode] = outcome;
    }
    return [
      for (final request in requests)
        KnowledgeImportRecovery(
          request.value,
          byRequest[request.value.requestId] ?? {},
        ),
    ];
  });
}

final knowledgeImportJournalRepositoryProvider =
    Provider<KnowledgeImportJournalRepository>(
      (ref) => KnowledgeImportJournalRepository(),
    );

final knowledgeImportRecoveryProvider =
    FutureProvider<List<KnowledgeImportRecovery>>(
      (ref) => ref.watch(knowledgeImportJournalRepositoryProvider).readAll(),
    );
