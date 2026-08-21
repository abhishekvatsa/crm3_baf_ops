// FILE: lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../data/template_governance_model.dart';
import '../data/maintenance_intelligence.dart';
import '../domain/governed_planned_work_asset_selection.dart';
import '../domain/template_publication_readiness.dart';
import '../domain/template_version_assignment_builder.dart';
import '../providers/job_module_provider.dart';
import '../providers/planned_maintenance_provider.dart';
import '../providers/template_governance_provider.dart';
import '../services/published_template_assignment_idempotency_store.dart';
import '../services/published_template_assignment_server_service.dart';
import 'governed_planned_work_asset_selector.dart';
import 'template_publisher_screen.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/validation/charge_number.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../data/job_module_model.dart';

class PublishedTemplateAssignmentScreen extends ConsumerStatefulWidget {
  const PublishedTemplateAssignmentScreen({super.key, this.sourcePlan});

  final MaintenancePlan? sourcePlan;

  @override
  ConsumerState<PublishedTemplateAssignmentScreen> createState() =>
      _PublishedTemplateAssignmentScreenState();
}

class _PublishedTemplateAssignmentScreenState
    extends ConsumerState<PublishedTemplateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chargeNoController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _selectedPackageId;
  String? _selectedVersionId;
  String? _selectedAssetInstanceId;
  bool _isSubmitting = false;
  TemplatePublicationReadinessDecision? _displayedReadiness;
  bool _displayedPreviewValid = false;
  bool _displayedAssetSelectionValid = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.sourcePlan;
    if (plan != null) {
      _selectedAssetInstanceId = plan.assetInstanceId;
      _remarksController.text = plan.planningNotes ?? '';
    }
  }

  @override
  void dispose() {
    _chargeNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);

    return appUserAsync.when(
      loading:
          () => const Scaffold(
            backgroundColor: BafColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      error: (e, _) => _AssignmentErrorScaffold(message: 'User error: $e'),
      data: (actor) {
        if (actor == null || !actor.canAssignJobExecution) {
          return const _AssignmentAccessDeniedScaffold();
        }

        final packagesAsync = ref.watch(templatePackagesProvider);
        return packagesAsync.when(
          loading:
              () => const Scaffold(
                backgroundColor: BafColors.background,
                body: Center(child: CircularProgressIndicator()),
              ),
          error:
              (e, _) => _AssignmentErrorScaffold(
                message: 'Template package error: $e',
              ),
          data: (packages) => _buildWithPackages(actor, packages),
        );
      },
    );
  }

  Widget _buildWithPackages(AppUser actor, List<TemplatePackage> packages) {
    // Disable submission by default for every rebuild. The resolved version
    // branch below enables it only after the current package/version preview
    // and publication readiness have both been evaluated.
    _displayedReadiness = null;
    _displayedPreviewValid = false;
    _displayedAssetSelectionValid = false;

    final assignablePackages =
        packages
            .where(
              (package) =>
                  !package.isDeleted &&
                  package.lifecycleStatus ==
                      TemplatePackageLifecycleStatus.active &&
                  _clean(package.firestoreId) != null,
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    _hydrateInitialPackage(assignablePackages);

    final selectedPackage = _findPackage(
      assignablePackages,
      _selectedPackageId,
    );
    final versionsAsync =
        selectedPackage == null
            ? null
            : ref.watch(packageVersionsProvider(selectedPackage.firestoreId!));

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Assign Published Catalogue'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
        actions: [
          if (actor.canManageTemplateGovernance)
            IconButton(
              tooltip: 'Open Template Publisher',
              onPressed: _openTemplatePublisher,
              icon: const Icon(Icons.publish_rounded),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child:
            versionsAsync == null
                ? _buildNoPackagesState(actor, assignablePackages)
                : versionsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _InlineError(message: 'Version error: $e'),
                  data: (versions) {
                    final activeVersion = activeTemplateVersionForPackage(
                      package: selectedPackage!,
                      versions: versions,
                    );
                    final activeVersions = <TemplateVersion>[
                      if (activeVersion != null) activeVersion,
                    ];
                    _hydrateInitialVersion(selectedPackage, activeVersions);
                    final selectedVersion = _findVersion(
                      activeVersions,
                      _selectedVersionId,
                    );
                    final readinessQuery =
                        selectedVersion == null
                            ? null
                            : TemplatePublicationReadinessQuery(
                              packageFirestoreId: selectedPackage.firestoreId!,
                              versionFirestoreId: selectedVersion.firestoreId!,
                            );
                    final readinessAsync =
                        readinessQuery == null
                            ? null
                            : ref.watch(
                              templatePublicationReadinessProvider(
                                readinessQuery,
                              ),
                            );
                    final readiness = readinessAsync?.asData?.value;
                    _displayedReadiness = readiness;
                    TemplateVersionAssignmentPreview? preview;
                    TemplateVersionAssignmentException? previewError;
                    if (selectedVersion != null) {
                      try {
                        preview = previewTemplateVersionAssignment(
                          package: selectedPackage,
                          version: selectedVersion,
                        );
                      } on TemplateVersionAssignmentException catch (error) {
                        previewError = error;
                      }
                    }

                    _displayedPreviewValid =
                        preview != null && previewError == null;
                    final assetClassesAsync = ref.watch(assetClassesProvider);
                    final assetClasses = assetClassesAsync.asData?.value;
                    final assetRoute =
                        preview == null || assetClasses == null
                            ? null
                            : resolveGovernedPlannedWorkAssetRoute(
                              assetType: preview.assetType,
                              templateReference:
                                  preview.assetHierarchyReference,
                              allClasses: assetClasses,
                            );
                    final physicalClassId = assetRoute?.physicalAssetClass?.id;
                    final assetInstancesAsync =
                        physicalClassId == null
                            ? null
                            : ref.watch(
                              assetInstancesProvider(physicalClassId),
                            );
                    final innerCoverAssignmentsAsync =
                        assetRoute?.innerCoverByBase == true
                            ? ref.watch(innerCoverAssignmentsProvider)
                            : null;
                    final linkedInnerCoversByBase = {
                      for (final assignment
                          in innerCoverAssignmentsAsync?.asData?.value ??
                              const <BaseInnerCoverAssignment>[])
                        assignment.baseAssetInstanceId: assignment,
                    };
                    final routeEligibleAssets =
                        assetRoute == null ||
                                assetInstancesAsync?.asData == null
                            ? const <AssetInstanceRecord>[]
                            : eligiblePlannedWorkAssets(
                              route: assetRoute,
                              assets: assetInstancesAsync!.requireValue,
                            );
                    final eligibleAssets =
                        assetRoute?.innerCoverByBase == true
                            ? routeEligibleAssets
                                .where(
                                  (asset) => linkedInnerCoversByBase
                                      .containsKey(asset.id),
                                )
                                .toList(growable: false)
                            : routeEligibleAssets;
                    final selectedAsset =
                        eligibleAssets
                            .where(
                              (item) => item.id == _selectedAssetInstanceId,
                            )
                            .firstOrNull;
                    _displayedAssetSelectionValid = selectedAsset != null;
                    if (preview != null &&
                        assetRoute?.fixedAssetInstanceId != null &&
                        selectedAsset == null &&
                        eligibleAssets.length == 1) {
                      _displayedAssetSelectionValid = true;
                    }

                    return ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        BafSpacing.lg,
                        BafSpacing.md,
                        BafSpacing.lg,
                        120,
                      ),
                      children: [
                        if (widget.sourcePlan != null) ...[
                          _SourcePlanCallout(plan: widget.sourcePlan!),
                          const SizedBox(height: BafSpacing.lg),
                        ],
                        _AssignmentHeaderCard(
                          package: selectedPackage,
                          version: selectedVersion,
                          preview: preview,
                        ),
                        if (previewError != null) ...[
                          const SizedBox(height: BafSpacing.md),
                          _PublisherPromptCallout(
                            message:
                                'This published version cannot be assigned because its governance snapshot is invalid: ${previewError.message}',
                            onOpenPublisher:
                                actor.canManageTemplateGovernance
                                    ? _openTemplatePublisher
                                    : null,
                          ),
                        ],
                        const SizedBox(height: BafSpacing.lg),
                        _SectionCard(
                          title: 'Governed catalogue source',
                          subtitle:
                              'Choose an active package. Its remotely confirmed active version is the only assignable source.',
                          icon: Icons.verified_rounded,
                          children: [
                            DropdownButtonFormField<String>(
                              key: const ValueKey('published-package-selector'),
                              initialValue: _selectedPackageId,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                'Template package',
                                icon: Icons.inventory_2_rounded,
                              ),
                              items:
                                  assignablePackages
                                      .map(
                                        (package) => DropdownMenuItem<String>(
                                          value: package.firestoreId,
                                          child: Text(
                                            '${package.packageCode} — ${package.title}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  _isSubmitting
                                      ? null
                                      : (value) => setState(() {
                                        _selectedPackageId = value;
                                        _selectedVersionId = null;
                                        _selectedAssetInstanceId =
                                            widget.sourcePlan?.assetInstanceId;
                                        _displayedReadiness = null;
                                        _displayedPreviewValid = false;
                                        _displayedAssetSelectionValid = false;
                                      }),
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Select a governed package'
                                          : null,
                            ),
                            const SizedBox(height: BafSpacing.md),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'published-version-${_selectedPackageId ?? ''}',
                              ),
                              initialValue: _selectedVersionId,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                'Published version',
                                icon: Icons.new_releases_rounded,
                              ),
                              items:
                                  activeVersions
                                      .map(
                                        (version) => DropdownMenuItem<String>(
                                          value: version.firestoreId,
                                          child: Text(
                                            _versionLabel(version),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: null,
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Select a published version'
                                          : null,
                            ),
                            if (activeVersions.isEmpty) ...[
                              const SizedBox(height: BafSpacing.sm),
                              _PublisherPromptCallout(
                                message:
                                    'This package has no active published TemplateVersion. Publish a valid version before assigning governed jobs.',
                                onOpenPublisher:
                                    actor.canManageTemplateGovernance
                                        ? _openTemplatePublisher
                                        : null,
                              ),
                            ],
                            if (selectedVersion != null) ...[
                              const SizedBox(height: BafSpacing.sm),
                              if (readinessAsync?.isLoading == true)
                                const _GovernanceReadinessCallout(
                                  message:
                                      'Checking package, active version, content hash, and publication audit confirmation…',
                                  isReady: false,
                                )
                              else if (readinessAsync?.hasError == true)
                                _GovernanceReadinessCallout(
                                  message:
                                      'Publication readiness could not be checked: ${readinessAsync!.error}',
                                  isReady: false,
                                  onRecheck:
                                      readinessQuery == null
                                          ? null
                                          : () => ref.invalidate(
                                            templatePublicationReadinessProvider(
                                              readinessQuery,
                                            ),
                                          ),
                                )
                              else if (readiness != null)
                                _GovernanceReadinessCallout(
                                  message: readiness.operatorMessage,
                                  isReady: readiness.isReady,
                                  onRecheck:
                                      readiness.isReady ||
                                              readinessQuery == null
                                          ? null
                                          : () => ref.invalidate(
                                            templatePublicationReadinessProvider(
                                              readinessQuery,
                                            ),
                                          ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: BafSpacing.lg),
                        _SectionCard(
                          title: 'Job details',
                          subtitle:
                              'Choose the exact asset and add assignment context.',
                          icon: Icons.assignment_turned_in_rounded,
                          children: [
                            GovernedPlannedWorkAssetSelector(
                              assetType: preview?.assetType,
                              classesValue: assetClassesAsync,
                              route: assetRoute,
                              assetsValue: assetInstancesAsync,
                              innerCoverAssignmentsValue:
                                  innerCoverAssignmentsAsync,
                              linkedInnerCoversByBase: linkedInnerCoversByBase,
                              eligibleAssets: eligibleAssets,
                              selectedAssetInstanceId: _selectedAssetInstanceId,
                              onAssetChanged:
                                  _isSubmitting || widget.sourcePlan != null
                                      ? null
                                      : (asset) => setState(
                                        () =>
                                            _selectedAssetInstanceId =
                                                asset?.id,
                                      ),
                            ),
                            const SizedBox(height: BafSpacing.md),
                            TextFormField(
                              controller: _chargeNoController,
                              keyboardType: TextInputType.number,
                              inputFormatters: chargeNumberInputFormatters,
                              decoration: _inputDecoration(
                                'Active charge number',
                                hint: 'Optional, exactly 5 digits',
                              ),
                              validator: validateChargeNumberText,
                            ),
                            const SizedBox(height: BafSpacing.md),
                            TextFormField(
                              controller: _remarksController,
                              maxLines: 3,
                              decoration: _inputDecoration(
                                'Instructions / remarks',
                                hint: 'Optional notes for attending teams',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.lg),
                        _ModulePreviewSection(preview: preview),
                      ],
                    );
                  },
                ),
      ),
      bottomNavigationBar: _AssignmentBottomBar(
        isSubmitting: _isSubmitting,
        onSubmit:
            _isSubmitting ||
                    _displayedReadiness?.isReady != true ||
                    !_displayedPreviewValid ||
                    !_displayedAssetSelectionValid
                ? null
                : () => _submit(actor),
      ),
    );
  }

  Widget _buildNoPackagesState(AppUser actor, List<TemplatePackage> packages) {
    if (packages.isNotEmpty) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: _EmptyAssignmentState(
          onOpenPublisher:
              actor.canManageTemplateGovernance ? _openTemplatePublisher : null,
        ),
      ),
    );
  }

  Future<void> _openTemplatePublisher() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TemplatePublisherScreen()));
  }

  void _hydrateInitialPackage(List<TemplatePackage> packages) {
    if (packages.isEmpty) {
      _selectedPackageId = null;
      return;
    }
    if (_selectedPackageId != null &&
        packages.any((package) => package.firestoreId == _selectedPackageId)) {
      return;
    }
    _selectedPackageId = packages.first.firestoreId;
  }

  void _hydrateInitialVersion(
    TemplatePackage package,
    List<TemplateVersion> versions,
  ) {
    if (_selectedVersionId != null &&
        versions.any((version) => version.firestoreId == _selectedVersionId)) {
      return;
    }
    if (versions.isEmpty) {
      _selectedVersionId = null;
      return;
    }
    final activeId = _clean(package.activeVersionFirestoreId);
    final active = activeId == null ? null : _findVersion(versions, activeId);
    _selectedVersionId = active?.firestoreId;
  }

  TemplatePackage? _findPackage(List<TemplatePackage> packages, String? id) {
    if (id == null) return null;
    for (final package in packages) {
      if (package.firestoreId == id) return package;
    }
    return null;
  }

  TemplateVersion? _findVersion(List<TemplateVersion> versions, String? id) {
    if (id == null) return null;
    for (final version in versions) {
      if (version.firestoreId == id) return version;
    }
    return null;
  }

  AssetInstanceRecord? _selectedGovernedAsset(
    TemplateVersionAssignmentPreview preview,
  ) {
    final classes = ref.read(assetClassesProvider).asData?.value;
    if (classes == null) return null;
    final route = resolveGovernedPlannedWorkAssetRoute(
      assetType: preview.assetType,
      templateReference: preview.assetHierarchyReference,
      allClasses: classes,
    );
    final physicalClassId = route.physicalAssetClass?.id;
    if (!route.isAvailable || physicalClassId == null) return null;
    final assets =
        ref.read(assetInstancesProvider(physicalClassId)).asData?.value;
    if (assets == null) return null;
    final routeEligible = eligiblePlannedWorkAssets(
      route: route,
      assets: assets,
    );
    final linkedBaseIds =
        route.innerCoverByBase
            ? ref
                .read(innerCoverAssignmentsProvider)
                .asData
                ?.value
                .map((assignment) => assignment.baseAssetInstanceId)
                .toSet()
            : null;
    if (route.innerCoverByBase && linkedBaseIds == null) return null;
    final eligible =
        linkedBaseIds == null
            ? routeEligible
            : routeEligible
                .where((asset) => linkedBaseIds.contains(asset.id))
                .toList(growable: false);
    final selected =
        eligible
            .where((item) => item.id == _selectedAssetInstanceId)
            .firstOrNull;
    if (selected != null) return selected;
    if (route.fixedAssetInstanceId != null && eligible.length == 1) {
      return eligible.single;
    }
    return null;
  }

  Future<void> _submit(AppUser actor) async {
    if (!_formKey.currentState!.validate()) return;
    if (!actor.canAssignJobExecution) {
      _showSnack('Not authorized to assign planned jobs.', BafColors.danger);
      return;
    }

    final package = await _selectedPackage();
    final version = await _selectedVersion();
    if (!mounted) return;

    if (package == null || version == null) {
      _showSnack(
        'Select the active published catalogue version first.',
        BafColors.danger,
      );
      return;
    }

    final repository = ref.read(templateGovernanceRepositoryProvider);
    final audits = await repository.getAuditsForVersion(version.firestoreId!);
    final readiness = evaluateTemplatePublicationReadiness(
      package: package,
      version: version,
      audits: audits,
    );
    if (!readiness.isReady) {
      if (mounted) {
        ref.invalidate(
          templatePublicationReadinessProvider(
            TemplatePublicationReadinessQuery(
              packageFirestoreId: package.firestoreId!,
              versionFirestoreId: version.firestoreId!,
            ),
          ),
        );
        _showSnack(readiness.operatorMessage, BafColors.warning);
      }
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    String? requestIdUsed;

    try {
      // Re-parse the frozen snapshots locally before the network call. The
      // server remains authoritative, but this gives the operator immediate
      // feedback for malformed local governance payloads.
      final preview = previewTemplateVersionAssignment(
        package: package,
        version: version,
      );
      final contentHash = version.contentHash!.trim();
      final selectedAsset = _selectedGovernedAsset(preview);
      if (selectedAsset == null) {
        throw const PublishedTemplateAssignmentServerException(
          code: 'invalid-asset-selection',
          message:
              'Choose an active physical asset from the governed register.',
        );
      }
      final assetNumber = selectedAsset.assetNumber;
      final chargeNo = _parseOptionalInt(_chargeNoController.text);
      final remarks = _clean(_remarksController.text);

      final fingerprintProbe = PublishedTemplateAssignmentRequest(
        requestId: '',
        packageFirestoreId: package.firestoreId!,
        versionFirestoreId: version.firestoreId!,
        expectedVersionNumber: version.versionNumber,
        expectedContentHash: contentHash,
        assetType: preview.assetType,
        assetNumber: assetNumber,
        assetClassId: selectedAsset.assetClassId,
        assetInstanceId: selectedAsset.id,
        chargeNoAtEvent: chargeNo,
        remarks: remarks,
        sourcePlanId: widget.sourcePlan?.id,
        sourcePlanExpectedVersion: widget.sourcePlan?.version,
      );
      final pendingIdentity = await ref
          .read(publishedTemplateAssignmentIdempotencyStoreProvider)
          .resolve(
            actorUid: actor.uid,
            payloadFingerprint: fingerprintProbe.payloadFingerprint,
          );

      requestIdUsed = pendingIdentity.requestId;
      final request = PublishedTemplateAssignmentRequest(
        requestId: pendingIdentity.requestId,
        packageFirestoreId: package.firestoreId!,
        versionFirestoreId: version.firestoreId!,
        expectedVersionNumber: version.versionNumber,
        expectedContentHash: contentHash,
        assetType: preview.assetType,
        assetNumber: assetNumber,
        assetClassId: selectedAsset.assetClassId,
        assetInstanceId: selectedAsset.id,
        chargeNoAtEvent: chargeNo,
        remarks: remarks,
        sourcePlanId: widget.sourcePlan?.id,
        sourcePlanExpectedVersion: widget.sourcePlan?.version,
      );

      final result = await ref
          .read(publishedTemplateAssignmentServerServiceProvider)
          .assign(request: request);

      Object? localPersistenceError;
      if (!kIsWeb) {
        try {
          await _persistCanonicalServerAssignment(result);
        } catch (error) {
          localPersistenceError = error;
        }
      }

      Object? idempotencyClearError;
      try {
        await ref
            .read(publishedTemplateAssignmentIdempotencyStoreProvider)
            .clearIfMatches(actorUid: actor.uid, requestId: request.requestId);
      } catch (error) {
        idempotencyClearError = error;
      }

      unawaited(
        ref
            .read(syncCoordinatorProvider)
            .runFullSync(
              reason: 'server_governed_template_assignment_confirmed',
              force: true,
            ),
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      final replayText = result.idempotentReplay ? ' (safe retry replay)' : '';
      final localWarning =
          localPersistenceError == null
              ? ''
              : ' The server assignment succeeded, but local insertion is pending pull reconciliation.';
      final retryIdentityWarning =
          idempotencyClearError == null
              ? ''
              : ' The completed request identity could not be cleared locally; do not repeat the same assignment without refreshing.';
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Assigned ${result.execution.templateName ?? preview.templateName} '
            'with ${result.modules.length} module(s)$replayText.$localWarning$retryIdentityWarning',
          ),
          backgroundColor:
              localPersistenceError == null && idempotencyClearError == null
                  ? BafColors.sync
                  : BafColors.warning,
        ),
      );
    } on TemplateVersionAssignmentException catch (error) {
      if (!mounted) return;
      _showSnack(
        'Cannot assign published catalogue: ${error.message}',
        BafColors.danger,
      );
    } on PublishedTemplateAssignmentServerException catch (error) {
      if (!error.isRetryable && requestIdUsed != null) {
        try {
          await ref
              .read(publishedTemplateAssignmentIdempotencyStoreProvider)
              .clearIfMatches(actorUid: actor.uid, requestId: requestIdUsed);
        } catch (_) {
          // A non-retryable server decision remains authoritative even if the
          // local retry marker cannot be removed. A changed form fingerprint
          // will replace the marker on the next attempt.
        }
      }
      if (!mounted) return;
      _showSnack(
        error.operatorMessage,
        error.isRetryable ? BafColors.warning : BafColors.danger,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'Failed to assign published catalogue: $error',
        BafColors.danger,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _persistCanonicalServerAssignment(
    PublishedTemplateAssignmentServerResult result,
  ) async {
    final plannedRepository = ref.read(plannedRepositoryProvider);
    final moduleRepository = ref.read(jobModuleRepositoryProvider);
    final executionFirestoreId = result.execution.firestoreId!;

    final existingExecution = await plannedRepository.getExecutionByFirestoreId(
      executionFirestoreId,
    );
    if (existingExecution == null) {
      await plannedRepository.insertExecutionFromRemote(result.execution);
    } else {
      result.execution.id = existingExecution.id;
      await plannedRepository.updateExecutionFromRemote(result.execution);
    }

    final localExecution = await plannedRepository.getExecutionByFirestoreId(
      executionFirestoreId,
    );
    if (localExecution == null) {
      throw StateError(
        'The server-created JobExecution could not be reconciled into the local store.',
      );
    }

    final moduleFirestoreIds = result.modules
        .map((module) => module.firestoreId!)
        .toList(growable: false);
    final existingModules = await moduleRepository.getModulesByFirestoreIds(
      moduleFirestoreIds,
    );
    final existingModuleIds = <String, int>{
      for (final module in existingModules)
        if (module.firestoreId != null) module.firestoreId!: module.id,
    };

    for (final module in result.modules) {
      final firestoreId = module.firestoreId!;
      final existingLocalId = existingModuleIds[firestoreId];
      if (existingLocalId != null) {
        module.id = existingLocalId;
      }
      module
        ..jobExecutionFirestoreId = executionFirestoreId
        ..jobExecutionLocalId = null
        ..isSynced = true;
    }
    await moduleRepository.batchUpsertModules(result.modules);
  }

  Future<TemplatePackage?> _selectedPackage() async {
    final id = _selectedPackageId;
    if (id == null) return null;
    return ref
        .read(templateGovernanceRepositoryProvider)
        .getPackageByFirestoreId(id);
  }

  Future<TemplateVersion?> _selectedVersion() async {
    final id = _selectedVersionId;
    if (id == null) return null;
    return ref
        .read(templateGovernanceRepositoryProvider)
        .getVersionByFirestoreId(id);
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: BafColors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: 14,
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
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }
}

class _GovernanceReadinessCallout extends StatelessWidget {
  final String message;
  final bool isReady;
  final VoidCallback? onRecheck;

  const _GovernanceReadinessCallout({
    required this.message,
    required this.isReady,
    this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReady ? BafColors.success : BafColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.verified_rounded : Icons.policy_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isReady ? BafColors.success : BafColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          if (onRecheck != null) ...[
            const SizedBox(width: BafSpacing.sm),
            IconButton(
              tooltip: 'Recheck publication readiness',
              onPressed: onRecheck,
              icon: const Icon(Icons.refresh_rounded),
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentHeaderCard extends StatelessWidget {
  final TemplatePackage package;
  final TemplateVersion? version;
  final TemplateVersionAssignmentPreview? preview;

  const _AssignmentHeaderCard({
    required this.package,
    required this.version,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.18)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Governed assignment',
            style: TextStyle(
              color: BafColors.planned,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            preview?.templateName ?? package.title,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          if (_clean(package.description) != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              package.description!.trim(),
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              StatusBadge(
                label: package.packageCode,
                color: BafColors.assets,
                icon: Icons.inventory_2_rounded,
              ),
              if (version != null)
                StatusBadge(
                  label: 'v${version!.versionNumber}',
                  color: BafColors.sync,
                  icon: Icons.verified_rounded,
                ),
              StatusBadge(
                label: '${preview?.modules.length ?? 0} modules',
                color: BafColors.planned,
                icon: Icons.view_module_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModulePreviewSection extends StatelessWidget {
  final TemplateVersionAssignmentPreview? preview;

  const _ModulePreviewSection({required this.preview});

  @override
  Widget build(BuildContext context) {
    final modules = preview?.modules ?? const <TemplateVersionModulePreview>[];
    return _SectionCard(
      title: 'Frozen module preview',
      subtitle:
          'These module snapshots will be copied into the runtime job. Later catalogue edits will not mutate this assignment.',
      icon: Icons.account_tree_rounded,
      children: [
        if (modules.isEmpty)
          const _InlineEmpty(
            text: 'No published modules found in this version.',
          )
        else
          ...modules
              .take(12)
              .map((module) => _ModulePreviewTile(module: module)),
        if (modules.length > 12) ...[
          const SizedBox(height: BafSpacing.sm),
          Text(
            '+${modules.length - 12} more module(s)',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ModulePreviewTile extends StatelessWidget {
  final TemplateVersionModulePreview module;

  const _ModulePreviewTile({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _disciplineColor(
                module.discipline,
              ).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Icon(
              Icons.view_module_rounded,
              color: _disciplineColor(module.discipline),
              size: 22,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${module.discipline.name} · ${module.fieldCount} field(s)',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_clean(module.code) != null)
            StatusBadge(label: module.code!, color: BafColors.admin),
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
              Icon(icon, color: BafColors.planned, size: 22),
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
                    const SizedBox(height: 2),
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _AssignmentBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _AssignmentBottomBar({
    required this.isSubmitting,
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
        child: FilledButton.icon(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.planned,
            foregroundColor: Colors.white,
            disabledBackgroundColor: BafColors.border,
            disabledForegroundColor: BafColors.textSecondary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
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
                  : const Icon(Icons.verified_rounded),
          label: Text(
            isSubmitting ? 'Assigning...' : 'Assign Published Job',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _EmptyAssignmentState extends StatelessWidget {
  final VoidCallback? onOpenPublisher;

  const _EmptyAssignmentState({this.onOpenPublisher});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.xl),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: BafColors.admin,
            size: 48,
          ),
          const SizedBox(height: BafSpacing.md),
          const Text(
            'No active published catalogue packages found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          const Text(
            'No assignable TemplateVersion is active yet. Publish a valid catalogue version from Template Publisher first, then return here to assign governed jobs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary, height: 1.35),
          ),
          if (onOpenPublisher != null) ...[
            const SizedBox(height: BafSpacing.lg),
            FilledButton.icon(
              onPressed: onOpenPublisher,
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Open Template Publisher'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublisherPromptCallout extends StatelessWidget {
  final String message;
  final VoidCallback? onOpenPublisher;

  const _PublisherPromptCallout({required this.message, this.onOpenPublisher});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: BafColors.warning),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          );

          final action =
              onOpenPublisher == null
                  ? null
                  : TextButton.icon(
                    onPressed: onOpenPublisher,
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text('Open Publisher'),
                  );

          if (action == null) return text;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: BafSpacing.sm), action],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: BafSpacing.sm),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _SourcePlanCallout extends StatelessWidget {
  const _SourcePlanCallout({required this.plan});

  final MaintenancePlan plan;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BafSpacing.md),
    decoration: BoxDecoration(
      color: BafColors.planned.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.planned.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.event_available_rounded, color: BafColors.planned),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Release ready maintenance plan',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${plan.assetInstanceName} · ${plan.maintenanceClass.title}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${DateFormat('dd MMM, HH:mm').format(plan.targetWindowStart.toLocal())} – '
                '${DateFormat('dd MMM, HH:mm').format(plan.targetWindowEnd.toLocal())}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Assignment and plan release commit together. Select a published catalogue carrying this exact maintenance class.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: BafColors.textSecondary));
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Text(message, style: const TextStyle(color: BafColors.danger)),
      ),
    );
  }
}

class _AssignmentAccessDeniedScaffold extends StatelessWidget {
  const _AssignmentAccessDeniedScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BafColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(BafSpacing.xl),
          child: Text(
            'Only Admin/SI, supervisors and senior discipline users can assign planned jobs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _AssignmentErrorScaffold extends StatelessWidget {
  final String message;

  const _AssignmentErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xl),
          child: Text(message, style: const TextStyle(color: BafColors.danger)),
        ),
      ),
    );
  }
}

String _versionLabel(TemplateVersion version) {
  final label = _clean(version.versionLabel);
  final hash = _clean(version.contentHash);
  final suffix =
      hash == null
          ? ''
          : ' · ${hash.substring(0, hash.length < 8 ? hash.length : 8)}';
  return 'v${version.versionNumber}${label == null ? '' : ' — $label'}$suffix';
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

Color _disciplineColor(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return BafColors.planned;
    case JobModuleDiscipline.electrical:
      return const Color(0xFFF59E0B);
    case JobModuleDiscipline.instrumentation:
      return BafColors.audit;
    case JobModuleDiscipline.operations:
      return BafColors.sync;
    case JobModuleDiscipline.emd:
      return BafColors.admin;
    case JobModuleDiscipline.refractory:
      return BafColors.warning;
    case JobModuleDiscipline.others:
      return BafColors.directives;
    case JobModuleDiscipline.shiftInCharge:
      return BafColors.charges;
    case JobModuleDiscipline.safety:
      return BafColors.danger;
    case JobModuleDiscipline.admin:
    case JobModuleDiscipline.shared:
      return BafColors.admin;
  }
}
