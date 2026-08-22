import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/template_governance_model.dart';
import '../data/maintenance_intelligence.dart';
import '../domain/module_composer_models.dart';
import '../domain/template_version_snapshot_contract.dart';
import '../providers/template_governance_provider.dart';
import '../providers/maintenance_intelligence_provider.dart';
import 'module_composer_screen.dart';

part 'template_publisher_screen.builders.dart';
part 'template_publisher_screen.actions.dart';
part 'template_publisher_screen.validation.dart';
part 'template_publisher_screen.support.dart';
part 'template_publisher_screen.helpers.dart';
part 'template_publisher_sections.dart';
part 'template_publisher_json_panel.dart';
part 'template_publisher_widgets.dart';
part 'template_publisher_models.dart';

const _newPackageSentinel = '__new_template_package__';

class TemplatePublisherScreen extends ConsumerStatefulWidget {
  const TemplatePublisherScreen({super.key});

  @override
  ConsumerState<TemplatePublisherScreen> createState() =>
      _TemplatePublisherScreenState();
}

class _TemplatePublisherScreenState
    extends ConsumerState<TemplatePublisherScreen> {
  final _packageCodeController = TextEditingController();
  final _packageTitleController = TextEditingController();
  final _packageDescriptionController = TextEditingController();
  final _assetTypeController = TextEditingController(text: 'furnace');
  final _assetScopeController = TextEditingController();

  final _versionLabelController = TextEditingController(text: 'v1');
  final _releaseNotesController = TextEditingController();
  final _changeSummaryController = TextEditingController();
  final _minAppVersionController = TextEditingController();
  final _publishReasonController = TextEditingController(
    text: 'Initial governed BAF catalogue publish.',
  );

  final _jobTemplateJsonController = TextEditingController(text: '{\n  \n}');
  final _moduleSnapshotsJsonController = TextEditingController(
    text: '[\n  \n]',
  );
  final _fieldDefinitionsJsonController = TextEditingController(
    text: '[\n  \n]',
  );
  final _checklistJsonController = TextEditingController(text: '[\n  \n]');

  final _selectedDisciplines = <String>{'mechanical'};
  String? _selectedMaintenanceClassId;
  String? _selectedPackageId = _newPackageSentinel;
  TemplatePackage? _selectedPackage;
  TemplateVersion? _workingDraft;
  bool _isPublishing = false;
  bool _hasLoadedInitialPackage = false;

  final Map<String, _CachedJsonCheck> _jsonValidationCache =
      <String, _CachedJsonCheck>{};
  String? _lastHashInputFingerprint;
  String? _cachedPreviewHash;

  static const _disciplineOptions = <_DisciplineOption>[
    _DisciplineOption('mechanical', 'Mechanical', Icons.settings_rounded),
    _DisciplineOption(
      'electrical',
      'Electrical',
      Icons.electrical_services_rounded,
    ),
    _DisciplineOption('instrumentation', 'I&A', Icons.sensors_rounded),
    _DisciplineOption(
      'operations',
      'Operations',
      Icons.supervisor_account_rounded,
    ),
    _DisciplineOption(
      'refractory',
      'Refractory',
      Icons.local_fire_department_rounded,
    ),
    _DisciplineOption('safety', 'Safety', Icons.health_and_safety_rounded),
    _DisciplineOption('shared', 'Shared', Icons.hub_rounded),
  ];

  void _setPublisherState(VoidCallback fn) {
    setState(fn);
  }

  @override
  void dispose() {
    _packageCodeController.dispose();
    _packageTitleController.dispose();
    _packageDescriptionController.dispose();
    _assetTypeController.dispose();
    _assetScopeController.dispose();
    _versionLabelController.dispose();
    _releaseNotesController.dispose();
    _changeSummaryController.dispose();
    _minAppVersionController.dispose();
    _publishReasonController.dispose();
    _jobTemplateJsonController.dispose();
    _moduleSnapshotsJsonController.dispose();
    _fieldDefinitionsJsonController.dispose();
    _checklistJsonController.dispose();
    _jsonValidationCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);

    return userAsync.when(
      loading:
          () => BafScreenStateScaffold.loading(
            appBarTitle: 'Template authoring',
            appBarSubtitle: 'Governed maintenance catalogues and versions',
            appBarIcon: Icons.architecture_outlined,
            accent: BafColors.planned,
            label: 'Checking publishing authority',
          ),
      error: (e, _) => _ErrorScaffold(message: 'User profile error: $e'),
      data: (actor) {
        if (actor == null || !actor.canManageTemplateGovernance) {
          return const _AccessDeniedScaffold();
        }

        final packagesAsync = ref.watch(templatePackagesProvider);
        return packagesAsync.when(
          loading:
              () => BafScreenStateScaffold.loading(
                appBarTitle: 'Template authoring',
                appBarSubtitle: 'Governed maintenance catalogues and versions',
                appBarIcon: Icons.architecture_outlined,
                accent: BafColors.planned,
                label: 'Loading governed catalogues',
              ),
          error:
              (e, _) =>
                  e is PersistedDataFormatException
                      ? const _ErrorScaffold(
                        title: 'Governance timeline needs repair',
                        message:
                            'A template package or version has missing, malformed, or inconsistent lifecycle history. Publishing is blocked until the source record is repaired and this view reloads cleanly.',
                      )
                      : _ErrorScaffold(message: 'Template package error: $e'),
          data: (packages) => _buildPublisher(context, actor, packages),
        );
      },
    );
  }
}
