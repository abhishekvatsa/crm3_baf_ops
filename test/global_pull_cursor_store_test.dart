import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/core/services/global_pull_cursor_store.dart';
import 'package:crm3_baf_ops/core/services/global_pull_protocol.dart';

const String _actorA = 'operator-a';
const String _actorB = 'operator-b';
const String _generationA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String _generationB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const String _runA = '11111111-1111-4111-8111-111111111111';
const String _runB = '22222222-2222-4222-8222-222222222222';
const String _authorityDigestA =
    'auth1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _authorityDigestB =
    'auth1-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
final DateTime _activatedAt = DateTime.utc(2026, 7, 27, 18);
final DateTime _anchorA = DateTime.utc(2026, 7, 27, 18, 5);
final DateTime _anchorB = DateTime.utc(2026, 7, 27, 18, 10);

GlobalPullRunAuthority _authority({
  String actorUid = _actorA,
  String authorityDigest = _authorityDigestA,
  DateTime? serverAnchor,
}) => GlobalPullRunAuthority(
  actorUid: actorUid,
  authorityDigest: authorityDigest,
  activatedAt: _activatedAt,
  serverAnchor: serverAnchor ?? _anchorA,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('global pull authority protocol', () {
    test('accepts the exact backend contract', () {
      final authority =
          GlobalPullRunAuthority.fromCallableData(<String, Object?>{
            'actorUid': _actorA,
            'authorityDigest': _authorityDigestA,
            'protocolVersion': globalPullProtocolVersion,
            'protocolFingerprint': globalPullProtocolFingerprint,
            'writerVersion': globalPullWriterVersion,
            'serverStampField': globalPullServerUpdatedAtField,
            'collections': globalPullProtocolCollections,
            'activatedAt': _activatedAt.toIso8601String(),
            'serverAnchor': _anchorA.toIso8601String(),
          }, expectedUid: _actorA);

      expect(authority.actorUid, _actorA);
      expect(authority.activatedAt, _activatedAt);
      expect(authority.serverAnchor, _anchorA);
    });

    test('rejects an unknown response field', () {
      expect(
        () => GlobalPullRunAuthority.fromCallableData(<String, Object?>{
          'actorUid': _actorA,
          'authorityDigest': _authorityDigestA,
          'protocolVersion': globalPullProtocolVersion,
          'protocolFingerprint': globalPullProtocolFingerprint,
          'writerVersion': globalPullWriterVersion,
          'serverStampField': globalPullServerUpdatedAtField,
          'collections': globalPullProtocolCollections,
          'activatedAt': _activatedAt.toIso8601String(),
          'serverAnchor': _anchorA.toIso8601String(),
          'unexpected': true,
        }, expectedUid: _actorA),
        throwsA(
          isA<GlobalPullProtocolException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'authority-invalid-shape',
          ),
        ),
      );
    });

    test('rejects actor and collection-set mismatches', () {
      final base = <String, Object?>{
        'actorUid': _actorA,
        'authorityDigest': _authorityDigestA,
        'protocolVersion': globalPullProtocolVersion,
        'protocolFingerprint': globalPullProtocolFingerprint,
        'writerVersion': globalPullWriterVersion,
        'serverStampField': globalPullServerUpdatedAtField,
        'collections': globalPullProtocolCollections,
        'activatedAt': _activatedAt.toIso8601String(),
        'serverAnchor': _anchorA.toIso8601String(),
      };

      expect(
        () =>
            GlobalPullRunAuthority.fromCallableData(base, expectedUid: _actorB),
        throwsA(
          isA<GlobalPullProtocolException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'authority-actor-mismatch',
          ),
        ),
      );
      expect(
        () => GlobalPullRunAuthority.fromCallableData(<String, Object?>{
          ...base,
          'collections': globalPullProtocolCollections.reversed.toList(),
        }, expectedUid: _actorA),
        throwsA(
          isA<GlobalPullProtocolException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'authority-collection-set-mismatch',
          ),
        ),
      );
    });
  });

  group('global pull run envelope', () {
    late SharedPreferences preferences;
    late SharedPreferencesGlobalPullCursorStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
      store = SharedPreferencesGlobalPullCursorStore(preferences);
    });

    test('new scope starts with every domain pending and no cursor', () async {
      final envelope = await store.begin(
        actorUid: _actorA,
        databaseGenerationId: _generationA,
        authority: _authority(),
        runId: _runA,
      );

      expect(envelope.state, GlobalPullRunState.prepared);
      expect(envelope.origin, GlobalPullCursorOrigin.freshScope);
      expect(envelope.serverAnchor, _anchorA);
      expect(
        envelope.domains.values.every(
          (cursor) => cursor.cursor == null && !cursor.completedInRun,
        ),
        isTrue,
      );
    });

    test(
      'legacy client-time cursor forces a full reconciliation reset',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          SharedPreferencesGlobalPullCursorStore.legacyGlobalCursorKey:
              '2026-07-27T17:00:00.000Z',
        });
        preferences = await SharedPreferences.getInstance();
        store = SharedPreferencesGlobalPullCursorStore(preferences);

        var envelope = await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationA,
          authority: _authority(),
          runId: _runA,
        );
        expect(envelope.origin, GlobalPullCursorOrigin.legacyReset);
        expect(
          envelope.domains.values.every((cursor) => cursor.cursor == null),
          isTrue,
        );

        for (final domain in GlobalPullDomain.values) {
          envelope = await store.completeDomain(envelope, domain);
        }
        envelope = await store.commit(envelope);

        expect(envelope.state, GlobalPullRunState.committed);
        expect(
          preferences.containsKey(
            SharedPreferencesGlobalPullCursorStore.legacyGlobalCursorKey,
          ),
          isFalse,
        );
      },
    );

    test('prepared run resumes its anchor and completed domains', () async {
      var envelope = await store.begin(
        actorUid: _actorA,
        databaseGenerationId: _generationA,
        authority: _authority(),
        runId: _runA,
      );
      envelope = await store.completeDomain(
        envelope,
        GlobalPullDomain.knowledgeBase,
      );

      final resumed = await store.begin(
        actorUid: _actorA,
        databaseGenerationId: _generationA,
        authority: _authority(serverAnchor: _anchorB),
        runId: _runB,
      );

      expect(resumed.runId, _runA);
      expect(resumed.serverAnchor, _anchorA);
      expect(
        resumed.cursorFor(GlobalPullDomain.knowledgeBase).completedInRun,
        isTrue,
      );
      expect(
        resumed.cursorFor(GlobalPullDomain.maintenanceRecords).completedInRun,
        isFalse,
      );
    });

    test(
      'committed run advances all domain cursors to one server anchor',
      () async {
        var envelope = await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationA,
          authority: _authority(),
          runId: _runA,
        );
        for (final domain in GlobalPullDomain.values) {
          envelope = await store.completeDomain(envelope, domain);
        }
        envelope = await store.commit(envelope);

        expect(envelope.state, GlobalPullRunState.committed);
        expect(
          envelope.domains.values.every(
            (cursor) => cursor.completedInRun && cursor.cursor == _anchorA,
          ),
          isTrue,
        );

        final next = await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationA,
          authority: _authority(serverAnchor: _anchorB),
          runId: _runB,
        );
        expect(next.state, GlobalPullRunState.prepared);
        expect(next.origin, GlobalPullCursorOrigin.continuation);
        expect(next.serverAnchor, _anchorB);
        expect(
          next.domains.values.every(
            (cursor) => !cursor.completedInRun && cursor.cursor == _anchorA,
          ),
          isTrue,
        );
      },
    );

    test(
      'actor and database generation use independent storage scopes',
      () async {
        await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationA,
          authority: _authority(),
          runId: _runA,
        );
        await store.begin(
          actorUid: _actorB,
          databaseGenerationId: _generationA,
          authority: _authority(actorUid: _actorB),
          runId: _runB,
        );
        await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationB,
          authority: _authority(),
          runId: '33333333-3333-4333-8333-333333333333',
        );

        expect(
          store.keyFor(actorUid: _actorA, databaseGenerationId: _generationA),
          isNot(
            store.keyFor(actorUid: _actorB, databaseGenerationId: _generationA),
          ),
        );
        expect(
          store.keyFor(actorUid: _actorA, databaseGenerationId: _generationA),
          isNot(
            store.keyFor(actorUid: _actorA, databaseGenerationId: _generationB),
          ),
        );
      },
    );

    test(
      'authority change resets every domain instead of reusing visibility',
      () async {
        var envelope = await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationA,
          authority: _authority(),
          runId: _runA,
        );
        for (final domain in GlobalPullDomain.values) {
          envelope = await store.completeDomain(envelope, domain);
        }
        await store.commit(envelope);

        final changed = await store.begin(
          actorUid: _actorA,
          databaseGenerationId: _generationA,
          authority: _authority(
            authorityDigest: _authorityDigestB,
            serverAnchor: _anchorB,
          ),
          runId: _runB,
        );

        expect(changed.origin, GlobalPullCursorOrigin.authorityChanged);
        expect(changed.authorityDigest, _authorityDigestB);
        expect(
          changed.domains.values.every(
            (cursor) => cursor.cursor == null && !cursor.completedInRun,
          ),
          isTrue,
        );
      },
    );

    test('malformed or partial domain sets fail closed', () async {
      final envelope = await store.begin(
        actorUid: _actorA,
        databaseGenerationId: _generationA,
        authority: _authority(),
        runId: _runA,
      );
      final malformed = Map<String, Object?>.from(
        jsonDecode(envelope.encode()) as Map,
      );
      final domains = Map<String, Object?>.from(malformed['domains']! as Map)
        ..remove(GlobalPullDomain.directives.wireName);
      malformed['domains'] = domains;
      await preferences.setString(
        store.keyFor(actorUid: _actorA, databaseGenerationId: _generationA),
        jsonEncode(malformed),
      );

      expect(
        () => store.read(actorUid: _actorA, databaseGenerationId: _generationA),
        throwsA(
          isA<GlobalPullCursorException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'cursor-domain-set-mismatch',
          ),
        ),
      );
    });

    test('wrong-typed scalar fields fail closed without coercion', () async {
      final envelope = await store.begin(
        actorUid: _actorA,
        databaseGenerationId: _generationA,
        authority: _authority(),
        runId: _runA,
      );
      final malformed = Map<String, Object?>.from(
        jsonDecode(envelope.encode()) as Map,
      )..['actorUid'] = 123456;
      await preferences.setString(
        store.keyFor(actorUid: _actorA, databaseGenerationId: _generationA),
        jsonEncode(malformed),
      );

      expect(
        () => store.read(actorUid: _actorA, databaseGenerationId: _generationA),
        throwsA(
          isA<GlobalPullCursorException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'cursor-field-type-invalid',
          ),
        ),
      );
    });
  });
}
