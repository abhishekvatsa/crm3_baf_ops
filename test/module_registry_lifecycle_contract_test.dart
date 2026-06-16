import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String providerSource() {
    return File(
      'lib/features/planned_maintenance/providers/module_registry_provider.dart',
    ).readAsStringSync();
  }

  String methodBody(String source, String methodName, String nextMethodName) {
    final start = source.indexOf(methodName);
    final end = source.indexOf(nextMethodName, start + methodName.length);
    expect(start, isNonNegative, reason: 'Missing $methodName');
    expect(
      end,
      isNonNegative,
      reason: 'Missing $nextMethodName after $methodName',
    );
    return source.substring(start, end);
  }

  test('draft create and update do not refresh canonical family metadata', () {
    final source = providerSource();
    final createDraft = methodBody(
      source,
      'Future<ModuleRegistryRevision> createDraftFromModule',
      'Future<void> updateDraftRevision',
    );
    final updateDraft = methodBody(
      source,
      'Future<void> updateDraftRevision',
      'Future<ModuleRegistryRevision> publishDraftRevision',
    );

    expect(createDraft, isNot(contains('refreshFromModule(module')));
    expect(updateDraft, isNot(contains('refreshFromModule(module')));
  });

  test(
    'publish refreshes canonical family metadata from the published revision',
    () {
      final source = providerSource();
      final publishDraft = methodBody(
        source,
        'Future<ModuleRegistryRevision> publishDraftRevision',
        'Future<void> retirePublishedRevision',
      );

      expect(publishDraft, contains('revision.toComposerModuleDraft()'));
      expect(
        publishDraft,
        contains('latestPublishedRevisionNumber = nextRevisionNumber'),
      );
    },
  );

  test('publish rejects identical latest hash and advances hash pointers', () {
    final source = providerSource();
    final publishDraft = methodBody(
      source,
      'Future<ModuleRegistryRevision> publishDraftRevision',
      'Future<void> retirePublishedRevision',
    );

    expect(source, contains('_ensureLatestPublishedPointers'));
    expect(source, contains('_loadLegacyLatestPublishedRevision'));
    expect(
      source,
      contains('multiple revisions claim latest published number'),
    );
    expect(source, contains('latest-published pointers are missing'));
    expect(publishDraft, contains('latestPublishedContentHash'));
    expect(publishDraft, contains('latestPublishedRevisionId'));
    expect(
      publishDraft,
      contains('latestPublished.contentHash == revision.contentHash'),
    );
    expect(publishDraft, contains('No-op registry publication rejected'));
    expect(
      publishDraft,
      contains('..latestPublishedRevisionId = revision.revisionId'),
    );
    expect(
      publishDraft,
      contains('..latestPublishedContentHash = revision.contentHash'),
    );
  });

  test(
    'retire actions re-read current registry documents inside transactions',
    () {
      final source = providerSource();
      final retireRevision = methodBody(
        source,
        'Future<void> retirePublishedRevision',
        'Future<void> retireFamily',
      );
      final retireFamily = methodBody(
        source,
        'Future<void> retireFamily',
        'Future<List<ModuleRegistryRevision>> getDraftRevisions',
      );

      expect(retireRevision, contains('final revisionSnap = await txn.get'));
      expect(retireRevision, contains('ModuleRegistryRevision.fromMap'));
      expect(retireFamily, contains('final familySnap = await txn.get'));
      expect(retireFamily, contains('ModuleRegistryFamily.fromMap'));
    },
  );
}
