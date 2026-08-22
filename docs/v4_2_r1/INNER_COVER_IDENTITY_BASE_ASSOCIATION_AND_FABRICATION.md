# Inner Cover Identity, Base Association and Fabrication Lifecycle

Status: SOURCE_IMPLEMENTED

Date: 2026-08-15

## Purpose

Operations normally addresses an Inner Cover by the Base carrying it. That is
useful operating language, but Base number is not durable physical identity.
This tranche keeps both truths:

- Base number is the primary operational address;
- Inner Cover serial number is the permanent physical identity;
- every change of association is explicit, versioned and historically retained;
- issue records freeze the Base/serial relationship that existed at event time.

A later transfer or swap therefore cannot make an old bulging, leakage or
maintenance history appear to belong to the wrong physical cover.

## Authoritative Records

| Collection | Purpose |
|---|---|
| `inner_cover_profiles` | Current serial identity, source, lifecycle state, acceptance and complete current-Base projection |
| `base_inner_cover_assignments` | One current Inner Cover per governed Base |
| `inner_cover_linkages` | Immutable association history with complete installation and removal evidence |
| `inner_cover_serial_claims` | Private normalized-serial uniqueness custody |
| `inner_cover_fabrications` | Resulting cover and section-level fabrication genealogy |
| `inner_cover_donor_part_claims` | Private single-use custody for known donor sections |
| `inner_cover_lifecycle_audits` | Admin-readable command before/after evidence, including donor effects |
| `inner_cover_lifecycle_receipts` | Private idempotency and replay custody |

The current profile's Base fields are an all-or-none projection. An installed
cover must carry Base instance ID, Base number, Base name and linkage ID. Every
other state must carry none of them. Partial projections fail closed in the
Function and strict client decoder.

## Lifecycle and Commands

Registration admits purchased, fabricated and governed legacy-existing covers.
Every new registration begins at `awaitingInspection`. Acceptance moves an
eligible cover to `available`; only an available cover may be linked.

The governed command surface supports:

- register and accept;
- set an allowed uninstalled pool/repair/retirement state;
- link an available cover to an empty Base;
- delink a cover into a stated pool or maintenance condition;
- transfer an installed cover to an empty Base;
- replace an installed cover with an available cover;
- atomically swap the installed covers of two Bases.

Transfer, replacement and swap close the old linkage records and create new
ones in the same transaction. They never rewrite prior history. Expected
profile and assignment versions prevent decisions made from stale screens.

## Fabrication Genealogy

A fabricated Inner Cover must describe exactly one of each required section:

1. lower assembly;
2. flat vertical section;
3. corrugated shell;
4. top cover.

Each section records its material source, optional measured length, cut count
and notes. Reused material is classified as known donor or explicitly unknown
legacy ancestry. A known donor requires the donor Inner Cover, reviewed donor
version and a stable donor-section key. The same donor part cannot be allocated
twice. Donors must already be in a salvage state; allocation advances them to
`partiallyDismantled` and records that before/after effect in the command audit.

Traceability is explicit:

- `T0`: legacy or unknown ancestry exists;
- `T2`: reused ancestry is known and claimed;
- `T3`: purchased/new material has complete declared provenance.

Acceptance reference, leak-test reference and NDT reference remain distinct.
Registration is not acceptance.

Each profile may also retain a plant `incorporatedOn` date separately from
supplier receipt or fabrication completion. The distinction prevents a
historical Base-use date from being presented as purchasing or fabrication
evidence. Owner-declared baseline origin is recorded explicitly:

- `ownerDeclaredNew` means the cover is known operationally as new but its
  purchase/source dossier is unavailable; it receives limited `T1` trace;
- `ownerDeclaredFabricated` means fabrication is known but section ancestry is
  unavailable; every unknown section remains explicit and the result is `T0`;
- `legacyUndocumented` means neither documented purchase nor fabrication
  provenance is asserted and remains `T0`.

These values supplement the backward-compatible source envelope, so already
distributed clients can still decode the profile without inventing `T3`
provenance.

## Issue Attribution

The issue form retains both routes:

- `BASE`: the Base is the reported asset and the current Inner Cover position
  is frozen as linked or none linked;
- `INNER COVER (BY BASE)`: the user enters the familiar Base number, but submit
  is allowed only when a governed physical Inner Cover is currently linked.

The frozen event evidence contains the Base instance and number, serial and
cover identity, linkage ID, assignment version, link time, event time, and the
user/time that confirmed the relationship. Partial identity, a mismatched Base,
or confirmation before the event fails closed. Open tickets, resolution views
and closed dossiers all display the event-time serial rather than the current
serial.

## Authority and Policy

- Every approved user may read profiles, current assignments, linkage history
  and fabrication dossiers.
- Only Admin may issue lifecycle commands.
- All lifecycle writes use the existing governed `mutateAssetHierarchy`
  callable, including shared App Check/admission controls and transactional
  Admin revalidation.
- Direct client writes to lifecycle, claim, audit and receipt collections are
  denied. Audits are Admin-readable; claims and receipts are private.
- Exact replay is write-free and requires the receipt, current profile and audit
  to remain mutually consistent.

## Pilot Reconciliation Gate

Source merge does not prove the plant's starting associations. Before lifecycle
mutations are enabled for pilot:

1. create exactly one active governed Base class and one active governed Inner
   Cover class;
2. register every in-scope Base as a governed physical asset;
3. inventory every in-scope serial, including physical condition and source;
4. record each current Base/serial pairing or explicitly confirm the Base has
   no cover;
5. identify spare, under-repair, rejected, salvage and unknown-location covers;
6. enter known fabricated ancestry and mark genuinely unknown legacy ancestry
   as `T0` without invention;
7. reconcile duplicate serials, duplicate Base pairings and ambiguous physical
   custody before any write;
8. perform a readback proving profile, assignment and active linkage agreement;
9. retain the signed inventory and readback as deployment evidence.

The pilot must remain blocked if an existing physical pairing is absent from
the governed records, a serial is ambiguous, or a current projection is partial.
No historical pairing may be inferred from issue counts or from today's Base
position.

## Verification Boundary

Final local verification for this source tranche includes:

- Flutter analysis: clean;
- complete Flutter suite: 963 passed, 1 intentionally skipped;
- complete Functions unit/custody suite: 462 passed, with 74 emulator-only
  tests intentionally skipped by that unit command;
- Firestore Rules suite: 171 passed;
- governed Functions emulator suite: 74 passed, followed by a final 10-test
  asset/lifecycle subset rerun after acceptance-state hardening;
- A-05 production-sweep contracts: 17 passed, including populated real-Dart
  reconciliation for all four app-readable Inner Cover collections;
- canonical source audit: 138/138 passed;
- whole-app reconciliation source audit: 23/23 passed.

No production data migration, Firebase deployment, client build, device proof,
pilot authorization or gate closure is claimed by this source document.
