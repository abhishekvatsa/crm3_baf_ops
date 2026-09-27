# Operational usability implementation — 26 September 2026

Status: shared implementation and connected-phone verification completed on
27 September 2026, with passing host regressions and final PDF visual acceptance.
This is not release approval.
The owner's request covers the issue-intake, abnormality and reporting gaps discussed
in this chat. Existing local changes on `claude/dev-loop-seeding` are preserved.
No production business writes, deployment, commit or release is part of this pass.

## Required user journeys

1. Report a known physical asset with a component that is not yet identified.
   Keep this distinct from a known but unlisted component and a whole-asset issue.
2. Select a frequent issue without repeating the supplied description. Ask only
   for facts absent from that selection, with explicit conditional requirements.
3. Admin, SI, Contract Supervisor or Shift Supervisor identifies the component
   later within the same asset. Preserve the original report, actor, timestamps,
   closure and linked evidence. Existing identified-target corrections retain
   their protections. This does not grant shared-register administration.
4. Maintenance starts with the process/equipment observation and possible quality
   impact. Direct abnormality logging starts with a result finding, with a clear
   process/equipment alternative. A result finding does not automatically require RA.
5. Record multiple assessed candidate causes, with evidence and optional links to
   the same-charge maintenance issue or process observation. Occurrence and causal
   contribution remain separate. Same charge never merges independent cases.
6. Record actual RA performance time and subsequent inspection result separately
   from entry time, RA requirement, and formal Quality closure. Historical missing
   completion times remain unknown; updates must not invent them or erase new evidence.
7. Export Quality PDFs by first report / RA performed / outstanding now, with source,
   observation-kind and explicit RA-required-or-completed filters. Keep case counts,
   distinct charges and linked warning evidence distinct. Include cause assessments.
8. Export the current Base–Inner Cover register in Base order. Missing, inconsistent
   or incomplete linkage evidence must not appear as confirmed vacancy. Include the
   current snapshot time and confirmation information.
9. Export maintenance for one asset, a class or all assets, with opened/assigned,
   active-during or resolved/completed date meanings and detailed evidence available.
   State the scope and completeness of the source population and current-vs-history meaning.

## Verification plan and limitations

- Meaningful host regressions: authority denial, cross-asset/charge links, replay,
  old-client compatibility, data preservation, dates and timezone boundaries,
  warning/case deduplication, incomplete linkage, and PDF scope/content.
- Actual emulator-backed connected-phone tests: normal UI issue creation, account
  transition and identification, result/process/cause/RA intake, report selection
  and PDF generation. No handler mocks or direct fixture writes count as business actions.
- Inspect representative generated PDFs for content and layout.
- Report exact passed checks and any remaining limitations; do not reuse prior-run
  counts as evidence for the new changes.

## DEV setup

`tool/dev/seed_usability_phone_fixture.py` creates only additive fixed-demo account
and catalogue fixtures. Existing fixture identities are verified, never overwritten.
The normal phone under test is a connected Android handset; the DEV application id is separate from
production. Production is not a test-data target in this pass.

## Implemented behavior

- Issue intake distinguishes not identified, known but not registered, registered,
  and whole asset. Frequent issue descriptions are used directly; extra observations
  are optional. Unlisted fault text supports the same 2,000-character boundary on
  client and server.
- Later component identification is a distinct audited command available to the
  four approved supervisory roles. It works after acknowledgement and closure,
  cannot change the physical asset, and preserves original report and linked Quality
  evidence. Narrow legacy blank-component records remain explicitly "not recorded".
- Log abnormality defaults to a result finding; process/equipment is a separate
  choice. Causes have independent stable identities and suspected/confirmed/ruled-out
  assessments. Confirmation and ruling out require evidence. Pickers link actual
  same-charge maintenance/process records without merging them or asserting causation.
- RA status never follows automatically from a colour classification or catalogue
  suggestion. New completion records require an explicitly selected actual date/time.
  SI closure, Operations completion and direct logging share this distinction.
  Unknown historical dates and classifications can remain unknown on unrelated edits.
- Quality PDF selection separates first report, performed RA, and outstanding-now
  populations. It exposes source, observation kind and RA-only filters; counts cases
  and distinct charges separately, and treats warnings as linked lifecycle evidence.
- The Base / Inner Cover register checks current assignment, profile and active
  linkage agreement. Unavailable evidence is unknown; complete absence is labelled
  "No recorded linkage", not proof of a physically vacant Base.
- Maintenance reports support selected asset/class/all assets and three explicit
  period meanings. Detailed mode includes both issue evidence and planned-job
  modules, work diary, lanes, compliance and workflow history, including retained
  removed entries. Failed reads and changing parent records refuse partial dossiers.

## Compatibility and release boundaries

The shared application and backend source contains these changes; they are not
DEV-only business implementations. DEV supplies separate identity/endpoints and
repeatable test journeys. Production users need the reviewed backend deployment
and subsequent client release to receive this entire feature set.

Firestore assessment fields are additive. Older requests that omit them preserve
existing assessment evidence. Local Isar keeps its current schema but enriched
records use a versioned envelope in the existing JSON property. An old Build29
client cannot read that enriched local envelope: an in-place local database
downgrade is not supported. This is not a database migration to Drift.

Historical missing RA dates are deliberately excluded from dated RA counts and
listed separately. Current linkage reads are server-confirmed separate snapshots,
not an atomic historical reconstruction. The reports disclose this distinction.

## Completed host verification

- Full final backend command: build, emitted-output custody, callable and
  notification inventories, asset-master and corrective checks, and Jest passed.
  Jest: **2,421 passed in 81 suites**, **249 skipped in 22 emulator-gated suites**.
  Evidence: `output/dev-usability-20260926/backend-final-complete.log`.
- Separately, **29 actual Firestore tests in 3 suites passed**, covering abnormality
  transactions, native timestamp persistence and the V2 callable boundary. These
  ran against separate loopback demo namespaces, not the phone dataset or production.
  Evidence: `output/dev-usability-20260926/backend-firestore-final.log`.
- Final broader Flutter run: **934 tests passed across 97 files**, no failures or
  skips. This includes actual Isar persistence/convergence, legacy unknown-kind
  corrections, identity replay/races, report selection, uncapped planned detail,
  and the prior selected business-domain regressions. Evidence:
  `output/dev-business-validation-20260926/usability-final-flutter-summary.json`
  and the adjacent machine log and test manifest.
- Targeted Flutter analyzer: **No issues found**, covering affected maintenance,
  abnormality, Quality, reports, synchronization and planned-report code/tests.
  Evidence: `output/dev-business-validation-20260926/usability-final-analyzer.log`.
- Host-generated PDFs: all **30 pages** were rendered and visually inspected
  (Base 1, Quality 2, maintenance 20, planned work 7). Long-text end markers
  remain, and detached headings, raw internal labels and duplicated narratives
  were corrected. Conservative whitespace and repeated table headers remain.
  Evidence: `output/dev-usability-20260926/report-visual-review-final.json`.
- Final device journeys are recorded below; earlier partial
  attempts are not counted as passes. The emulator does not establish production
  FCM delivery, IAM, App Check or release-signing behavior.

## Connected-phone verification (completed 27 September)

The first complete usability journey passed **1/1 in 3:02** on the actual
Samsung phone. It raised charge **87343** without a component or additional
comments, acknowledged it as Contract Supervisor, identified the Furnace seal,
and checked canonical preservation of the original issue and linked evidence.
Operations then created independent process and result cases with two candidate
causes, linked actual recorded evidence, explicitly selected RA performance time
and RA charge **87344**, and recorded an acceptable post-RA result. Three PDFs
were generated through the actual report composer and copied from the DEV app.
Evidence: `output/dev-usability-20260926/phone-usability-06.log`.

Inspection of those exact PDFs found two additional defects: the new form still
inferred a legacy root-cause category from selected equipment, and a class-scoped
Quality report omitted an exactly linked warning whose own asset snapshot had
only legacy type/number fields. Both were reproduced with regression tests and
corrected. New cause fields remain unknown unless entered; historical recorded
fields remain preserved. Warnings use their exact source identity and matching
physical evidence, never another case on the same charge. Conflicting identity
evidence blocks the report instead of silently discarding the warning.

The final usability rerun passed **1/1 in 2:59**, with exit code 0, using the final
shared source. Charge **83287** repeats the entire intake/identification journey,
then creates independent process and result cases, two cause assessments and RA
**83288** with an explicit actual time and acceptable post-RA result. Canonical
readback confirms both new records retained unknown legacy root cause, the exact
open warning exists, and the original maintenance evidence remains unchanged.
Evidence: `output/dev-usability-20260926/phone-usability-07.log`.

The final actual phone PDFs contain:

- Maintenance: **53 pages**, including the new issue, original unidentified
  intake and later Furnace seal identification with supervisor/basis/time.
- Quality: **4 pages**, **4 cases on 3 distinct source charges**, including both
  reporting routes and **3 open linked warnings**. The previously omitted charge
  87343 warning and new 83287 warning appear. The process-only case is evidence
  linked to the result case, not another performed-RA case. Historical undated
  RA remains separate and excluded from dated counts. The new result has no
  inferred legacy cause category; older preserved entries retain their history.
- Base / Inner Cover: **4 pages**, including confirmed Base 901 linkage and Base
  902's explicit "No recorded linkage" state.

Exact file sizes and SHA-256 hashes are recorded in
`output/dev-usability-20260926/phone-pdf-manifest.json`. Earlier phone PDFs are
preserved separately under `phone-first-complete`; they are not the final output.

Final PDF review accepted all four Quality pages, maintenance pages 5–6 containing
the new issue/identification, and the relevant Base linkage page. No clipping or
orphan headings were found in those pages. All 50 pages of the previous device
output were inspected earlier; the unchanged maintenance renderer's entire new
53-page output was not visually re-reviewed. Evidence and content assertions:
`output/dev-usability-20260926/phone-pdf-review-final07.json`.

The adjacent Quality/adjudication journey passed **1/1 in 2:41**, charge **75037**:
two maintenance-origin Quality cases (acceptable without RA and completed RA to
**75038**) were adjudicated by SI, while two direct cases (without RA and with RA
to **75039**) remained separate. The test verified that Quality adjudication did
not resolve physical maintenance. Evidence:
`output/dev-usability-20260926/phone-quality-regression.log`.

Local Base fixtures were created without overwriting prior records. Actual V2
registration, acceptance and installation commands establish **Base 901 →
DEV-USABILITY-IC-901**. **Base 902** has no recorded linkage. The phone PDF
correctly shows these two distinct states. Fixture replay preserved original
versions, linkage and audits.

Earlier unsuccessful device attempts are preserved. They exposed test selector
ambiguities and attempts to act before acknowledgement/startup recovery checks
settled. The tests now wait for normal UI readiness; no recovery protection or
account approval was bypassed. One stalled native DEV launch was restarted
without clearing its data. Emulator FCM registration warnings are expected and
do not establish push delivery. A caught sync diagnostic during deliberate test
container teardown is retained in the Quality log; it did not fail the journey.

The normal DEV app was rebuilt from `lib/main.dart`, installed without clearing
its data and launched successfully after the tests. Its home screen was visually
verified. It remains connected to the local emulators for further manual testing.
Evidence: `output/dev-usability-20260926/restore-normal-dev.log` and
`restored-dev-home.png`. The installed production app was not replaced.

Final `git diff --check` passed; only existing CRLF-normalization warnings were
emitted. All implementation changes remain local and uncommitted.
