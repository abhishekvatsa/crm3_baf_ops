# CRM3 Maintenance Workflow — Authority Precedence and Reviewer Adjudication (v3.2)

## Governing rule

The external review is valuable adversarial input, but it is not the business
or architectural authority. The reviewer did not have the complete record of
later agreements. Every criticism is therefore decided in this order:

1. explicit later user decisions and the consolidated frozen business contract;
2. the generated policy and executable source implementing those decisions;
3. verified behaviour of the pre-existing app;
4. reviewer preference or recommendation.

A criticism that conflicts with a later agreement is not implemented merely to
satisfy the review. A criticism that exposes a real source defect, integration
regression, unhandled cascade or missing proof is retained and acted on.

## Decisions already binding for this candidate

- All maintenance-workflow lifecycle mutations use the **online command
  gateway**.
- A command is retained locally only for an uncertain outcome: the request may
  have reached the server but the receipt was lost.
- This decision does not redefine ordinary local drafting in unrelated,
  pre-existing non-workflow features.
- EMD is a real lane digitally represented by Admin/SI in v1, with represented
  lane and delegation basis captured.
- Operations may acknowledge OPRN work, record progress and comply; Shift
  Supervisor/SI/Admin closes or terminates OPRN.
- Refractory may acknowledge and work RED; Senior Refractory/SI/Admin closes or
  terminates RED.
- Lane-less creation, subsequent lane finalisation, protected-progress rules,
  return-for-correction, one counter-condition, `awaitingPreparation`, and
  server-resolved RED succession are accepted workflow semantics.

## Item-by-item adjudication

| Review item | Adjudication under the agreed basis | v3.2 action |
|---|---|---|
| F1 emulator suites not executed | Valid verification gate, not a code defect | Retained as mandatory pre-pilot proof |
| F2 Flutter analyzer/Isar generation not executed | Valid verification gate | Retained; source-only audit does not overclaim |
| F3 offline acknowledgement requires ratification | **Superseded**: online-only lifecycle was already authorised | No hybrid reintroduction; explicit online/not-queued UX added |
| F4 A2 decisions need ratification | **Superseded** by the user's later agreement and consolidated frozen contract | Treated as binding; precedence now recorded explicitly |
| F5 generated policy parity incomplete | Largely already closed in v3.1; role universe still hand-maintained | Generator extended to emit the workflow role universe; callable consumes it |
| F6 escalation scheduler needs runtime proof | Valid | Retained as deployment/emulator gate |
| O1 generic command payload factory | Real hardening opportunity, not a present defect; all current payload seams match | Kept as future typed-constructor improvement; no unnecessary rewrite in this pass |
| O2 client-generated counter successor ID | Safe/idempotent under current server validation and command receipt model | No change; monitor as consistency hardening only |
| T1 workflow notifier lacks dead-token cleanup | Valid | Fixed by reusing the mature shared notification sender and race-safe cleanup |
| T2 notification routing is parallel hardcode | Valid drift risk, though `AGENCY_TO_ROLES` is not the correct lane authority | Fixed from the stronger source: generated `LANE_POLICY` |
| T3 online-only flag unused in UI | Valid UX gap, not evidence against online-only architecture | Fixed; assignment explicitly states online authority and no offline queue |
| T4 workflow pull differs from mature watermark system | Difference is intentional; reviewer overstated it as a defect | Separate collection watermarks retained; collection failures isolated and reported |
| T5 no workflow analogue of local-link repair | Not applicable: workflow consumers do not join through `JobLaneRecord.jobExecutionLocalId` | Verified by full-tree source audit; no repair added |
| T6 provider registration/disposal | Provider graph is reachable; one dormant lane-inbox provider is unused but harmless | Recorded as cleanup opportunity, not a release defect |
| T7 roles maintained in four places | Valid structural drift risk | Generated role universe now drives callable filtering |
| T8 admin browser lacks workflow collections | Supportability scope, not correctness | Retained as optional pilot-support enhancement |
| T9 enum fallback sweep | Valid and broader than review identified | Full `lib/` switch sweep completed; untouched UI switches fixed |
| T10 timestamp parsing | Review concern is false for v3.1 source | `_date` already accepts Firestore `Timestamp`; no change |
| T11 assigned-agency legacy bridge | Valid coherence question | Live governed creation paths create both execution and workflow; legacy display field retained as compatibility projection |
| C-DEFECT-1 batch execution write uses full `toMap()` | **Valid high-severity defect** | Fixed; batch uses `toClientWritableMap()` and that map now also removes `workflowSchemaVersion` |
| C-DEFECT-2 online-only assignment/completion is regression | **Rejected as stale architecture criticism** | Online-only retained; no input is silently discarded because the form stays open; clearer failure message added |
| C-OBS-3 schema-version branch fragile | Valid hardening concern | `JobExecution` now defaults to schema 0; only server-proven aggregate creation elevates to 1 |
| C-OBS-4 home-screen notification route | Valid | Foreground/background tap and terminated-app initial message now navigate imperatively to the workflow |
| C-DEFECT-5 workflow failure corrupts mature sync status | Valid integration defect | Fixed with independently caught supplemental workflow retry/pull |
| C-DEFECT-6 notification tap dead-end | Valid | Fixed through authenticated HomeScreen navigation and workflow-detail opening |
| C-DEFECT-7 non-atomic multi-collection watermark | Risk was overstated; independent watermarks are deliberate | Parent-first ordering retained; per-collection failure isolation prevents cascade abort |
| C-OBS-8 workflow visibility tied to planned-maintenance permission | Not a current restriction: `canViewPlannedMaintenance` equals approved-user visibility | No change |
| C-DEFECT-9 legacy module permission changed | Mixed: Operations change is agreed; loss of `others` compatibility was unintended | Operations retained; Senior Refractory access to historical `others` restored |
| C-DEFECT-10 refractory remap bifurcates old data | Historical split is real, but blind migration is unsafe | Existing `others` remains operable; all new published-template parsers now map Refractory and EMD correctly |

## Result

The review has been used exactly as intended: as a source of hypotheses to
prove or disprove. It has not been allowed to override already-set plant and
architecture decisions.
