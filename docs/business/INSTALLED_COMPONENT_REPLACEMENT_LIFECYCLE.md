# Installed Component Replacement Lifecycle

## Purpose

The governed asset registry distinguishes a physical component replacement from
editing a component's descriptive data. Replacement retires one physical
identity and installs another while preserving one traceable lifecycle.

## Delivered behavior

- An approved Admin can replace an active installed component from the physical
  asset registry.
- The incoming component must use the same active hierarchy definition and the
  same physical asset as the outgoing component.
- Installation date and time and a change reason are mandatory.
- Manufacturer, model, serial number, physical tag, service state, and ownership
  are recorded for the incoming identity.
- The server performs retirement, installation, asset-version advancement, tag
  release or transfer, and immutable audit writes in one Firestore transaction.
- The active-component count is validated and remains unchanged.
- The outgoing record retains its historical tag and receives
  `replacedByComponentInstanceId`; the incoming record receives
  `replacesComponentInstanceId`. Both share `componentLineageId`.
- A superseded identity is terminal history and cannot be restored.
- Exact request replay returns the original result only while the receipt,
  incoming identity, outgoing identity, and both audit records still agree.
- An Admin may optionally bind a resolved maintenance issue or completed,
  non-cancelled planned job as replacement evidence. The server revalidates its
  lifecycle, version, exact physical-asset identity and, when present, outgoing
  installed-component identity in the replacement transaction.
- Accepted work evidence is frozen into both lifecycle audits and the request
  receipt; later source-record edits cannot rewrite the accepted snapshot.
- The Admin UI exposes replacement and lifecycle history through the component
  actions menu. History includes legacy direct-identity entries and new
  lineage-aware entries.
- Every approved operational user can inspect current assets, operating
  condition, installed and retired component identities, and replacement
  lineage from the read-only Asset registry screen.
- Registry mutation controls and immutable hierarchy-audit records remain
  Admin-only; the operational screen does not broaden either authority.

## Integrity invariants

1. The asset class, physical asset, outgoing component, and hierarchy definition
   agree before any write.
2. The outgoing component is active and version-matched.
3. The incoming identity is a new canonical UUID.
4. Replacement cannot change the governed component definition.
5. The physical asset version is matched and advanced once.
6. A tag claim either belongs to the outgoing identity, is unclaimed, or is
   transferred only after the existing owner is shown and explicitly approved.
7. A malformed or missing existing tag claim fails closed.
8. Retirement and installation cannot commit independently.
9. The outgoing and incoming audit snapshots share the request, actor, time,
   lineage, and reciprocal identity references.

## Business use

The operation is reusable for furnace burner blocks, instruments, valves,
relays, motors, cables, base components, forced-cooler components, and other
installed physical items represented in the governed hierarchy. Maintenance
issues and planned-work modules may record that replacement work was performed.
Eligible completed work is presented to the Admin during replacement, while the
registry action remains the authority that confirms the physical identity
change. Manual Admin confirmation remains available when no suitable work
record exists.

## Deliberate boundary

Maintenance closure never mutates the asset registry implicitly. The approval
bridge is evidence-assisted, not evidence-driven: an Admin must still review and
commit the replacement, the exact incoming physical identity, installation time
and reason. Legacy or definition-only work without exact governed physical-asset
identity is deliberately ineligible.
