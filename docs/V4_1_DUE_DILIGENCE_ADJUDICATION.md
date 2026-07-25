# v4.1 Due-Diligence Adjudication

## Governing programme decision

v3.3/v4 is the successor architecture. The current deployed application remains operationally canonical until governed integration, but conflicting legacy mechanisms do not outrank the successor design. Valid current-app security, release and operational closures must be absorbed into v4.

## Review findings adjudicated

| Review item | Adjudication | v4.1 treatment |
|---|---|---|
| Immediate replacement/merge/build is NO-GO | Agreed and already declared | Retained as a runtime/governance gate |
| Reconcile against exact current `main` | Mandatory integration gate; asserted `633c58bb…` could not be verified from this environment | No repository mutation; explicit baseline note added |
| Missing Firebase build files | Real build prerequisite, intentionally excluded from evidence custody | Custody/restoration guide added; NO-GO remains |
| Firebase Android app ID contradiction | Valid source defect | `firebase.json` and startup contract aligned to permanent registration `…fba14…` |
| Admin user-document whitelist | Valid Rules defect | Exact `hasOnly` schema perimeter added and source-tested |
| Escalation ISO String/Timestamp mismatch | Rejected as stated | Actual Firestore adapter converts all lifecycle `*At`/`*DueAt` ISO values to native Timestamp; executable regression tests added |
| Compliance mapper incomplete | Valid client projection defect | Complete lifecycle mapper implemented; pure mapper seam and Flutter test source added |
| Provisional Isar bindings | Agreed deliberate release blocker | No weakening; pinned generation/migration remains required |
| Dependency advisories | External/current gate requiring controlled lockfile remediation | Not altered without verified dependency resolution |
| Client/widget tests insufficient | Valid verification gap | Compliance mapper test source added; full Flutter execution remains required |
| Root documentation inadequate | Valid maintainability gap | Root README replaced with architecture/build/validation guide |
| Stage 2D should remain sole programme | Conflicts with successor-programme agreement | Current app stays operational authority; v4 proceeds as governed successor branch/programme |

## Timestamp persistence proof

Domain handlers deliberately use ISO strings so commands, receipts and deterministic unit fixtures remain JSON-safe. `FirebaseWorkflowStore` is the sole production workflow persistence boundary. It recursively converts ISO instants for timestamp-named fields into `admin.firestore.Timestamp` before transaction writes.

v4.1 adds executable tests for:

- `nextEscalationAt`
- `acknowledgementDueAt`
- `complianceDueAt`
- lifecycle actor timestamps
- nested escalation timestamps
- non-timestamp fields remaining unchanged

This closes the review's allegation at the actual database boundary while preserving the established domain model.

## Remaining disposition

v4.1 remains:

- principal successor-source candidate: **GO**;
- source of a governed reconciliation branch: **CONDITIONAL GO**;
- direct replacement, merge, build, deployment or distribution: **NO-GO**.
