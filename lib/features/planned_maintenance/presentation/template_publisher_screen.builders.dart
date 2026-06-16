part of 'template_publisher_screen.dart';

extension _TemplatePublisherBuilders on _TemplatePublisherScreenState {
  Widget _buildPublisher(
    BuildContext context,
    AppUser actor,
    List<TemplatePackage> packages,
  ) {
    _hydrateInitialPackage(packages);

    final validation = _buildValidation();
    final selectedPackageId = _selectedPackage?.firestoreId;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Template Authoring'),
        centerTitle: false,
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0.4,
        actions: [
          IconButton(
            tooltip: 'Open Module Composer',
            onPressed: () => _openModuleComposer(actor),
            icon: const Icon(Icons.architecture_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: BafSpacing.md),
            child: StatusBadge(
              label: 'Admin/SI',
              color: BafColors.admin,
              icon: Icons.verified_user_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          // Scaffold already reserves body-space above bottomNavigationBar.
          // Adding viewPadding.bottom here was double-counting the system inset.
          padding: const EdgeInsets.all(BafSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PublisherHeader(validation: validation),
                    const SizedBox(height: BafSpacing.lg),
                    _ComposerQuickStartSection(
                      validation: validation,
                      onOpenComposer: () => _openModuleComposer(actor),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _PackageSection(
                      packages: packages,
                      selectedPackageId: _selectedPackageId,
                      packageCodeController: _packageCodeController,
                      packageTitleController: _packageTitleController,
                      descriptionController: _packageDescriptionController,
                      assetTypeController: _assetTypeController,
                      assetScopeController: _assetScopeController,
                      onPackageChanged: (id) => _selectPackage(id, packages),
                    ),
                    if (selectedPackageId != null) ...[
                      const SizedBox(height: BafSpacing.lg),
                      _ExistingVersionsSection(
                        packageFirestoreId: selectedPackageId,
                        onResumeDraft:
                            (version) => _resumeDraft(version, packages),
                        onArchiveDraft:
                            (version) => _archivePublisherDraft(version, actor),
                        onRestoreDraft:
                            (version) => _restorePublisherDraft(version, actor),
                      ),
                    ],
                    const SizedBox(height: BafSpacing.lg),
                    _DisciplineSection(
                      selectedDisciplines: _selectedDisciplines,
                      options: _TemplatePublisherScreenState._disciplineOptions,
                      onToggle: _toggleDiscipline,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _VersionSection(
                      nextVersionNumber: _nextVersionNumber(),
                      versionLabelController: _versionLabelController,
                      releaseNotesController: _releaseNotesController,
                      changeSummaryController: _changeSummaryController,
                      minAppVersionController: _minAppVersionController,
                      publishReasonController: _publishReasonController,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _JsonPayloadSection(
                      jobTemplateJsonController: _jobTemplateJsonController,
                      moduleSnapshotsJsonController:
                          _moduleSnapshotsJsonController,
                      fieldDefinitionsJsonController:
                          _fieldDefinitionsJsonController,
                      checklistJsonController: _checklistJsonController,
                      onChanged: () => _setPublisherState(() {}),
                      onOpenComposer: () => _openModuleComposer(actor),
                      onPretty: _prettyFormat,
                      onPaste: _pasteFromClipboard,
                      onClear: _clearJson,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _ValidationSection(validation: validation),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _PublishBar(
        validation: validation,
        isPublishing: _isPublishing,
        onOpenComposer: () => _openModuleComposer(actor),
        onSaveDraft: () => _saveDraft(actor),
        onPublish: () => _publish(actor),
        onReset: _resetVersionPayloads,
      ),
    );
  }
}
