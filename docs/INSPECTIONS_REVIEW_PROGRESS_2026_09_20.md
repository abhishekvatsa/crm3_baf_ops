# Inspection review and completed local corrections — 20 September 2026

Source evidence: `C:/Users/abhis/Downloads/CRM3_Inspections_Final_Review.pdf`.
The report reviewed b35df6bd; this work started from d038797f. Its source-derived models are not application test results. Recommendations were evaluated as audit evidence, not treated as user instructions.

## Owner decision implemented

The survey may close while findings continue through existing corrective maintenance and inspection verification. Survey closure is not a claim that every finding is resolved. Existing campaign closure admission still requires accounted targets and legitimate finding disposition/linkage; this work does not silently permit unaccounted survey coverage.

- Closed surveys expose outstanding findings and a scoped follow-up reading action. It targets an existing active finding and cannot expand survey scope.
- Corrective maintenance owns execution and physical completion. Completing maintenance does not automatically verify the inspection finding.
- Findings retain authorised acceptance, invalidation, verification and reopening independently of survey reopening. A closed survey's original closure audit remains immutable.
- Explicitly reopening survey scope remains available for actual survey work; it is unnecessary for existing-finding follow-up.
- Re-audit comparisons retain both their recording-time cutoff and the original closure revision. A follow-up recorded at the same server instant cannot become part of the original survey baseline.

## Repairs completed locally

### INS-01 — exact repair applicability and reviewed broader work

Automatic applicability requires the same physical subject and exact component scope where a component is identified. Position-specific readings and broader work require an explicit authorised supervisor review. Review records bind the inspected target/component/position, repair identity, scope, description, reviewed revision, actor, reason and time. Inner Cover serial/host safeguards remain mandatory; review cannot waive physical identity.

The screen reads the selected maintenance issue from the server and presents its scope and description before review. A reviewed replacement requires the current finding revision. Original links and review records are retained; verification checks the immutable review evidence as well as the current repair. Linked work remains visibly outstanding rather than appearing resolved.

### INS-02 — physical repair chronology and retained verification basis

Resolved verification of linked maintenance requires technical completion, a valid ticket revision and physical completion after the episode's first adverse reading and no later than the verification reading. It uses endDate and the current maintenance episode start, not administrative updatedAt. The immutable verification retains the ticket revision, subject reference, physical dates and scope review relied on. Original accepted command replay remains unchanged.

### INS-03 — report population evidence

Reports strictly read independently stored finding creation events and require their exact identities to match the finding population, including terminal and corrected episodes. Missing, duplicate and extra identities refuse completeness; an omitted history read is not evidence of an empty history.

New campaigns additionally maintain an atomic finding-creation manifest. The report compares that manifest with creation history, detecting loss of both a finding and its creation event when the root manifest survives. Existing campaigns without a manifest still require the retained creation history. No legacy manifest is silently backfilled, and no historical production reconciliation or protection against coordinated corruption of every evidence source is claimed.

### INS-04 — incomplete campaign browsing

Campaign snapshots retain rejected document identities and distinguish server freshness from population completeness. Browse screens qualify counts, choices and empty states while retaining valid rows. A partial or cached list does not establish that a missing campaign was deleted. Reports and finding cards distinguish outstanding findings from a closed survey.

### Historical amendments, actor binding and recovery

The observation editor exposes a reasoned historical amendment for an older reading or a closed survey. Original readings and closure audits remain unchanged. A correction can surface a new actionable finding without reopening the survey. Existing episode ownership, competing-finding, current-evidence and context checks remain enforced.

Inspection actions retain the account that opened the action across awaited dialogs. The existing workflow command journal and origin-bound executor own durable exact-envelope dispatch and recovery. Native restart tests cover record, link, verify, adjudicate, context review and survey status: an uncertain request survives database closure/reopening; a different account cannot send it; the original account retries the same envelope; a stored acceptance replays without a second send. These tests cover saved submitted commands, not unsent editor drafts or a physical phone process-kill campaign.

## Verification

- Backend build, emitted-output custody, callable/notification inventories and their tool tests passed.
- Full Functions host Jest: 72 suites, 2,035 tests passed in the recorded run; 18 emulator suites / 189 tests were skipped by that host run.
- Separately ran the inspection Firestore emulator suite: 16 tests passed, including real Timestamp persistence, closed-survey follow-up/review/verification, replay and concurrent episode operations. The isolated emulator was stopped afterward.
- Final selected Flutter run: 170 tests passed, covering all inspection test files, native account-bound recovery, architecture/persistence contracts, programme ledger and affected operational-event screens/models.
- Flutter analyzer: no issues in the recorded completed run.
- Canonical post-codegen source audit: 150/150 checks passed.
- Diff whitespace validation passed (only an existing line-ending normalization warning).

Current inventory refresh: A-03 601 operations / 2,095 sites / 72 surfaces; A-04 55 fields / 104 inherited decoder surfaces; A-05 104 surfaces / 60 strict-reader files / 479 risk candidates. Historical custody receipts were not changed. An existing operational-events empty-state widget was moved intact into its existing summary part to retain the established screen-size boundary; unrelated business edits were preserved.

## Release and historical-data boundaries

These are local code and test results. No commit, push, production mutation, deployment, APK, AAB or distribution was performed by this inspection task. The client and backend additions require a coordinated release before users can use them; production reconciliation and physical-device pilot validation are separate evidence. A legacy broad repair link lacking a scope review must be reviewed before it can justify resolution.

The previously recorded UV installation-date correction and compatible-client/backend rollout requirements remain pending in `docs/DOMAIN_AUDIT_REMEDIATION_LEDGER.md`. Other work already present or being edited in this shared working tree was preserved; the recorded counts describe the tested snapshot, not unverified later edits.
