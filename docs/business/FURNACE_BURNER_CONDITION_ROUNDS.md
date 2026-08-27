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
- A red-hot directive cannot use the ordinary client closure route. Its
  closure command reads the authoritative latest Furnace round, rejects a
  stale expected round or directive version, projects all eight Burner/UV
  positions, writes the immutable compliance round, closes the source
  directive and creates any still-required successor directive in one server
  transaction.
- Every newly recorded round also advances a private, server-owned current
  pointer for that Furnace. This serializes competing audit and compliance
  transactions; installations without the pointer use the existing indexed
  latest-round query once and establish it on the same commit.
- The condition matrix resolves one current pointer per governed Furnace and
  point-reads the referenced immutable round. A Furnace without a legacy
  pointer uses its own indexed two-record lookup, rejects an equal-time
  ambiguity, and never derives current condition from a fleet-history window.
- The phone adopts the exact closure version and server time from the callable
  receipt before treating the local row as synchronized. A dirty or changed
  local directive is preserved instead of being overwritten.
- An unchanged submission retains its idempotency identity across timeout,
  disconnect and app restart. Editing any submitted value rotates that
  identity before another write.
- A valid committed server result is never replaced by a local retry-cleanup
  failure. The UI reports the committed round with a cleanup warning, while
  the retained identity keeps an unchanged retry bound to the same receipt.
- Red-hot directives are limited to legacy-compatible Furnace numbers 1-26
  until operational directives adopt governed physical-asset identity.

## Storage and access

`burner_condition_rounds` is approved-user readable and client-write denied.
`burner_condition_current` is approved-user readable and client-write denied;
`burner_condition_round_receipts` remains server-only. Report queries are date
bounded and visibly limited to 1,000 round records per selected period. A
selected Furnace is filtered before that limit; fleet reports retain the
explicit global limit.

## Deliberate boundaries

- A round is online-only because the authoritative command is a callable. It is
  not queued as an offline local mutation.
- A flame-not-seen observation does not automatically create a lockout issue.
  The existing burner-lockout intake remains the accountable fault path.
- A round cannot alter component identity or reset service life. Physical
  replacement remains governed by the installed-component lifecycle.
- Shift identity, required round frequency, alarm thresholds, trend rules and
  escalation timers remain plant-policy inputs and are not guessed in source.
