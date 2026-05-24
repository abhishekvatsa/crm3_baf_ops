// FILE: lib/features/maintenance/presentation/maintenance_form.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/maintenance_model.dart';
import '../providers/maintenance_provider.dart';
import '../validation/maintenance_input_validator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../planned_maintenance/domain/baf_tag_resolver_v2.dart';
import '../../../core/services/auto_sync_service.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

class MaintenanceForm extends ConsumerStatefulWidget {
  const MaintenanceForm({super.key});

  @override
  ConsumerState<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends ConsumerState<MaintenanceForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isCritical = false;

  AssetType _assetType = AssetType.base;
  MaintenanceType _maintenanceType = MaintenanceType.breakdown;
  RoutedTo _routedTo = RoutedTo.mechanical;
  DateTime _startTime = DateTime.now();

  final _assetNumController = TextEditingController();
  final _descController = TextEditingController();
  final _chargeNoController = TextEditingController();
  final _tagController = TextEditingController();
  final _componentController = TextEditingController();
  final _otherDepartmentController = TextEditingController();

  String? _resolvedSystem;
  String? _resolvedSubsystem;
  List<String>? _resolvedPath;

  bool _isAutoResolved = false;
  bool _userOverrodeComponent = false;

  @override
  void initState() {
    super.initState();

    _componentController.addListener(() {
      if (!_isAutoResolved) return;
      _userOverrodeComponent = true;
    });
  }

  @override
  void dispose() {
    _assetNumController.dispose();
    _descController.dispose();
    _chargeNoController.dispose();
    _tagController.dispose();
    _componentController.dispose();
    _otherDepartmentController.dispose();
    super.dispose();
  }

  void _resolveTag(String rawTag) {
    final tag = rawTag.trim();
    _userOverrodeComponent = false;

    if (tag.isEmpty) {
      _clearAutoFields();
      return;
    }

    final result = BafTagResolverV2.resolveToMap(tag, assetContext: _assetType);
    final bool isResolved = result['isAutoResolved'] == true;

    if (!isResolved) {
      _clearAutoFields();
      return;
    }

    final path = result['hierarchyPath'];
    final safePath = path is List ? List<String>.from(path) : null;

    if (!mounted) return;

    setState(() {
      _resolvedSystem = result['system'] as String?;
      _resolvedSubsystem = result['subsystem'] as String?;
      _resolvedPath = safePath;

      if (!_userOverrodeComponent && _componentController.text.trim().isEmpty) {
        _componentController.text = (result['component'] as String?) ?? '';
      }

      _isAutoResolved = true;
    });
  }

  void _clearAutoFields() {
    if (!mounted) return;

    setState(() {
      _resolvedSystem = null;
      _resolvedSubsystem = null;
      _resolvedPath = null;
      _isAutoResolved = false;
      _userOverrodeComponent = false;
    });
  }

  String? _cleanOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _cleanRequiredText(String value) {
    return value.trim();
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );

    if (!mounted || time == null) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (picked.isAfter(now)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Start time cannot be in the future')),
      );
      return;
    }

    setState(() => _startTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final inputValidation = MaintenanceInputValidator.validateCreate(
      MaintenanceCreateInput(
        assetType: _assetType,
        assetNumberText: _assetNumController.text,
        component: _componentController.text,
        description: _descController.text,
        tag: _tagController.text,
        chargeNumberText: _chargeNoController.text,
        startDate: _startTime,
        routedTo: _routedTo,
        otherDepartment: _otherDepartmentController.text,
      ),
    );
    if (inputValidation.isInvalid) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(inputValidation.summary),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appUser = ref.read(currentAppUserProvider).value;
      final firebaseUser = ref.read(firebaseAuthProvider).currentUser;

      if (appUser == null && firebaseUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Please sign in before raising an issue'),
            backgroundColor: BafColors.danger,
          ),
        );
        return;
      }

      final now = DateTime.now();
      final reporterUid = appUser?.uid ?? firebaseUser?.uid;
      final reporterName =
          _cleanOptionalText(appUser?.name) ??
          _cleanOptionalText(firebaseUser?.displayName) ??
          _cleanOptionalText(firebaseUser?.email);
      final tagText = _cleanOptionalText(_tagController.text)?.toUpperCase();
      final hierarchyPath =
          _resolvedPath == null || _resolvedPath!.isEmpty
              ? null
              : List<String>.from(_resolvedPath!);

      final record =
          MaintenanceRecord()
            ..firestoreId = const Uuid().v4()
            ..assetType = _assetType
            ..assetNumber = int.parse(_assetNumController.text.trim())
            ..maintenanceType = _maintenanceType
            ..routedTo = _routedTo
            ..otherDepartment =
                _routedTo == RoutedTo.others
                    ? _cleanOptionalText(_otherDepartmentController.text)
                    : null
            ..description = _cleanRequiredText(_descController.text)
            ..loggedByUid = reporterUid
            ..loggedByName = reporterName
            ..reportedBy = reporterName
            ..chargeNoAtEvent = int.tryParse(_chargeNoController.text.trim())
            ..startDate = _startTime
            ..createdAt = now
            ..updatedAt = now
            ..status = TicketStatus.open
            ..isResolved = false
            ..isCritical = _isCritical
            ..teamsInvolved = []
            ..isSynced = false
            ..component = _cleanRequiredText(_componentController.text)
            ..tag = tagText
            ..subsystem = _cleanOptionalText(_resolvedSubsystem)
            ..hierarchyPath = hierarchyPath;

      final repository = ref.read(maintenanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final autoSyncService = ref.read(autoSyncServiceProvider);

      await repository.saveTicket(record);

      if (_isCritical) {
        unawaited(
          syncCoordinator.runFullSync(
            reason: 'critical_ticket_created',
            force: true,
          ),
        );
      } else {
        // Normal raised issues must still leave the sender immediately so a
        // receiving device's manual sync can fetch them before the 5-minute
        // safety window. The 5-minute queue now acts as retry/catch-up if the
        // immediate attempt fails, is interrupted, or misses connectivity.
        autoSyncService.scheduleTicketSyncWithinFiveMinutes(
          reason: 'normal_ticket_created_retry',
        );

        unawaited(
          syncCoordinator
              .runFullSyncWithResult(
                reason: 'normal_ticket_created_immediate',
                force: true,
              )
              .then((completed) {
                if (completed) {
                  autoSyncService.clearPendingTicketSync(
                    reason: 'normal_ticket_created_immediate_success',
                  );
                }
              }),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Issue raised successfully'),
          backgroundColor: BafColors.sync,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text(
          'Raise Issue',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.md,
            BafSpacing.lg,
            112,
          ),
          children: [
            _IntroCard(appUserName: appUser?.name),
            const SizedBox(height: BafSpacing.lg),

            _SectionCard(
              title: 'Asset context',
              subtitle: 'Where is the issue happening?',
              icon: Icons.precision_manufacturing_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AssetType>(
                        initialValue: _assetType,
                        isExpanded: true,
                        decoration: _inputDecoration('Type'),
                        items:
                            AssetType.values
                                .map(
                                  (type) => DropdownMenuItem<AssetType>(
                                    value: type,
                                    child: Text(
                                      _assetTypeLabel(type),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _assetType = value);
                        },
                      ),
                    ),
                    const SizedBox(width: BafSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _assetNumController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Number'),
                        validator:
                            (value) =>
                                MaintenanceInputValidator.validateAssetNumber(
                                  assetType: _assetType,
                                  value: value,
                                ).messageFor('assetNumber'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _tagController,
                  decoration: _inputDecoration(
                    'Instrument tag / equipment tag',
                    hint: 'Optional, helps auto-fill component context',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _resolveTag,
                  validator:
                      (value) => MaintenanceInputValidator.validateTag(
                        value,
                      ).messageFor('tag'),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _componentController,
                  decoration: _inputDecoration(
                    _isAutoResolved
                        ? 'Component (auto-filled, editable)'
                        : 'Component name',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator:
                      (value) => MaintenanceInputValidator.validateComponent(
                        value,
                      ).messageFor('component'),
                ),
                if (_isAutoResolved) ...[
                  const SizedBox(height: BafSpacing.md),
                  _ResolvedTagPanel(
                    system: _resolvedSystem,
                    subsystem: _resolvedSubsystem,
                    path: _resolvedPath,
                  ),
                ],
              ],
            ),

            const SizedBox(height: BafSpacing.lg),

            _SectionCard(
              title: 'Issue details',
              subtitle: 'Describe the problem clearly for the attending team.',
              icon: Icons.report_problem_rounded,
              children: [
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    'Fault description',
                    hint: 'What happened? What is affected?',
                    alignLabelWithHint: true,
                  ),
                  validator:
                      (value) => MaintenanceInputValidator.validateDescription(
                        value,
                      ).messageFor('description'),
                ),
                const SizedBox(height: BafSpacing.md),
                _CriticalIssueToggle(
                  value: _isCritical,
                  onChanged: (value) => setState(() => _isCritical = value),
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<RoutedTo>(
                  initialValue: _routedTo,
                  isExpanded: true,
                  decoration: _inputDecoration('Route to'),
                  items:
                      RoutedTo.values
                          .map(
                            (dept) => DropdownMenuItem<RoutedTo>(
                              value: dept,
                              child: Text(
                                _deptLabel(dept),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _routedTo = value;
                      if (_routedTo != RoutedTo.others) {
                        _otherDepartmentController.clear();
                      }
                    });
                  },
                ),
                if (_routedTo == RoutedTo.others) ...[
                  const SizedBox(height: BafSpacing.md),
                  TextFormField(
                    controller: _otherDepartmentController,
                    decoration: _inputDecoration(
                      'Other department',
                      hint: 'Specify receiving team / agency',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator:
                        (value) =>
                            MaintenanceInputValidator.validateOtherDepartment(
                              routedTo: _routedTo,
                              value: value,
                            ).messageFor('otherDepartment'),
                  ),
                ],
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<MaintenanceType>(
                  initialValue: _maintenanceType,
                  isExpanded: true,
                  decoration: _inputDecoration('Maintenance type'),
                  items:
                      MaintenanceType.values
                          .map(
                            (type) => DropdownMenuItem<MaintenanceType>(
                              value: type,
                              child: Text(
                                _maintenanceTypeLabel(type),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _maintenanceType = value);
                  },
                ),
              ],
            ),

            const SizedBox(height: BafSpacing.lg),

            _SectionCard(
              title: 'Operational timing',
              subtitle: 'When did this issue start?',
              icon: Icons.schedule_rounded,
              children: [
                InkWell(
                  onTap: _pickStartTime,
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                  child: Container(
                    padding: const EdgeInsets.all(BafSpacing.lg),
                    decoration: BoxDecoration(
                      color: BafColors.background,
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                      border: Border.all(color: BafColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: BafColors.maintenance,
                        ),
                        const SizedBox(width: BafSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start time',
                                style: TextStyle(
                                  color: BafColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: BafSpacing.xs),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy, HH:mm',
                                ).format(_startTime),
                                style: const TextStyle(
                                  color: BafColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_calendar_rounded,
                          color: BafColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _chargeNoController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'Charge number',
                    hint: 'Optional',
                  ),
                  validator:
                      (value) => MaintenanceInputValidator.validateChargeNumber(
                        value,
                      ).messageFor('chargeNoAtEvent'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SubmitIssueBar(
        isSubmitting: _isSubmitting,
        isCritical: _isCritical,
        onSubmit: _isSubmitting ? null : _submit,
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: BafColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.maintenance, width: 1.5),
      ),
    );
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCE COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
    }
  }

  String _maintenanceTypeLabel(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.scheduled:
        return 'SCHEDULED';
      case MaintenanceType.breakdown:
        return 'BREAKDOWN';
      case MaintenanceType.performance:
        return 'PERFORMANCE';
      case MaintenanceType.inspection:
        return 'INSPECTION';
      case MaintenanceType.overhaul:
        return 'OVERHAUL';
    }
  }

  String _deptLabel(RoutedTo dept) {
    switch (dept) {
      case RoutedTo.operations:
        return 'Operations';
      case RoutedTo.electrical:
        return 'Electrical';
      case RoutedTo.mechanical:
        return 'Mechanical';
      case RoutedTo.instrumentation:
        return 'I&A';
      case RoutedTo.refractory:
        return 'RED / Refractory';
      case RoutedTo.emd:
        return 'EMD';
      case RoutedTo.shiftInCharge:
        return 'Shift In-Charge';
      case RoutedTo.others:
        return 'Others';
    }
  }
}

class _SubmitIssueBar extends StatelessWidget {
  final bool isSubmitting;
  final bool isCritical;
  final VoidCallback? onSubmit;

  const _SubmitIssueBar({
    required this.isSubmitting,
    required this.isCritical,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isCritical ? Icons.priority_high_rounded : Icons.sync_rounded,
                  color: isCritical ? BafColors.danger : BafColors.maintenance,
                  size: 18,
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    isCritical
                        ? 'Critical issue: sends immediately.'
                        : 'Normal issue: sends now, with 5-minute retry safety.',
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isCritical ? BafColors.danger : BafColors.maintenance,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: BafColors.border,
                  disabledForegroundColor: BafColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
                ),
                icon:
                    isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.add_task_rounded),
                label: Text(
                  isSubmitting ? 'Submitting...' : 'Submit Issue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriticalIssueToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CriticalIssueToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            value
                ? BafColors.danger.withValues(alpha: 0.08)
                : BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color:
              value
                  ? BafColors.danger.withValues(alpha: 0.34)
                  : BafColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked == true),
        activeColor: BafColors.danger,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.sm,
          vertical: BafSpacing.xs,
        ),
        title: const Text(
          'Critical / safety-sensitive issue',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'Tick this for H₂-sensitive or urgent breakdowns. Critical issues are pushed immediately; normal issues are sent within 5 minutes unless manually synced earlier.',
          style: TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String? appUserName;

  const _IntroCard({this.appUserName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(
          color: BafColors.maintenance.withValues(alpha: 0.18),
        ),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.maintenance.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: BafColors.maintenance,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raise an issue',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                const Text(
                  'Give the attending team enough context to act quickly and safely.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (appUserName != null && appUserName!.trim().isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.sm),
                  StatusBadge(
                    label: 'Logging as $appUserName',
                    color: BafColors.maintenance,
                    icon: Icons.person_outline_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BafColors.maintenance, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _ResolvedTagPanel extends StatelessWidget {
  final String? system;
  final String? subsystem;
  final List<String>? path;

  const _ResolvedTagPanel({this.system, this.subsystem, this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 17, color: BafColors.sync),
              SizedBox(width: 6),
              Text(
                'Tag resolved',
                style: TextStyle(
                  color: BafColors.sync,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          if (system != null && system!.trim().isNotEmpty)
            _ResolvedLine(label: 'System', value: system!),
          if (subsystem != null && subsystem!.trim().isNotEmpty)
            _ResolvedLine(label: 'Subsystem', value: subsystem!),
          if (path != null && path!.isNotEmpty)
            _ResolvedLine(label: 'Path', value: path!.join(' › ')),
        ],
      ),
    );
  }
}

class _ResolvedLine extends StatelessWidget {
  final String label;
  final String value;

  const _ResolvedLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
