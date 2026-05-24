// test/issue67C_hybrid_contract_test.dart
//
// Contract test for the 67C hybrid patch.
//
// Verifies every "best-of-breed" property that was identified across the two
// candidate patches (67C and 67C1_3) and merged into the hybrid:
//
//  Admin Data Browser  ──  complete _showAdminDataSnack rollout (zero raw calls)
//  Abnormality Types   ──  dialog-owned controllers + _isSaving busy-guard +
//                          complete _showAbnormalityTypeSnack rollout (zero raw)
//  Knowledge Row Editor ── readonly-field ValueKey + late final lifecycle
//                          controller + listener-driven canSubmit (≥15 chars) +
//                          defence-in-depth outer trim guard
//
// Run from the project root:
//   flutter test test/issue67C_hybrid_contract_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // 67C.1  Admin Data Browser
  // ──────────────────────────────────────────────────────────────────────────

  group('67C.1 admin_data_browser', () {
    late String src;
    late String sharedSrc;
    late String deleteDialogSrc;
    late String ticketSrc;
    setUpAll(() {
      src = _read('lib/features/admin/presentation/admin_data_browser.dart');
      sharedSrc = _read(
        'lib/features/admin/presentation/admin_data_browser/admin_data_browser_shared.dart',
      );
      deleteDialogSrc = _read(
        'lib/features/admin/presentation/admin_data_browser/admin_delete_reason_dialog.dart',
      );
      ticketSrc = _read(
        'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
      );
    });

    test('uses dialog-owned AdminDeleteReasonDialog for all soft-deletes', () {
      expect(
        deleteDialogSrc,
        contains('class AdminDeleteReasonDialog extends StatefulWidget'),
      );
      expect(deleteDialogSrc, contains('class AdminDeleteDecision'));
      expect(src, contains('showDialog<AdminDeleteDecision>'));
    });

    test('uses dialog-owned controllers for ticket edit', () {
      expect(
        ticketSrc,
        contains('class _AdminEditTicketDialog extends StatefulWidget'),
      );
      expect(ticketSrc, contains('showDialog<MaintenanceRecord>'));
    });

    test('uses dialog-owned controllers for directive edit', () {
      expect(
        src,
        contains('class _AdminEditDirectiveDialog extends StatefulWidget'),
      );
      expect(src, contains('showDialog<OperationalDirective>'));
    });

    test('showAdminDataSnack helper is defined with maybeOf', () {
      expect(sharedSrc, contains('void showAdminDataSnack('));
      expect(
        sharedSrc,
        contains('final messenger = ScaffoldMessenger.maybeOf(context);'),
      );
    });

    test(
      'showAdminDataSnack is used everywhere – zero raw ScaffoldMessenger.of calls',
      () {
        // The helper must be the ONLY way snackbars are shown; no raw .of() left.
        expect(src, isNot(contains('ScaffoldMessenger.of(')));
        expect(ticketSrc, isNot(contains('ScaffoldMessenger.of(')));
      },
    );

    test('old inline controller patterns are gone', () {
      expect(
        src,
        isNot(contains('final reasonController = TextEditingController();')),
      );
      expect(
        src,
        isNot(contains('final assetNumberCtrl = TextEditingController')),
      );
      expect(src, isNot(contains('final titleCtrl = TextEditingController')));
      expect(src, isNot(contains('reasonController.dispose();')));
      expect(
        ticketSrc,
        isNot(contains('final assetNumberCtrl = TextEditingController')),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 67C.2  Abnormality Types Screen
  // ──────────────────────────────────────────────────────────────────────────

  group('67C.2 abnormality_types_screen', () {
    late String src;
    setUpAll(() {
      src = _read(
        'lib/features/abnormalities/presentation/abnormality_types_screen.dart',
      );
    });

    test(
      'form dialog is a proper StatefulWidget that owns its controllers',
      () {
        expect(
          src,
          contains(
            'class _AbnormalityTypeFormDialog extends ConsumerStatefulWidget',
          ),
        );
        expect(
          src,
          contains('late final TextEditingController _codeController;'),
        );
        expect(src, contains('_codeController.dispose();'));
      },
    );

    test(
      'delete dialog is a proper StatefulWidget that owns its controller',
      () {
        expect(
          src,
          contains('class _AbnormalityTypeDeleteDialog extends StatefulWidget'),
        );
        expect(
          src,
          contains('late final TextEditingController _reasonController;'),
        );
        expect(src, contains('_reasonController.dispose();'));
      },
    );

    test('showDialog returns typed results', () {
      expect(src, contains('showDialog<bool>'));
      expect(src, contains('showDialog<_AbnormalityTypeDeleteDecision>'));
    });

    test(
      'form dialog has _isSaving busy-guard disabling actions during async save',
      () {
        expect(src, contains('bool _isSaving = false;'));
        expect(src, contains('onPressed: _isSaving ? null : _submit'));
        // buttons disabled while saving
        expect(src, contains('onPressed: _isSaving ? null :'));
        // spinner shown instead of label
        expect(src, contains('_isSaving\n'));
      },
    );

    test('_showAbnormalityTypeSnack helper is defined with maybeOf', () {
      expect(src, contains('void _showAbnormalityTypeSnack('));
      expect(src, contains('ScaffoldMessenger.maybeOf(context)'));
    });

    test(
      '_showAbnormalityTypeSnack is used everywhere – zero raw ScaffoldMessenger.of calls',
      () {
        expect(src, isNot(contains('ScaffoldMessenger.of(')));
      },
    );

    test('saved-locally confirmation copy is present', () {
      expect(src, contains('Saved locally; sync has been queued.'));
    });

    test('old no-dispose workaround comments are gone', () {
      expect(
        src,
        isNot(contains('Intentionally no immediate controller.dispose')),
      );
      expect(
        src,
        isNot(contains('Intentionally no immediate reasonController.dispose')),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 67C.3  Knowledge Row Editor
  // ──────────────────────────────────────────────────────────────────────────

  group('67C.3 knowledge_row_editor', () {
    late String src;
    setUpAll(() {
      src = _read(
        'lib/features/planned_maintenance/presentation/widgets/knowledge_row_editor.dart',
      );
    });

    test(
      'readonly fields use TextFormField + ValueKey, not build-time controller',
      () {
        expect(src, isNot(contains('controller ?? TextEditingController')));
        expect(src, contains('TextFormField('));
        expect(src, contains("ValueKey('readonly_knowledge_field_"));
      },
    );

    test('lifecycle reason dialog is a proper StatefulWidget', () {
      expect(
        src,
        contains(
          'class _KnowledgeLifecycleReasonDialog extends StatefulWidget',
        ),
      );
      expect(src, contains('late final TextEditingController _controller;'));
      expect(src, contains('_controller.dispose();'));
    });

    test(
      'lifecycle dialog uses listener-driven canSubmit (≥15 chars enforced in UI)',
      () {
        expect(src, contains('_controller.addListener(_handleChanged)'));
        expect(src, contains('final canSubmit = reason.length >= 15'));
        expect(src, contains('onPressed: canSubmit ?'));
        expect(src, contains('final errorText ='));
        expect(src, contains('reason.isEmpty || canSubmit'));
        expect(src, contains('errorText: errorText'));
      },
    );

    test('showDialog is typed to String (non-nullable)', () {
      expect(src, contains('showDialog<String>'));
    });

    test(
      'outer guard has both null and trim().isEmpty checks (defence-in-depth)',
      () {
        expect(src, contains('reason == null || reason.trim().isEmpty'));
      },
    );

    test('save/lifecycle ops have duplicate-submit guard', () {
      expect(src, contains('if (_saving)'));
    });

    test(
      'Navigator.pop uses typed generic and captures messenger before pop',
      () {
        expect(src, contains('Navigator.pop<bool>(context, true)'));
        expect(
          src,
          contains('final messenger = ScaffoldMessenger.maybeOf(context);'),
        );
      },
    );

    test('old inline controller creation inside dialog builder is gone', () {
      expect(
        src,
        isNot(contains('final controller = TextEditingController();')),
      );
    });
  });
}
