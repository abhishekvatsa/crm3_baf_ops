import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/services/sync_rejection_service.dart';
import 'package:crm3_baf_ops/features/admin/repositories/user_directory_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/closed_ticket_history_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_correction_promoter.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/repositories/knowledge_correction_source_repository.dart';

void main() {
  test('A-03 exact operation inventory is complete and source-enforced', () {
    final result = Process.runSync(_dartExecutable(), const <String>[
      'run',
      'tools/v4/a03_persistence_boundary_inventory.dart',
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final output = '${result.stdout}';
    final jsonStart = output.indexOf('{');
    expect(jsonStart, greaterThanOrEqualTo(0), reason: output);
    final report =
        jsonDecode(output.substring(jsonStart)) as Map<String, dynamic>;
    expect(report['result'], 'PASS');
    expect(report['findingId'], 'A-03');
    expect(report['operationCount'], greaterThan(0));
    expect(report['siteCount'], greaterThanOrEqualTo(report['operationCount']));
    expect(report['failures'], isEmpty);
  });

  test('presentation and widgets own no direct database access', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (!path.contains('/presentation/') && !path.contains('/widgets/')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('FirebaseFirestore.instance') ||
          source.contains('Isar.getInstance()') ||
          source.contains('.writeTxn(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('user roster authority is rejected before repository access', () async {
    final repository = _UserDirectoryProbe();
    final service = UserDirectoryReadService(repository);
    await expectLater(
      service.watchAllUsers(actor: _actor(AppRole.operations)).first,
      throwsStateError,
    );
    expect(repository.reads, 0);

    await service.watchAllUsers(actor: _actor(AppRole.admin)).first;
    expect(repository.reads, 1);
  });

  test('closed history authority is rejected before repository access', () {
    final repository = _MaintenanceRepositoryProbe();
    final service = ClosedTicketHistoryService(repository);
    expect(
      () => service.count(actor: _actor(AppRole.operations, approved: false)),
      throwsStateError,
    );
    expect(repository.reads, 0);
  });

  test(
    'template correction authority is rejected before remote read',
    () async {
      final repository = _KnowledgeCorrectionProbe();
      final service = KnowledgeCorrectionSourceService(repository);
      await expectLater(
        service.loadPromotableCorrections(
          actor: _actor(AppRole.operations),
          existingRowsByCode: const <String, BafKnowledgeRow>{},
        ),
        throwsStateError,
      );
      expect(repository.reads, 0);
    },
  );

  test('sync rejection mutation denies before local database lookup', () async {
    var lookups = 0;
    final service = SyncRejectionService(
      databaseLookup: () {
        lookups++;
        return null;
      },
    );
    await expectLater(
      service.resolve(
        rejectionId: 1,
        actor: _actor(AppRole.operations),
        notes: 'not admitted',
      ),
      throwsStateError,
    );
    expect(lookups, 0);
  });

  test('loading, error, offline and denial states remain user-visible', () {
    final userManagement =
        File(
          'lib/features/admin/presentation/user_management_screen.dart',
        ).readAsStringSync();
    final closedHistory =
        File(
          'lib/features/maintenance/presentation/closed_tickets_screen.dart',
        ).readAsStringSync();
    final corrections =
        File(
          'lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart',
        ).readAsStringSync();
    final diagnostics =
        File(
          'lib/features/admin/presentation/local_diagnostics_screen.dart',
        ).readAsStringSync();
    expect(userManagement, contains('Could not verify admin access'));
    expect(userManagement, contains('Could not load users'));
    expect(closedHistory, contains('Could not verify closure-history access'));
    expect(closedHistory, contains('Error loading closed tickets'));
    expect(corrections, contains('Harvest failed'));
    expect(diagnostics, contains('Local diagnostics unavailable on web'));
  });
}

String _dartExecutable() {
  final suffix = Platform.isWindows ? 'dart.exe' : 'dart';
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null && configuredRoot.trim().isNotEmpty) {
    final root = configuredRoot.trim();
    return '$root${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
        '${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}$suffix';
  }
  final normalized = Platform.resolvedExecutable.replaceAll('\\', '/');
  const marker = '/bin/cache/';
  final markerIndex = normalized.indexOf(marker);
  if (markerIndex >= 0) {
    final flutterRoot = normalized.substring(0, markerIndex);
    return '$flutterRoot/bin/cache/dart-sdk/bin/$suffix';
  }
  return 'dart';
}

AppUser _actor(AppRole role, {bool approved = true}) => AppUser(
  uid: 'actor-${role.name}',
  name: 'Boundary actor',
  email: 'boundary@example.invalid',
  roles: <AppRole>[role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

class _UserDirectoryProbe implements UserDirectoryRepository {
  int reads = 0;

  @override
  Stream<List<AppUser>> watchAllUsers() {
    reads++;
    return Stream.value(const <AppUser>[]);
  }
}

class _KnowledgeCorrectionProbe implements KnowledgeCorrectionSourceRepository {
  int reads = 0;

  @override
  Future<List<HarvestableTemplateSnapshot>> loadPublishedSnapshots() async {
    reads++;
    return const <HarvestableTemplateSnapshot>[];
  }
}

class _MaintenanceRepositoryProbe implements MaintenanceRepository {
  int reads = 0;

  @override
  Future<int> getClosedTicketsCount() async {
    reads++;
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
