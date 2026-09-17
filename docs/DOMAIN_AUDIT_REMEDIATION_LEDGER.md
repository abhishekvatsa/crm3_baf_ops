# Domain audit remediation ledger

What the three domain audits of 14 September 2026 found, what has been repaired
in the backend, and what is deliberately left — with the reason, so the next
person picks it up knowing why it waited rather than guessing.

The audits are chapters SRC-04, SRC-05 and SRC-06 of the consolidated audit
dossier (Domain 01 Critical Safety Alarms, Domain 02 Multi-agency planned
maintenance, Domain 03 Inner Cover lifecycle). Their findings were reproduced
against the current source before being repaired or deferred; where a finding is
recorded here as still open, that is a statement about this repository at the
commit that added the line, not a repetition of the audit's claim.

Status values:

- **repaired** — fixed here, with a regression test that fails without the fix.
- **client** — the defect is in the Flutter or native client. It can be written
  at any time, but it only reaches operators in a new build, and no build is
  authorised.
- **decision** — the repair requires a business decision that code review cannot
  invent. The options are stated; the owner is the plant, not the implementer.
- **design** — a bounded repair does not exist; the domain needs a model it does
  not have yet (an evidence episode, an accountable exception owner).

## Domain 02 — Multi-agency planned maintenance

| Finding | Status | Note |
|---|---|---|
| D02-01 runtime work addition rejects the acknowledged lane | **repaired** | The lane writer persists `status`; the module consumer read `statusKey`, which is the client's own local property name and which no producer writes, so every real lane refused new work. The persisted field is now named once in `maintenanceWorkflow/laneRecord.ts` and read through it. The test that hid this seeded the invented name; it now builds the lane through the real classification and acknowledgment handlers. |
| D02-02 generic dependency confirmation is hardcoded as RED preparation | open | Confirmation passes `"red"` as the expected lane while the sibling path passes nothing, so six of the seven lanes can be raised and complied but never confirmed. The repair is not deleting the parameter: request purpose and RED-preparation side effects (equipment condition, RED contribution counters) have to be separated first, or a generic confirmation starts changing equipment state. |
| D02-03 a non-blocking request outlives a parent that forbids its completion | **decision** | Only gated requests block finalization, by design, but completing any request needs a mutable parent. Three defensible policies: let non-blocking completion proceed independently of the parent; transfer the open request to an accountable follow-up owner; or require an explicit disposition before finalization. Each changes what a supervisor is answerable for. |
| D02-04 removed or terminated lanes veto already prepared RED work | **repaired** | `prepareRedLane` decided readiness over the active lane set while `acknowledgeLane` read every generation, so a lane removed through its authorised path, or a generation replaced by a later one, vetoed work preparation had already released. Both now read the same active set, and history stays history. |
| D02-05 last-lane removal advertises reclassification but reuses generation 1 | open | The removal path returns the job to classification while keeping generation 1 as removed; reclassification then tries to create the same lane id and refuses. Bounded: allocate monotonic generations in finalization as the separate `addLane` path already does. |
| D02-06 preselected RED stand preparation has no initial escalation schedule | **repaired** | The handover carried `raisedAt` and `becameDueAt` but neither `acknowledgementDueAt` nor `nextEscalationAt`, and the sweeper finds work by the latter, so an unacknowledged stand preparation was never chased. It now carries the same attention clock as any other immediate request. Still open as a **decision**: whether the blocked RED agency's own clock should keep running while Operations prepares the stand. |

## Domain 01 — Critical Safety Alarms

| Finding | Status | Note |
|---|---|---|
| CSA-05 a generic FCM failure retires a working registration | **repaired** | `messaging/invalid-argument` was treated as proof of a dead token. Firebase returns it for a rejected message as well as a rejected registration, so a fault in what we sent could quietly remove a recipient. It is now classified separately, the registration is kept, and the count is reported on the delivery receipt so the real fault is visible. Genuine unregistered-token cleanup is unchanged. |
| CSA-01 interrupted delivery can become a permanently skipped recipient | **design** | The record commits `dispatching` before the external send, so a worker lost in between leaves a durable record and no message. One bounded slice is available now — a re-observed interrupted dispatch should raise the same delivery-uncertainty signal the other failure branches raise, instead of completing quietly. The rest needs an accountable delivery-exception owner and a stated uncertainty policy; blind retry can duplicate an emergency alert. |
| CSA-02 an obsolete raise can be sent after resolution | **design** | State is validated before recipients are discovered and the plan is then reused, so a resolution during discovery still sends the original raise. Re-reading immediately before dispatch narrows the race and is worth doing; it cannot close it. The rest is a notification freshness contract — incident revision, event time, deliberate transport lifetime, device reconciliation — and a decision about what an unverified wake-up may claim. |
| CSA-03 original actor identity is not retained across the command boundary | **client** | The alarm service dispatches through the ordinary V1 path and does not bind the originating uid across its awaits, so a first unaccepted call after an account switch can arrive under a different session. The origin-bound V2 transport already exists and is used elsewhere. |
| CSA-04 a successful native call is mistaken for notification readiness | **client** | Native `showActiveNotification` returns true if posting did not throw, and the host then suppresses further attempts for that alarm. A blocked or silenced critical channel is never observed. Needs typed permission and channel readiness, not a boolean. |
| CSA-06 fresh alarms have no exposed path to amend their details | **client** | The backend already permits an audited amendment; the screen does not offer it. |
| CSA-07 one malformed active record can interrupt the whole active feed | **client** | A whole snapshot is decoded through one throwing map, so a single damaged record can end the stream. Needs per-record outcomes and an explicit completeness state — the same shape as the quality feed isolation item. |
| CSA-08 recipient coverage is not an owned incident outcome | **decision** | A zero-recipient dispatch completes normally with nothing recorded at incident level. Persisting a coverage disposition first requires agreeing who the intended audience is and what the plant promises about reaching them. |

## Domain 03 — Inner Cover lifecycle

| Finding | Status | Note |
|---|---|---|
| D03-04 a backward server time can create a negative installation interval | **repaired** | Closing a linkage stamped the removal instant with no comparison against the installation it ends, so a clock regression could store a removal before its installation. A demonstrated reversal is now refused with nothing written. It refuses only a reversal it can read: an unreadable stored instant is a record-shape problem, handled by the validators, not silently reinterpreted here. |
| D03-01 old inspection evidence can qualify a cover after later repair or retirement | **design** | Acceptance is bound to the original receipt, not to the latest event that invalidated clearance, so an inspection dated before a repair or a bulged retirement can restore availability. A real repair needs an assurance episode — the physical event that voided prior clearance, and evidence bound to it — plus a rule for delayed recording that does not confuse inspection time with entry time. Also part **decision**: whether plant policy requires reinspection after every such event. |
| D03-02 reacceptance overwrites earlier acceptance evidence | **design** | A second acceptance replaces the first one's inspection, leak-test and NDT references, and the audit snapshot does not carry those fields, so the authoritative record keeps no readable copy. One bounded slice is available now — include the acceptance evidence in the audit snapshot so it survives in the immutable record. The rest is an acceptance-event history with a latest pointer. |
| D03-03 movement writes do not validate the whole custody triangle | open | Profile, assignment and linkage are checked separately, so an injected single-document disagreement lets two covers read as installed on one Base, or lets a delink stamp a history that belongs to another cover. Bounded: validate the three identities together, both sides for replace and swap, and route a genuine disagreement to reviewed reconciliation rather than deleting whichever record disagrees. |
| D03-05 invalid fabrication numbers become plausible evidence | **client** | `double.tryParse` and `int.tryParse(...) ?? 1` run before validation, so `1,200` becomes "not specified" and `1.5` becomes one cut. Validate the raw input and keep the operator's text. |
| D03-06 native durable recovery covers acceptance only | **client** | Registration, state, link, delink, transfer, replace and swap generate fresh identities per invocation and do not carry the original actor, so a lost response leaves no recoverable original intent. The acceptance path already has the machinery to extend. |

## What a repair here has to keep

Every item above sits behind the same constraints the quality-case work
established, and they are not negotiable in a later pass:

- Nothing rewrites an immutable audit, a stored command's bytes or a receipt
  fingerprint to make a comparison succeed.
- A repair of damaged data is a reviewed operation that derives its values from
  a stated source of truth; it never invents evidence.
- A test proves the defect before it proves the fix, and it is built against the
  real producer rather than a hand-written fixture of what the consumer expects.
