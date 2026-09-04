part of 'maintenance_form.dart';

extension _MaintenanceFormDraft on _MaintenanceFormState {
  bool get _hasDraft =>
      _qualityAssessment != null ||
      _issueAssetClassId != null ||
      _assetInstanceId != null ||
      _isFurnaceStuckup ||
      _isBurnerLockout ||
      _isCritical ||
      _selectedFrequentIssue != null ||
      _frequentIssueUnlisted ||
      _maintenanceType != MaintenanceType.breakdown ||
      _plantConditionEffect != MaintenanceIssuePlantConditionEffect.unfit ||
      _routedTo != RoutedTo.mechanical ||
      _routedLanes.length != 1 ||
      _startTime != _initialStartTime ||
      _burnerRelightAttemptsController.text != '0' ||
      [
        _descController,
        _chargeNoController,
        _tagController,
        _componentController,
        _otherDepartmentController,
        _qualityReasonController,
        _burnerHmiAlarmController,
      ].any((controller) => controller.text.isNotEmpty);

  Future<void> _requestExit() async {
    if (!mounted || _isSubmitting || _isExitConfirmationOpen) return;
    final focus = FocusManager.instance.primaryFocus;
    final editing =
        focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (editing || MediaQuery.viewInsetsOf(context).bottom > 0) {
      focus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      return;
    }
    if (!_hasDraft) {
      Navigator.of(context).pop();
      return;
    }
    _isExitConfirmationOpen = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Discard this issue?'),
              content: const Text('Your entries have not been submitted.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Keep editing'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: BafColors.danger,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Discard issue'),
                ),
              ],
            ),
      );
      if (!mounted || discard != true) return;
      Navigator.of(context).pop();
    } finally {
      _isExitConfirmationOpen = false;
    }
  }

  String? _qualityClassificationError() {
    if (_qualityAssessment != IssueQualityAssessment.suspected) return null;
    final types = ref.read(activeAbnormalityTypesProvider);
    if (types.hasError || types.isLoading) {
      return 'Quality classifications are being verified. Your selection is kept; retry when they are available.';
    }
    if (_qualityAbnormalityTypeId == null) {
      return 'Select the governed abnormality type';
    }
    final applicable = _qualityTypesForCurrentAsset(types.value ?? []);
    if (!applicable.any(
      (type) => type.firestoreId == _qualityAbnormalityTypeId,
    )) {
      return 'Choose an active abnormality classification for this asset';
    }
    return null;
  }

  String? _qualityReasonError() {
    if (_qualityAssessment != IssueQualityAssessment.suspected) return null;
    final reason = _qualityReasonController.text.trim();
    if (reason.isEmpty) return 'Describe the suspected effect';
    if (reason.length > 1000) {
      return 'Keep the quality note within 1000 characters';
    }
    return null;
  }

  bool _validateQualityDraft() {
    // Off-screen FormFields can be unmounted; validate the retained draft too.
    final error =
        _qualityAssessment == null
            ? 'Assess whether coil quality may be affected.'
            : _qualityClassificationError() ?? _qualityReasonError();
    if (error == null) return true;
    _showMessage(error, BafColors.warning);
    if (_formScrollController.hasClients) {
      unawaited(
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
    return false;
  }
}
