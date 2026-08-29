import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/baf_design_system.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/burner_condition_round.dart';
import '../../assets/domain/plant_asset_overview.dart';
import '../../critical_alarm/domain/critical_alarm_models.dart';
import '../../directives/data/operational_directive_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/data/compliance_request_record.dart';
import '../../operational_events/data/operational_event.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/data/maintenance_intelligence.dart';
import '../domain/operations_report_document.dart';
import '../domain/report_provenance.dart';
import '../models/operations_report.dart';

class OperationsReportPdfService {
  OperationsReportPdfService._();

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');
  static const PdfColor _graphite = PdfColor(0.078, 0.129, 0.157);
  static const PdfColor _teal = PdfColor(0.055, 0.478, 0.494);
  static const PdfColor _cobalt = PdfColor(0.196, 0.404, 0.694);
  static const PdfColor _ember = PdfColor(0.784, 0.298, 0.212);
  static const PdfColor _surface = PdfColor(0.949, 0.965, 0.969);
  static const PdfColor _border = PdfColor(0.831, 0.867, 0.882);
  static const PdfColor _muted = PdfColor(0.333, 0.404, 0.435);

  static Future<Uint8List> build({
    required OperationsReport report,
    required OperationsReportDocumentRequest request,
    required String assetClassLabel,
    required String assetLabel,
    required List<AssetInstanceRecord> furnaceAssets,
    required Map<String, BurnerConditionRound> currentBurnerRounds,
  }) async {
    final sailData = await rootBundle.load(BafBrand.sailMarkAsset);
    final manmithasData = await rootBundle.load(BafBrand.markAsset);
    final regularFontData = await rootBundle.load(BafBrand.reportFontAsset);
    final mediumFontData = await rootBundle.load(
      BafBrand.reportFontMediumAsset,
    );
    final sailLogo = pw.MemoryImage(_assetBytes(sailData));
    final manmithasLogo = pw.MemoryImage(_assetBytes(manmithasData));
    final regularFont = pw.Font.ttf(regularFontData);
    final mediumFont = pw.Font.ttf(mediumFontData);
    final document = pw.Document(
      title: request.title,
      author: request.generatedByName,
      creator: '${BafBrand.productName} | ${BafBrand.makerName}',
      subject: 'BAF operations and maintenance report ${request.reportId}',
      keywords: 'BAF, maintenance, operations, SAIL, CRM-III',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: regularFont, bold: mediumFont),
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 30),
        header:
            (context) => _header(
              request: request,
              sailLogo: sailLogo,
              manmithasLogo: manmithasLogo,
            ),
        footer: (context) => _footer(context, request, report),
        build:
            (context) => <pw.Widget>[
              _documentIdentity(
                report: report,
                request: request,
                assetClassLabel: assetClassLabel,
                assetLabel: assetLabel,
              ),
              pw.SizedBox(height: 16),
              for (
                var sectionIndex = 0;
                sectionIndex < request.orderedSections.length;
                sectionIndex += 1
              ) ...<pw.Widget>[
                ..._buildSection(
                  section: request.orderedSections[sectionIndex],
                  report: report,
                  furnaceAssets: furnaceAssets,
                  currentBurnerRounds: currentBurnerRounds,
                ),
                if (sectionIndex < request.orderedSections.length - 1)
                  pw.SizedBox(height: 16),
              ],
            ],
      ),
    );
    return document.save();
  }

  static pw.Widget _header({
    required OperationsReportDocumentRequest request,
    required pw.MemoryImage sailLogo,
    required pw.MemoryImage manmithasLogo,
  }) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 9),
    margin: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        pw.SizedBox(
          width: 74,
          height: 35,
          child: pw.Image(sailLogo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                BafBrand.plantName,
                style: const pw.TextStyle(
                  color: _graphite,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${BafBrand.productName}  |  ${request.title}',
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ),
        pw.SizedBox(
          width: 38,
          height: 32,
          child: pw.Image(manmithasLogo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 7),
        pw.Text(
          BafBrand.makerLabel,
          style: const pw.TextStyle(
            color: _graphite,
            fontSize: 6.8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _footer(
    pw.Context context,
    OperationsReportDocumentRequest request,
    OperationsReport report,
  ) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 7),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                '${request.reportId}  |  ${request.provenance.sourceMode.label}',
                style: const pw.TextStyle(color: _muted, fontSize: 6.8),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _sourceRowSummary(report),
                style: const pw.TextStyle(color: _muted, fontSize: 5.2),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(color: _muted, fontSize: 7),
        ),
      ],
    ),
  );

  static pw.Widget _documentIdentity({
    required OperationsReport report,
    required OperationsReportDocumentRequest request,
    required String assetClassLabel,
    required String assetLabel,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(
        request.title,
        style: const pw.TextStyle(
          color: _graphite,
          fontSize: 23,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'A decision-ready record of the selected BAF operating and maintenance scope.',
        style: const pw.TextStyle(color: _muted, fontSize: 10),
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: _metadataGrid(<String, String>{
              'Reporting period':
                  '${_date.format(report.filter.startInclusive)} to ${_date.format(report.filter.endExclusive.subtract(const Duration(days: 1)))}',
              'Asset class': assetClassLabel,
              'Asset': assetLabel,
              'Current-state as of': _dateTime.format(report.asOf),
            }),
          ),
          pw.SizedBox(width: 18),
          pw.Expanded(
            child: _metadataGrid(<String, String>{
              'Generated by': request.generatedByName,
              'Document class': 'Application-generated operational report',
              'Generated at': _dateTime.format(request.generatedAt),
              'Report ID': request.reportId,
            }),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.922, 0.957, 0.957),
          border: pw.Border.all(color: _teal, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          request.snapshotStatement,
          style: const pw.TextStyle(color: _graphite, fontSize: 8.2),
        ),
      ),
    ],
  );

  static pw.Widget _metadataGrid(Map<String, String> values) => pw.Table(
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(92),
      1: pw.FlexColumnWidth(),
    },
    children: values.entries
        .map(
          (entry) => pw.TableRow(
            children: <pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  entry.key,
                  style: const pw.TextStyle(
                    color: _muted,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  entry.value,
                  style: const pw.TextStyle(color: _graphite, fontSize: 8),
                ),
              ),
            ],
          ),
        )
        .toList(growable: false),
  );

  static List<pw.Widget> _buildSection({
    required OperationsReportSection section,
    required OperationsReport report,
    required List<AssetInstanceRecord> furnaceAssets,
    required Map<String, BurnerConditionRound> currentBurnerRounds,
  }) => switch (section) {
    OperationsReportSection.executiveSummary => _executiveSummary(report),
    OperationsReportSection.assetCondition => _assetCondition(report),
    OperationsReportSection.maintenanceIssues => _maintenanceIssues(report),
    OperationsReportSection.plannedMaintenance => _plannedMaintenance(report),
    OperationsReportSection.operationalControl => _operationalControl(report),
    OperationsReportSection.reliability => _reliability(report),
    OperationsReportSection.qualityAndAssurance => _qualityAndAssurance(report),
    OperationsReportSection.burnerUvCondition => _burnerUvCondition(
      report: report,
      furnaceAssets: furnaceAssets,
      rounds: currentBurnerRounds,
    ),
    OperationsReportSection.plantDisruptions => _plantDisruptions(report),
    OperationsReportSection.safetyCriticalAlarms => _safetyCriticalAlarms(
      report,
    ),
  };

  static List<pw.Widget> _executiveSummary(
    OperationsReport report,
  ) => <pw.Widget>[
    _sectionHeading(
      'Executive summary',
      'Selected-period outcomes with current exception and availability signals.',
    ),
    _metricGrid(<({String label, String value, PdfColor color})>[
      (
        label: 'Asset availability',
        value: _percent(report.assetAvailabilityRate),
        color: _teal,
      ),
      (
        label: 'Open issues',
        value: '${report.openIssueCount}',
        color: report.openCriticalIssueCount > 0 ? _ember : _cobalt,
      ),
      (
        label: 'Issue impact',
        value: _duration(report.issueImpactDuration),
        color: _ember,
      ),
      (
        label: 'Open planned work',
        value: '${report.openPlannedJobCount}',
        color: _cobalt,
      ),
      (
        label: 'Operational impact',
        value: _duration(report.disruptionDuration),
        color: _ember,
      ),
      (
        label: 'Assurance backlog',
        value: '${report.assuranceBacklogCount}',
        color: _teal,
      ),
    ]),
    pw.SizedBox(height: 10),
    if (report.managementSignals.isEmpty)
      _emptyStatement('No active management exception leads this scope.')
    else
      ..._simpleTables(
        headers: const <String>['Priority', 'Signal', 'Decision context'],
        rows: report.managementSignals
            .map(
              (signal) => <String>[
                signal.level.name.toUpperCase(),
                signal.title,
                signal.detail,
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(65),
          1: pw.FlexColumnWidth(1.2),
          2: pw.FlexColumnWidth(1.8),
        },
      ),
  ];

  static List<pw.Widget> _assetCondition(
    OperationsReport report,
  ) => <pw.Widget>[
    _sectionHeading(
      'Plant condition',
      'Current fleet state as of ${_dateTime.format(report.asOf)}; these figures are not historical-period totals.',
    ),
    _metricGrid(<({String label, String value, PdfColor color})>[
      (label: 'Assets', value: '${report.assetCount}', color: _graphite),
      (
        label: 'Available',
        value: '${report.availableAssetCount}',
        color: _teal,
      ),
      (
        label: 'Under maintenance',
        value: '${report.underMaintenanceAssetCount}',
        color: _cobalt,
      ),
      (label: 'Down', value: '${report.downAssetCount}', color: _ember),
      (label: 'Unfit', value: '${report.unfitAssetCount}', color: _ember),
    ]),
    pw.SizedBox(height: 10),
    if (report.classSummaries.isEmpty)
      _emptyStatement('No active asset class is present in this scope.')
    else
      ..._simpleTables(
        headers: const <String>[
          'Asset class',
          'Fleet',
          'Available',
          'Maintenance',
          'Down',
          'Unfit',
          'Open issues',
          'Open PM',
        ],
        rows: report.classSummaries
            .map(
              (summary) => <String>[
                summary.assetClassName,
                '${summary.assetCount}',
                '${summary.availableCount}',
                '${summary.underMaintenanceCount}',
                '${summary.downCount}',
                '${summary.unfitCount}',
                '${summary.openIssueCount}',
                '${summary.openPlannedJobCount}',
              ],
            )
            .toList(growable: false),
      ),
    pw.SizedBox(height: 12),
    if (report.assetStates.isEmpty)
      _emptyStatement('No physical asset row is present in this scope.')
    else
      ..._simpleTables(
        headers: const <String>[
          'Asset',
          'Current state',
          'Condition / basis',
          'Reason / linked work',
          'Maintenance exposure',
          'Since / updated',
        ],
        rows: report.assetStates
            .map(
              (state) => <String>[
                '${state.asset.name}\n${state.asset.assetClassName}',
                _plantAssetStateLabel(state),
                _assetConditionEvidence(state),
                _assetConditionReason(state),
                _assetMaintenanceExposure(state),
                _assetStateTime(state),
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.15),
          1: pw.FlexColumnWidth(0.9),
          2: pw.FlexColumnWidth(1.35),
          3: pw.FlexColumnWidth(2.1),
          4: pw.FlexColumnWidth(1.35),
          5: pw.FlexColumnWidth(1.25),
        },
      ),
  ];

  static List<pw.Widget> _maintenanceIssues(OperationsReport report) {
    final tickets = report.tickets.toList(growable: false)
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
    return <pw.Widget>[
      _sectionHeading(
        'Maintenance issues',
        'Issues intersecting the selected reporting period, including reopen-aware impact.',
      ),
      _metricGrid(<({String label, String value, PdfColor color})>[
        (label: 'Issues', value: '${report.issueCount}', color: _graphite),
        (label: 'Open', value: '${report.openIssueCount}', color: _ember),
        (
          label: 'Resolved',
          value: '${report.resolvedIssueCount}',
          color: _teal,
        ),
        (
          label: 'Closed unresolved',
          value: '${report.administrativelyClosedIssueCount}',
          color: _cobalt,
        ),
        (
          label: 'Reopen events',
          value: '${report.issueReopenEventCount}',
          color: _cobalt,
        ),
        (
          label: 'Total impact',
          value: _duration(report.issueImpactDuration),
          color: _ember,
        ),
      ]),
      pw.SizedBox(height: 10),
      if (tickets.isEmpty)
        _emptyStatement('No maintenance issue falls within this scope.')
      else
        ..._simpleTables(
          headers: const <String>[
            'Opened at',
            'Resolved / closed at',
            'Asset',
            'Status',
            'Lane(s)',
            'Component / tag',
            'Issue',
            'Impact',
          ],
          rows: tickets
              .map(
                (ticket) => <String>[
                  _dateTime.format(ticket.startDate.toLocal()),
                  ticket.endDate == null
                      ? '-'
                      : _dateTime.format(ticket.endDate!.toLocal()),
                  _assetLabel(ticket.assetType, ticket.assetNumber),
                  '${ticket.lifecycleSummaryLabel}${ticket.isCritical ? ' | Critical' : ''}',
                  _ticketLanes(ticket),
                  _componentLabel(ticket),
                  ticket.description,
                  _duration(report.issueImpactDurationFor(ticket)),
                ],
              )
              .toList(growable: false),
          widths: const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(72),
            1: pw.FixedColumnWidth(78),
            2: pw.FixedColumnWidth(54),
            3: pw.FixedColumnWidth(70),
            4: pw.FixedColumnWidth(76),
            5: pw.FlexColumnWidth(1.0),
            6: pw.FlexColumnWidth(1.5),
            7: pw.FixedColumnWidth(50),
          },
        ),
    ];
  }

  static List<pw.Widget> _plannedMaintenance(OperationsReport report) {
    final jobs = report.executions.toList(growable: false)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return <pw.Widget>[
      _sectionHeading(
        'Planned maintenance',
        'Planned jobs in the selected period; current completion state is shown for each dossier.',
      ),
      _metricGrid(<({String label, String value, PdfColor color})>[
        (label: 'Jobs', value: '${report.plannedJobCount}', color: _graphite),
        (label: 'Open', value: '${report.openPlannedJobCount}', color: _cobalt),
        (
          label: 'Completed',
          value: '${report.completedPlannedJobCount}',
          color: _teal,
        ),
        (
          label: 'Cancelled',
          value: '${report.cancelledPlannedJobCount}',
          color: _ember,
        ),
        (
          label: 'Completion',
          value: _percent(report.plannedCompletionRate),
          color: _teal,
        ),
        (
          label: 'Overdue counters',
          value: '${report.overdueMaintenanceCount}',
          color: _ember,
        ),
      ]),
      pw.SizedBox(height: 10),
      if (jobs.isEmpty)
        _emptyStatement(
          'No planned-maintenance execution falls within this scope.',
        )
      else
        ..._simpleTables(
          headers: const <String>[
            'Assigned',
            'Asset',
            'Template / work package',
            'Agencies',
            'Status',
            'Closed',
          ],
          rows: jobs
              .map((job) {
                final lifecycleDates = _plannedJobLifecycleDateCells(job);
                return <String>[
                  lifecycleDates[0],
                  _assetLabel(job.assetType, job.assetNumber),
                  job.templateName?.trim().isNotEmpty == true
                      ? job.templateName!.trim()
                      : 'Untitled work package',
                  job.assignedAgencies.isEmpty
                      ? 'Not recorded'
                      : job.assignedAgencies.join(', '),
                  _jobStatus(job),
                  lifecycleDates[1],
                ];
              })
              .toList(growable: false),
          widths: const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(62),
            1: pw.FixedColumnWidth(66),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(1.1),
            4: pw.FixedColumnWidth(62),
            5: pw.FixedColumnWidth(62),
          },
        ),
      pw.SizedBox(height: 12),
      if (report.dueStates.isEmpty)
        _emptyStatement(
          'No maintenance cadence projection is present in this scope.',
        )
      else
        ..._simpleTables(
          headers: const <String>[
            'Asset',
            'Counter / interval',
            'Last completion',
            'Next due',
            'Current cadence state',
            'Last class',
          ],
          rows: (report.dueStates.toList(growable: false)..sort((left, right) {
                final leftDue = left.nextDueAt;
                final rightDue = right.nextDueAt;
                if (leftDue == null && rightDue == null) {
                  return left.counterLabel.compareTo(right.counterLabel);
                }
                if (leftDue == null) return 1;
                if (rightDue == null) return -1;
                return leftDue.compareTo(rightDue);
              }))
              .map(
                (state) => <String>[
                  state.assetDisplayName ??
                      '${_reportLabel(state.assetTypeKey)} ${state.assetNumber ?? ''}',
                  '${state.counterLabel}\n${state.thresholdDays == null ? 'No interval set' : '${state.thresholdDays} days'}',
                  state.lastCompletionAt == null
                      ? 'No completion recorded'
                      : _dateTime.format(state.lastCompletionAt!.toLocal()),
                  state.nextDueAt == null
                      ? 'Not calculated'
                      : _dateTime.format(state.nextDueAt!.toLocal()),
                  _maintenanceDueStateLabel(state, report.asOf),
                  state.lastMaintenanceClassCode ?? 'Not recorded',
                ],
              )
              .toList(growable: false),
          widths: const <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(1.1),
            3: pw.FlexColumnWidth(1.1),
            4: pw.FlexColumnWidth(1.1),
            5: pw.FlexColumnWidth(0.9),
          },
        ),
    ];
  }

  static List<pw.Widget> _operationalControl(
    OperationsReport report,
  ) => <pw.Widget>[
    _sectionHeading(
      'Operational control and workflow',
      'Current control obligations plus disruption impact in the selected period.',
    ),
    _metricGrid(<({String label, String value, PdfColor color})>[
      (label: 'Disruptions', value: '${report.disruptionCount}', color: _ember),
      (
        label: 'Open disruptions',
        value: '${report.openDisruptionCount}',
        color: _ember,
      ),
      (
        label: 'Disruption impact',
        value: _duration(report.disruptionDuration),
        color: _ember,
      ),
      (
        label: 'Active directives',
        value: '${report.activeDirectiveCount}',
        color: _cobalt,
      ),
      (
        label: 'Lane acknowledgements',
        value: '${report.pendingLaneAcknowledgementCount}',
        color: _cobalt,
      ),
      (
        label: 'Due compliance',
        value: '${report.dueComplianceRequestCount}',
        color: _teal,
      ),
    ]),
    pw.SizedBox(height: 10),
    ..._simpleTables(
      headers: const <String>[
        'Control domain',
        'Current count',
        'Interpretation',
      ],
      rows: <List<String>>[
        <String>[
          'High-priority directives',
          '${report.highPriorityDirectiveCount}',
          'Active high or critical instructions requiring owned response.',
        ],
        <String>[
          'Active workflow lanes',
          '${report.activeWorkflowLaneCount}',
          'Lane records not yet closed, removed or terminated.',
        ],
        <String>[
          'Active compliance requests',
          '${report.activeComplianceRequestCount}',
          'Operational support or assurance requests still in lifecycle.',
        ],
        <String>[
          'Issues linked to disruptions',
          '${report.linkedDisruptionIssueCount}',
          'Distinct maintenance issues connected to operational events.',
        ],
      ],
      widths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(1.2),
        1: pw.FixedColumnWidth(76),
        2: pw.FlexColumnWidth(2.4),
      },
    ),
    pw.SizedBox(height: 12),
    if (report.directives.isNotEmpty)
      ..._simpleTables(
        headers: const <String>[
          'Issued',
          'Priority / directive',
          'Directed to',
          'Asset / component',
          'Status / acknowledgement',
        ],
        rows: report.directives
            .map(
              (directive) => <String>[
                _dateTime.format(
                  (directive.issuedAt ?? directive.createdAt).toLocal(),
                ),
                '${_reportLabel(directive.priority.name)} / ${directive.title}\n${directive.description}',
                _reportLabel(directive.directedTo.name),
                directive.hasAssetContext
                    ? '${_assetLabel(directive.assetType!, directive.assetNumber!)}\n${_directiveComponent(directive)}'
                    : 'Plant / general\n${_directiveComponent(directive)}',
                directive.acknowledgedAt == null
                    ? _reportLabel(directive.status.name)
                    : '${_reportLabel(directive.status.name)} at '
                        '${_dateTime.format(directive.acknowledgedAt!.toLocal())} by '
                        '${directive.acknowledgedByName ?? 'Not recorded'}',
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.0),
          1: pw.FlexColumnWidth(2.7),
          2: pw.FlexColumnWidth(0.9),
          3: pw.FlexColumnWidth(1.4),
          4: pw.FlexColumnWidth(1.7),
        },
      ),
    if (report.workflowLanes.isNotEmpty) ...<pw.Widget>[
      pw.SizedBox(height: 12),
      ..._simpleTables(
        headers: const <String>[
          'Asset',
          'Lane',
          'Status',
          'Acknowledged',
          'Closed / control note',
        ],
        rows: report.workflowLanes
            .map(
              (lane) => <String>[
                '${_reportLabel(lane.assetTypeKey)} ${lane.assetNumber}',
                _reportLabel(lane.laneKey),
                _reportLabel(lane.statusKey),
                lane.acknowledgedAt == null
                    ? 'Not acknowledged'
                    : '${_dateTime.format(lane.acknowledgedAt!.toLocal())} by '
                        '${lane.acknowledgedByName ?? 'Not recorded'}',
                lane.closedAt != null
                    ? '${_dateTime.format(lane.closedAt!.toLocal())} by '
                        '${lane.closedByName ?? 'Not recorded'}; '
                        '${lane.closeNote ?? 'No close note'}'
                    : lane.gatingComplianceRequestId == null
                    ? 'No terminal evidence'
                    : 'Gated by ${lane.gatingComplianceRequestId}',
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.0),
          1: pw.FlexColumnWidth(0.9),
          2: pw.FlexColumnWidth(0.8),
          3: pw.FlexColumnWidth(1.7),
          4: pw.FlexColumnWidth(2.3),
        },
      ),
    ],
    if (report.complianceRequests.isNotEmpty) ...<pw.Widget>[
      pw.SizedBox(height: 12),
      ..._simpleTables(
        headers: const <String>[
          'Asset / raised',
          'Purpose / target',
          'Request',
          'Status',
          'Response evidence',
        ],
        rows: report.complianceRequests
            .map(
              (request) => <String>[
                '${_reportLabel(request.assetTypeKey)} ${request.assetNumber}\n'
                    '${_dateTime.format((request.raisedAt ?? request.createdAt).toLocal())}',
                '${request.requestPurposeLabel} / ${_reportLabel(request.targetLaneKey)}',
                '${request.title}\n${request.description}',
                _reportLabel(request.statusKey),
                _complianceEvidence(request),
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.1),
          1: pw.FlexColumnWidth(1.15),
          2: pw.FlexColumnWidth(2.3),
          3: pw.FlexColumnWidth(0.8),
          4: pw.FlexColumnWidth(2.4),
        },
      ),
    ],
  ];

  static List<pw.Widget> _plantDisruptions(
    OperationsReport report,
  ) => <pw.Widget>[
    _sectionHeading(
      'Plant disruptions',
      'Every operating-event occurrence overlapping the selected period, including recurring interruptions.',
    ),
    _metricGrid(<({String label, String value, PdfColor color})>[
      (label: 'Occurrences', value: '${report.disruptionCount}', color: _ember),
      (
        label: 'Open now',
        value: '${report.openDisruptionCount}',
        color: report.openDisruptionCount > 0 ? _ember : _teal,
      ),
      (
        label: 'Period impact',
        value: _duration(report.disruptionDuration),
        color: _cobalt,
      ),
      (
        label: 'Linked issues',
        value: '${report.linkedDisruptionIssueCount}',
        color: _teal,
      ),
    ]),
    pw.SizedBox(height: 10),
    if (report.eventOccurrences.isEmpty)
      _emptyStatement('No plant disruption overlaps the selected period.')
    else
      ..._simpleTables(
        headers: const <String>[
          'Started',
          'Ended / state',
          'Type / severity',
          'Event',
          'Scope',
          'Period impact',
          'Linked issues',
        ],
        rows: report.eventOccurrences
            .map((occurrence) {
              final interval = occurrence.interval;
              final scopeDetail = switch (interval.scope) {
                OperationalEventScope.plantWide => interval.scope.label,
                OperationalEventScope.assetClasses =>
                  '${interval.scope.label} (${interval.affectedAssetClassIds.length})',
                OperationalEventScope.assets =>
                  '${interval.scope.label} (${interval.affectedAssetInstanceIds.length})',
              };
              final timeCells = _plantDisruptionTimeCells(
                startedAt: interval.startedAt,
                resolvedAt: interval.resolvedAt,
                asOf: report.asOf,
                isOpen: occurrence.isOpen,
              );
              return <String>[
                timeCells[0],
                timeCells[1],
                '${interval.eventType.label} / ${interval.severity.label}',
                '${interval.title}\n${interval.description}',
                scopeDetail,
                _duration(
                  interval.durationWithin(
                    report.filter.startInclusive,
                    report.filter.endExclusive,
                  ),
                ),
                '${interval.linkedIssueIds.length}',
              ];
            })
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(82),
          1: pw.FixedColumnWidth(92),
          2: pw.FlexColumnWidth(0.9),
          3: pw.FlexColumnWidth(1.8),
          4: pw.FlexColumnWidth(0.9),
          5: pw.FixedColumnWidth(68),
          6: pw.FixedColumnWidth(48),
        },
      ),
  ];

  static List<pw.Widget> _safetyCriticalAlarms(
    OperationsReport report,
  ) => <pw.Widget>[
    _sectionHeading(
      'Safety-critical alarms',
      'Alarm lifecycle evidence overlapping the selected period, with active carry-forward exposure.',
    ),
    _metricGrid(<({String label, String value, PdfColor color})>[
      (
        label: 'Period alarms',
        value: '${report.criticalAlarms.length}',
        color: _ember,
      ),
      (
        label: 'Active now',
        value: '${report.activeCriticalAlarmCount}',
        color: report.activeCriticalAlarmCount > 0 ? _ember : _teal,
      ),
      (
        label: 'Highest active',
        value: '${report.highestActiveCriticalAlarmCount}',
        color: _ember,
      ),
      (
        label: 'Awaiting support',
        value: '${report.awaitingCriticalAlarmSupportCount}',
        color: _cobalt,
      ),
      (
        label: 'Resolved',
        value: '${report.resolvedCriticalAlarmCount}',
        color: _teal,
      ),
      (
        label: 'Withdrawn in error',
        value: '${report.withdrawnCriticalAlarmCount}',
        color: _muted,
      ),
    ]),
    pw.SizedBox(height: 10),
    if (report.criticalAlarms.isEmpty)
      _emptyStatement('No safety-critical alarm overlaps the selected period.')
    else
      ..._simpleTables(
        headers: const <String>[
          'Alarm / criticality',
          'Location / asset',
          'Raised',
          'Support response',
          'Terminal evidence',
          'Status',
        ],
        rows: report.criticalAlarms
            .map((alarm) {
              final asset =
                  alarm.assetTypeKey == null
                      ? 'No specific asset'
                      : '${alarm.assetTypeKey} ${alarm.assetNumber}';
              final support =
                  alarm.supportConfirmedAt == null
                      ? 'Awaiting confirmation'
                      : '${_supportBasisLabel(alarm.supportBasis)} at '
                          '${_formatLocalDateTime(alarm.supportConfirmedAt!)} by '
                          '${alarm.supportConfirmedByName}';
              final terminal =
                  alarm.resolvedAt != null
                      ? 'Resolved ${_formatLocalDateTime(alarm.resolvedAt!)} by '
                          '${alarm.resolvedByName}: ${alarm.resolutionSummary}'
                      : alarm.withdrawnAt != null
                      ? 'Withdrawn ${_formatLocalDateTime(alarm.withdrawnAt!)} by '
                          '${alarm.withdrawnByName}: ${alarm.withdrawalReason}'
                      : 'Active';
              return <String>[
                '${alarm.definition.name} / ${alarm.definition.criticalityLabel}',
                '${alarm.location}\n$asset',
                '${_formatLocalDateTime(alarm.raisedAt)} by ${alarm.raisedByName}',
                support,
                terminal,
                _criticalAlarmStatusLabel(alarm.status),
              ];
            })
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(1.2),
          2: pw.FlexColumnWidth(1.25),
          3: pw.FlexColumnWidth(1.65),
          4: pw.FlexColumnWidth(1.8),
          5: pw.FlexColumnWidth(0.8),
        },
      ),
  ];

  static List<pw.Widget> _reliability(OperationsReport report) => <pw.Widget>[
    _sectionHeading(
      'Reliability concentrations',
      'Repeated component and hierarchy-path involvement in selected-period issues.',
    ),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(child: _rankedList('Top components', report.topComponents)),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _rankedList('Top subsystem paths', report.topSubsystemPaths),
        ),
      ],
    ),
  ];

  static List<pw.Widget> _qualityAndAssurance(
    OperationsReport report,
  ) => <pw.Widget>[
    _sectionHeading(
      'Quality and assurance',
      'Current warning, monitoring and assurance posture with selected-period abnormality evidence.',
    ),
    _metricGrid(<({String label, String value, PdfColor color})>[
      (
        label: 'Open warnings',
        value: '${report.openQualityWarningCount}',
        color: _ember,
      ),
      (
        label: 'Closure requests',
        value: '${report.qualityClosureRequestCount}',
        color: _cobalt,
      ),
      (
        label: 'Active monitoring',
        value: '${report.activeQualityMonitoringCount}',
        color: _teal,
      ),
      (
        label: 'High-severity abnormalities',
        value: '${report.highSeverityAbnormalityCount}',
        color: _ember,
      ),
      (
        label: 'RA required',
        value: '${report.pendingReannealingCount}',
        color: _cobalt,
      ),
      (
        label: 'Active inspection findings',
        value: '${report.activeInspectionFindingCount}',
        color: _teal,
      ),
    ]),
    pw.SizedBox(height: 10),
    ..._simpleTables(
      headers: const <String>['Assurance item', 'Count', 'Required attention'],
      rows: <List<String>>[
        <String>[
          'Awaiting inspection verification',
          '${report.awaitingInspectionVerificationCount}',
          'Evidence must be verified before finding closure.',
        ],
        <String>[
          'Warnings awaiting closure decision',
          '${report.qualityClosureRequestCount}',
          'Review charge evidence and linked abnormality / RA outcome.',
        ],
        <String>[
          'Re-annealing required',
          '${report.pendingReannealingCount}',
          'Follow through to a governed charge disposition.',
        ],
      ],
      widths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(1.2),
        1: pw.FixedColumnWidth(58),
        2: pw.FlexColumnWidth(2.4),
      },
    ),
    pw.SizedBox(height: 12),
    if (report.qualityWarnings.isEmpty)
      _emptyStatement('No quality warning intersects this report scope.')
    else
      ..._simpleTables(
        headers: const <String>[
          'Charge / source',
          'Affected assets',
          'Warning evidence',
          'Status / request',
          'Closure / RA outcome',
        ],
        rows: report.qualityWarnings
            .map(
              (warning) => <String>[
                '${warning.sourceChargeNo}\n${_reportLabel(warning.sourceType.name)} ${warning.sourceId}',
                warning.affectedAssets.map((asset) => asset.label).join(', '),
                '${warning.warningReason}\n${warning.sourceSummary}'
                    '${warning.component == null ? '' : '\nComponent: ${warning.component}'}',
                warning.closureRequestedAt == null
                    ? _reportLabel(warning.status.name)
                    : '${_reportLabel(warning.status.name)} at '
                        '${_dateTime.format(warning.closureRequestedAt!.toLocal())} by '
                        '${warning.closureRequestedByName ?? 'Not recorded'}: '
                        '${warning.closureRequestReason ?? 'No reason recorded'}',
                warning.closedAt == null
                    ? 'Not closed'
                    : '${_reportLabel(warning.closureDisposition?.name ?? 'closed')} at '
                        '${_dateTime.format(warning.closedAt!.toLocal())} by '
                        '${warning.closedByName ?? 'Not recorded'}; '
                        '${warning.decisionReason ?? 'No decision reason'}'
                        '${warning.linkedReannealingChargeNos.isEmpty ? '' : '\nRA charges: ${warning.linkedReannealingChargeNos.join(', ')}'}',
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.15),
          1: pw.FlexColumnWidth(1.25),
          2: pw.FlexColumnWidth(2.3),
          3: pw.FlexColumnWidth(1.8),
          4: pw.FlexColumnWidth(2.2),
        },
      ),
    if (report.qualityMonitoringRequests.isNotEmpty) ...<pw.Widget>[
      pw.SizedBox(height: 12),
      ..._simpleTables(
        headers: const <String>[
          'Base / grade',
          'Cycle / charges',
          'Monitoring reason',
          'Raised',
          'Status / closure',
        ],
        rows: report.qualityMonitoringRequests
            .map(
              (request) => <String>[
                'Base ${request.baseNumber}\n${request.grade}',
                '${request.cycleReference}\n${request.chargeNumbers.isEmpty ? 'No charges listed' : request.chargeNumbers.join(', ')}',
                request.reason,
                '${_dateTime.format(request.createdAt.toLocal())} by '
                    '${request.createdByName ?? 'Not recorded'}',
                request.closedAt == null
                    ? _reportLabel(request.status.name)
                    : 'Closed ${_dateTime.format(request.closedAt!.toLocal())} by '
                        '${request.closedByName ?? 'Not recorded'}: '
                        '${request.closeReason ?? 'No reason recorded'}',
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.05),
          1: pw.FlexColumnWidth(1.35),
          2: pw.FlexColumnWidth(2.4),
          3: pw.FlexColumnWidth(1.45),
          4: pw.FlexColumnWidth(2.0),
        },
      ),
    ],
    if (report.abnormalities.isNotEmpty) ...<pw.Widget>[
      pw.SizedBox(height: 12),
      ..._simpleTables(
        headers: const <String>[
          'Logged / charge',
          'Type / severity',
          'Assets / component',
          'Observation',
          'RA status / charge',
          'Recorded by',
        ],
        rows: report.abnormalities
            .map(
              (record) => <String>[
                '${_dateTime.format(record.loggedAt.toLocal())}\nCharge ${record.sourceChargeNo}',
                '${record.abnormalityTypeTitle}\n${_reportLabel(record.severity.name)}',
                '${record.affectedAssetsLabel}'
                    '${record.component == null ? '' : '\n${record.component}'}',
                '${record.observedReason}'
                    '${record.description == null ? '' : '\n${record.description}'}',
                '${_reportLabel(record.reannealingStatus.name)}'
                    '${record.reannealedToChargeNo == null ? '' : '\nCharge ${record.reannealedToChargeNo}'}',
                '${record.loggedByName ?? 'Not recorded'}\nv${record.version}',
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.15),
          1: pw.FlexColumnWidth(1.3),
          2: pw.FlexColumnWidth(1.4),
          3: pw.FlexColumnWidth(2.3),
          4: pw.FlexColumnWidth(1.05),
          5: pw.FlexColumnWidth(0.9),
        },
      ),
    ],
    if (report.inspectionFindings.isNotEmpty) ...<pw.Widget>[
      pw.SizedBox(height: 12),
      ..._simpleTables(
        headers: const <String>[
          'Asset / target',
          'Component / position',
          'Status',
          'First / latest observation',
          'Recurrence',
          'Corrective / verification evidence',
        ],
        rows: report.inspectionFindings
            .map(
              (finding) => <String>[
                '${_reportLabel(finding.assetTypeKey)} ${finding.assetNumber}\n${finding.targetKey}',
                '${finding.componentName ?? 'Not recorded'}'
                    '${finding.physicalPosition == null ? '' : '\n${finding.physicalPosition}'}',
                _reportLabel(finding.status.name),
                '${_dateTime.format(finding.firstObservedAt.toLocal())}\n'
                    '${_dateTime.format(finding.latestObservedAt.toLocal())}',
                '${finding.recurrenceCount}',
                '${finding.linkedTicketId == null ? 'No linked issue' : 'Issue ${finding.linkedTicketId}'}\n'
                    '${finding.verificationCount} verification(s)'
                    '${finding.lastVerificationOutcome == null ? '' : '; ${_reportLabel(finding.lastVerificationOutcome!.name)}'}',
              ],
            )
            .toList(growable: false),
        widths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.35),
          1: pw.FlexColumnWidth(1.45),
          2: pw.FlexColumnWidth(1.0),
          3: pw.FlexColumnWidth(1.45),
          4: pw.FixedColumnWidth(58),
          5: pw.FlexColumnWidth(2.0),
        },
      ),
    ],
  ];

  static List<pw.Widget> _burnerUvCondition({
    required OperationsReport report,
    required List<AssetInstanceRecord> furnaceAssets,
    required Map<String, BurnerConditionRound> rounds,
  }) {
    final assets = furnaceAssets.toList(growable: false)
      ..sort((left, right) => left.assetNumber.compareTo(right.assetNumber));
    return <pw.Widget>[
      _sectionHeading(
        'Current Burner Block and UV condition',
        'Latest governed audit per Furnace. Missing rows are shown as not yet audited, never inferred as healthy.',
      ),
      if (assets.isEmpty)
        _emptyStatement(
          'No active Furnace asset falls within this report scope.',
        )
      else
        ..._simpleTables(
          headers: const <String>[
            'Furnace',
            'Observed',
            'Burner Blocks red hot',
            'Draft seal',
            'UV exceptions',
            'Recorded by',
          ],
          rows: assets
              .map((asset) {
                final round = rounds[asset.id];
                if (round == null) {
                  return <String>[
                    asset.name,
                    'Not yet audited',
                    'Unknown',
                    'Unknown',
                    'Unknown',
                    '-',
                  ];
                }
                final uvExceptions = round.uvObservations
                    .where(
                      (observation) =>
                          observation.condition !=
                          BurnerUvCondition.serviceable,
                    )
                    .map(
                      (observation) =>
                          'B${observation.position}: ${observation.condition.label}',
                    )
                    .join('; ');
                final draftFlags = <String>[
                  if (round.draftSealRedHotObserved) 'Red hot',
                  if (round.hotAirAtDraftSealObserved) 'Hot air',
                ];
                return <String>[
                  round.assetName,
                  _burnerObservationTime(round.observedAt),
                  round.redHotPositions.isEmpty
                      ? 'None recorded'
                      : round.redHotPositions
                          .map((position) => 'B$position')
                          .join(', '),
                  draftFlags.isEmpty ? 'No exception' : draftFlags.join(', '),
                  uvExceptions.isEmpty ? 'All in service' : uvExceptions,
                  round.recordedByName,
                ];
              })
              .toList(growable: false),
          widths: const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(65),
            1: pw.FixedColumnWidth(92),
            2: pw.FlexColumnWidth(1.1),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(1.7),
            5: pw.FlexColumnWidth(1.0),
          },
        ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Condition values are current-state evidence as of each row\'s observation time; the selected reporting period does not exclude the latest governed condition round.',
        style: const pw.TextStyle(color: _muted, fontSize: 7.5),
      ),
    ];
  }

  static pw.Widget _sectionHeading(String title, String subtitle) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.only(left: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _teal, width: 3)),
        ),
        child: pw.Text(
          title,
          style: const pw.TextStyle(
            color: _graphite,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Text(subtitle, style: const pw.TextStyle(color: _muted, fontSize: 8)),
      pw.SizedBox(height: 9),
    ],
  );

  static pw.Widget _metricGrid(
    List<({String label, String value, PdfColor color})> values,
  ) => pw.Wrap(
    spacing: 7,
    runSpacing: 7,
    children: values
        .map(
          (metric) => pw.Container(
            width: 116,
            height: 50,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _border, width: 0.7),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  metric.value,
                  style: pw.TextStyle(
                    color: metric.color,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  metric.label,
                  maxLines: 2,
                  style: const pw.TextStyle(color: _muted, fontSize: 7),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false),
  );

  static List<pw.Widget> _simpleTables({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? widths,
  }) {
    const rowsPerBlock = 8;
    final normalizedRows = rows
        .expand(_reportRowSegments)
        .toList(growable: false);
    final tables = <pw.Widget>[];
    for (var start = 0; start < normalizedRows.length; start += rowsPerBlock) {
      if (tables.isNotEmpty) {
        tables.add(pw.SizedBox(height: 6));
      }
      final end =
          start + rowsPerBlock < normalizedRows.length
              ? start + rowsPerBlock
              : normalizedRows.length;
      tables.add(
        _simpleTable(
          headers: headers,
          rows: normalizedRows.sublist(start, end),
          widths: widths,
        ),
      );
    }
    return tables;
  }

  static pw.Widget _simpleTable({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? widths,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: pw.TableBorder.all(color: _border, width: 0.55),
    columnWidths: widths,
    headerDecoration: const pw.BoxDecoration(color: _graphite),
    headerStyle: const pw.TextStyle(
      color: PdfColors.white,
      fontSize: 7.2,
      fontWeight: pw.FontWeight.bold,
    ),
    cellStyle: const pw.TextStyle(color: _graphite, fontSize: 7),
    oddRowDecoration: const pw.BoxDecoration(color: _surface),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
  );

  static List<List<String>> _reportRowSegments(List<String> row) {
    final cells = row
        .map(_reportCellText)
        .map(_reportCellSegments)
        .toList(growable: false);
    final segmentCount = cells.fold<int>(
      1,
      (maximum, segments) =>
          segments.length > maximum ? segments.length : maximum,
    );
    return List<List<String>>.generate(
      segmentCount,
      (segmentIndex) => cells
          .map(
            (segments) =>
                segmentIndex < segments.length ? segments[segmentIndex] : '',
          )
          .toList(growable: false),
      growable: false,
    );
  }

  static List<String> _reportCellSegments(String value) {
    const maximumSegmentCharacters = 360;
    if (value.length <= maximumSegmentCharacters) {
      return <String>[value];
    }

    final segments = <String>[];
    var remaining = value;
    while (remaining.length > maximumSegmentCharacters) {
      final wordBoundary = remaining.lastIndexOf(' ', maximumSegmentCharacters);
      final splitAt =
          wordBoundary > 0 ? wordBoundary : maximumSegmentCharacters;
      segments.add(remaining.substring(0, splitAt));
      remaining = remaining.substring(splitAt).trimLeft();
    }
    if (remaining.isNotEmpty) segments.add(remaining);
    return segments;
  }

  static String _reportCellText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _formatLocalDateTime(DateTime value) =>
      _dateTime.format(value.toLocal());

  static String _formatLocalDate(DateTime value) =>
      _date.format(value.toLocal());

  static List<String> _plannedJobLifecycleDateCells(JobExecution job) =>
      <String>[
        _formatLocalDate(job.createdAt),
        job.completedAt == null
            ? job.cancelledAt == null
                ? '-'
                : _formatLocalDate(job.cancelledAt!)
            : _formatLocalDate(job.completedAt!),
      ];

  static String _burnerObservationTime(DateTime observedAt) =>
      _formatLocalDateTime(observedAt);

  static List<String> _plantDisruptionTimeCells({
    required DateTime startedAt,
    required DateTime resolvedAt,
    required DateTime asOf,
    required bool isOpen,
  }) => <String>[
    _formatLocalDateTime(startedAt),
    isOpen
        ? 'Open at ${_formatLocalDateTime(asOf)}'
        : _formatLocalDateTime(resolvedAt),
  ];

  @visibleForTesting
  static String normalizeReportCellTextForTesting(String value) =>
      _reportCellText(value);

  @visibleForTesting
  static List<List<String>> segmentReportRowForTesting(List<String> row) =>
      _reportRowSegments(row);

  @visibleForTesting
  static List<String> plantDisruptionTimeCellsForTesting({
    required DateTime startedAt,
    required DateTime resolvedAt,
    required DateTime asOf,
    required bool isOpen,
  }) => _plantDisruptionTimeCells(
    startedAt: startedAt,
    resolvedAt: resolvedAt,
    asOf: asOf,
    isOpen: isOpen,
  );

  @visibleForTesting
  static List<String> plannedJobLifecycleDateCellsForTesting(
    JobExecution job,
  ) => _plannedJobLifecycleDateCells(job);

  @visibleForTesting
  static String burnerObservationTimeForTesting(DateTime observedAt) =>
      _burnerObservationTime(observedAt);

  static pw.Widget _rankedList(String title, List<CountedReportLabel> values) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              title,
              style: const pw.TextStyle(
                color: _graphite,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 7),
            if (values.isEmpty)
              pw.Text(
                'No repeated concentration is present.',
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              )
            else
              ...values
                  .take(12)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: <pw.Widget>[
                          pw.SizedBox(
                            width: 22,
                            child: pw.Text(
                              '${entry.key + 1}.',
                              style: const pw.TextStyle(
                                color: _muted,
                                fontSize: 7.5,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              entry.value.label,
                              style: const pw.TextStyle(
                                color: _graphite,
                                fontSize: 8,
                              ),
                            ),
                          ),
                          pw.Text(
                            '${entry.value.count}',
                            style: const pw.TextStyle(
                              color: _teal,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      );

  static pw.Widget _emptyStatement(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _surface,
      border: pw.Border.all(color: _border, width: 0.6),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(text, style: const pw.TextStyle(color: _muted, fontSize: 8)),
  );

  static String _plantAssetStateLabel(PlantAssetState state) {
    final labels = <String>[
      if (state.isDown) 'Down',
      if (state.isUnfit) 'Unfit',
      if (state.isTemporarilyBlocked) 'Temporarily blocked',
      if (state.isUnderMaintenance) 'Under maintenance',
      if (state.isAdministrativelyOutOfService) 'Out of service',
      if (state.isStandby) 'Standby',
      if (state.isAvailable) 'Available',
    ];
    return labels.isEmpty
        ? _reportLabel(state.asset.serviceState.name)
        : labels.join(', ');
  }

  static String _assetConditionEvidence(PlantAssetState state) {
    final condition = state.operationalCondition;
    final availability = state.availability;
    final details = <String>[
      if (condition?.active == true)
        '${condition!.condition.label}${condition.basis == null ? '' : ' / ${condition.basis!.label}'}',
      if (condition?.causes.isNotEmpty == true)
        condition!.causes.map((cause) => cause.label).join(', '),
      if (condition?.componentReference != null)
        condition!.componentReference!.hierarchyPath.join(' > '),
      if (availability?.isTemporarilyBlocked == true)
        'Availability: ${_reportLabel(availability!.reasonType ?? 'blocked')}',
    ];
    return details.isEmpty
        ? 'No active condition declaration'
        : details.join('\n');
  }

  static String _assetConditionReason(PlantAssetState state) {
    final condition = state.operationalCondition;
    final availability = state.availability;
    final details = <String>[
      if (condition?.active == true) condition!.reason,
      if (condition?.linkedIssueIds.isNotEmpty == true)
        'Issues: ${condition!.linkedIssueIds.join(', ')}',
      if (availability?.linkedTicketId != null)
        'Constraint issue: ${availability!.linkedTicketId}',
      if (availability?.linkedCaseId != null)
        'Case: ${availability!.linkedCaseId}',
    ];
    return details.isEmpty ? 'No active exception' : details.join('\n');
  }

  static String _assetMaintenanceExposure(PlantAssetState state) {
    final status = state.workflowStatus;
    if (status == null) return 'No workflow projection';
    return 'Maintenance ${status.openMaintenanceCount}; '
        'RED ${status.openRedCount}; '
        'preparation ${status.awaitingPreparationCount}';
  }

  static String _assetStateTime(PlantAssetState state) {
    final details = <String>[
      if (state.operationalCondition?.declaredAt != null)
        'Declared ${_dateTime.format(state.operationalCondition!.declaredAt!.toLocal())}',
      if (state.availability?.since != null)
        'Blocked ${_dateTime.format(state.availability!.since!.toLocal())}',
      if (state.workflowStatus?.lastTransitionAt != null)
        'Workflow ${_dateTime.format(state.workflowStatus!.lastTransitionAt!.toLocal())}',
    ];
    return details.isEmpty ? 'No active-state timestamp' : details.join('\n');
  }

  static String _maintenanceDueStateLabel(
    MaintenanceDueState state,
    DateTime asOf,
  ) {
    if (state.classificationPending) return 'Classification pending';
    final nextDue = state.nextDueAt;
    if (nextDue == null) return 'No due date';
    if (nextDue.isBefore(asOf)) return 'Overdue';
    if (!nextDue.isAfter(asOf.add(const Duration(days: 7)))) {
      return 'Due within 7 days';
    }
    return 'Scheduled';
  }

  static String _directiveComponent(OperationalDirective directive) {
    final parts = <String>[
      if (directive.hierarchyPath?.isNotEmpty == true)
        directive.hierarchyPath!.join(' > '),
      if (directive.hierarchyPath?.isNotEmpty != true &&
          directive.subsystem?.trim().isNotEmpty == true)
        directive.subsystem!.trim(),
      if (directive.hierarchyPath?.isNotEmpty != true &&
          directive.component?.trim().isNotEmpty == true)
        directive.component!.trim(),
      if (directive.tag?.trim().isNotEmpty == true)
        'Tag ${directive.tag!.trim()}',
    ];
    return parts.isEmpty ? 'No component target' : parts.join(' / ');
  }

  static String _complianceEvidence(ComplianceRequestRecord request) {
    final rows = <String>[
      if (request.acknowledgedAt != null)
        'Acknowledged ${_dateTime.format(request.acknowledgedAt!.toLocal())} by '
            '${request.acknowledgedByName ?? 'Not recorded'}',
      if (request.compliedAt != null)
        'Complied ${_dateTime.format(request.compliedAt!.toLocal())} by '
            '${request.compliedByName ?? 'Not recorded'}: '
            '${request.complianceNote ?? 'No note'}',
      if (request.confirmedAt != null)
        'Confirmed ${_dateTime.format(request.confirmedAt!.toLocal())} by '
            '${request.confirmedByName ?? 'Not recorded'}: '
            '${request.confirmNote ?? 'No note'}',
      if (request.becameDueAt != null)
        'Due since ${_dateTime.format(request.becameDueAt!.toLocal())}',
      if (request.correctionCount > 0)
        '${request.correctionCount} correction(s); last by '
            '${request.lastCorrectionByName ?? 'Not recorded'}',
    ];
    return rows.isEmpty ? 'No response evidence yet' : rows.join('\n');
  }

  static String _reportLabel(String value) {
    final spaced = value
        .trim()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
    if (spaced.isEmpty) return 'Not recorded';
    return spaced
        .split(RegExp(r'\s+'))
        .map(
          (word) =>
              word.length <= 2
                  ? word.toUpperCase()
                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _sourceRowSummary(OperationsReport report) =>
      'Decoded source rows: issues ${report.sourceTicketCount} | '
      'PM ${report.sourceExecutionCount} | events ${report.sourceEventCount} | '
      'counters ${report.sourceDueStateCount} | '
      'inspections ${report.sourceInspectionFindingCount} | '
      'warnings ${report.sourceQualityWarningCount} | '
      'monitoring ${report.sourceQualityMonitoringCount} | '
      'abnormalities ${report.sourceAbnormalityCount} | '
      'directives ${report.sourceDirectiveCount} | '
      'lanes ${report.sourceWorkflowLaneCount} | '
      'compliance ${report.sourceComplianceRequestCount} | '
      'alarms ${report.sourceCriticalAlarmCount} | '
      'Long narrative cells may be abbreviated; complete records remain in the app.';

  static String _criticalAlarmStatusLabel(CriticalAlarmStatus status) =>
      switch (status) {
        CriticalAlarmStatus.raised => 'Raised',
        CriticalAlarmStatus.supportConfirmed => 'Support confirmed',
        CriticalAlarmStatus.resolved => 'Resolved',
        CriticalAlarmStatus.withdrawnInError => 'Withdrawn in error',
      };

  static String _supportBasisLabel(CriticalAlarmSupportBasis? basis) =>
      switch (basis) {
        CriticalAlarmSupportBasis.supportDispatched => 'Support dispatched',
        CriticalAlarmSupportBasis.supportAlreadyPresent =>
          'Support already present',
        CriticalAlarmSupportBasis.raiserContactedDirectly =>
          'Raiser contacted directly',
        null => 'Support confirmed',
      };

  static String _ticketLanes(MaintenanceRecord ticket) {
    final plan = ticket.issueLanePlanReadResult.value;
    if (plan == null || plan.assignedLanes.isEmpty) return ticket.routedTo.name;
    return plan.assignedLanes
        .map(
          (lane) =>
              lane == 'others' ? ticket.otherDepartment ?? 'Others' : lane,
        )
        .join(', ');
  }

  static String _componentLabel(MaintenanceRecord ticket) {
    final parts = <String>[
      if (ticket.subsystem?.trim().isNotEmpty == true) ticket.subsystem!.trim(),
      if (ticket.component?.trim().isNotEmpty == true) ticket.component!.trim(),
      if (ticket.tag?.trim().isNotEmpty == true) 'Tag ${ticket.tag!.trim()}',
    ];
    return parts.isEmpty ? 'Not specified' : parts.join(' / ');
  }

  static String _assetLabel(AssetType type, int number) => switch (type) {
    AssetType.base => 'Base $number',
    AssetType.furnace => 'Furnace $number',
    AssetType.forceCooler => 'Forced Cooler $number',
    AssetType.innerCover => 'Inner Cover $number',
    AssetType.governedCustom => 'Asset $number',
  };

  static String _jobStatus(JobExecution job) {
    if (job.isDeleted) return 'Deleted';
    if (job.isCancelled) return 'Cancelled';
    if (job.isCompleted) return 'Completed';
    return 'Open';
  }

  static String _duration(Duration value) {
    if (value.inMinutes <= 0) return '0 min';
    final days = value.inDays;
    final hours = value.inHours.remainder(24);
    final minutes = value.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  static String _percent(double? value) =>
      value == null ? '-' : '${(value * 100).toStringAsFixed(1)}%';

  static Uint8List _assetBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
