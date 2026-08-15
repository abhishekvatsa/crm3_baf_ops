# Furnace Burner Lockout Workflow

## Purpose

`furnaceBurnerLockout` is a governed specialization of the existing maintenance
issue. It is not a second ticket system.

The workflow records one Furnace, one or more of its eight burner positions,
initial operating observations, I&A accountability, per-burner attendance, and
one terminal outcome for every affected position.

## Delivered source behavior

- A Furnace issue can be raised as a standard issue or a burner-lockout issue.
- Burner positions are numbered 1 through 8 and use display tags such as
  `FR-03-B08`. `B` identifies the burner position and does not replace OEM
  component references such as the UV detector reference.
- One or more positions must be selected. A common-mode flag is available only
  for multi-burner events.
- Intake captures cycle/firing stage, HMI indication, flame and spark
  observations, relight attempts, whether lockout persists, and red-hot burner
  block observations.
- Burner lockouts are fixed to the I&A route and breakdown classification.
  Additional disciplines continue to use the existing scoped-help workflow.
- A red-hot burner-block observation makes the issue critical and atomically
  creates a deterministic, linked I&A directive. Either both records commit or
  neither commits.
- The directive requires acknowledgement and recorded compliance with the
  approved plant procedure. It does not actuate a PLC or field device.
- Resolution requires recorded work or inspection evidence and a terminal
  outcome for every affected burner.
- Attendance can record an optional flame-signal reading in microamps for each
  affected burner. The value is retained in structured closure and action
  evidence, survives offline close/reopen replay, and appears in completed
  issue history and the burner report matrix.
- `returnedToService` is rejected when the only evidence is feedback reset,
  controller reset, or controller power-on.
- Admin correction may clarify narrative evidence but cannot change burner
  classification, I&A routing, breakdown type, component identity, or red-hot
  criticality.
- The Operations report presents a period- and asset-filtered burner matrix by
  Furnace and burner position, including lockout, open, red-hot, outcome, and
  frequent-action counts.

## Action catalogue

The source catalogue includes feedback reset, air-line cleaning, UV detector
cleaning, poking or passage clearing, flame adjustment, igniter rod/holder
cleaning, burner-controller reset and power-on, safety shutoff-valve relay work,
the site term `6A / 6B relay work`, igniter rod replacement, UV detector
replacement, safety shutoff-valve solenoid work, and a described `other` action.

The `6A / 6B`, `220 V relay`, and `burner card` terms remain site terminology
until the controlled electrical schematic establishes canonical component
references. The UI therefore uses neutral component names where possible and
does not invent OEM tags.

## Invariants

1. Burner-lockout classification and all structured burner fields occur
   together or not at all.
2. The parent asset is a Furnace and the route is I&A.
3. Positions are unique values from 1 through 8.
4. Red-hot positions are a subset of affected positions.
5. Red-hot evidence always remains critical.
6. Open issues carry no manufactured closure outcomes.
7. Closed issues account for every affected position in sorted position order.
8. Closure carries non-empty structured action evidence.
9. Ordinary maintenance issues cannot acquire burner closure fields.
10. Offline create/close/reopen replay carries the same structured evidence.
11. A supplied microamp reading belongs to an attended burner, is finite and
    non-negative, and agrees across closure and action evidence.

## Deliberate boundaries

- Attendance is saved as structured closure evidence in this tranche. Durable,
  append-only intermediate attendance sessions require a separate server
  mutation and are not claimed here.
- A repair, clean, reset, or configuration action does not reset component life.
- Physical burner-block replacement and component revisioning now use the
  reusable atomic installed-component lifecycle: preserve the removed identity,
  install the new identity, retain one lineage, transfer tag custody, and append
  immutable audits. Direct issue/job evidence approval remains a following
  bridge; maintenance evidence and registry confirmation are not silently
  conflated.
- Automatic red-hot escalation thresholds, timers, and severity changes remain
  governed plant configuration. No threshold has been inferred from the manual.
- Microamp readings are observations, not automatic pass/fail decisions. The
  source applies only a broad structural bound to reject malformed values or an
  accidental unit mismatch; operational limits require governed plant data.
- Shift-round capture and proactive condition monitoring remain a following
  tranche built on the same eight-position identity.
