// FILE: lib/features/abnormalities/presentation/charge_abnormalities_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation/charge_number.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/presentation/widgets/governed_asset_target_picker.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/repositories/asset_hierarchy_repository.dart';
import '../../audit/models/audit_event_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/domain/governed_issue_asset_selection.dart';
import '../data/abnormality_model.dart';
import '../providers/abnormality_provider.dart';

part 'charge_abnormalities_screen.form.dart';
part 'charge_abnormalities_screen.widgets.dart';

class ChargeAbnormalitiesScreen extends ConsumerStatefulWidget {
  final int sourceChargeNo;
  final String? title;
  final String? subtitle;

  const ChargeAbnormalitiesScreen({
    super.key,
    required this.sourceChargeNo,
    this.title,
    this.subtitle,
  });

  @override
  ConsumerState<ChargeAbnormalitiesScreen> createState() =>
      _ChargeAbnormalitiesScreenState();
}

class _ChargeAbnormalitiesScreenState
    extends ConsumerState<ChargeAbnormalitiesScreen> {
  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Charge abnormalities',
        appBarSubtitle: 'Verifying your approved abnormality scope',
        appBarIcon: Icons.warning_amber_outlined,
        accent: BafColors.charges,
        label: 'Checking charge-abnormality access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Charge abnormalities',
        appBarSubtitle: 'Verifying your approved abnormality scope',
        appBarIcon: Icons.warning_amber_outlined,
        accent: BafColors.charges,
        message: 'Charge-abnormality access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Charge abnormalities',
        appBarSubtitle: 'Approved abnormality access only',
        appBarIcon: Icons.warning_amber_outlined,
        accent: BafColors.charges,
        title: 'Charge-abnormality access required',
        message:
            'An approved operational role is required to view charge abnormalities.',
      );
    }
    final abnormalitiesAsync = ref.watch(
      abnormalitiesForChargeProvider(widget.sourceChargeNo),
    );

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: BafAppBarTitle(
          title: widget.title ?? 'Charge abnormalities',
          subtitle: 'Charge ${widget.sourceChargeNo} · governed cycle evidence',
          icon: Icons.warning_amber_outlined,
          accent: BafColors.charges,
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          key: const ValueKey('charge-abnormalities-scroll'),
          slivers: [
            if (actor.canLogChargeAbnormality)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.md,
                  BafSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('charge-abnormalities-create'),
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.charges,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Log Abnormality'),
                      onPressed: () => _showAbnormalityForm(),
                    ),
                  ),
                ),
              ),
            ...abnormalitiesAsync.when<List<Widget>>(
              loading:
                  () => const [
                    SliverToBoxAdapter(
                      child: BafLoadingPanel(
                        label: 'Loading charge abnormalities',
                        color: BafColors.charges,
                      ),
                    ),
                  ],
              error:
                  (err, _) => [
                    SliverToBoxAdapter(
                      child: _StateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load abnormalities',
                        message: '$err',
                        color: BafColors.danger,
                      ),
                    ),
                  ],
              data:
                  (records) => [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        BafSpacing.lg,
                        BafSpacing.lg,
                        BafSpacing.lg,
                        BafSpacing.sm,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _HeaderCard(
                          sourceChargeNo: widget.sourceChargeNo,
                          subtitle: widget.subtitle,
                          total: records.length,
                          raCount:
                              records
                                  .where((record) => record.requiresReannealing)
                                  .length,
                          completedRaCount:
                              records
                                  .where(
                                    (record) => record.hasCompletedReannealing,
                                  )
                                  .length,
                        ),
                      ),
                    ),
                    if (records.isEmpty)
                      const SliverToBoxAdapter(
                        child: _StateCard(
                          icon: Icons.fact_check_outlined,
                          title: 'No abnormalities logged',
                          message:
                              'Use “Log Abnormality” to record process, equipment, result-quality or RA observations for this charge.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          BafSpacing.lg,
                          BafSpacing.sm,
                          BafSpacing.lg,
                          BafSpacing.lg,
                        ),
                        sliver: SliverList.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];

                            return _ChargeAbnormalityCard(
                              record: record,
                              onEdit:
                                  actor.canEditChargeAbnormality
                                      ? () =>
                                          _showAbnormalityForm(existing: record)
                                      : null,
                              onDelete:
                                  actor.canSoftDeleteChargeAbnormality
                                      ? () => _confirmDelete(record)
                                      : null,
                            );
                          },
                        ),
                      ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAbnormalityForm({ChargeAbnormality? existing}) async {
    final actor = ref.read(currentAppUserProvider).value;

    final allowed =
        existing == null
            ? actor?.canLogChargeAbnormality == true
            : actor?.canEditChargeAbnormality == true;

    if (actor == null || !allowed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'You are not authorized to log charge abnormalities.'
                : 'Only Admin can edit charge abnormalities.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final repository = ref.read(abnormalityRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider);

    final activeTypes = await repository.getActiveTypes();

    if (existing == null && activeTypes.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'No active abnormality types found. Seed or create master data first.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final draft = await showDialog<_ChargeAbnormalityDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _ChargeAbnormalityFormDialog(
          sourceChargeNo: widget.sourceChargeNo,
          activeTypes: activeTypes,
          existing: existing,
        );
      },
    );

    if (!mounted || draft == null) return;

    try {
      final now = DateTime.now();

      final record =
          existing == null
              ? ChargeAbnormality()
              : copyChargeAbnormality(existing);

      if (existing == null) {
        record
          ..firestoreId = const Uuid().v4()
          ..sourceChargeNo = widget.sourceChargeNo
          ..loggedAt = draft.eventAt
          ..loggedByUid = actor.uid
          ..loggedByName = actor.name
          ..version = 1;
      }

      record
        ..abnormalityTypeId =
            draft.selectedType.firestoreId ?? draft.selectedType.code
        ..abnormalityTypeCode = draft.selectedType.code
        ..abnormalityTypeTitle = draft.selectedType.title
        ..category = draft.selectedType.category
        ..severity = draft.severity
        ..affectedAssets = draft.affectedAssets
        ..component = draft.component
        ..observedReason = draft.observedReason
        ..description = draft.description
        ..possibleRootReasonCategory = draft.rootReasonCategory
        ..possibleRootReasonNotes = draft.rootReasonNotes
        ..reannealingStatus = draft.reannealingStatus
        ..reannealedToChargeNo = draft.reannealedToChargeNo
        ..updatedAt = now
        ..updatedByUid = actor.uid
        ..updatedByName = actor.name
        ..isDeleted = false
        ..isSynced = false;

      record.normalizeReannealingState();

      if (existing == null) {
        await repository.saveAbnormality(
          record,
          actor: actor,
          auditContext: AuditContext(
            performedByUid: actor.uid,
            performedByName: actor.name,
            reasonNotes: 'Logged charge abnormality',
          ),
        );
      } else {
        final result = await ref
            .read(chargeAbnormalityCommandServiceProvider)
            .update(
              abnormality: record,
              expectedVersion: existing.version,
              reason: draft.correctionReason!,
            );
        final adopted = await repository
            .applyAbnormalityServerReadbackIfUnchanged(
              result.abnormality,
              expectedLocal: SyncPushSnapshot(
                id: existing.id,
                version: existing.version,
                updatedAt: existing.updatedAt,
              ),
              expectedLocalSynced: existing.isSynced,
            );
        if (!adopted) {
          throw StateError(
            'The abnormality was updated by the server, but newer local work '
            'was preserved for reconciliation.',
          );
        }
      }

      SyncRequestOutcome? createSyncOutcome;
      if (existing == null && !record.isSynced) {
        createSyncOutcome = await syncCoordinator.runFullSyncWithResult(
          reason: 'charge_abnormality_created',
          force: true,
        );
      } else {
        // Updates already carry an authoritative callable receipt. This sync
        // only refreshes related local projections and may remain background.
        unawaited(
          syncCoordinator.runFullSync(
            reason:
                existing == null
                    ? 'charge_abnormality_created_refresh'
                    : 'charge_abnormality_edited_refresh',
            force: true,
          ),
        );
      }

      if (!mounted) return;

      final (message, color) =
          existing != null || record.isSynced
              ? (
                existing == null
                    ? 'Charge abnormality logged and synchronized.'
                    : 'Charge abnormality updated in the plant system.',
                BafColors.sync,
              )
              : switch (createSyncOutcome!) {
                SyncRequestOutcome.succeeded => (
                  'Charge abnormality logged and synchronized.',
                  BafColors.sync,
                ),
                SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
                  'Charge abnormality saved on this device; synchronization is queued.',
                  BafColors.warning,
                ),
                SyncRequestOutcome.failed => (
                  'Charge abnormality saved on this device, but cloud synchronization needs attention.',
                  BafColors.danger,
                ),
              };

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(ChargeAbnormality record) async {
    final actor = ref.read(currentAppUserProvider).value;

    if (actor == null || !actor.canSoftDeleteChargeAbnormality) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Only Admin can delete charge abnormalities.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final decision = await showDialog<_DeleteDecision>(
      context: context,
      builder: (_) => const _DeleteAbnormalityDialog(),
    );

    if (!mounted || decision == null) return;

    try {
      if (record.firestoreId == null) {
        if (!mounted) return;

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Abnormality ID is missing')),
        );
        return;
      }

      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      final deleteReason = <String>[
        if (decision.reason != null) _auditReasonLabel(decision.reason!),
        if (decision.notes?.trim().isNotEmpty == true) decision.notes!.trim(),
      ].join(': ');
      final result = await ref
          .read(chargeAbnormalityCommandServiceProvider)
          .softDelete(
            abnormality: record,
            expectedVersion: record.version,
            reason: deleteReason,
          );
      final adopted = await repository
          .applyAbnormalityServerReadbackIfUnchanged(
            result.abnormality,
            expectedLocal: SyncPushSnapshot(
              id: record.id,
              version: record.version,
              updatedAt: record.updatedAt,
            ),
            expectedLocalSynced: record.isSynced,
          );
      if (!adopted) {
        throw StateError(
          'The abnormality was deleted by the server, but newer local work '
          'was preserved for reconciliation.',
        );
      }

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'charge_abnormality_deleted',
          force: true,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Charge abnormality deleted')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// FORM DIALOGS
// ─────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({
  required String label,
  String? hint,
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    filled: true,
    fillColor: BafColors.card,
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
      borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
    ),
  );
}

List<AbnormalityType> _abnormalityTypesForForm({
  required List<AbnormalityType> activeTypes,
  required ChargeAbnormality? existing,
}) {
  final available = List<AbnormalityType>.from(activeTypes);
  if (existing == null) return available;

  final matchIndex = available.indexWhere(
    (type) =>
        type.firestoreId == existing.abnormalityTypeId ||
        type.code == existing.abnormalityTypeId ||
        type.code == existing.abnormalityTypeCode,
  );
  if (matchIndex >= 0) {
    final match = available.removeAt(matchIndex);
    return <AbnormalityType>[match, ...available];
  }

  final historical =
      AbnormalityType()
        ..firestoreId = existing.abnormalityTypeId
        ..code = existing.abnormalityTypeCode
        ..title = '${existing.abnormalityTypeTitle} (historical)'
        ..description =
            'Retained from the original abnormality because its governed type is no longer active.'
        ..category = existing.category
        ..severity = existing.severity
        ..applicableAssetTypes =
            existing.affectedAssets
                .map((asset) => asset.assetType)
                .toSet()
                .toList()
        ..suggestsReannealing = existing.requiresReannealing
        ..isActive = false
        ..isDeleted = true
        ..version = 1
        ..isSynced = true
        ..createdAt = existing.loggedAt
        ..updatedAt = existing.updatedAt;
  return <AbnormalityType>[historical, ...available];
}

AssetClassRecord? _findAssetClass(
  Iterable<AssetClassRecord> classes,
  String? id,
) {
  if (id == null) return null;
  for (final assetClass in classes) {
    if (assetClass.id == id) return assetClass;
  }
  return null;
}

AssetInstanceRecord? _findAsset(
  Iterable<AssetInstanceRecord> assets,
  String? id,
) {
  if (id == null) return null;
  for (final asset in assets) {
    if (asset.id == id) return asset;
  }
  return null;
}

String _registeredAssetLabel(AssetInstanceRecord asset) {
  final name = asset.name.trim();
  final number = asset.assetNumber.toString();
  if (name == number || name.endsWith(' $number')) return name;
  return '$number - $name';
}

RootReasonCategory _rootReasonForAssetType(AssetType type) => switch (type) {
  AssetType.base || AssetType.innerCover => RootReasonCategory.baseRelated,
  AssetType.furnace => RootReasonCategory.furnaceRelated,
  AssetType.forceCooler => RootReasonCategory.forceCoolerRelated,
  AssetType.governedCustom => RootReasonCategory.other,
};

AssetHierarchyReference _copyReferenceWithAssociation(
  AssetHierarchyReference reference,
  InnerCoverEventReference association,
) => AssetHierarchyReference(
  scope: reference.scope,
  assetClassId: reference.assetClassId,
  assetClassCode: reference.assetClassCode,
  assetClassName: reference.assetClassName,
  nodeId: reference.nodeId,
  nodeVersion: reference.nodeVersion,
  nodeName: reference.nodeName,
  assetInstanceId: reference.assetInstanceId,
  assetInstanceVersion: reference.assetInstanceVersion,
  assetNumber: reference.assetNumber,
  assetInstanceName: reference.assetInstanceName,
  componentInstanceId: reference.componentInstanceId,
  componentInstanceVersion: reference.componentInstanceVersion,
  componentTag: reference.componentTag,
  hierarchyPath: reference.hierarchyPath,
  ownershipStatus: reference.ownershipStatus,
  ownerDiscipline: reference.ownerDiscipline,
  accountableRoleKeys: reference.accountableRoleKeys,
  innerCoverAssociation: association,
);

String? _requiredTextValidation(
  String? value, {
  required String label,
  required int maximum,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '$label is required';
  if (text.length > maximum) {
    return '$label must not exceed $maximum characters';
  }
  return null;
}

String? _optionalTextValidation(
  String? value, {
  required String label,
  required int maximum,
}) {
  final text = value?.trim() ?? '';
  if (text.length > maximum) {
    return '$label must not exceed $maximum characters';
  }
  return null;
}

String? _componentSummary(
  Iterable<AffectedAssetRef> assets,
  String? legacyComponent,
) {
  final components = assets
      .map((asset) => asset.componentLabel?.trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (components.isEmpty) return _emptyToNull(legacyComponent ?? '');
  final summary = components.join(', ');
  return summary.length <= 200
      ? summary
      : '${components.length} governed components selected';
}

ReannealingStatus _defaultRaStatusForType(AbnormalityType type) {
  if (type.isRaCoilColourType) {
    return ReannealingStatus.required;
  }

  if (type.suggestsReannealing) {
    return ReannealingStatus.pendingDecision;
  }

  return ReannealingStatus.notApplicable;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _categoryLabel(AbnormalityCategory category) {
  switch (category) {
    case AbnormalityCategory.process:
      return 'Process';
    case AbnormalityCategory.equipment:
      return 'Equipment';
    case AbnormalityCategory.resultQuality:
      return 'Result / Quality';
    case AbnormalityCategory.reannealing:
      return 'Re-annealing';
    case AbnormalityCategory.other:
      return 'Other';
  }
}

String _severityLabel(AbnormalitySeverity severity) {
  switch (severity) {
    case AbnormalitySeverity.low:
      return 'Low';
    case AbnormalitySeverity.medium:
      return 'Medium';
    case AbnormalitySeverity.high:
      return 'High';
    case AbnormalitySeverity.critical:
      return 'Critical';
  }
}

String _raStatusLabel(ReannealingStatus status) {
  switch (status) {
    case ReannealingStatus.notApplicable:
      return 'Not Applicable';
    case ReannealingStatus.pendingDecision:
      return 'Pending Decision';
    case ReannealingStatus.required:
      return 'Required';
    case ReannealingStatus.notRequired:
      return 'Not Required';
    case ReannealingStatus.completed:
      return 'Completed';
  }
}

String _rootReasonCategoryLabel(RootReasonCategory category) {
  switch (category) {
    case RootReasonCategory.unknown:
      return 'Unknown';
    case RootReasonCategory.baseRelated:
      return 'Base Related';
    case RootReasonCategory.furnaceRelated:
      return 'Furnace Related';
    case RootReasonCategory.forceCoolerRelated:
      return 'Force Cooler Related';
    case RootReasonCategory.atmosphereRelated:
      return 'Atmosphere Related';
    case RootReasonCategory.thermocoupleTemperature:
      return 'Thermocouple / Temperature';
    case RootReasonCategory.cycleInterruption:
      return 'Cycle Interruption';
    case RootReasonCategory.materialOrCoilCondition:
      return 'Material / Coil Condition';
    case RootReasonCategory.operationsRelated:
      return 'Operations Related';
    case RootReasonCategory.other:
      return 'Other';
  }
}

IconData _assetIcon(AssetType type) {
  switch (type) {
    case AssetType.base:
      return Icons.foundation_rounded;
    case AssetType.furnace:
      return Icons.local_fire_department_rounded;
    case AssetType.forceCooler:
      return Icons.ac_unit_rounded;
    case AssetType.innerCover:
      return Icons.inventory_2_outlined;
    case AssetType.governedCustom:
      return Icons.precision_manufacturing_outlined;
  }
}

Color _categoryColor(AbnormalityCategory category) {
  switch (category) {
    case AbnormalityCategory.process:
      return BafColors.planned;
    case AbnormalityCategory.equipment:
      return BafColors.maintenance;
    case AbnormalityCategory.resultQuality:
      return BafColors.charges;
    case AbnormalityCategory.reannealing:
      return BafColors.audit;
    case AbnormalityCategory.other:
      return BafColors.admin;
  }
}

Color _severityColor(AbnormalitySeverity severity) {
  switch (severity) {
    case AbnormalitySeverity.low:
      return BafColors.success;
    case AbnormalitySeverity.medium:
      return BafColors.warning;
    case AbnormalitySeverity.high:
      return BafColors.maintenance;
    case AbnormalitySeverity.critical:
      return BafColors.danger;
  }
}

Color _raStatusColor(ReannealingStatus status) {
  switch (status) {
    case ReannealingStatus.notApplicable:
      return BafColors.textSecondary;
    case ReannealingStatus.pendingDecision:
      return BafColors.warning;
    case ReannealingStatus.required:
      return BafColors.audit;
    case ReannealingStatus.notRequired:
      return BafColors.admin;
    case ReannealingStatus.completed:
      return BafColors.success;
  }
}

String _auditReasonLabel(AuditReason reason) {
  final raw = reason.name;

  final words = raw
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'));

  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
