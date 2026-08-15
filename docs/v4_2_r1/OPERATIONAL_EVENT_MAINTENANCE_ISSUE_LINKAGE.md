# Operational Event and Maintenance Issue Linkage

## Status

This source tranche implements an explicit relationship between one immutable
operational-event occurrence and one maintenance issue. It is source and CI
evidence only until the matching Function and Firestore Rules are deployed.

## Business behavior

Approved Operations, Shift Supervisor, Contract Supervisor, SI and Admin users
can link a synchronized maintenance issue to an operational event as:

- caused by the disruption;
- restoration work raised in response to the disruption; or
- maintenance work affected by the disruption.

Open issues are presented first, but resolved synchronized issues remain
available so historical disruption evidence can be completed retrospectively.

Plant-wide events may link any visible issue. Asset-class and asset-scoped
events require the issue's governed asset identity to fall inside the frozen
event scope. A free-text reason records why the two records belong together.

The event workspace shows links for the current occurrence separately from
prior occurrences. The maintenance issue exposes the reverse history. The
Operations report counts unique linked issues and shows the link count on each
disruption occurrence.

## Authority and evidence

`LINK_OPERATIONAL_EVENT_ISSUE` is routed through the existing
`mutateAssetHierarchy` callable. Actor authority is checked before the
transaction and revalidated inside it. The command requires exact event and
issue versions and performs one atomic transaction that:

- appends a bounded link ID to the current event occurrence;
- appends the same ID to the maintenance issue projection;
- writes an immutable `operational_event_issue_links` record;
- writes an Admin-readable immutable audit record; and
- writes a private idempotency receipt.

The immutable record freezes event occurrence identity, scope and severity,
the issue identity and lifecycle at link time, relationship, reason, actor and
server commit time. A second link between the same event occurrence and issue
is rejected. Replaying the same request returns the original evidence without
writes. Replay is receipt-first and validates the immutable link and audit; it
does not depend on the event or issue remaining in their original state.

Ordinary event edits preserve current link IDs. Reopening an event moves those
IDs into the completed occurrence and starts the new occurrence with an empty
projection, so later recurrence cannot rewrite earlier linkage.

## Bounds and compatibility

An event occurrence accepts at most 100 issue links and a maintenance issue at
most 50 event links. Missing projection fields on legacy records decode as an
empty list; malformed, duplicate, or over-bound present fields fail closed.

The local `MaintenanceRecord` projection advances governed Isar provenance
from v5 to v6. The additive migration retains the exact v5 fingerprint and old
rows open with an empty link list. The populated v1, v2-adoption and v3
migration rehearsals cover the new target version.

The A-05 production inventory treats `operational_event_issue_links` as a real
Dart-decoded operational collection. Audits and receipts are explicitly
classified as server controls. The strict decoder validates immutable
identity, chronology, relationship, text bounds, scope and issue-to-scope
agreement.

## Deliberate boundary

This tranche links an already synchronized issue. It does not create a
maintenance issue inside the linkage transaction and does not claim atomic
issue creation. Direct create-and-link ergonomics may be added only through a
server-governed maintenance-creation command; the current offline-first issue
creation path cannot truthfully promise that atomic boundary.

No production data is migrated or mutated by this source tranche.
