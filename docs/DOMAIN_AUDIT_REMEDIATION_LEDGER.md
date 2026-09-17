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
| D02-02 generic dependency confirmation is hardcoded as RED preparation | **repaired** | Confirmation demanded that the gated lane be RED while the raise path accepted any active lane, so six of the seven lanes could be raised and complied but never confirmed; and a request that happened to gate the RED lane performed RED preparation without the preparation decision. Confirmation now resolves whichever lane the request names, and only the request the RED decision installed as that lane's gate releases RED work and changes what the equipment is doing. Any other gated request is an ordinary dependency: confirming it releases that dependency and writes no equipment state. |
| D02-03 a non-blocking request outlives a parent that forbids its completion | **decision** | Only gated requests block finalization, by design, but completing any request needs a mutable parent. Three defensible policies: let non-blocking completion proceed independently of the parent; transfer the open request to an accountable follow-up owner; or require an explicit disposition before finalization. Each changes what a supervisor is answerable for. |
| D02-04 removed or terminated lanes veto already prepared RED work | **repaired** | `prepareRedLane` decided readiness over the active lane set while `acknowledgeLane` read every generation, so a lane removed through its authorised path, or a generation replaced by a later one, vetoed work preparation had already released. Both now read the same active set, and history stays history. |
| D02-05 last-lane removal advertises reclassification but reuses generation 1 | **repaired** | Removing the last lane returns the job for reclassification and keeps generation 1 as removed history, but finalisation always created generation 1 again and collided with it. Finalisation now allocates the next generation per lane key, the way the add-lane path already did, and remaps the affected modules to it. Removed history is kept as history. |
| D02-06 preselected RED stand preparation has no initial escalation schedule | **repaired** | The handover carried `raisedAt` and `becameDueAt` but neither `acknowledgementDueAt` nor `nextEscalationAt`, and the sweeper finds work by the latter, so an unacknowledged stand preparation was never chased. It now carries the same attention clock as any other immediate request. Still open as a **decision**: whether the blocked RED agency's own clock should keep running while Operations prepares the stand. |

## Domain 01 — Critical Safety Alarms

| Finding | Status | Note |
|---|---|---|
| CSA-05 a generic FCM failure retires a working registration | **repaired** | `messaging/invalid-argument` was treated as proof of a dead token. Firebase returns it for a rejected message as well as a rejected registration, so a fault in what we sent could quietly remove a recipient. It is now classified separately, the registration is kept, and the count is reported on the delivery receipt so the real fault is visible. Genuine unregistered-token cleanup is unchanged. |
| CSA-01 interrupted delivery can become a permanently skipped recipient | **partly repaired**, rest **design** | The record commits `dispatching` before the external send, so a worker lost in between leaves a durable record and no message, and the next trigger skipped it silently. A re-observation now raises the same delivery-uncertainty signal a newly detected unknown send raises, carrying its own attempt id and the phase `prior-dispatch-unresolved`. What remains needs an accountable delivery-exception owner, an attention deadline and a stated uncertainty policy; blind retry can duplicate an emergency alert, and there is no transaction spanning Firestore and FCM. |
| CSA-02 an obsolete raise can be sent after resolution | **partly repaired**, rest **design** | State was validated before recipients were discovered and the plan was then reused, so an alarm resolved during discovery still had its original raise sent. Each recipient's dispatch now re-reads the alarm and suppresses the send when it is no longer one to alert about. Evidence is weaker here than elsewhere and is stated as such: the suppression that follows is covered by the receipt suite, but this trigger has no unit seam, so the re-read itself is pinned by a source contract rather than exercised end to end. It narrows the race; it cannot close it, because nothing spans Firestore and the delivery service. The rest is a freshness contract — incident revision, event time, a deliberate transport lifetime, device reconciliation — and a decision about what an unverified wake-up may claim. |
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
| D03-02 reacceptance overwrites earlier acceptance evidence | **partly repaired**, rest **design** | A second acceptance replaces the first one's inspection, leak-test and NDT references on the profile, and the audit snapshot did not carry those fields, so the authoritative store kept no readable copy of what an earlier clearance rested on. The snapshot now carries them, so each acceptance's evidence survives in the immutable record. What remains is a readable acceptance-event history with a latest pointer, and an honest marker where older evidence was never retained. |
| D03-03 movement writes do not validate the whole custody triangle | **partly repaired** | Closing a linkage checked only that the record was active and unremoved, so a history naming another cover or another Base could still take the removal stamp, leaving that cover installed while its record said it had come off. Every close — delink, transfer, and both sides of replace and swap — now requires the history to be this cover's history on this Base. The other half is not done: when a Base's assignment document is missing, nothing establishes that no other profile or active linkage still claims that Base, so a second cover can be installed on it. Closing that needs a query across profiles or linkages, which this handler's read interface does not expose, and a reviewed reconciliation route for a Base that two records claim. |
| D03-05 invalid fabrication numbers become plausible evidence | **client** | `double.tryParse` and `int.tryParse(...) ?? 1` run before validation, so `1,200` becomes "not specified" and `1.5` becomes one cut. Validate the raw input and keep the operator's text. |
| D03-06 native durable recovery covers acceptance only | **client** | Registration, state, link, delink, transfer, replace and swap generate fresh identities per invocation and do not carry the original actor, so a lost response leaves no recoverable original intent. The acceptance path already has the machinery to extend. |

## Domain 04 — Burner blocks, UV detectors and condition rounds

Chapter SRC-07 of the dossier. Triaged and begun in the same pass.

| Finding | Status | Note |
|---|---|---|
| D04-04 one physical action referenced twice becomes two replacement events | **repaired** | A closure supplies actions at execution scope and again at module scope, and the lifecycle event identity includes where the reference came from, so one physical replacement was written into the asset's history twice while the current projection showed one. Both planners, burner block and UV detector, now collapse identical claims about one physical action to the first, and refuse two claims that describe it differently, which only a person can settle. |
| D04-02 directive completion makes inherited observations look fresh | **partly repaired**, rest **design** | Compliance copies the values at positions it did not direct into a new round under a new time and actor. The half repaired is the worst of it: a round recorded before UV and draft-seal evidence existed carried none, and compliance read every position as serviceable, turning eight positions nobody examined into positions examined and found normal, timed and attributed to the complying actor. That is now refused, with the available route named — record a current condition round, then complete the directive. Carrying an observation forward with its own time, observer and evidence episode still needs a sparse compliance event or field-level provenance. |
| D04-01 the client selects the wrong installation after a late historical entry | **client** | Both backend planners order by action time, then recording time, then event identity; the Dart projection reverses the first two, so a replacement entered late but performed earlier is chosen as current, and cleared red-hot or melted-UV evidence can reappear. The backend is the correct side. |
| D04-03 a stale partial matrix edit overwrites a newer observation | **design** | The matrix submits a whole eight-position snapshot carrying the asset version, not the current round or a per-field pre-image, so an older draft can clear a newer operator's observation. The intentional complete survey must stay possible, so the protocol has to distinguish a full witnessed round from a sparse edit before this can be refused. |
| D04-05 editing during an in-flight save can lose the newer draft | **client** | |
| D04-06 an explicit installation correction path is unestablished | **decision** | What a correction of a recorded installation means — and who may make one — is a plant decision before it is an implementation. |

## What a repair here has to keep

Every item above sits behind the same constraints the quality-case work
established, and they are not negotiable in a later pass:

- Nothing rewrites an immutable audit, a stored command's bytes or a receipt
  fingerprint to make a comparison succeed.
- A repair of damaged data is a reviewed operation that derives its values from
  a stated source of truth; it never invents evidence.
- A test proves the defect before it proves the fix, and it is built against the
  real producer rather than a hand-written fixture of what the consumer expects.
