# Operations Command Centre and Business Model

## Purpose

This document binds the app's maintenance, asset, disruption, reporting and
quality functions into one operating model. It distinguishes controls already
implemented from the policy boundaries that must remain explicit as the model
grows.

## Maintenance lanes

The controlled maintenance lanes remain:

- Mechanical (`mech`);
- Electrical (`elec`);
- Operations (`oprn`);
- Refractory (`red`);
- Instrumentation and Automation (`ia`).

Each selected lane owns its acknowledgement, work evidence and closure. Admin,
SI and Contract Supervisor may establish the lane set. This does not let those
roles silently perform a represented lane's acknowledgement or completion.

## Assurance, deferment and operational support

The compliance-request workflow is the common mechanism for:

- assurance that an identified condition or prerequisite has been reviewed;
- a maintenance deferment request based on cycle, equipment need or another
  recorded operating constraint;
- mid-maintenance Operations support such as moving a furnace, base, inner
  cover or forced cooler, or arranging a crane or transfer car.

Every request has an origin lane, one exact target lane, a purpose, a reason,
an expiry and recorded lifecycle evidence. The target lane acknowledges the
obligation before it can be treated as accepted.

If Operations accepts and then fulfils the exact acknowledged obligation, the
fulfilment evidence completes that obligation without a second ceremonial
acknowledgement. A fresh acknowledgement is required when a revised condition
changes the scope, target, timing or operational constraint. An accepted
counter-condition therefore becomes a new acknowledged obligation rather than
quietly altering the first one.

Admin retains oversight but is not a substitute for the accountable target
lane unless the governing command explicitly permits that authority.

## Operational disruptions

`operational_events` is the source of truth for plant constraints that are not
well represented as equipment maintenance tickets. It covers water, nitrogen,
mixed gas, hydrogen, power trips, cranes, transfer cars and an explicit other
category.

An event can affect the whole plant, selected asset classes, or selected asset
instances. It records severity, start time, current status, reasoned changes,
resolution evidence and immutable audit/receipt records. Operations, Shift
Supervisor, SI and Admin may confirm restoration. Contract Supervisor can
record and update an event but cannot assert plant restoration.

Reopening archives the completed occurrence's original type, title,
description, severity, timing, scope and closure evidence. Later corrections
therefore cannot rewrite how an earlier disruption appears in history or
reports.

These records supply the app-open attention picture and the duration-aware
reporting view. They do not replace an asset issue when physical maintenance is
required; both records may coexist and remain independently accountable.

When both records exist, an authorised user can bind the maintenance issue to
the exact disruption occurrence as causal work, restoration work, or work
affected by the disruption. The immutable link freezes both identities and the
event scope at link time. Reopening an event archives the earlier occurrence's
links rather than carrying them into the recurrence.

## Dynamic asset model

Admin can add and maintain asset classes, hierarchy definitions, physical
assets and installed components. The hierarchy supports ownership discipline,
accountable roles, operating type, normal/fail/contact state and source
references. The same model is available to issues, planned work, reports and
operational-event targeting.

Component tags are globally claimed. A duplicate tag cannot overwrite an
existing component. The user is shown the current owner and may perform an
explicit, version-checked transfer where policy permits. The transfer records
the old and new owner atomically.

An asset can independently be declared under maintenance, down or unfit. The
plant overview reports these states by asset class; retirement remains a
separate registry decision and cannot be used to hide an active condition.

## Quality lifecycle

Every recorded cycle abnormality creates a deterministic, source-bound quality
warning. Issue creation asks whether coil quality may be affected. A suspected
impact requires a charge number and creates both the issue and its source-bound
warning atomically; an issue without suspected impact creates no warning.

Warnings progress through `open`, `closureRequested` and `closed`:

- Operations or supervision may request closure when follow-up indicates that
  the coil is acceptable;
- SI or Admin makes the final quality decision;
- closure records one of coil found acceptable, re-annealing completed, or
  quality adjudication;
- re-annealing closure requires the linked re-annealing charge numbers;
- SI or Admin may reopen a closed warning with reasoned audit evidence.

Quality monitoring requests let SI or Admin identify a base, grade, cycle and
charge set for proactive monitoring. A warning is never implicitly discarded
because its source issue or abnormality was resolved.

## Reports and app-open view

The app-open screen presents the current whole-plant position: asset
availability, maintenance, down/unfit state, open issues, open disruptions and
open quality attention. Every attention count links to its operational screen.

The Operations report supports:

- all asset classes, one asset class, or one physical asset;
- custom start/end dates plus common duration presets;
- issue totals, critical/open issues and unresolved issue details;
- planned-job totals split into open, completed and cancelled;
- disruption count, open count and overlapping duration;
- unique maintenance issues explicitly linked to disruption occurrences;
- per-class health and workload summaries;
- top component and subsystem failure concentrations.

Source limits are displayed where a bounded live report is used. A later
server-side analytical store may extend history without weakening the visible
bound or silently returning an incomplete "all time" result.

## Governed correction boundary

"Admin can edit" means a governed correction, not unrestricted document
editing. A mutable business record may be corrected only through a command
that requires:

- the current version and a meaningful reason;
- field-level validation and role authority;
- an immutable before/after audit record;
- an idempotent request receipt;
- preserved links to assets, issues, warnings and workflow evidence.

Audit events, receipts, published template snapshots, historical closure
evidence and other immutable custody records are never edited in place. An
error in immutable evidence is addressed by a linked superseding correction or
adjudication record. This preserves accountability while still allowing Admin
to repair genuine business-data mistakes.

## Next integration increments

1. Continue governed-selector integration. Raise Issue, published planned-work
   assignment and retained legacy-template assignment now require an exact
   governed class and physical asset while retaining documented historical
   compatibility. New whole-asset templates preserve their selected class.
2. Extend component and subsystem analytics with server-side aggregates after
   sufficient governed history exists.
3. Add record-specific Admin correction commands only where an actual mutable
   correction need is demonstrated; do not introduce a generic database editor.
4. Consider direct create-and-link ergonomics only after maintenance issue
   creation has a server-governed atomic command boundary.
