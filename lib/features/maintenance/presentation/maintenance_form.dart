// FILE: lib/features/maintenance/presentation/maintenance_form.dart

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/maintenance_model.dart';
import '../domain/governed_issue_asset_selection.dart';
import '../providers/maintenance_provider.dart';
import '../validation/maintenance_input_validator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../planned_maintenance/domain/baf_tag_resolver_v2.dart';
import '../../../core/services/auto_sync_service.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/repositories/asset_hierarchy_repository.dart';
import '../../quality/domain/issue_quality_intent.dart';
import '../domain/burner_lockout_case.dart';

class MaintenanceForm extends ConsumerStatefulWidget {
  const MaintenanceForm({super.key});

  @override
  ConsumerState<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends ConsumerState<MaintenanceForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isCritical = false;
  bool _isBurnerLockout = false;
  bool _burnerCommonMode = false;
  bool _burnerRemainsLockedOut = true;
  IssueQualityAssessment? _qualityAssessment;
  BurnerCycleStage _burnerCycleStage = BurnerCycleStage.notRecorded;
  BurnerObservation _burnerFlameObservation = BurnerObservation.notChecked;
  BurnerObservation _burnerSparkObservation = BurnerObservation.notChecked;
  final Set<int> _burnerPositions = <int>{};
  final Set<int> _redHotBurnerPositions = <int>{};

  AssetType _assetType = AssetType.base;
  String? _issueAssetClassId;
  String? _assetInstanceId;
  MaintenanceType _maintenanceType = MaintenanceType.breakdown;
  RoutedTo _routedTo = RoutedTo.mechanical;
  DateTime _startTime = DateTime.now();

  final _descController = TextEditingController();
  final _chargeNoController = TextEditingController();
  final _tagController = TextEditingController();
  final _componentController = TextEditingController();
  final _otherDepartmentController = TextEditingController();
  final _qualityReasonController = TextEditingController();
  final _burnerHmiAlarmController = TextEditingController();
  final _burnerRelightAttemptsController = TextEditingController(text: '0');

  String? _resolvedSystem;
  String? _resolvedSubsystem;
  List<String>? _resolvedPath;
  AssetHierarchyReference? _assetHierarchyReference;
  String? _resolvedOwnership;
  int _tagResolutionGeneration = 0;
  Timer? _tagResolutionDebounce;

  bool _isAutoResolved = false;
  bool _isGovernedTagResolution = false;
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
    _tagResolutionDebounce?.cancel();
    _descController.dispose();
    _chargeNoController.dispose();
    _tagController.dispose();
    _componentController.dispose();
    _otherDepartmentController.dispose();
    _qualityReasonController.dispose();
    _burnerHmiAlarmController.dispose();
    _burnerRelightAttemptsController.dispose();
    super.dispose();
  }

  void _scheduleTagResolution(String rawTag) {
    _tagResolutionDebounce?.cancel();
    final generation = ++_tagResolutionGeneration;
    if (rawTag.trim().isEmpty) {
      _clearAutoFields();
      return;
    }
    _tagResolutionDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) unawaited(_resolveTag(rawTag, generation: generation));
    });
  }

  Future<bool> _resolveTag(String rawTag, {required int generation}) async {
    final tag = rawTag.trim();
    _userOverrodeComponent = false;

    if (tag.isEmpty) {
      _clearAutoFields();
      return true;
    }

    final selectedAsset = _selectedPhysicalAsset();
    if (selectedAsset == null) {
      _clearAutoFields();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose the governed asset before resolving a tag.'),
          backgroundColor: BafColors.warning,
        ),
      );
      return false;
    }
    if (_assetType == AssetType.innerCover) {
      _clearAutoFields();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inner Cover identity is taken from the selected Base linkage. Enter the affected component by name.',
          ),
          backgroundColor: BafColors.warning,
        ),
      );
      return false;
    }

    try {
      final repository = ref.read(assetHierarchyRepositoryProvider);
      final component = await repository.findActiveInstalledComponentByTag(tag);
      if (!mounted || generation != _tagResolutionGeneration) return false;
      if (component != null) {
        if (component.assetInstanceId != selectedAsset.id ||
            component.assetClassId != selectedAsset.assetClassId) {
          throw AssetHierarchyException(
            'Tag $tag belongs to ${component.assetClassName} ${component.assetNumber}, not the selected ${selectedAsset.assetClassName} ${selectedAsset.assetNumber}.',
          );
        }
        final reference = component.toReference();
        setState(() {
          _resolvedSystem = component.assetClassName;
          _resolvedSubsystem =
              component.hierarchyPath.length > 1
                  ? component.hierarchyPath[component.hierarchyPath.length - 2]
                  : null;
          _resolvedPath = List<String>.from(component.hierarchyPath);
          _assetHierarchyReference = reference;
          _resolvedOwnership = [
            component.ownershipStatus.label,
            if (component.ownerDiscipline != null) component.ownerDiscipline!,
            if (component.accountableRoleKeys.isNotEmpty)
              component.accountableRoleKeys
                  .map(_roleLabelForReference)
                  .join(', '),
          ].join(' · ');
          if (!_userOverrodeComponent ||
              _componentController.text.trim().isEmpty) {
            _componentController.text = component.definitionName;
          }
          _isAutoResolved = true;
          _isGovernedTagResolution = true;
        });
        return true;
      }
    } on AssetHierarchyException catch (error) {
      if (!mounted || generation != _tagResolutionGeneration) return false;
      _tagController.clear();
      _clearAutoFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
      return false;
    } on FormatException {
      if (!mounted || generation != _tagResolutionGeneration) return false;
      _tagController.clear();
      _clearAutoFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This tag has malformed governed component evidence. Reconcile the asset register before using it.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return false;
    } on FirebaseException {
      if (!mounted || generation != _tagResolutionGeneration) return false;
      _tagController.clear();
      _clearAutoFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The tag could not be verified. Sync and retry, or leave the optional tag blank.',
          ),
          backgroundColor: BafColors.warning,
        ),
      );
      return false;
    }

    final result = BafTagResolverV2.resolveToMap(tag, assetContext: _assetType);
    final bool isResolved = result['isAutoResolved'] == true;

    if (!isResolved) {
      _clearAutoFields();
      return true;
    }

    final path = result['hierarchyPath'];
    final safePath = path is List ? List<String>.from(path) : null;

    if (!mounted || generation != _tagResolutionGeneration) return false;

    setState(() {
      _resolvedSystem = result['system'] as String?;
      _resolvedSubsystem = result['subsystem'] as String?;
      _resolvedPath = safePath;
      _assetHierarchyReference = selectedAsset.toReference();
      _resolvedOwnership = null;

      if (!_userOverrodeComponent && _componentController.text.trim().isEmpty) {
        _componentController.text = (result['component'] as String?) ?? '';
      }

      _isAutoResolved = true;
      _isGovernedTagResolution = false;
    });
    return true;
  }

  void _clearAutoFields() {
    if (!mounted) return;

    setState(() {
      _resolvedSystem = null;
      _resolvedSubsystem = null;
      _resolvedPath = null;
      _assetHierarchyReference = null;
      _resolvedOwnership = null;
      _isAutoResolved = false;
      _isGovernedTagResolution = false;
      _userOverrodeComponent = false;
    });
  }

  GovernedIssueAssetRoute? _selectedAssetRoute() {
    final classId = _issueAssetClassId;
    final classes = ref.read(assetClassesProvider).value;
    if (classId == null || classes == null) return null;
    final issueClass = classes.where((item) => item.id == classId).firstOrNull;
    if (issueClass == null) return null;
    return resolveGovernedIssueAssetRoute(
      issueClass: issueClass,
      allClasses: classes,
    );
  }

  AssetInstanceRecord? _selectedPhysicalAsset() {
    final route = _selectedAssetRoute();
    final assetId = _assetInstanceId;
    final physicalClassId = route?.physicalAssetClass?.id;
    if (route == null || assetId == null || physicalClassId == null) {
      return null;
    }
    final assets = ref.read(assetInstancesProvider(physicalClassId)).value;
    return assets
        ?.where(
          (item) =>
              item.id == assetId &&
              item.isActive &&
              item.assetClassId == physicalClassId,
        )
        .firstOrNull;
  }

  void _selectIssueAssetRoute(GovernedIssueAssetRoute? route) {
    setState(() {
      _issueAssetClassId = route?.issueClass.id;
      _assetInstanceId = null;
      _assetType = route?.assetType ?? AssetType.base;
      if (_assetType != AssetType.furnace) _resetBurnerLockout();
      _resetAssetEvidence();
    });
  }

  void _selectPhysicalAsset(AssetInstanceRecord? asset) {
    setState(() {
      _assetInstanceId = asset?.id;
      _resetAssetEvidence();
      _assetHierarchyReference = asset?.toReference();
    });
  }

  void _resetAssetEvidence() {
    _tagResolutionDebounce?.cancel();
    _tagResolutionGeneration++;
    _tagController.clear();
    _componentController.clear();
    _resolvedSystem = null;
    _resolvedSubsystem = null;
    _resolvedPath = null;
    _assetHierarchyReference = null;
    _resolvedOwnership = null;
    _isAutoResolved = false;
    _isGovernedTagResolution = false;
    _userOverrodeComponent = false;
  }

  void _resetBurnerLockout() {
    _isBurnerLockout = false;
    _burnerCommonMode = false;
    _burnerRemainsLockedOut = true;
    _burnerCycleStage = BurnerCycleStage.notRecorded;
    _burnerFlameObservation = BurnerObservation.notChecked;
    _burnerSparkObservation = BurnerObservation.notChecked;
    _burnerPositions.clear();
    _redHotBurnerPositions.clear();
    _burnerHmiAlarmController.clear();
    _burnerRelightAttemptsController.text = '0';
  }

  void _setBurnerLockout(bool enabled) {
    setState(() {
      _resetBurnerLockout();
      _isBurnerLockout = enabled;
      if (enabled) {
        _componentController.text = 'Burner system';
        _routedTo = RoutedTo.instrumentation;
        _maintenanceType = MaintenanceType.breakdown;
      } else {
        _componentController.clear();
      }
    });
  }

  BurnerLockoutCase _buildBurnerLockoutCase() {
    if (_burnerPositions.isEmpty) {
      throw StateError('Select at least one affected burner.');
    }
    final attempts = int.tryParse(_burnerRelightAttemptsController.text.trim());
    if (attempts == null || attempts < 0 || attempts > 20) {
      throw StateError('Relight attempts must be a whole number from 0 to 20.');
    }
    return BurnerLockoutCase(
      positions: _burnerPositions.toList(),
      commonMode: _burnerCommonMode,
      cycleStage: _burnerCycleStage,
      hmiAlarm: _cleanOptionalText(_burnerHmiAlarmController.text),
      flameObservation: _burnerFlameObservation,
      sparkObservation: _burnerSparkObservation,
      relightAttempts: attempts,
      remainsLockedOut: _burnerRemainsLockedOut,
      redHotPositions: _redHotBurnerPositions.toList(),
    );
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

  Future<AssetHierarchyReference?> _resolveEventAssetReference({
    required AssetType assetType,
    required int assetNumber,
    required AssetHierarchyReference selectedReference,
    required String reporterUid,
    required String reporterName,
    required DateTime confirmedAt,
  }) async {
    final usesBasePosition =
        assetType == AssetType.base || assetType == AssetType.innerCover;
    if (!usesBasePosition) return selectedReference;
    final repository = ref.read(assetHierarchyRepositoryProvider);
    final context = await repository.resolveGovernedAssetEventContext(
      legacyAssetTypeKey: AssetType.base.name,
      assetNumber: assetNumber,
    );
    if (context == null) {
      if (assetType == AssetType.innerCover) {
        throw const AssetHierarchyException(
          'This Base is not available in the governed asset register. Register or reconcile it before raising an Inner Cover issue.',
        );
      }
      return selectedReference;
    }
    final existing = selectedReference;
    if (existing.assetInstanceId != context.asset.id) {
      throw const AssetHierarchyException(
        'The resolved component and selected Base disagree. Review the equipment tag.',
      );
    }
    final assignment = context.innerCoverAssignment;
    if (assetType == AssetType.innerCover && assignment == null) {
      throw const AssetHierarchyException(
        'No Inner Cover is currently linked to this Base. Link the physical cover before raising an Inner Cover issue.',
      );
    }
    final association = InnerCoverEventReference(
      baseAssetInstanceId: context.asset.id,
      baseAssetNumber: context.asset.assetNumber,
      positionState:
          assignment == null
              ? InnerCoverPositionState.noneLinked
              : InnerCoverPositionState.linked,
      innerCoverId: assignment?.innerCoverId,
      innerCoverSerialNumber: assignment?.innerCoverSerialNumber,
      linkageId: assignment?.linkageId,
      assignmentVersion: assignment?.version,
      linkedAt: assignment?.linkedAt,
      eventAt: _startTime,
      confirmedAt: confirmedAt,
      confirmedByUid: reporterUid,
      confirmedByName: reporterName,
    );
    return AssetHierarchyReference(
      scope: existing.scope,
      assetClassId: existing.assetClassId,
      assetClassCode: existing.assetClassCode,
      assetClassName: existing.assetClassName,
      nodeId: existing.nodeId,
      nodeVersion: existing.nodeVersion,
      nodeName: existing.nodeName,
      assetInstanceId: existing.assetInstanceId,
      assetInstanceVersion: existing.assetInstanceVersion,
      assetNumber: existing.assetNumber,
      assetInstanceName: existing.assetInstanceName,
      componentInstanceId: existing.componentInstanceId,
      componentInstanceVersion: existing.componentInstanceVersion,
      componentTag: existing.componentTag,
      hierarchyPath: existing.hierarchyPath,
      ownershipStatus: existing.ownershipStatus,
      ownerDiscipline: existing.ownerDiscipline,
      accountableRoleKeys: existing.accountableRoleKeys,
      innerCoverAssociation: association,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final assetRoute = _selectedAssetRoute();
    final selectedAsset = _selectedPhysicalAsset();
    if (assetRoute == null ||
        !assetRoute.isAvailable ||
        selectedAsset == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Choose an active governed asset before submitting.'),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }
    final assetType = assetRoute.assetType;
    final assetNumber = selectedAsset.assetNumber;
    BurnerLockoutCase? burnerLockout;
    if (_isBurnerLockout) {
      if (assetType != AssetType.furnace) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Burner lockout can only be raised for a Furnace.'),
            backgroundColor: BafColors.warning,
          ),
        );
        return;
      }
      try {
        burnerLockout = _buildBurnerLockoutCase();
      } on StateError catch (error) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: BafColors.warning,
          ),
        );
        return;
      } on FormatException catch (error) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: BafColors.warning,
          ),
        );
        return;
      }
    }

    if (_qualityAssessment == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Assess whether coil quality may be affected.'),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }

    final inputValidation = MaintenanceInputValidator.validateCreate(
      MaintenanceCreateInput(
        assetType: assetType,
        assetNumberText: '$assetNumber',
        hasGovernedAssetIdentity: true,
        component:
            burnerLockout == null ? _componentController.text : 'Burner system',
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
      _tagResolutionDebounce?.cancel();
      final submittedTag =
          burnerLockout == null ? _tagController.text.trim() : '';
      if (submittedTag.isNotEmpty) {
        final generation = ++_tagResolutionGeneration;
        final accepted = await _resolveTag(
          submittedTag,
          generation: generation,
        );
        if (!mounted ||
            !accepted ||
            _tagController.text.trim() != submittedTag) {
          return;
        }
      }

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
      final selectedReference =
          _assetHierarchyReference ?? selectedAsset.toReference();
      final eventAssetReference = await _resolveEventAssetReference(
        assetType: assetType,
        assetNumber: assetNumber,
        selectedReference: selectedReference,
        reporterUid: reporterUid!,
        reporterName: reporterName ?? reporterUid,
        confirmedAt: now,
      );
      final tagText =
          burnerLockout == null
              ? _cleanOptionalText(_tagController.text)?.toUpperCase()
              : null;
      final hierarchyPath =
          _resolvedPath == null || _resolvedPath!.isEmpty
              ? null
              : List<String>.from(_resolvedPath!);

      final record =
          MaintenanceRecord()
            ..firestoreId = const Uuid().v4()
            ..assetType = assetType
            ..assetNumber = assetNumber
            ..maintenanceType =
                burnerLockout == null
                    ? _maintenanceType
                    : MaintenanceType.breakdown
            ..classification =
                burnerLockout == null ? null : burnerLockoutClassification
            ..routedTo =
                burnerLockout == null ? _routedTo : RoutedTo.instrumentation
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
            ..isCritical =
                _isCritical || (burnerLockout?.hasRedHotObservation ?? false)
            ..teamsInvolved = []
            ..isSynced = false
            ..component =
                burnerLockout == null
                    ? _cleanRequiredText(_componentController.text)
                    : 'Burner system'
            ..tag = tagText
            ..subsystem = _cleanOptionalText(_resolvedSubsystem)
            ..hierarchyPath = hierarchyPath;
      record.assetHierarchyRefJson = eventAssetReference?.encode();
      record.burnerLockoutCase = burnerLockout;
      record.qualityIntent = IssueQualityIntent(
        assessment: _qualityAssessment!,
        warningReason:
            _qualityAssessment == IssueQualityAssessment.suspected
                ? _cleanRequiredText(_qualityReasonController.text)
                : null,
      );

      final repository = ref.read(maintenanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final autoSyncService = ref.read(autoSyncServiceProvider);

      await repository.saveTicket(record);

      if (record.isCritical) {
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
              .then((outcome) {
                if (outcome.isSuccessful) {
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
              title: 'Quality impact',
              subtitle: 'Record whether the current charge may be affected.',
              icon: Icons.fact_check_outlined,
              children: [
                SegmentedButton<IssueQualityAssessment>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(
                      value: IssueQualityAssessment.notSuspected,
                      icon: Icon(Icons.check_circle_outline_rounded),
                      label: Text('Not suspected'),
                    ),
                    ButtonSegment(
                      value: IssueQualityAssessment.suspected,
                      icon: Icon(Icons.warning_amber_rounded),
                      label: Text('Suspected'),
                    ),
                  ],
                  selected:
                      _qualityAssessment == null
                          ? const <IssueQualityAssessment>{}
                          : <IssueQualityAssessment>{_qualityAssessment!},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _qualityAssessment =
                          selection.isEmpty ? null : selection.first;
                      if (_qualityAssessment !=
                          IssueQualityAssessment.suspected) {
                        _qualityReasonController.clear();
                      }
                    });
                  },
                ),
                if (_qualityAssessment == IssueQualityAssessment.suspected) ...[
                  const SizedBox(height: BafSpacing.md),
                  TextFormField(
                    controller: _qualityReasonController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      'Suspected quality effect',
                      hint: 'What may have affected the coil or cycle?',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (_qualityAssessment !=
                          IssueQualityAssessment.suspected) {
                        return null;
                      }
                      final cleaned = value?.trim() ?? '';
                      if (cleaned.length < 8) {
                        return 'Describe the suspected effect (at least 8 characters)';
                      }
                      if (cleaned.length > 1000) {
                        return 'Keep the quality note within 1000 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: BafSpacing.lg),

            _SectionCard(
              title: 'Asset context',
              subtitle: 'Where is the issue happening?',
              icon: Icons.precision_manufacturing_rounded,
              children: [
                _GovernedIssueAssetSelector(
                  selectedIssueClassId: _issueAssetClassId,
                  selectedAssetInstanceId: _assetInstanceId,
                  onRouteChanged: _selectIssueAssetRoute,
                  onAssetChanged: _selectPhysicalAsset,
                ),
                if (_assetType == AssetType.furnace) ...[
                  const SizedBox(height: BafSpacing.md),
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.build_outlined),
                        label: Text('Standard issue'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.local_fire_department_outlined),
                        label: Text('Burner lockout'),
                      ),
                    ],
                    selected: <bool>{_isBurnerLockout},
                    onSelectionChanged: (selection) {
                      _setBurnerLockout(selection.first);
                    },
                  ),
                ],
                if (!_isBurnerLockout) ...[
                  const SizedBox(height: BafSpacing.md),
                  TextFormField(
                    controller: _tagController,
                    enabled:
                        _selectedPhysicalAsset() != null &&
                        _assetType != AssetType.innerCover,
                    decoration: _inputDecoration(
                      'Instrument tag / equipment tag',
                      hint:
                          _assetType == AssetType.innerCover
                              ? 'Inner Cover identity comes from the Base linkage'
                              : 'Optional, must belong to the selected asset',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: _scheduleTagResolution,
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
                      ownership: _resolvedOwnership,
                      governed: _isGovernedTagResolution,
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: BafSpacing.md),
                  const _BurnerRouteNotice(),
                ],
              ],
            ),

            if (_isBurnerLockout) ...[
              const SizedBox(height: BafSpacing.lg),
              _BurnerLockoutIntake(
                selectedPositions: _burnerPositions,
                redHotPositions: _redHotBurnerPositions,
                commonMode: _burnerCommonMode,
                cycleStage: _burnerCycleStage,
                flameObservation: _burnerFlameObservation,
                sparkObservation: _burnerSparkObservation,
                remainsLockedOut: _burnerRemainsLockedOut,
                hmiAlarmController: _burnerHmiAlarmController,
                relightAttemptsController: _burnerRelightAttemptsController,
                onPositionChanged: (position, selected) {
                  setState(() {
                    if (selected) {
                      _burnerPositions.add(position);
                    } else {
                      _burnerPositions.remove(position);
                      _redHotBurnerPositions.remove(position);
                    }
                    if (_burnerPositions.length < 2) {
                      _burnerCommonMode = false;
                    }
                  });
                },
                onRedHotChanged: (position, selected) {
                  setState(() {
                    if (selected) {
                      _redHotBurnerPositions.add(position);
                      _isCritical = true;
                    } else {
                      _redHotBurnerPositions.remove(position);
                    }
                  });
                },
                onCommonModeChanged:
                    (value) => setState(() => _burnerCommonMode = value),
                onCycleStageChanged:
                    (value) => setState(() => _burnerCycleStage = value),
                onFlameObservationChanged:
                    (value) => setState(() => _burnerFlameObservation = value),
                onSparkObservationChanged:
                    (value) => setState(() => _burnerSparkObservation = value),
                onRemainsLockedOutChanged:
                    (value) => setState(() => _burnerRemainsLockedOut = value),
              ),
            ],

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
                  value: _isCritical || _redHotBurnerPositions.isNotEmpty,
                  onChanged:
                      _redHotBurnerPositions.isNotEmpty
                          ? (_) {}
                          : (value) => setState(() => _isCritical = value),
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<RoutedTo>(
                  key: ValueKey('issue-route-${_routedTo.name}'),
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
                  onChanged:
                      _isBurnerLockout
                          ? null
                          : (value) {
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
                  key: ValueKey('issue-type-${_maintenanceType.name}'),
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
                  onChanged:
                      _isBurnerLockout
                          ? null
                          : (value) {
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
                    hint:
                        _qualityAssessment == IssueQualityAssessment.suspected
                            ? 'Required for a quality warning'
                            : 'Optional',
                  ),
                  validator: (value) {
                    final message =
                        MaintenanceInputValidator.validateChargeNumber(
                          value,
                        ).messageFor('chargeNoAtEvent');
                    if (message != null) return message;
                    if (_qualityAssessment ==
                            IssueQualityAssessment.suspected &&
                        int.tryParse(value?.trim() ?? '') == null) {
                      return 'Charge number is required when quality impact is suspected';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SubmitIssueBar(
        isSubmitting: _isSubmitting,
        isCritical: _isCritical || _redHotBurnerPositions.isNotEmpty,
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

class _BurnerRouteNotice extends StatelessWidget {
  const _BurnerRouteNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.audit.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.audit.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_rounded, color: BafColors.audit),
          SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Burner lockout is routed to I&A as a breakdown issue. Other '
              'disciplines can be requested through the existing scoped-help '
              'workflow.',
              style: TextStyle(
                color: BafColors.textPrimary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BurnerLockoutIntake extends StatelessWidget {
  const _BurnerLockoutIntake({
    required this.selectedPositions,
    required this.redHotPositions,
    required this.commonMode,
    required this.cycleStage,
    required this.flameObservation,
    required this.sparkObservation,
    required this.remainsLockedOut,
    required this.hmiAlarmController,
    required this.relightAttemptsController,
    required this.onPositionChanged,
    required this.onRedHotChanged,
    required this.onCommonModeChanged,
    required this.onCycleStageChanged,
    required this.onFlameObservationChanged,
    required this.onSparkObservationChanged,
    required this.onRemainsLockedOutChanged,
  });

  final Set<int> selectedPositions;
  final Set<int> redHotPositions;
  final bool commonMode;
  final BurnerCycleStage cycleStage;
  final BurnerObservation flameObservation;
  final BurnerObservation sparkObservation;
  final bool remainsLockedOut;
  final TextEditingController hmiAlarmController;
  final TextEditingController relightAttemptsController;
  final void Function(int position, bool selected) onPositionChanged;
  final void Function(int position, bool selected) onRedHotChanged;
  final ValueChanged<bool> onCommonModeChanged;
  final ValueChanged<BurnerCycleStage> onCycleStageChanged;
  final ValueChanged<BurnerObservation> onFlameObservationChanged;
  final ValueChanged<BurnerObservation> onSparkObservationChanged;
  final ValueChanged<bool> onRemainsLockedOutChanged;

  @override
  Widget build(BuildContext context) {
    final sortedPositions = selectedPositions.toList()..sort();
    return _SectionCard(
      title: 'Burner lockout evidence',
      subtitle: 'Identify the affected positions and what was observed.',
      icon: Icons.local_fire_department_rounded,
      children: [
        const Text(
          'Affected burners',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        Wrap(
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.sm,
          children: [
            for (var position = 1; position <= 8; position++)
              FilterChip(
                label: Text('B$position'),
                selected: selectedPositions.contains(position),
                onSelected: (selected) => onPositionChanged(position, selected),
              ),
          ],
        ),
        if (selectedPositions.length > 1) ...[
          const SizedBox(height: BafSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Possible common-mode event'),
            subtitle: const Text(
              'The selected burners may share one initiating condition.',
            ),
            value: commonMode,
            onChanged: onCommonModeChanged,
          ),
        ],
        if (sortedPositions.isNotEmpty) ...[
          const Divider(height: BafSpacing.xl),
          const Text(
            'Red-hot burner blocks',
            style: TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select only positions where the refractory burner block was '
            'observed red hot. This is not a UV-detector observation.',
            style: TextStyle(color: BafColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: BafSpacing.sm),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              for (final position in sortedPositions)
                FilterChip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 17),
                  label: Text('B$position red hot'),
                  selected: redHotPositions.contains(position),
                  selectedColor: BafColors.danger.withValues(alpha: 0.12),
                  checkmarkColor: BafColors.danger,
                  onSelected: (selected) => onRedHotChanged(position, selected),
                ),
            ],
          ),
          if (redHotPositions.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BafSpacing.md),
              decoration: BoxDecoration(
                color: BafColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(BafRadius.medium),
                border: Border.all(
                  color: BafColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'A critical I&A safety directive will be created with this '
                'issue. I&A must acknowledge and record compliance with the '
                'approved plant procedure; the app does not actuate the PLC.',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
        const Divider(height: BafSpacing.xl),
        DropdownButtonFormField<BurnerCycleStage>(
          initialValue: cycleStage,
          decoration: _burnerDecoration('Cycle / firing stage'),
          items: [
            for (final stage in BurnerCycleStage.values)
              DropdownMenuItem(
                value: stage,
                child: Text(_cycleStageLabel(stage)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onCycleStageChanged(value);
          },
        ),
        const SizedBox(height: BafSpacing.md),
        TextFormField(
          controller: hmiAlarmController,
          maxLength: 300,
          decoration: _burnerDecoration(
            'HMI alarm / indication',
            hint: 'Optional alarm text or code',
          ),
        ),
        const SizedBox(height: BafSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<BurnerObservation>(
                initialValue: flameObservation,
                decoration: _burnerDecoration('Flame'),
                items: [
                  for (final value in BurnerObservation.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_observationLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onFlameObservationChanged(value);
                },
              ),
            ),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: DropdownButtonFormField<BurnerObservation>(
                initialValue: sparkObservation,
                decoration: _burnerDecoration('Spark'),
                items: [
                  for (final value in BurnerObservation.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_observationLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onSparkObservationChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        TextFormField(
          controller: relightAttemptsController,
          keyboardType: TextInputType.number,
          decoration: _burnerDecoration('Relight attempts'),
          validator: (value) {
            final attempts = int.tryParse(value?.trim() ?? '');
            if (attempts == null || attempts < 0 || attempts > 20) {
              return 'Enter a whole number from 0 to 20';
            }
            return null;
          },
        ),
        const SizedBox(height: BafSpacing.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Still locked out when reported'),
          subtitle: const Text(
            'The issue remained present after the observations above.',
          ),
          value: remainsLockedOut,
          onChanged: onRemainsLockedOutChanged,
        ),
      ],
    );
  }

  static InputDecoration _burnerDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: BafColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.border),
        ),
      );

  static String _cycleStageLabel(BurnerCycleStage value) => switch (value) {
    BurnerCycleStage.notRecorded => 'Not recorded',
    BurnerCycleStage.purge => 'Purge',
    BurnerCycleStage.ignition => 'Ignition',
    BurnerCycleStage.firing => 'Firing',
    BurnerCycleStage.unknown => 'Unknown',
  };

  static String _observationLabel(BurnerObservation value) => switch (value) {
    BurnerObservation.seen => 'Seen',
    BurnerObservation.notSeen => 'Not seen',
    BurnerObservation.notChecked => 'Not checked',
  };
}

class _GovernedIssueAssetSelector extends ConsumerWidget {
  const _GovernedIssueAssetSelector({
    required this.selectedIssueClassId,
    required this.selectedAssetInstanceId,
    required this.onRouteChanged,
    required this.onAssetChanged,
  });

  final String? selectedIssueClassId;
  final String? selectedAssetInstanceId;
  final ValueChanged<GovernedIssueAssetRoute?> onRouteChanged;
  final ValueChanged<AssetInstanceRecord?> onAssetChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesValue = ref.watch(assetClassesProvider);
    return classesValue.when(
      loading:
          () => const _AssetSelectorMessage(
            icon: Icons.sync_rounded,
            message: 'Loading the governed asset register...',
            color: BafColors.maintenance,
            showProgress: true,
          ),
      error:
          (error, stackTrace) => const _AssetSelectorMessage(
            icon: Icons.error_outline_rounded,
            message:
                'The governed asset register could not be loaded. Sync and try again.',
            color: BafColors.danger,
          ),
      data: (allClasses) {
        final classes = activeIssueAssetClasses(allClasses);
        if (classes.isEmpty) {
          return const _AssetSelectorMessage(
            icon: Icons.inventory_2_outlined,
            message:
                'No active asset classes are registered. An administrator must add one before issues can be raised.',
            color: BafColors.warning,
          );
        }

        final selectedClass =
            classes
                .where((item) => item.id == selectedIssueClassId)
                .firstOrNull;
        final route =
            selectedClass == null
                ? null
                : resolveGovernedIssueAssetRoute(
                  issueClass: selectedClass,
                  allClasses: allClasses,
                );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(
                'issue-asset-class-${selectedClass?.id ?? 'none'}-${classes.length}',
              ),
              initialValue: selectedClass?.id,
              isExpanded: true,
              decoration: _decoration('Asset class'),
              items: classes
                  .map(
                    (assetClass) => DropdownMenuItem<String>(
                      value: assetClass.id,
                      child: Text(
                        assetClass.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (classId) {
                if (classId == null) {
                  onRouteChanged(null);
                  return;
                }
                final issueClass = classes.firstWhere(
                  (item) => item.id == classId,
                );
                onRouteChanged(
                  resolveGovernedIssueAssetRoute(
                    issueClass: issueClass,
                    allClasses: allClasses,
                  ),
                );
              },
              validator:
                  (value) =>
                      value == null ? 'Choose the affected asset class' : null,
            ),
            if (route != null) ...[
              const SizedBox(height: BafSpacing.md),
              if (!route.isAvailable)
                _AssetSelectorMessage(
                  icon: Icons.block_rounded,
                  message:
                      route.blockingReason ??
                      'This asset class cannot currently accept issues.',
                  color: BafColors.danger,
                )
              else ...[
                if (route.innerCoverByBase) ...[
                  const _AssetSelectorMessage(
                    icon: Icons.link_rounded,
                    message:
                        'Select the Base carrying the Inner Cover. Its current serial number and linkage are frozen with the issue.',
                    color: BafColors.maintenance,
                  ),
                  const SizedBox(height: BafSpacing.md),
                ],
                _PhysicalAssetSelector(
                  route: route,
                  selectedAssetInstanceId: selectedAssetInstanceId,
                  onAssetChanged: onAssetChanged,
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
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
}

class _PhysicalAssetSelector extends ConsumerWidget {
  const _PhysicalAssetSelector({
    required this.route,
    required this.selectedAssetInstanceId,
    required this.onAssetChanged,
  });

  final GovernedIssueAssetRoute route;
  final String? selectedAssetInstanceId;
  final ValueChanged<AssetInstanceRecord?> onAssetChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final physicalClass = route.physicalAssetClass!;
    final assetsValue = ref.watch(assetInstancesProvider(physicalClass.id));
    return assetsValue.when(
      loading:
          () => const _AssetSelectorMessage(
            icon: Icons.sync_rounded,
            message: 'Loading active physical assets...',
            color: BafColors.maintenance,
            showProgress: true,
          ),
      error:
          (error, stackTrace) => const _AssetSelectorMessage(
            icon: Icons.error_outline_rounded,
            message: 'Physical assets could not be loaded. Sync and try again.',
            color: BafColors.danger,
          ),
      data: (allAssets) {
        final assets = eligibleIssueAssets(route: route, assets: allAssets);
        final selectedAsset =
            assets
                .where((item) => item.id == selectedAssetInstanceId)
                .firstOrNull;
        if (assets.isEmpty) {
          return _AssetSelectorMessage(
            icon: Icons.precision_manufacturing_outlined,
            message:
                'No active ${physicalClass.name} assets are registered. Add or reactivate the physical asset before raising an issue.',
            color: BafColors.warning,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(
                'issue-physical-asset-${physicalClass.id}-${selectedAsset?.id ?? 'none'}-${assets.length}',
              ),
              initialValue: selectedAsset?.id,
              isExpanded: true,
              decoration: _decoration(
                route.innerCoverByBase
                    ? 'Base carrying Inner Cover'
                    : 'Physical asset',
              ),
              items: assets
                  .map(
                    (asset) => DropdownMenuItem<String>(
                      value: asset.id,
                      child: Text(
                        _assetLabel(asset),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (assetId) {
                if (assetId == null) {
                  onAssetChanged(null);
                  return;
                }
                onAssetChanged(assets.firstWhere((item) => item.id == assetId));
              },
              validator:
                  (value) =>
                      value == null ? 'Choose the exact physical asset' : null,
            ),
            if (selectedAsset != null) ...[
              const SizedBox(height: BafSpacing.sm),
              _SelectedAssetSummary(asset: selectedAsset),
            ],
          ],
        );
      },
    );
  }

  String _assetLabel(AssetInstanceRecord asset) {
    final numberLabel = '${asset.assetClassName} ${asset.assetNumber}';
    final name = asset.name.trim();
    if (name.isEmpty || name.toLowerCase() == numberLabel.toLowerCase()) {
      return numberLabel;
    }
    return '$numberLabel · $name';
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
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
}

class _SelectedAssetSummary extends StatelessWidget {
  const _SelectedAssetSummary({required this.asset});

  final AssetInstanceRecord asset;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      asset.serviceState.label,
      if (asset.plantTag case final tag? when tag.trim().isNotEmpty) tag.trim(),
      if (asset.location case final location? when location.trim().isNotEmpty)
        location.trim(),
      asset.ownershipStatus.label,
    ];
    final color = switch (asset.serviceState) {
      AssetServiceState.inService => BafColors.sync,
      AssetServiceState.standby => BafColors.warning,
      AssetServiceState.outOfService => BafColors.danger,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_outlined, color: color, size: 18),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            details.join(' · '),
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetSelectorMessage extends StatelessWidget {
  const _AssetSelectorMessage({
    required this.icon,
    required this.message,
    required this.color,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final Color color;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (showProgress) ...[
          const SizedBox(height: BafSpacing.sm),
          LinearProgressIndicator(
            minHeight: 2,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ],
      ],
    );
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
  final String? ownership;
  final bool governed;

  const _ResolvedTagPanel({
    this.system,
    this.subsystem,
    this.path,
    this.ownership,
    this.governed = false,
  });

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
          Row(
            children: [
              Icon(
                governed ? Icons.verified_outlined : Icons.auto_awesome_rounded,
                size: 17,
                color: BafColors.sync,
              ),
              const SizedBox(width: 6),
              Text(
                governed ? 'Governed component resolved' : 'Tag resolved',
                style: const TextStyle(
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
          if (ownership != null && ownership!.trim().isNotEmpty)
            _ResolvedLine(label: 'Ownership', value: ownership!),
        ],
      ),
    );
  }
}

String _roleLabelForReference(String role) => switch (role) {
  'admin' => 'Admin',
  'si' => 'SI',
  'contractSupervisor' => 'Contract supervisor',
  'shiftSupervisor' => 'Shift supervisor',
  'seniorElectrical' => 'Sr. Electrical',
  'seniorMechanical' => 'Sr. Mechanical',
  'seniorInstrumentation' => 'Sr. I&A',
  'seniorRefractory' => 'Sr. Refractory',
  'refractory' => 'Refractory',
  'operations' => 'Operations',
  _ => role,
};

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
