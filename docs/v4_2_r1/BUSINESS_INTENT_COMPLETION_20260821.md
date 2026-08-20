# CRM-III BAF Ops Business Intent Completion

Date: 21 August 2026

## Decision

The accepted business intents are complete in successor source. The implementation
now carries each governed mutation through a server-owned command or existing
atomic mutation boundary, exposes the capability to the entitled user in the app,
and retains strict persisted-data, Rules, audit, and idempotency controls.

This decision is source authority only. It does not claim that these changes are
present in Build 12, deployed to production, installed on a device, or admitted for
pilot distribution. A later numbered build, backend/Rules deployment, and role-based
device validation remain separate release activities.

## Original Intent Matrix

### Furnace stuck-up

- Operations can raise the classified Furnace stuck-up case against the familiar
  Furnace and Base route. Base is the only Inner-Cover identity the intake asks
  the user to choose; the app resolves the currently linked serial in context.
- The current Base-to-Inner-Cover association, linked serial, charge, operating
  context, suspected cause, availability constraints, release and adjudication are
  frozen and validated.
- The user must physically confirm that exact linked cover before submission. If a
  different cover is found, intake stops and routes the user to delink the recorded
  cover and link the physical cover before the stuck-up record can be accepted. The
  server also rejects the submission if that confirmed linkage changes before commit.
- A confirmed bulged condition becomes durable asset-condition evidence instead of
  disappearing with ticket closure.
- UI: maintenance intake, stuck-up operations workspace, asset overview and reports.
- Authority: governed maintenance-workflow commands and server transactions.

### Classified maintenance and days-since-maintenance

- Governed maintenance classes define applicable asset types/classes, principal
  lane, reset counters and optional due thresholds.
- Plans freeze the exact class and exact asset identity/version.
- Numbered equipment releases through the published-template assignment path.
- Serial-identified Inner Covers, including pool covers, can be planned and completed
  directly with immutable completion evidence.
- Qualifying resolved maintenance issues can be classified after the reopen window;
  the actual issue completion time resets the same common cadence ledger.
- Admin can add an immutable previous-maintenance record against an exact governed
  asset and maintenance class, with completion date and evidence note plus optional
  performer and source reference. Older additions enrich history but cannot rewind
  a newer current due-state projection.
- Classification correction recomputes affected counters rather than layering a
  contradictory second reset.
- UI: Maintenance programme and Closed Tickets; due and overdue state also appears
  on Home and in Reports.
- Authority: server-owned class, plan, completion, issue-classification and template
  assignment transactions.

### Elemental and functional inspection campaigns

- Definitions support asset-class, component-node, physical-position, value type,
  unit, limits, choices and operating-condition evidence.
- Campaign start freezes an exact machine-generated target population.
- Campaigns may address all assets in a class, one exact asset, one component across
  many assets, or a selected subset without collapsing the plant into one all-at-once
  maintenance event.
- Every target has an auditable pending, observed, deferred or not-applicable
  disposition. Later-added targets are identified as such.
- Repeat observations preserve chronology; out-of-range observations create durable
  findings. Corrective issue linkage, adjudication, verification and baseline
  re-audit are represented.
- Campaign closure is blocked by incomplete population evidence or unresolved
  findings.
- UI: Inspection Programmes, Home attention and Reports findings.
- Authority: governed inspection commands and server-owned transactions.

### Asset hierarchy and Valve Stand

- Asset classes, instances, hierarchy nodes and components are dynamic governed
  records; Admin/SI can add and revise them without changing application code.
- Base, Furnace, Forced Cooler, Inner Cover and Valve Stand are represented through
  the same hierarchy contract while retaining stable existing identities.
- Components carry grouping, parent, tag/reference, short and long description,
  discipline, operating type, normal state, applicability and source reference.
- Component ownership is explicit: unassigned, provisional or confirmed, with owner
  discipline and accountable roles. Installed component references require confirmed
  ownership.
- Duplicate tags fail closed. Existing ownership is shown before a governed override
  can be considered; tag resolution does not silently replace another component.
- UI: Asset Registry, hierarchy editors and exact component picker.
- Authority: atomic asset-hierarchy mutation with audit and version checks.

### Frequent issues and exact component selection

- A versioned frequent-issue catalogue can prefill applicability, route, evidence and
  workflow profile. Unlisted cases retain an explicit governed reason.
- Maintenance intake resolves a selected hierarchy component and stores the exact
  class, instance, node, version, ownership and hierarchy path.
- The component picker supports asset-level work when no lower node is appropriate;
  it does not invent a component match from free text.

### Charge identity

- Charge number is the common five-digit identity wherever issue, stuck-up,
  abnormality, inspection or quality evidence requires it.
- Present malformed values fail closed; optional absence is allowed only where the
  relevant business record explicitly permits it.

### Lanes, acknowledgement, deferment and Operations support

- Mech, Electrical, Operations, RED and I&A lanes retain generated policy ownership,
  including legacy compatibility where required.
- Contract Supervisor/Supervisor acknowledgement, issue deferment request and
  Operations decision are explicit workflow states with reasons and evidence.
- Mid-maintenance operational support is represented through compliance/directive
  requests, acknowledgement, compliance, return and closure rather than an informal
  note.
- Admin correction is versioned and audited; it is not an unrestricted record edit.

## Additional Accepted Intents

### Inner Cover lifecycle and genealogy

- Users may continue to work through the operationally familiar Base number while
  the system preserves the actual Inner Cover serial as the durable asset identity.
- Link, delink, pool availability, purchased/fabricated entry, retirement and
  reuse-of-retired-material are governed lifecycle operations.
- Conflicting Base assignment is disclosed and cannot be silently overwritten.
- Fabrication genealogy records bottom/base, flat section, corrugated cuts and top
  cover, including new/old state, known or unknown ancestor, source serial and length
  where known.
- Statistics follow the Inner Cover serial across Base changes, preventing faults on
  different physical covers from being attributed to one Base-associated identity.

### Burner lockout and burner condition

- Operations and I&A can raise the Furnace burner-lockout case and select affected
  positions 1-8. The default accountable lane is I&A; additional lane assistance is
  available through the workflow.
- Attendance records structured known actions, other work/observation and a terminal
  per-burner outcome.
- Microamp reading is a first-class optional measurement on every attended burner.
- Shift condition rounds cover all eight positions, including red-hot evidence.
- Red-hot evidence creates an I&A operational directive; component replacement resets
  burner-block life through governed component revision history.
- Reports provide Furnace/burner rows, action history, readings, lockouts and
  burner-block life.

### Quality warnings

- Suspected quality impact at issue intake requires a five-digit charge and reason.
- Issue and abnormality sources project durable quality warnings with source identity.
- Operations can request closure after outcome evidence; Admin/SI adjudicates closure,
  rejection or reopening. RA linkage is supported but is not mandatory for every
  warning.
- Monitoring and reporting can be filtered by charge, Base, grade and cycle evidence
  where those fields are present.

### Operational delays and global events

- Utilities and shared-resource events cover water, N2, mixed gas, H2, power, cranes
  and transfer car rather than forcing every interruption onto one equipment record.
- Events carry affected scope, delay, lifecycle and issue links and remain visible in
  the Operations workspace and reporting period.

### Home and reports

- Home is an operational command centre, not a menu-only landing screen. It surfaces
  asset availability, down/unfit/maintenance counts, workflow attention, overdue
  maintenance, active inspection findings, quality and operational attention.
- Reports support all classes or one class, optional exact asset, and start/end date.
- Output includes issues, open work, component/subsystem failures, planned maintenance,
  cadence, inspection findings, quality warnings, operational delays and burner
  reliability where applicable.

## Verification Ownership

- Functions tests own command parsing, authority, version, idempotency and atomic
  projection behavior.
- Firestore Rules emulator tests own client read/write boundaries for every new
  projection.
- Flutter model and UI tests own strict decoding, role-scoped representation,
  responsive layout and source-to-screen reachability.
- A-02 through A-05 machine inventories own architecture, persistence, schema,
  timestamp and decoder re-arm conditions.
- The expanded implementation audit requires all 47 Dart and TypeScript workflow
  commands to match and have a client entry point.

## Remaining Release Work

1. Merge the verified successor source through the normal review path.
2. Allocate a new monotonically increasing Android build; do not rewrite Build 12.
3. Deploy the matching Functions, Rules and indexes only through the governed release
   checks.
4. Install as an in-place upgrade and validate Admin, SI, Operations, lane-supervisor
   and field-maintainer journeys on emulator and physical device.
5. Record live readback and device evidence before changing pilot or distribution
   authority.
