import 'dart:io';

import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cross-business offline/cloud alignment', () {
    test('every sync operation remains explicitly inventoried', () {
      final source =
          File('lib/core/services/sync_service.dart').readAsStringSync();
      final body = _functionBody(source, 'Future<void> syncAll(');
      final discovered = <String>{
        for (final match in RegExp(
          r'await\s+(?:_auditRepo\.)?(_sync[A-Za-z0-9]+|syncPendingAuditEvents)\s*\(',
        ).allMatches(body))
          match.group(1)!,
      };

      expect(
        discovered,
        equals(<String>{
          '_syncTickets',
          '_syncTemplates',
          '_syncTemplateGovernance',
          '_syncKnowledgeBase',
          '_syncExecutions',
          '_syncJobDiaryEntries',
          '_syncJobModules',
          '_syncCompletedExecutionClosures',
          '_syncDirectives',
          '_syncAbnormalityTypes',
          '_syncChargeAbnormalities',
          'syncPendingAuditEvents',
        }),
        reason:
            'A changed sync surface requires an explicit reconciliation-policy review.',
      );
    });

    test('generic lost-response convergence is exact and symmetric', () {
      final local = <String, dynamic>{
        'status': 'acknowledged',
        'version': 2,
        'evidence': <String, dynamic>{
          'teams': <String>['mechanical', 'operations'],
        },
      };
      expect(syncPersistedSnapshotsEquivalent(local, {...local}), isTrue);
      expect(
        syncPersistedSnapshotsEquivalent(local, <String, dynamic>{
          ...local,
          'serverOnly': true,
        }),
        isFalse,
        reason: 'generic convergence must compare the complete payload',
      );
      expect(
        syncPersistedSnapshotsEquivalent(local, <String, dynamic>{
          ...local,
          'version': 3,
        }),
        isFalse,
      );
    });

    test(
      'every ordinary offline queue has an uncertain-write convergence path',
      () {
        final expectedGenericCoverage = <String, int>{
          'lib/core/services/sync_service.tickets_templates.dart': 1,
          'lib/core/services/sync_service.executions.dart': 1,
          'lib/core/services/sync_service.job_diary.dart': 1,
          'lib/core/services/sync_service.directives_abnormalities.dart': 2,
          'lib/core/services/sync_service.template_governance.dart': 2,
        };

        for (final entry in expectedGenericCoverage.entries) {
          final source = File(entry.key).readAsStringSync();
          expect(
            'syncPersistedSnapshotsEquivalent(record.toMap(), remote.toMap())'
                .allMatches(source)
                .length,
            entry.value,
            reason: '${entry.key} lost-response coverage changed',
          );
        }

        final maintenance =
            File(
              'lib/core/services/sync_service.tickets_templates.dart',
            ).readAsStringSync();
        expect(maintenance, contains('_applyMaintenanceLifecycleReplayStep'));
        expect(maintenance, contains('applyGovernedCreationReceiptForSync'));

        final modules =
            File(
              'lib/features/planned_maintenance/providers/job_module_provider.remote.dart',
            ).readAsStringSync();
        expect(modules, contains('jobModuleClientSnapshotsEquivalentForSync'));

        final governedAbnormality =
            File(
              'lib/core/services/sync_service.directives_abnormalities.dart',
            ).readAsStringSync();
        expect(
          governedAbnormality,
          contains('_governedChargeAbnormalityStateMatches(record, remote)'),
        );

        final governance =
            File(
              'lib/core/services/sync_service.template_governance.dart',
            ).readAsStringSync();
        expect(governance, contains('_templatePublishAuditMatchesRemote'));
      },
    );

    test('server-timestamped knowledge writes adopt an exact remote receipt', () {
      final source =
          File(
            'lib/features/planned_maintenance/domain/baf_knowledge_repository.dart',
          ).readAsStringSync();
      expect(source, contains('final receipt = await _pushLocalRow(row);'));
      expect(source, contains('_applyKnowledgePushReceiptIfUnchanged'));
      expect(source, contains('_knowledgePushReceiptMatches'));
      expect(source, contains('observed ??= await reference.get();'));
      expect(source, contains('BafKnowledgeRow.fromCloudMap'));
      expect(
        source,
        isNot(contains('await _markLocalRowSyncedIfUnchanged(snapshot);')),
      );
    });

    test(
      'approved users may recheck a held row without deleting local evidence',
      () {
        final coordinator =
            File('lib/core/services/sync_coordinator.dart').readAsStringSync();
        final push =
            File(
              'lib/core/services/sync_service.push_infrastructure.dart',
            ).readAsStringSync();
        final indicator =
            File(
              'lib/core/widgets/sync_status_indicator.dart',
            ).readAsStringSync();

        expect(
          coordinator,
          contains(
            "recheckPermanentRejections: reason == 'manual_rejection_recheck'",
          ),
        );
        expect(push, contains('if (_recheckPermanentRejections)'));
        expect(
          push,
          contains(
            'No source record was marked synchronized, changed, or deleted',
          ),
        );
        expect(indicator, contains('Recheck with server'));
        expect(indicator, contains("reason: 'manual_rejection_recheck'"));
        expect(indicator, contains('Local evidence was preserved'));
      },
    );
  });
}

String _functionBody(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  if (markerIndex < 0) {
    throw StateError('Missing function marker: $marker');
  }

  final asyncMarker = source.indexOf('async {', markerIndex + marker.length);
  final openBrace =
      asyncMarker < 0 ? -1 : source.indexOf('{', asyncMarker + 'async'.length);
  if (openBrace < 0) {
    throw StateError('Missing function body for: $marker');
  }

  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    final character = source[index];
    if (character == '{') depth++;
    if (character == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBrace + 1, index);
      }
    }
  }
  throw StateError('Unterminated function body for: $marker');
}
