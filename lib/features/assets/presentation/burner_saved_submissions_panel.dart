import 'package:flutter/material.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/theme/baf_design_system.dart';
import '../data/burner_condition_round.dart';
import '../services/burner_condition_round_service.dart';

/// Displays original saved entries independently of the current editing form.
class BurnerSavedSubmissionsPanel extends StatefulWidget {
  const BurnerSavedSubmissionsPanel({
    super.key,
    required this.service,
    required this.actorUid,
    required this.refreshKey,
    required this.onLoaded,
    required this.onCheck,
  });
  final BurnerConditionRoundService service;
  final String actorUid;
  final int refreshKey;
  final void Function(List<DurableSubmission>? rows) onLoaded;
  final Future<void> Function(DurableSubmission row) onCheck;

  @override
  State<BurnerSavedSubmissionsPanel> createState() =>
      _BurnerSavedSubmissionsPanelState();
}

class _BurnerSavedSubmissionsPanelState
    extends State<BurnerSavedSubmissionsPanel> {
  List<DurableSubmission>? _rows;
  String? _error;
  String? _checking;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BurnerSavedSubmissionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actorUid != widget.actorUid ||
        oldWidget.refreshKey != widget.refreshKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _rows = null;
    _error = null;
    try {
      final rows = await widget.service.pending();
      if (!mounted || generation != _generation) return;
      setState(() => _rows = rows);
      widget.onLoaded(rows);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = 'Saved Burner/UV entries could not be checked: $error',
      );
      widget.onLoaded(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: BafSpacing.md),
        child: Text(_error!, style: const TextStyle(color: BafColors.danger)),
      );
    }
    final rows = _rows;
    if (rows == null) {
      return const Padding(
        padding: EdgeInsets.all(BafSpacing.md),
        child: Text('Checking saved Burner/UV entries...'),
      );
    }
    return Column(children: [for (final row in rows) _saved(row)]);
  }

  Widget _saved(DurableSubmission row) {
    if (row.isLegacy) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(BafSpacing.md),
          child: Text(
            'Older Burner/UV retry details need support review. The old app retained only a request reference and checksum, so its original entries cannot be safely reconstructed. The original evidence is preserved.',
          ),
        ),
      );
    }
    final request = row.envelope['request'] as Map;
    final isRound = request['operation'] == burnerConditionRoundOperation;
    final metadata = row.displayMetadataJson == null
        ? null
        : durableSubmissionJsonObject(row.displayMetadataJson!);
    final title =
        '${isRound ? 'Saved burner round' : 'Saved directive compliance'} — ${metadata?['furnaceName'] ?? 'Furnace'}';
    final observations = request['observations'] as List? ?? const [];
    final uv = request['uvObservations'] as List? ?? const [];
    final dispositions = request['dispositions'] as List? ?? const [];
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title),
        subtitle: Text(
          row.state.isAccepted
              ? 'Recorded; device confirmation is pending.'
              : 'Outcome is not confirmed. These original entries are retained.',
        ),
        childrenPadding: const EdgeInsets.all(BafSpacing.md),
        children: [
          if (isRound) ...[
            for (final item in observations)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Burner ${item['position']}: ${_flameLabel(item['flameObservation'])}; red hot: ${item['redHotObserved'] == true ? 'yes' : 'no'}; signal: ${item['microampReading'] ?? 'not recorded'}; ${item['remarks'] ?? ''}',
                ),
              ),
            for (final item in uv)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'UV ${item['position']}: ${_uvLabel(item['condition'])}; ${item['remarks'] ?? ''}',
                ),
              ),
            if (request.containsKey('draftSealRedHotObserved'))
              Text(
                'Draft seal red hot: ${request['draftSealRedHotObserved'] == true ? 'yes' : 'no'}; hot air: ${request['hotAirAtDraftSealObserved'] == true ? 'yes' : 'no'}',
              ),
            if (request['roundNote'] != null)
              Text('Note: ${request['roundNote']}'),
          ] else ...[
            for (final item in dispositions)
              Text(
                'Burner ${item['position']}: ${_dispositionLabel(item['disposition'])}',
              ),
            if (request['closureRemarks'] != null)
              Text('Remarks: ${request['closureRemarks']}'),
            const Text(
              'Open this directive to check its original saved compliance and confirm the device copy.',
            ),
          ],
          if (isRound)
            TextButton.icon(
              onPressed: _checking == null
                  ? () async {
                      setState(() => _checking = row.submissionId);
                      try {
                        await widget.onCheck(row);
                      } finally {
                        if (mounted) {
                          setState(() => _checking = null);
                          await _load();
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.refresh),
              label: Text(
                _checking == row.submissionId
                    ? 'Checking...'
                    : 'Check saved round',
              ),
            ),
        ],
      ),
    );
  }
}

String _flameLabel(Object? raw) {
  for (final value in BurnerRoundFlameObservation.values) {
    if (value.name == raw) return value.label;
  }
  return 'Needs review';
}

String _uvLabel(Object? raw) {
  for (final value in BurnerUvCondition.values) {
    if (value.name == raw) return value.label;
  }
  return 'Needs review';
}

String _dispositionLabel(Object? raw) {
  for (final value in BurnerDirectiveComplianceDisposition.values) {
    if (value.name == raw) return value.label;
  }
  return 'Needs review';
}
