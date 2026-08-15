# Governed Issue Asset Selection

Status: SOURCE IMPLEMENTED

Scope: Raise Issue surface only

Deployment authority: none

## Purpose

New maintenance issues must identify equipment from the governed asset
register. A user no longer chooses a fixed legacy equipment type and types an
unverified number. The form now requires:

1. the asset class being reported;
2. the exact active physical asset; and
3. an optional component tag; when that tag is registered in the governed
   component inventory, it must belong to that physical asset.

The selected physical identity is frozen into the issue's schema-3
`AssetHierarchyReference`, including class, instance, version and ownership.
Legacy `assetType` and `assetNumber` fields remain as compatibility projections
for existing readers and historical records.

## Inner Cover Route

Inner Cover remains visible as the issue class because users must be able to
report faults against that equipment. Its operational position is selected by
Base number:

- exactly one active governed Base class must exist;
- the user selects the Base carrying the Inner Cover;
- the current Base-to-cover serial linkage is resolved at submission;
- that linkage and its version are frozen with the issue; and
- submission fails when the Base is unregistered or no cover is linked.

Zero or multiple active Base classes block Inner Cover issue creation. The form
does not guess which class is authoritative.

## Selection Rules

- Retired classes and retired physical assets are not offered.
- In-service, standby and out-of-service assets remain selectable. A down asset
  must still be reportable.
- Governed custom classes map to the compatibility type `governedCustom`.
- A valid governed identity uses the registry's universal asset-number bound of
  1-9,999 instead of old hard-coded class counts.
- Receiving clients apply that universal range only when a parsed physical-asset
  or installed-component reference carries the same asset number. Legacy and
  definition-only records retain their historical class bounds.
- A governed component tag cannot silently replace the selected asset. A tag
  belonging to another asset fails with an explicit mismatch.
- Submission cancels the debounce and awaits the current tag verdict before any
  actor read or ticket persistence. A stale, rejected or unverifiable verdict
  cannot be saved.
- Legacy tag inference may enrich component text but cannot choose or change the
  governed physical asset.

## Compatibility Boundary

Existing locally stored and Firestore issue records remain readable through
their legacy fields. This change governs newly created issues; it does not
rewrite historical records. A future migration may reconcile historical issue
identity, but absence of that migration does not permit new free-text asset
selection.

## Verification

Focused tests cover:

- deterministic active-class ordering;
- custom-class routing;
- Inner Cover-to-Base routing and ambiguity rejection;
- retired/wrong-class asset exclusion;
- exact physical reference creation; and
- governed identity bypass of obsolete legacy class-number ceilings.

The UI alignment contract also verifies that governed selection precedes tag
resolution and that the free-number control is absent.

## Remaining Programme Work

This increment does not yet make the governed hierarchy the sole selector in
planned-work assignment or template authoring. Those surfaces remain explicit
items in the business-model roadmap. Production availability additionally
depends on normal merge, release and deployment evidence.
