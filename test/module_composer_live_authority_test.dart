import 'dart:async';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('non-governor cannot load composer knowledge data', (
    tester,
  ) async {
    var knowledgeReads = 0;

    await tester.pumpWidget(
      _composerApp(
        actorStream: Stream<AppUser?>.value(_operator()),
        knowledgeLoader: () async {
          knowledgeReads++;
          return _knowledgeBundle();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Template authoring access required'), findsOneWidget);
    expect(find.text('Knowledge Picker'), findsNothing);
    expect(knowledgeReads, 0);
  });

  testWidgets('live role downgrade closes an initialized composer', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    actors.add(_admin());
    var knowledgeReads = 0;

    await tester.pumpWidget(
      _composerApp(
        actorStream: actors.stream,
        knowledgeLoader: () async {
          knowledgeReads++;
          return _knowledgeBundle();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('module-composer-template-title')),
      findsOneWidget,
    );
    expect(knowledgeReads, 1);

    actors.add(_operator());
    await tester.pumpAndSettle();

    expect(find.text('Template authoring access required'), findsOneWidget);
    expect(
      find.byKey(const Key('module-composer-template-title')),
      findsNothing,
    );
    expect(knowledgeReads, 1);
  });
}

Widget _composerApp({
  required Stream<AppUser?> actorStream,
  required Future<BafKnowledgeBundle> Function() knowledgeLoader,
}) {
  return ProviderScope(
    overrides: [currentAppUserProvider.overrideWith((ref) => actorStream)],
    child: MaterialApp(
      home: ModuleComposerScreen(
        initialJobTemplateJson: '{}',
        initialModuleSnapshotsJson: '[]',
        initialFieldDefinitionsJson: '[]',
        initialChecklistJson: '[]',
        knowledgeBundleLoader: knowledgeLoader,
      ),
    ),
  );
}

BafKnowledgeBundle _knowledgeBundle() {
  return BafKnowledgeBundle(
    entries: BafKnowledgeLayer.entries,
    meta: BafKnowledgeMatrixMeta.staticFallback(),
    source: BafKnowledgeSource.staticFallback,
  );
}

AppUser _admin() => _actor(AppRole.admin);

AppUser _operator() => _actor(AppRole.operations);

AppUser _actor(AppRole role) {
  return AppUser(
    uid: 'authority-${role.name}',
    name: 'Authority ${role.name}',
    email: '${role.name}@example.com',
    roles: <AppRole>[role],
    isApproved: true,
    createdAt: DateTime.utc(2026, 8, 5),
  );
}
