part of 'directives_screen.dart';

extension _BurnerDirectiveRecovery on _DirectiveCardState {
  Future<bool> _checkSavedBurnerDirective(
    OperationalDirective directive,
    AppUser origin, {
    required bool onlySaved,
  }) async {
    if (_isClosing) return true;
    final container = ProviderScope.containerOf(context, listen: false);
    AppUser currentActor() {
      final value = container.read(currentAppUserProvider);
      final actor = value.isLoading || value.hasError
          ? null
          : value.valueOrNull;
      if (actor == null ||
          actor.uid != origin.uid ||
          !actor.isApproved ||
          !actor.canRecordBurnerConditionRound) {
        throw const BurnerConditionRoundException(
          'Return to the approved account that saved this compliance.',
          code: 'permission-denied',
        );
      }
      return actor;
    }

    _setBurnerClosing(true);
    try {
      currentActor();
      final service = container.read(burnerConditionRoundServiceProvider);
      final rows = await service.pending();
      currentActor();
      if (!mounted) return true;
      if (rows.any((row) => row.isLegacy)) {
        _showDirectiveSnack(
          'Older Burner/UV retry details need support review. Their original bytes are preserved; a new closure cannot safely replace them.',
          BafColors.warning,
        );
        return true;
      }
      final matches = rows.where((row) {
        final request = row.envelope['request'];
        return request is Map &&
            request['operation'] == burnerDirectiveComplianceOperation &&
            request['directiveId'] == directive.firestoreId;
      }).toList();
      if (matches.isEmpty) {
        if (onlySaved) {
          _showDirectiveSnack(
            'No saved compliance needs confirmation for this directive.',
            BafColors.info,
          );
        }
        return onlySaved;
      }
      if (matches.length != 1) {
        throw const BurnerConditionRoundException(
          'Multiple saved closures need support review.',
          code: 'data-loss',
        );
      }
      final saved = matches.single;
      final request = saved.envelope['request'] as Map;
      final metadata = durableSubmissionJsonObject(
        saved.displayMetadataJson ?? '{}',
      );
      final wasUnacknowledged = metadata['wasUnacknowledged'];
      if (wasUnacknowledged is! bool ||
          request['expectedDirectiveVersion'] is! int ||
          request['dispositions'] is! List ||
          saved.actorUid != origin.uid) {
        throw const BurnerConditionRoundException(
          'Saved closure evidence is incomplete and needs review.',
          code: 'data-loss',
        );
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            final authority = ref.watch(currentAppUserProvider);
            final available =
                !authority.isLoading &&
                !authority.hasError &&
                authority.valueOrNull?.uid == origin.uid &&
                authority.valueOrNull?.canRecordBurnerConditionRound == true;
            return AlertDialog(
              title: const Text('Saved Burner/UV compliance'),
              content: SingleChildScrollView(
                child: available
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            saved.state.isAccepted
                                ? 'The server recorded this closure. Confirm its saved result on this device.'
                                : 'The earlier outcome is uncertain. Check these original entries with the same request.',
                          ),
                          const SizedBox(height: BafSpacing.md),
                          for (final item in request['dispositions'] as List)
                            Text(
                              'Burner ${item['position']}: ${_burnerDispositionLabel(item['disposition'])}',
                            ),
                          if (request['closureRemarks'] != null)
                            Text('Remarks: ${request['closureRemarks']}'),
                        ],
                      )
                    : const Text(
                        'Return to the original approved account to review these saved entries.',
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep saved'),
                ),
                FilledButton(
                  onPressed: available
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Check saved request'),
                ),
              ],
            );
          },
        ),
      );
      if (approved != true) return true;
      final actor = currentActor();
      final result = await service.resumeDirective(saved);
      currentActor();
      await container
          .read(directiveRepositoryProvider)
          .adoptServerDirectiveClosure(
            firestoreId: request['directiveId'] as String,
            expectedBeforeVersion: request['expectedDirectiveVersion'] as int,
            committedVersion: result.closedDirectiveVersion,
            actor: actor,
            closedAt: result.committedAt,
            wasUnacknowledged: wasUnacknowledged,
            remarks: request['closureRemarks'] as String?,
          );
      currentActor();
      final finalized = await service.finalizeDirectiveCompliance(
        result: result,
        actorUid: origin.uid,
      );
      currentActor();
      if (mounted) {
        _showDirectiveSnack(
          finalized.retryIdentityCleanupPending
              ? 'The closure is recorded; saved device confirmation still needs attention.'
              : 'Original Burner/UV compliance confirmed on this device.',
          BafColors.sync,
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        _showDirectiveSnack(
          'Saved Burner/UV evidence is retained: $error',
          BafColors.warning,
        );
      }
      return true;
    } finally {
      if (mounted) _setBurnerClosing(false);
    }
  }
}

String _burnerDispositionLabel(Object? value) {
  for (final disposition in BurnerDirectiveComplianceDisposition.values) {
    if (disposition.name == value) return disposition.label;
  }
  return 'Needs evidence review';
}
