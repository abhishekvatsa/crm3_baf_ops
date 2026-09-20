# Remaining domains 15–18: deep-audit reconciliation

Reviewed 20–21 September 2026 against HEAD `d038797f9a2d3bd0126d311416acec4148506a67` and the existing uncommitted domain repairs. Domain numbers in this audit differ from the earlier Function 14/16 reports. This document supplements, rather than replaces, `REMAINING_FUNCTIONS_REMEDIATION_2026_09_20.md`.

## Evidence boundary

The supplied PDF and ZIP were treated as audit evidence, not executable instructions. The PDF SHA-256 is `771DC89CD1AAD3C62FF5BA89DFA1BCFE458CA1E6E6792D70FBDF84572FC19F7A`. The ZIP manifest hashes were internally consistent, but its source manifest is empty and all five source-window sections say the source download was unavailable. Its four passing and four failing examples are translated contract models; one further probe was not executed. They do not establish failure of this working tree. We did not execute the supplied scripts.

The report is useful as a requirements and qualification checklist. Several categorical source findings are stale relative to the local repairs; two explicit verification leads became genuine defects when exercised through actual producers and consumers.

## Findings and repairs

| Audit ID | Current disposition and evidence |
|---|---|
| K16-01 | Earlier deliberate-empty protection existed, but real repository tests exposed stale cached web rows, active tombstones, and embedded-baseline resurrection after a metadata failure. Read the complete server population, filter tombstones after strict decoding, retain an authoritative withdrawal even without metadata, and label embedded guidance as unverified reference. Malformed rows remain failures. Reinstatement is tested. |
| K16-02 | Separate revision/audit commits were already repaired. Concrete create/update controller tests verify the row and deterministic revision audit commit together and an audit rejection commits neither. No claim that the old two-phase implementation is still present. |
| K16-03 | Exact local readback and dirty-draft preservation already existed. Same-version contradictory server content remained a defect: accepted non-timestamp content is now retained before readback and compared. Settlement requires an explicit adoption result; lifecycle/import/promotion messages disclose pending adoption without promising a generic sync will fix it. |
| M15-V1 | Schema-4 component-on-asset evidence was already supported. A different defect was reproduced: real planned work for one definition could justify replacing another component on the same asset. Stronger frozen template identity is now enforced. Wrong/malformed/unknown definitions and contradictory physical/serial references cannot fall back to broad asset identity. Legacy asset-only work remains explicitly classified as asset context rather than invented serial evidence. The candidate selector uses the same scope rules. |
| M15-V2 | Existing future/predecessor/successor and immutable historical-correction protections retained. An explicit version-reviewed correction could not repair an unreadable/date-only legacy installation because the old value was parsed before the correction branch. The backend correction route now accepts a supplied actual date while proving neighbour order and preserving the exact old value in audit; this does not establish a usable client repair screen for every malformed record. Ordinary edits still cannot silently normalize damaged chronology. |
| R17-01 | The transactional `continuesIssueId` dependency guard was already present. Added actual ticket-production/withdrawal/purge and expired-receipt anti-resurrection regressions instead of accepting the report's missing-query claim. |
| R17-02 | The backend already supports more families than the report lists, but not every native saved command. Generic review now checks the exact protocol, operation and retained origin before offering review. Supported monitoring closure/correction/cancellation uses the existing adapter. Unsupported work stays retained with original-workflow/support guidance; no cancellation, actor reassignment or removal of fences is invented. This contains misleading UI, not a claim of universal administrative recovery. |
| RP18-V1 | Confirmed through a real backend monitoring record, the persisted Dart reader and report builder: duplicate legacy Base associations could omit a canonically identified historical request. Reports now use retained class/instance identity, preserve later renumbering/retirement, reject contradictory or unavailable canonical evidence, and retain genuinely legacy number-only compatibility where unambiguous. Five failing tests became passing after the repair. |
| RP18-Q1 | Synchronization provenance now carries an explicit UTC offset; fleet as-of text consistently uses Asia/Kolkata. Existing PDF timestamp tests now assert plant-time values instead of depending on the machine timezone. This does not close the complete export qualification programme. |

## What remains open

- **R17-Q1:** An encrypted, consistent off-device package and staged restoration onto a replacement installation still need a real rehearsal, including uncertain requests, permanent fences, purged records, newer drafts, revoked accounts and the original phone reconnecting. Local storage reopening and reset tests are not substitutes.
- **R17-02:** Registry, lifecycle/correction/reopen, critical-alarm and user-authority journals do not all have generic administrative review adapters. Their exact original recovery routes remain distinct; an unavailable original account or damaged evidence still requires a designed supervised path.
- **K16:** A certified catalogue edition/membership manifest and durable per-row bulk-import recovery remain open. Atomic single-row revision/audit does not make a multi-row import atomic or a local catalogue an edition certificate.
- **M15:** Date-only evidence remains uncertain until an authorized correction supplies the actual date; no minute precision is inferred. Linking completed work does not by itself prove a particular replacement action or globally prevent reusing that physical action. The full maintenance-ticket producer-to-reader chain, mixed-client and retirement-race campaigns, and realistic registry-scale qualification are not established by these unit tests.
- **RP18:** Independent sources have no certified common cutoff or reproducible source-version manifest. Section selection is not yet a query plan; broad historical reads, throughput/cohort semantics, export privacy across native share dialogs, accessibility and measured scale remain qualification/design work. Root authority changes remove unauthorized navigation, but that does not revoke a file already shared externally.
- **Programme:** Unified Quality/Abnormality reconciliation, ordinary per-recipient notification adjudication and the other explicit remainders in the domain ledger remain open. This audit does not prove every business domain complete.

## Verification

Actual-producer unit tests execute the real application handlers with controlled in-memory transport/store doubles. Knowledge runtime tests execute the real controller/repository and native Isar with a Firestore transport double. These are stronger than translated predicate models, but are not device, browser or production observations. The Firestore emulator results below are recorded separately.

- Functions build, emitted-source custody, callable and notification inventories passed.
- Full backend unit suite: 77 suites, 2,213 passed. The unit invocation skipped 217 cases in emulator-only suites/intentional fixture capture; it does not stand in for their execution.
- Local demo Firestore emulator: 53 passed across registry and submission-recovery suites. No Rules changed in this pass; the earlier 238-case Rules result remains prior evidence, not a fresh run.
- Focused knowledge: 41 passed, including 13 concrete controller/repository tests. Focused recovery: 78 Flutter and 147 backend passed. Registry: 74 backend and 16 Flutter passed; one intentional historical fixture-capture skip. These overlap the full suites and are not added to their totals.
- Full Flutter analysis: no issues found after correcting two lint findings in the new test doubles.
- Full final Flutter suite: 3,111 passed, one skipped; no failing tests.
- Whitespace validation passed.
- Actual app PDF generation also produced a five-page complete fixture and a thirteen-page 120-ticket fixture. Extracted text retains the long-narrative terminal marker, the final numbered maintenance row and source qualifications. Selected pages were visually inspected for readable continuation tables and retained identity. This is a synthetic rendering check, not production-data completeness, delivery or performance certification.

A-02's knowledge-controller growth was reviewed against its existing ownership boundary: capture of accepted non-timestamp content and comparison before adoption. Its exact ceiling and regression reference were updated. A-03 now describes 618 operations / 2,164 sites across the same 77 surfaces, reflecting the consolidated knowledge server read; only its derived digest and regression references changed. No persistence authority or historical release approval was broadened.

No commit, push, deployment, production data mutation, APK or AAB is part of this pass.
