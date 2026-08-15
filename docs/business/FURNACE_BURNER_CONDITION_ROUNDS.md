# Furnace Burner Condition Rounds

## Purpose

A condition round records routine visual and flame-signal evidence without
manufacturing a breakdown ticket. It complements the burner-lockout workflow:
the round is proactive observation, while a lockout issue remains the governed
path for fault attendance and resolution.

## Delivered behavior

- The recorder selects one active governed Furnace.
- Every round contains positions 1 through 8 exactly once.
- Each position explicitly records flame seen, flame not seen, burner not
  operating or not checked; a red-hot burner-block indication; an optional
  microamp reading; and an optional note. `Not checked` requires a reason.
- A microamp value is evidence only. No acceptance threshold or equipment
  decision is inferred from the manuals or from source code.
- Operations, I&A, Shift Supervisor, SI and Admin may record a round. Every
  approved user may read round evidence through Burner reliability.
- The server revalidates actor authority, active Furnace class and physical
  asset identity, and the expected asset version inside the transaction.
- The immutable round and private idempotency receipt use the request UUID as
  their stable identity. Exact replay is write-free; drift fails as data loss.
- Red-hot evidence creates a deterministic critical directive to I&A in the
  same transaction. The directive requires acknowledgement and recorded
  compliance and explicitly performs no automatic plant actuation.

## Storage and access

`burner_condition_rounds` is approved-user readable and client-write denied.
`burner_condition_round_receipts` is server-only. The report query is date
bounded and visibly limited to 1,000 round records per selected period.

## Deliberate boundaries

- A round is online-only because the authoritative command is a callable. It is
  not queued as an offline local mutation.
- A flame-not-seen observation does not automatically create a lockout issue.
  The existing burner-lockout intake remains the accountable fault path.
- A round cannot alter component identity or reset service life. Physical
  replacement remains governed by the installed-component lifecycle.
- Shift identity, required round frequency, alarm thresholds, trend rules and
  escalation timers remain plant-policy inputs and are not guessed in source.
