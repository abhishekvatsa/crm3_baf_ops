// FILE: lib/features/planned_maintenance/domain/knowledge_governance_export.dart
//
// Phase 5E — Export and import helpers for the Knowledge Governance screen.
//
// Two transport formats are supported deliberately:
//   - JSON: the canonical machine-readable format. Round-trips through the
//     existing `BafKnowledgeRow.fromCloudMap(...)` constructor without loss.
//   - CSV: a flat compatibility format for offline review/edit in
//     spreadsheet tools. Multi-value columns use `;` as the inner
//     separator. CSV import is deliberately strict: extra columns are
//     ignored, missing columns mean "no change".

import 'dart:convert';

import '../data/baf_knowledge_model.dart';
import 'knowledge_governance_models.dart';
import 'module_composer_models.dart';

class KnowledgeBundleExport {
  final String matrixVersion;
  final String exportedAt;
  final int rowCount;
  final String body;
  final KnowledgeBundleFormat format;

  const KnowledgeBundleExport({
    required this.matrixVersion,
    required this.exportedAt,
    required this.rowCount,
    required this.body,
    required this.format,
  });
}

enum KnowledgeBundleFormat { json, csv }

class KnowledgeImportSummary {
  final int rowsConsidered;
  final int rowsAccepted;
  final int rowsRejected;
  final List<KnowledgeImportRowResult> rejected;
  final List<KnowledgeImportRowResult> accepted;

  const KnowledgeImportSummary({
    required this.rowsConsidered,
    required this.rowsAccepted,
    required this.rowsRejected,
    required this.rejected,
    required this.accepted,
  });
}

class KnowledgeImportRowResult {
  final String rowCode;
  final bool accepted;
  final List<String> messages;
  final KnowledgeRowDraft? draft;

  const KnowledgeImportRowResult({
    required this.rowCode,
    required this.accepted,
    required this.messages,
    this.draft,
  });
}

class KnowledgeGovernanceExport {
  KnowledgeGovernanceExport._();

  static const _csvColumns = <String>[
    'rowCode',
    'lifecycleStatus',
    'matrixVersion',
    'taskText',
    'moduleCandidateCode',
    'assetFamily',
    'functionalSection',
    'componentGroup',
    'taskType',
    'frequency',
    'discipline',
    'ownerDisciplines',
    'safetyClasses',
    'procedureRefs',
    'partRefs',
    'deviceTags',
    'targetRefs',
    'suggestedFields',
    'requiredForClosure',
    'resolverImpact',
    'composerReadiness',
    'confidence',
    'consultQuestion',
    'sourceManual',
    'sourcePage',
    'sourceType',
    'changeSummary',
    'version',
    'updatedAt',
    'updatedByName',
  ];

  /// Convert a list of rows into an export bundle in the requested format.
  static KnowledgeBundleExport export(
    Iterable<BafKnowledgeRow> rows, {
    required KnowledgeBundleFormat format,
    required String matrixVersion,
  }) {
    final rowList = rows.toList()
      ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
    final exportedAt = DateTime.now().toIso8601String();
    if (format == KnowledgeBundleFormat.json) {
      final payload = <String, dynamic>{
        'matrixVersion': matrixVersion,
        'exportedAt': exportedAt,
        'rowCount': rowList.length,
        'rows': rowList.map(_rowToJsonMap).toList(),
      };
      return KnowledgeBundleExport(
        matrixVersion: matrixVersion,
        exportedAt: exportedAt,
        rowCount: rowList.length,
        body: const JsonEncoder.withIndent('  ').convert(payload),
        format: format,
      );
    }
    final buffer = StringBuffer();
    buffer.writeln(_csvColumns.map(_csvEscape).join(','));
    for (final row in rowList) {
      buffer.writeln(
        _csvColumns.map((column) => _csvEscape(_csvCellOf(row, column))).join(','),
      );
    }
    return KnowledgeBundleExport(
      matrixVersion: matrixVersion,
      exportedAt: exportedAt,
      rowCount: rowList.length,
      body: buffer.toString(),
      format: format,
    );
  }

  /// Parse an import bundle (JSON or CSV) and return drafts plus a summary.
  /// The summary lists each row that was accepted (with its draft) and each
  /// row that was rejected (with messages explaining why).
  ///
  /// This is a pure parser — no I/O is performed. The caller is responsible
  /// for applying accepted drafts via the `KnowledgeGovernanceController`.
  static KnowledgeImportSummary parse({
    required String body,
    required KnowledgeBundleFormat format,
    Map<String, BafKnowledgeRow>? existingRowsByCode,
  }) {
    final accepted = <KnowledgeImportRowResult>[];
    final rejected = <KnowledgeImportRowResult>[];

    Iterable<Map<String, dynamic>> rowMaps;
    try {
      if (format == KnowledgeBundleFormat.json) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final rawRows = decoded['rows'];
          if (rawRows is List) {
            rowMaps = rawRows
                .whereType<Map>()
                .map((map) => Map<String, dynamic>.from(map))
                .toList();
          } else {
            return _emptyRejection('JSON: missing "rows" array');
          }
        } else if (decoded is List) {
          rowMaps = decoded
              .whereType<Map>()
              .map((map) => Map<String, dynamic>.from(map))
              .toList();
        } else {
          return _emptyRejection('JSON: top-level must be object or array');
        }
      } else {
        rowMaps = _parseCsv(body);
      }
    } catch (e) {
      return _emptyRejection('Parse failed: $e');
    }

    for (final raw in rowMaps) {
      final rowCode = (raw['rowCode'] ?? '').toString().trim();
      if (rowCode.isEmpty) {
        rejected.add(const KnowledgeImportRowResult(
          rowCode: '<missing>',
          accepted: false,
          messages: <String>['rowCode missing'],
        ));
        continue;
      }
      final messages = <String>[];
      if ((raw['taskText'] ?? '').toString().trim().isEmpty) {
        messages.add('taskText missing');
      }
      final reason = (raw['changeSummary'] ?? '').toString().trim();
      if (reason.length < 15) {
        messages.add('changeSummary missing or shorter than 15 characters');
      }
      if (messages.isNotEmpty) {
        rejected.add(KnowledgeImportRowResult(
          rowCode: rowCode,
          accepted: false,
          messages: messages,
        ));
        continue;
      }
      final existing = existingRowsByCode == null ? null : existingRowsByCode[rowCode];
      final draft = existing == null
          ? KnowledgeRowDraft.blank(prefilledRowCode: rowCode)
          : KnowledgeRowDraft.fromRow(existing);
      _hydrateDraft(draft, raw);
      draft.changeSummary = reason;
      accepted.add(KnowledgeImportRowResult(
        rowCode: rowCode,
        accepted: true,
        messages: const <String>[],
        draft: draft,
      ));
    }

    return KnowledgeImportSummary(
      rowsConsidered: accepted.length + rejected.length,
      rowsAccepted: accepted.length,
      rowsRejected: rejected.length,
      rejected: rejected,
      accepted: accepted,
    );
  }

  static KnowledgeImportSummary _emptyRejection(String message) {
    return KnowledgeImportSummary(
      rowsConsidered: 0,
      rowsAccepted: 0,
      rowsRejected: 1,
      rejected: <KnowledgeImportRowResult>[
        KnowledgeImportRowResult(
          rowCode: '<bundle>',
          accepted: false,
          messages: <String>[message],
        ),
      ],
      accepted: const <KnowledgeImportRowResult>[],
    );
  }

  static Map<String, dynamic> _rowToJsonMap(BafKnowledgeRow row) {
    return <String, dynamic>{
      'rowCode': row.rowCode,
      'lifecycleStatus': row.lifecycleStatus,
      'matrixVersion': row.matrixVersion,
      'taskText': row.taskText,
      'moduleCandidateCode': row.moduleCandidateCode,
      'assetFamily': row.assetFamily,
      'functionalSection': row.functionalSection,
      'componentGroup': row.componentGroup,
      'taskType': row.taskType,
      'frequency': row.frequency,
      'discipline': row.discipline,
      'ownerDisciplines': row.ownerDisciplines,
      'safetyClasses': row.safetyClasses,
      'procedureRefs': row.procedureRefs,
      'partRefs': row.partRefs,
      'deviceTags': row.deviceTags,
      'targetRefs': row.targetRefs,
      'suggestedFields': row.suggestedFields,
      'requiredForClosure': row.requiredForClosure,
      'resolverImpact': row.resolverImpact,
      'composerReadiness': row.composerReadiness,
      'confidence': row.confidence,
      'consultQuestion': row.consultQuestion,
      'sourceManual': row.sourceManual,
      'sourcePage': row.sourcePage,
      'sourceType': row.sourceType,
      'changeSummary': row.changeSummary,
      'version': row.version,
      'updatedAt': row.updatedAt.toIso8601String(),
      'updatedByName': row.updatedByName,
    };
  }

  static String _csvCellOf(BafKnowledgeRow row, String column) {
    switch (column) {
      case 'rowCode':
        return row.rowCode;
      case 'lifecycleStatus':
        return row.lifecycleStatus;
      case 'matrixVersion':
        return row.matrixVersion;
      case 'taskText':
        return row.taskText;
      case 'moduleCandidateCode':
        return row.moduleCandidateCode;
      case 'assetFamily':
        return row.assetFamily;
      case 'functionalSection':
        return row.functionalSection;
      case 'componentGroup':
        return row.componentGroup;
      case 'taskType':
        return row.taskType;
      case 'frequency':
        return row.frequency;
      case 'discipline':
        return row.discipline;
      case 'ownerDisciplines':
        return row.ownerDisciplines.join(';');
      case 'safetyClasses':
        return row.safetyClasses.join(';');
      case 'procedureRefs':
        return row.procedureRefs.join(';');
      case 'partRefs':
        return row.partRefs.join(';');
      case 'deviceTags':
        return row.deviceTags.join(';');
      case 'targetRefs':
        return row.targetRefs.join(';');
      case 'suggestedFields':
        return row.suggestedFields.join(';');
      case 'requiredForClosure':
        return row.requiredForClosure;
      case 'resolverImpact':
        return row.resolverImpact;
      case 'composerReadiness':
        return row.composerReadiness;
      case 'confidence':
        return row.confidence;
      case 'consultQuestion':
        return row.consultQuestion;
      case 'sourceManual':
        return row.sourceManual;
      case 'sourcePage':
        return row.sourcePage;
      case 'sourceType':
        return row.sourceType;
      case 'changeSummary':
        return row.changeSummary;
      case 'version':
        return row.version.toString();
      case 'updatedAt':
        return row.updatedAt.toIso8601String();
      case 'updatedByName':
        return row.updatedByName;
    }
    return '';
  }

  static void _hydrateDraft(KnowledgeRowDraft draft, Map<String, dynamic> raw) {
    draft.rowCode = (raw['rowCode'] ?? draft.rowCode).toString().trim();
    draft.taskText = (raw['taskText'] ?? draft.taskText).toString();
    draft.moduleCandidateCode =
        (raw['moduleCandidateCode'] ?? draft.moduleCandidateCode).toString();
    draft.assetFamily = (raw['assetFamily'] ?? draft.assetFamily).toString();
    draft.functionalSection =
        (raw['functionalSection'] ?? draft.functionalSection).toString();
    draft.componentGroup =
        (raw['componentGroup'] ?? draft.componentGroup).toString();
    draft.taskType = (raw['taskType'] ?? draft.taskType).toString();
    draft.frequency = (raw['frequency'] ?? draft.frequency).toString();
    draft.discipline = (raw['discipline'] ?? draft.discipline).toString();
    draft.ownerDisciplines =
        _readList(raw['ownerDisciplines'], draft.ownerDisciplines);
    draft.safetyClasses =
        _readList(raw['safetyClasses'] ?? raw['safetyClass'], draft.safetyClasses);
    draft.procedureRefs = _readList(raw['procedureRefs'], draft.procedureRefs);
    draft.partRefs = _readList(raw['partRefs'], draft.partRefs);
    draft.deviceTags = _readList(raw['deviceTags'], draft.deviceTags)
        .map((tag) => tag.toUpperCase())
        .toList();
    draft.targetRefs = _readList(raw['targetRefs'], draft.targetRefs);
    draft.suggestedFields =
        _readList(raw['suggestedFields'], draft.suggestedFields);
    draft.requiredForClosure =
        (raw['requiredForClosure'] ?? draft.requiredForClosure).toString();
    draft.resolverImpact =
        (raw['resolverImpact'] ?? draft.resolverImpact).toString();
    draft.consultQuestion =
        (raw['consultQuestion'] ?? draft.consultQuestion).toString();
    draft.sourceManual = (raw['sourceManual'] ?? draft.sourceManual).toString();
    draft.sourcePage = (raw['sourcePage'] ?? draft.sourcePage).toString();
    draft.sourceType = (raw['sourceType'] ?? draft.sourceType).toString();

    final readinessRaw = (raw['composerReadiness'] ?? '').toString().trim();
    if (readinessRaw.isNotEmpty) {
      for (final state in ComposerReadiness.values) {
        if (state.name == readinessRaw) {
          draft.composerReadiness = state;
          break;
        }
      }
    }
    final confidenceRaw = (raw['confidence'] ?? '').toString().trim();
    if (confidenceRaw.isNotEmpty) {
      for (final state in KnowledgeConfidence.values) {
        if (state.name == confidenceRaw) {
          draft.confidence = state;
          break;
        }
      }
    }
    final lifecycleRaw = (raw['lifecycleStatus'] ?? '').toString().trim();
    if (lifecycleRaw.isNotEmpty) {
      draft.lifecycleStatus = KnowledgeLifecycleStatusX.parse(lifecycleRaw);
    }
    final matrixRaw = (raw['matrixVersion'] ?? '').toString().trim();
    if (matrixRaw.isNotEmpty) draft.matrixVersion = matrixRaw;
  }

  static List<String> _readList(Object? value, List<String> fallback) {
    if (value == null) return fallback;
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text
        .split(RegExp(r'[;,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String _csvEscape(String input) {
    if (input.contains(RegExp(r'[",\n\r]'))) {
      return '"${input.replaceAll('"', '""')}"';
    }
    return input;
  }

  /// Minimal CSV parser. Supports quoted fields with embedded commas/newlines
  /// and `""` as an escaped double-quote. Refuses input that contains a
  /// stray unterminated quote rather than silently accepting it.
  static List<Map<String, dynamic>> _parseCsv(String body) {
    final rows = <List<String>>[];
    final current = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < body.length) {
      final char = body[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < body.length && body[i + 1] == '"') {
            cell.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        cell.write(char);
        i++;
        continue;
      }
      if (char == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (char == ',') {
        current.add(cell.toString());
        cell.clear();
        i++;
        continue;
      }
      if (char == '\n') {
        current.add(cell.toString());
        cell.clear();
        rows.add(List<String>.from(current));
        current.clear();
        i++;
        continue;
      }
      if (char == '\r') {
        i++;
        continue;
      }
      cell.write(char);
      i++;
    }
    if (inQuotes) {
      throw const FormatException('CSV: unterminated quoted field');
    }
    if (cell.isNotEmpty || current.isNotEmpty) {
      current.add(cell.toString());
      rows.add(List<String>.from(current));
    }
    if (rows.isEmpty) return const <Map<String, dynamic>>[];
    final headers = rows.first;
    return rows
        .skip(1)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .map((row) {
      final map = <String, dynamic>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j];
      }
      return map;
    }).toList();
  }
}
