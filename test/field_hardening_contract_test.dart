import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = _ProjectFiles();

  test(
    '67B.4 knowledge governance uses one tab controller and dialog-owned import/export surfaces',
    () {
      final source = files.knowledgeGovernance;
      final compact = _compact(source);

      expect(source, isNot(contains('DefaultTabController(')));
      expect(compact, contains('TabBar( controller: _tab'));
      expect(compact, contains('TabBarView( controller: _tab'));
      expect(
        source,
        contains('class _KnowledgeBundlePasteDialog extends StatefulWidget'),
      );
      expect(source, contains('late final TextEditingController _controller;'));
      expect(source, contains('_controller.addListener(_handleBodyChanged);'));
      expect(
        source,
        contains('_controller.removeListener(_handleBodyChanged);'),
      );
      expect(source, contains('_controller.dispose();'));
      expect(
        source,
        contains('final canParse = _controller.text.trim().isNotEmpty;'),
      );
      expect(compact, contains('onPressed: canParse ?'));
      expect(source, contains('showDialog<String>'));
      expect(source, contains('Future<void> _showExportBundleSheet'));
      expect(source, contains('DraggableScrollableSheet'));
      expect(source, contains('Clipboard.setData'));
      expect(source, contains('if (!context.mounted)'));
      expect(
        source,
        isNot(contains('final controller = TextEditingController();')),
      );
    },
  );

  test(
    '67B.5 correction promoter prevents duplicate submits and owns reason controller',
    () {
      final source = files.correctionPromoter;
      final compact = _compact(source);

      expect(source, contains('extends ConsumerStatefulWidget'));
      expect(
        source,
        contains("import '../../domain/knowledge_governance_models.dart';"),
      );
      expect(source, contains('final Set<String> _promotingKeys'));
      expect(source, contains('showDialog<String>'));
      expect(
        source,
        contains('class _PromotionReasonDialog extends StatefulWidget'),
      );
      expect(source, contains('final KnowledgeRowDraft draftPreview;'));
      expect(source, isNot(contains('final BafKnowledgeRow draftPreview;')));
      expect(source, contains('static const int _minReasonLength = 15'));
      expect(
        source,
        contains('late final TextEditingController _reasonController;'),
      );
      expect(
        source,
        contains('_reasonController.addListener(_handleReasonChanged);'),
      );
      expect(
        source,
        contains('_reasonController.removeListener(_handleReasonChanged);'),
      );
      expect(source, contains('_reasonController.dispose();'));
      expect(compact, contains('onPressed: canPromote ?'));
      expect(
        source,
        contains('ref.invalidate(knowledgePromotableCorrectionsProvider)'),
      );
      expect(source, contains('ref.invalidate(knowledgeRowsViewProvider)'));
      expect(
        source,
        contains('ref.invalidate(knowledgeGovernanceAuditFeedProvider)'),
      );
    },
  );

  test(
    '67B.6 template delete dialog owns controller and centralizes snack handling',
    () {
      final source = files.templateDetail;

      expect(source, contains('showDialog<_TemplateDeleteDecision>'));
      expect(
        source,
        contains('class _TemplateDeleteDialog extends StatefulWidget'),
      );
      expect(source, contains('class _TemplateDeleteDecision'));
      expect(
        source,
        contains('final _reasonController = TextEditingController();'),
      );
      expect(source, contains('_reasonController.dispose();'));
      expect(source, contains('void _showTemplateDetailSnack'));
      expect(source, contains('ScaffoldMessenger.maybeOf'));
      expect(source, contains('reason: decision.reason'));
      expect(source, contains('reasonNotes: decision.notes'));
      expect(
        source,
        isNot(contains('final reasonController = TextEditingController')),
      );
    },
  );

  test(
    '67B.7 closed tickets listens outside build and keeps reopen busy per ticket',
    () {
      final source = files.closedTickets;

      expect(source, contains('ref.listenManual<int>'));
      expect(source, contains('_refreshSubscription.close();'));
      expect(
        source,
        contains('class _ReopenTicketDialog extends StatefulWidget'),
      );
      expect(
        source,
        contains('late final TextEditingController _remarksController;'),
      );
      expect(source, contains('_remarksController.dispose();'));
      expect(source, contains('final Set<String> _reopeningTicketKeys'));
      expect(source, contains('isReopening: _reopeningTicketKeys.contains'));
      expect(
        source,
        contains('setState(() => _reopeningTicketKeys.add(ticketKey))'),
      );
      expect(
        source,
        contains('setState(() => _reopeningTicketKeys.remove(ticketKey))'),
      );
      expect(
        source,
        contains('final nextTickets = await repo.getClosedTickets'),
      );
      expect(
        source,
        isNot(contains('ref.listen<int>(refreshClosedTicketsProvider')),
      );
      expect(source, isNot(contains('reopenReasonController')));
      expect(
        RegExp(r'static\s+String\s+_ticketKey\s*\(').allMatches(source),
        hasLength(1),
      );
    },
  );

  test(
    '67B.8 directives owns closure dialog controller and keeps action-specific busy states',
    () {
      final source = files.directives;

      expect(source, contains('bool _isAcknowledging = false;'));
      expect(source, contains('bool _isClosing = false;'));
      expect(source, contains('showDialog<String>'));
      expect(
        source,
        contains('class _CloseDirectiveDialog extends StatefulWidget'),
      );
      expect(
        source,
        contains('late final TextEditingController _remarksController;'),
      );
      expect(source, contains('_remarksController.dispose();'));
      expect(source, contains('setState(() => _isAcknowledging = true)'));
      expect(source, contains('setState(() => _isClosing = true)'));
      expect(source, contains('void _showDirectiveSnack'));
      expect(source, contains('ScaffoldMessenger.maybeOf'));
      expect(
        source,
        isNot(contains('final remarksController = TextEditingController')),
      );
    },
  );
}

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

class _ProjectFiles {
  const _ProjectFiles();

  String get knowledgeGovernance => _read(
    'lib/features/planned_maintenance/presentation/knowledge_governance_screen.dart',
  );

  String get correctionPromoter => _read(
    'lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart',
  );

  String get templateDetail => _read(
    'lib/features/planned_maintenance/presentation/template_detail_screen.dart',
  );

  String get closedTickets =>
      _read('lib/features/maintenance/presentation/closed_tickets_screen.dart');

  String get directives =>
      _read('lib/features/directives/presentation/directives_screen.dart');

  String _read(String path) => File(path).readAsStringSync();
}
