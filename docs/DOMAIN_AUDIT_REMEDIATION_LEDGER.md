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
| D04-01 the client selects the wrong installation after a late historical entry | **repaired** (client) | Both backend planners order by action time, then recording time, then event identity; the Dart projection reversed the first two, so a replacement entered late but performed earlier was chosen as current and cleared red-hot or melted-UV evidence could reappear. The backend is the correct side and writes the authoritative current-state record, so the projection now reads the same order. The Dart test that asserted the opposite was itself written against the client's imagined rule on the very scenario the backend's regression uses; it is corrected rather than kept, and a tie-break case was added so delivery order still carries no meaning. A sweep of the other client projections found no second instance: the inspection report already orders by observation time before recording time. |
| D04-03 a stale partial matrix edit overwrites a newer observation | **design** | The matrix submits a whole eight-position snapshot carrying the asset version, not the current round or a per-field pre-image, so an older draft can clear a newer operator's observation. The intentional complete survey must stay possible, so the protocol has to distinguish a full witnessed round from a sparse edit before this can be refused. |
| D04-05 editing during an in-flight save can lose the newer draft | **repaired** (client) | The matrix disabled the save controls while a save was in flight but not the position inputs, and the reply cleared the draft's pending state outright. An observation recorded during the save was therefore marked as recorded although it was never in the envelope, and the next snapshot - arriving under a new source key because the save had just produced one - replaced the draft with the server's copy of the earlier one. A draft now carries which revision of itself was submitted; the reply settles that revision only, an edit made during the flight keeps the draft pending, and a pending draft is never replaced by an arriving snapshot. Whoever recorded the round is told how many furnaces are still pending rather than being shown a bare success. The draft moved out of the screen into its own domain type so the sequence is asserted directly; the tests fail against the old arithmetic. That extraction also took a responsibility out of a presentation file, so its architecture-boundary exception no longer applies and was removed. |
| D04-06 an explicit installation correction path is unestablished | **decision** | What a correction of a recorded installation means — and who may make one — is a plant decision before it is an implementation. |

## Domain 05 — Inspection campaigns, findings and corrective verification

Chapter SRC-08 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D05-01 correct physical subject, wrong corrective episode | **repaired** | Linking an observation to the maintenance issue that repaired it wrote that issue onto whichever finding was currently active for the target, without establishing that the observation belonged to that episode. A repair carried out for an earlier, already-adjudicated episode therefore became the later episode's corrective action, and the later episode could no longer take the issue that actually belonged to it. An observation now belongs to an episode when it is that episode's origin or a correction of it through the recorded supersession chain; the historical reference is still recorded either way, and only the owning episode is bound. |
| D05-02 "not numerically out of range" becomes "within defined condition" | **design** and **decision** | Only a numeric limit produces an adverse result, so boolean, choice and text observations are recorded with `outOfRange: false`, and the report prints that as conformity. The repair needs an assessment model that separates recorded, not assessed, conforming, adverse and not comparable, and owner-defined predicates saying which boolean or choice value is adverse — which is a plant decision, not an implementation one. Migrating the existing `false` must not silently give it a new meaning. |
| D05-03 historical non-current errors have no amendment route | **decision** | The same family as D03-01 and D04-06: what it means to amend a record that is no longer current, and who may do it. |

## Domain 06 — Operational disruptions and occurrence identity

Chapter SRC-09 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D06-01 the linker calls current, producer-valid tickets malformed | **repaired** | Two shapes this application produces itself were read as corrupt data. A governed reference is now read by the contract that produced it, which knows each scope's schema version and checks that the reference names this very asset — so an ordinary component-on-asset issue links instead of being refused as malformed evidence; older shapes are still read as before. An issue closed administratively is likewise a state this application records, not malformed data: it is recognised, and the link keeps the real status and resolution, so nothing counts a closure without resolution as a technical repair. |
| D06-02 correcting occurrence facts strands or invalidates links | **partly repaired**, rest **design** | The half repaired is the contradiction the event itself could commit: linking checks that an issue belongs to the occurrence's governed scope, and correcting that scope afterwards could leave the event listing as current a link its own rule would refuse. A narrowing or moving correction is now held while issues are linked, naming them, and a widening to plant-wide or a correction that leaves the scope alone still commits. The rest is the occurrence identity itself: the link id derives from the editable start time, so correcting the start strands existing links under a prior occurrence. That needs an immutable occurrence id and a migration that does not reassign identities by recomputing timestamps. |
| D06-03 reopening is not correction of an erroneous closed interval | **decision** | The same family as D03-01, D04-06 and D05-03: what correcting a closed interval means, as distinct from recording a recurrence. |

## Domain 07 — Morning Review and action follow-through

Chapter SRC-10 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D07-02 typed asset references can name non-existent or contradictory subjects | **repaired** | An action's asset is typed identity — the agenda groups by it and people are held to it — but the write stored whatever the client sent, so an action could name an asset the register does not hold, or name a real instance under another class, number and label. The register is now read at the write: an unknown asset and an instance that belongs to another class are refused with nothing written, and the class name and asset number recorded are the register's rather than the label supplied. The same shape exists on the minutes-entry path, which this audit did not exercise; it is unfixed. |
| D07-01 yesterday's unfinished minutes cannot be finalized today | **decision** | Finalisation and facilitator takeover are bound to the current plant day, so a meeting held yesterday and left open cannot be closed truthfully. The repair is a policy first: what a late finalisation or an administratively abandoned session means, what it includes, and who may record it. An old meeting must not be made to look like today's. |
| D07-03 cancellation, reassignment and correction are not completion | **decision** | |
| D07-04 inspection uncertainty is lost in the management snapshot | **design** | The same root as D05-02: absence of numeric adverse evidence is presented as conformity, and the management summary inherits it. |

## Domain 08 — Reactive maintenance

Chapter SRC-12 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D08-02 repair closure supplies physical completion time as recording time | **repaired** | Closing a reactive repair passed the closure time as both the completion and the recording time of the component-life event, so work finished at 04:00 and entered at 07:00 was recorded as if the evidence had existed at 04:00. The recording time is now the server clock at the write, and the physical completion time is preserved untouched. The planners enforced the equality too: they now require only that a recording cannot precede the completion it records. |
| D08-01 an audited component or tag correction can contradict the retained subject | **design** | A correction changes the component and tag while the retained governed reference still names the original node, leaving one record describing two subjects. The repair needs the model to say which is canonical and which is a display alias, and a reviewed route for a true subject change; refusing the correction without that route would strand ordinary work. |
| D08-03 still-relevant administrative closure has no technical follow-through | **decision** | An issue closed administratively but explicitly still relevant cannot be reopened technically or resolved. What continuation means — and how it is recorded without re-labelling yesterday's decision as a repair — is a plant decision. |

## Domains 09 and 10 — templates and assignment; equipment condition

Chapters SRC-13 and SRC-14. Every finding in these two domains has now been checked against the current source; each row says what was found and what was done about it.

| Finding | Status | Note |
|---|---|---|
| D10-01 current component-on-asset issues are rejected by the condition linker | **repaired** | The third place this application refused a record it produced itself. Linking a maintenance issue as condition evidence read only the older reference schemas, so the component-on-asset reference the maintenance producer writes for an ordinary component issue looked like a different or malformed asset. The reference is now read by the contract that produced it, and the checks binding it to this very asset — instance, class and number — are unchanged. |
| D09-01 a fresh legacy-shaped assignment can bypass the physical asset register | **repaired** | An older request shape carries only an asset type and number, and admitting a fresh one skipped the register lookup the governed path performs, so new work could be assigned to an asset the plant does not have or one already retired — while the same request carrying explicit identity was refused. A fresh legacy-shaped request now resolves that pair to a single active register entry or is refused with an actionable compatibility reason. Replays are untouched: an accepted request is answered from its receipt before this runs, and the shipped client always sends governed identity, so this path serves only older submissions. The unit and emulator fixtures that assigned to an unregistered asset were corrected rather than the rule weakened. |
| D09-02 embedded module fields can hide a required reading and still yield closure attestation | **repaired** | A published template can describe one module's fields twice: embedded in the module, and in the template's own definitions linked back by module code. Materialisation took any non-empty embedded list and stopped, so a module whose embedded list held only optional text dropped the required reading linked to it, and the job closed and issued a closure attestation without it. Nothing is merged to fix this — a module's two lists can legitimately describe alternative modes, and a union would materialise a module nobody published. Agreeing accounts materialise exactly as before; a disagreement, whether the reading is missing or its required flag differs, is refused at assignment, naming the field. The required flag is read as the closure validator reads it, and the field key through the producer's own alias contract rather than a second copy of it. |
| D09-03 publishing a resumed older draft can create a pointer current Rules reject | **repaired** (client) | The governed store requires a package's active version to be its latest one. A draft resumed after another version was published kept its own older number, and publishing it left the package active on that older version while the counter stayed where it was — a package the store refuses, so the publication could never synchronize while the device went on showing it as published. Publication is now monotonic: a draft not already beyond the published history is published under the next free number, and the package counter follows the version it points at. Nothing already published is renumbered, rewritten or deactivated, the draft keeps its own number while it is a draft, and the operator is told when a resumed draft was published under a new number. The rule is a small domain function with its own tests rather than arithmetic inside a screen, so the store's invariant is asserted directly. |
| D10-02 asset retirement overlooks a concern that still affects Plant Condition | **repaired** | An issue closed administratively while explicitly still relevant is resolved in the lifecycle sense and not in the plant's: Plant Condition keeps counting it, but the retirement guard asked only whether the issue was unresolved, so the asset could be retired underneath it and the retained concern was left pointing at an asset no longer in the active population. Both sides read the same rule now — a concern still applies while it is open, or while its administrative closure says it remains relevant — and the query was widened to return those records at all, since a still-relevant closure is marked resolved. Ending the concern's relevance remains the supported way through, and the regression walks that route. |
| D10-03 workflow deployment can say In Service while operational inhibitions remain | **partly repaired** | Two parts of this were repairable without an owner's decision. Deploying equipment whose register entry is administratively out of service is refused, matching the rule that already refuses an operational condition declaration on such an asset; only an explicit out-of-service entry refuses, so a missing or differently shaped asset row never turns a deployment into a failure for an unrelated record's sake. And the board no longer announces a return to service it did not adjudicate: the confirmation says the equipment is marked In Service on this board and that condition declarations and open issues are recorded separately and are not cleared by it. What remains is in the next section. |

Chapters SRC-16 and SRC-17 cover domains 11 to 18 together and have not been read.

## Left for a decision: what a workflow deployment means

D10-03's remaining part is not a defect with a correct repair, it is a question
about scope that belongs to the business and Safety owner, and the audit says so
too. Deploying equipment either releases it from the maintenance workflow, or it
is an operational return-to-service decision. If it is the first, the board
should show the inhibitions that still stand beside the equipment so nobody
reads the row as fitness. If it is the second, it needs a transactional,
identity-bound readiness contract over the condition declarations, the register
and the applicable issues, and the authority to make that call.

Two things were deliberately not done while that is open. The equipment board
was not wired to the composite plant state: that is a new data dependency on a
live operator screen, and which inhibitions to show depends on which of the two
meanings is chosen. And reconciliation was not changed to drop an existing
In Service projection when an asset later goes out of service; nothing in the
audit asks for it, and it would move a state rather than refuse a new one.

## A review of the repairs themselves

An external review read the commits on this branch rather than the original
domains, and found four defects in the repairs. All four are repaired here.

| Finding | Status |
|---|---|
| R1 a standalone case's decision was compared against governed subjects the warning never carried, so any decided standalone case read as stale | repaired |
| R2 a decision returned for review by a correction or a repair kept the re-annealing answer that decision had given | repaired |
| R3 a skipped notification receipt returned no attempt identity, so the caller could not name the attempt it had just been told about | repaired |
| R4 a lifecycle claim keyed on the time the work was performed, so a contradictory time made a second event instead of a refusal | repaired |

R2 is worth naming precisely, because the commit messages on this branch claimed
the repair left a case "exactly as a reopen leaves it" and it did not.
`REOPEN_QUALITY_WARNING` withdraws the re-annealing judgement with the decision
that made it, keeping a completed re-annealing and its charge because that is
something that happened rather than something decided. The projection repair and
the reviewed repair left `notRequired` standing under a case they had just
returned for review, so the case read as an open question whose re-annealing
answer was already final. One rule now states what a withdrawn decision leaves
behind, and the two write paths and the frozen-command replay derivation all
read it; the replay regressions fail when the derivation is removed, because a
lost response would otherwise come back as tampered evidence.

## A sweep for the recurring class

Three of the repairs above — D02-01, D06-01 and D10-01 — are the same mistake in
three domains: a consumer written from an assumption about its producer rather
than from the producer, so the application refuses records it made itself, and
the test that should have caught it was written against the consumer's imagined
shape. Because the mistake is mechanical, it can be searched for.

Searching every backend site that judges a governed asset reference by its own
list of schema versions or scopes, rather than by the contract that produces the
reference, found one more: retiring an asset read an open condition-changing
issue's reference through a two-scope list, so an ordinary component issue on
that asset was reported as damaged data — `asset-instance-open-condition-ticket-malformed`
— instead of as the open condition that genuinely stands in the way of
retirement. That is repaired, with an emulator regression that fails without it.

Two sites were examined and deliberately left: replacement evidence in the asset
registry, and the Inner Cover association rule, both of which restrict scope and
schema for a stated domain reason rather than by oversight.

A broader sweep for fields read but never written anywhere was attempted and is
not reported: the heuristic produced too much noise to distinguish a real
invented field from an ordinary type member, and a noisy list presented as
findings would be worse than none.

## What a repair here has to keep

Every item above sits behind the same constraints the quality-case work
established, and they are not negotiable in a later pass:

- Nothing rewrites an immutable audit, a stored command's bytes or a receipt
  fingerprint to make a comparison succeed.
- A repair of damaged data is a reviewed operation that derives its values from
  a stated source of truth; it never invents evidence.
- A test proves the defect before it proves the fix, and it is built against the
  real producer rather than a hand-written fixture of what the consumer expects.
