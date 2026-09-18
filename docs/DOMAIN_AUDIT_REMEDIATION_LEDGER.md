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
| D03-01 old inspection evidence can qualify a cover after later repair or retirement | **partly repaired** | Filed with the correction family, wrongly again — and this one is an assurance defect, not a records question. A cover accepted on 2 August, removed into repair on the 8th or retired as bulged, could be re-accepted on the 11th using the same 2 August inspection and installed under a Base. The only lower bound on the inspection date was the original receipt. **Decision: a re-acceptance cannot rest on the evidence the previous one already used.** An inspection dated at or before the acceptance it replaces certifies nothing about what happened since, so it is refused. The comparison is between two physical inspection dates, never recording times, so evidence entered late is unaffected. Three existing tests re-accepted returned covers on the original inspection — the audit names one of them as revealing — and they now date the re-inspection to the return that prompted it. What remains is the fuller model the audit describes: a recorded assurance episode with the physical event that invalidated the previous clearance, which would also refuse an inspection dated after the last acceptance but before the damage. That needs a physical event time the lifecycle does not record today. |
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
| D04-03 a stale partial matrix edit overwrites a newer observation | **repaired** | I had this filed as needing the sparse-versus-full distinction first. It does not. A round is eight positions witnessed against what the furnace read when the observer opened it, and the submission can simply name that: it carries the condition round it was composed against, and is refused when a newer one now stands. The deliberate complete survey is untouched - re-open the furnace on the round that stands and record it - and the sparse-edit protocol is still the open design question for D04-02's remainder, not a prerequisite for this. The draft already knew the answer: its source key leads with the round it was built from. A client that cannot say which round it composed against sends nothing and is judged exactly as it was, rather than asserting there was none; the field enters the command fingerprint only when it is sent, so existing receipts still replay. |
| D04-05 editing during an in-flight save can lose the newer draft | **repaired** (client) | The matrix disabled the save controls while a save was in flight but not the position inputs, and the reply cleared the draft's pending state outright. An observation recorded during the save was therefore marked as recorded although it was never in the envelope, and the next snapshot - arriving under a new source key because the save had just produced one - replaced the draft with the server's copy of the earlier one. A draft now carries which revision of itself was submitted; the reply settles that revision only, an edit made during the flight keeps the draft pending, and a pending draft is never replaced by an arriving snapshot. Whoever recorded the round is told how many furnaces are still pending rather than being shown a bare success. The draft moved out of the screen into its own domain type so the sequence is asserted directly; the tests fail against the old arithmetic. That extraction also took a responsibility out of a presentation file, so its architecture-boundary exception no longer applies and was removed. |
| D04-06 an explicit installation correction path is unestablished | **partly repaired** | An installation recorded on the wrong date could not be put right by recording another replacement: a later entry is another physical event, and correct ordering leaves the mistaken date current with the truth in history. Using the `revised` disposition for it is the same thing relabelled, which the commissioning brief asks to keep apart. **Decision: a correction is its own event.** It names the event it replaces and says why, the original stays exactly as recorded, and what is installed now is rebuilt from the evidence that survives — which is why it cannot reuse the ordinary write plan, since that only moves the projection forward and a corrected date can move it back, to an earlier replacement that was the true one all along. An event already corrected is not corrected twice, and a correction that would leave the position with no installation is refused. What remains is the surrounding command: this is the write plan and its rebuild, exercised directly; wiring it to a dispatcher command with `integrity.adjudicate` authority, an audit and a receipt is the last step, and the same rebuild serves the UV detector lifecycle, which has the identical shape. |

## Domain 05 — Inspection campaigns, findings and corrective verification

Chapter SRC-08 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D05-01 correct physical subject, wrong corrective episode | **repaired** | Linking an observation to the maintenance issue that repaired it wrote that issue onto whichever finding was currently active for the target, without establishing that the observation belonged to that episode. A repair carried out for an earlier, already-adjudicated episode therefore became the later episode's corrective action, and the later episode could no longer take the issue that actually belonged to it. An observation now belongs to an episode when it is that episode's origin or a correction of it through the recorded supersession chain; the historical reference is still recorded either way, and only the owning episode is bound. |
| D05-02 "not numerically out of range" becomes "within defined condition" | **partly repaired**, rest **decision** | Only a numeric limit produces an adverse result, so boolean, choice and text observations are recorded with `outOfRange: false`, and the report printed that as conformity. One part of this needs nobody's decision: whether an observation was assessed at all is determined by the stored evidence, since a comparison happened exactly when a numeric reading met a defined limit. The report now says "Recorded; no defined condition to assess it against" for everything else, including a numeric reading on a definition that sets no limit. Nothing is migrated and no stored value changes meaning: the distinction is derived at read time from the observation and the frozen definition it already carries. What remains is the owner's: the assessment model that separates conforming from not comparable, and the predicates saying which boolean or choice value is adverse. Until those exist, the application no longer claims conformity it never established. |
| D05-03 historical non-current errors have no amendment route | **repaired** | Correction was permitted only on the reading that currently certifies a target, so a reading known to be wrong but no longer current had no way out - and inventing a fresh physical reading to get around that is worse than the error. **Decision: an amendment says explicitly that it is one, and says why.** It names the earlier reading it replaces, carries its reason, and is otherwise held to every rule an ordinary correction is held to; correcting the current reading stays the ordinary route and cannot be dressed as an amendment. The original stays exactly as recorded. The consequence machinery needed no work: the episode already recomputes its surviving adverse evidence over unsuperseded readings, so where an amendment removes the basis of a decision the finding asks for evidence review rather than silently certifying itself — which is what the audit asked for. The safeguard against a correction merging an earlier terminal episode is not relaxed by stating a reason. |

## Domain 06 — Operational disruptions and occurrence identity

Chapter SRC-09 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D06-01 the linker calls current, producer-valid tickets malformed | **repaired** | Two shapes this application produces itself were read as corrupt data. A governed reference is now read by the contract that produced it, which knows each scope's schema version and checks that the reference names this very asset — so an ordinary component-on-asset issue links instead of being refused as malformed evidence; older shapes are still read as before. An issue closed administratively is likewise a state this application records, not malformed data: it is recognised, and the link keeps the real status and resolution, so nothing counts a closure without resolution as a technical repair. |
| D06-02 correcting occurrence facts strands or invalidates links | **partly repaired**, rest **design** | Two halves are repaired. The first is the contradiction the event could commit: linking an issue checks that it belongs to the occurrence's governed scope, and correcting that scope afterwards could leave the event listing as current a link its own rule would refuse, so a narrowing or moving correction is held while issues are linked, naming them. The second is the stranding: a link's identity derives from the occurrence start, so correcting the start left every existing link stored under an identity nothing could reach again - neither current nor relinkable - while the event went on listing it. That correction is held the same way, with the same route through. A test that asserted the links survived such a correction was asserting the stranding; its two subjects are separated, and link survival is now asserted on a correction that is allowed. What remains is the larger repair: a durable occurrence identity that survives a corrected start, and a migration that does not reassign existing link identities by recomputation. |
| D06-03 reopening is not correction of an erroneous closed interval | **partly repaired** | Two of the four cases the audit distinguishes are repaired: a duplicate recording and an entry that never happened. **Decision: withdraw, never edit.** The interval stays exactly as recorded, because it is evidence of what somebody entered; what changes is that it stops counting as a disruption, in cumulative time, occurrence counts and the leading topic. The withdrawal carries its reason, actor and time, and appears in the audit's before and after. A withdrawn entry is not edited, resolved or reopened afterwards, which is the fabricated recurrence this route exists to make unnecessary; an entry that was never withdrawn keeps exactly the shape it has always had, and a record written before the route existed reads as not withdrawn. What remains is the third case, a corrected end time, which changes a number rather than whether it counts, and belongs to the amendment contract below. True recurrence was always supported and is untouched. |

## Domain 07 — Morning Review and action follow-through

Chapter SRC-10 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D07-02 typed asset references can name non-existent or contradictory subjects | **repaired** | An action's asset is typed identity — the agenda groups by it and people are held to it — but the write stored whatever the client sent, so an action could name an asset the register does not hold, or name a real instance under another class, number and label. The register is now read at the write: an unknown asset and an instance that belongs to another class are refused with nothing written, and the class name and asset number recorded are the register's rather than the label supplied. The same shape exists on the minutes-entry path, which this audit did not exercise; it is unfixed. |
| D07-01 yesterday's unfinished minutes cannot be finalized today | **repaired** | Filed with the correction family, wrongly: this asks for a way to *finish*, not to rewrite. A meeting held on the 10th and left open could never be closed, because every operation but addenda and action lifecycle was bound to the current plant day. **Decision: a meeting that was held can have its minutes closed late.** Finalizing an open session from an earlier day is allowed, and so is the facilitator takeover that lets somebody close one whose facilitator is away — as an administrative act, since an Admin closing an abandoned meeting is not claiming to have attended it and joining it today would be the false record. Nothing else moved: an old meeting never pretends to be today's, a held meeting is still never recorded as not held, and a past day still cannot be opened as a new session. The lateness needed no new field — the session already carries the day it was held and the time it was finalized, and the session document is read by an exact-field client reader that an added field would break. |
| D07-03 cancellation, reassignment and correction are not completion | **decision** | |
| D07-04 inspection uncertainty is lost in the management snapshot | **partly repaired**, rest **client build** | My earlier note called this the same root as D05-02. It is not, and reading the dossier entry properly made it tractable. An inspection finding whose only adverse reading was later corrected keeps three markers saying technical verification cannot substitute for reviewing the corrected basis; the Morning Review compiler dropped all three, so the frozen minutes showed an ordinary item awaiting verification while the originating module demanded a different adjudication first. The manager now reads 'Evidence review required before verification' in the summary, in place of a recurrence count that a correction leaves standing at one while nothing adverse remains. **The markers are deliberately not added as fields on the fact.** The installed client reads a source fact with an exact field set and refuses any Morning Review schema but 1, so an additive field would stop it reading the very session that carries the finding. The tolerant reader is in this branch and a regression pins the emitted shape, so carrying them as structured data is a one-line change once a client that can read them is the installed one. |

## Domain 08 — Reactive maintenance

Chapter SRC-12 of the dossier.

| Finding | Status | Note |
|---|---|---|
| D08-02 repair closure supplies physical completion time as recording time | **repaired** | Closing a reactive repair passed the closure time as both the completion and the recording time of the component-life event, so work finished at 04:00 and entered at 07:00 was recorded as if the evidence had existed at 04:00. The recording time is now the server clock at the write, and the physical completion time is preserved untouched. The planners enforced the equality too: they now require only that a recording cannot precede the completion it records. |
| D08-01 an audited component or tag correction can contradict the retained subject | **design** | A correction changes the component and tag while the retained governed reference still names the original node, leaving one record describing two subjects. The repair needs the model to say which is canonical and which is a display alias, and a reviewed route for a true subject change; refusing the correction without that route would strand ordinary work. |
| D08-03 still-relevant administrative closure has no technical follow-through | **repaired** | Filed with the correction family, wrongly: this asks for a way *forward*, not a way to rewrite the past. An issue closed administratively while explicitly still relevant could be neither reopened (the status is not technically resolved) nor resolved (the record is terminal), so when the work became practical there was nowhere to do it. **Decision: a linked continuation, not a reopen.** The closure was a true decision and stays one; the new work is new work, with its own dates, assignee and technical resolution, naming the concern it continues so the two read as one story. One open continuation at a time, and it must be about the same physical subject. The original's relevance still ends only through its own administrative decision — nothing here flips it. The four-hour physical-closure guard on ordinary reopening is untouched. |

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

## Domains 11 to 18 — the remaining business functions

Chapters SRC-16 and SRC-17, which cover these eight domains together and number
their findings R-01 to R-10 rather than by domain. All ten are listed here; only
the rows marked otherwise have been checked against the current source.

| Finding | Status | Note |
|---|---|---|
| R-01 an acknowledgement capability can change unrelated directive content (13, directives) | **repaired** | The burner directive rule limited which fields an acknowledgement may touch; the ordinary one did not, so a recipient could change what the instruction said in the same write that acknowledged it, and the record went on attributing the changed instruction to its issuer. Closing had the same gap. Both now carry the list of what the operation is allowed to touch, taken from what the client actually writes: acknowledging records the acknowledgement, closing records the outcome including the remark that closes it, and changing the instruction remains an Admin correction with its own authority. The audit could only model this; the three refusals and the legitimate closure are now proven against the Rules engine itself. |
| R-02 a later valid authority change blocks recovery of an earlier accepted one (14, user administration) | **repaired** | Replaying an accepted authority command compared its recorded outcome against the target's authority as it stands now, so an ordinary later change by somebody else made the earlier acceptance unrecoverable: support could not tell an accepted command from a failed one using the original request. What a request committed is now settled by its own immutable pair, the receipt and the audit written in the same transaction, and the outcome returned is the one that pair records rather than whatever the live capsule says. The current authority is reported beside it, with a flag saying it has moved on, instead of being folded into the outcome - which also removes a quieter fault, since the replay used to return live roles under the earlier request's name. Replay still writes nothing, and a receipt that disagrees with its audit still fails closed. |
| R-03 permanent pilot removal leaves active completion and due-state effects (17 and 11) | **partly repaired** | A classified ticket resets maintenance counters, and the completion event, its source projection and the due state it produced outlived the ticket when the ticket was permanently removed. The due state carries a next-due date the plant schedules against, so cleanup left the cadence being driven by work that no longer existed. The purge now refuses while any of the three still names the record, in the same shape as every other dependency it already blocks on, and a completion belonging to another ticket or another source type is unaffected. What is deliberately not done is the second branch the audit offers: an audited withdrawal that removes the derived effects and recomputes the counters from surviving evidence. That decides whether genuine maintenance history may be withdrawn along with its ticket, which is the owner question recorded above. |
| R-04 rejected due-state records disappear from the list used for headline counts (11 and 18) | **repaired** (client) | A due-state record that cannot be read was dropped from a plain list, and the headline counts built on that list could not tell a complete population from a short one. Zero overdue read as an all-clear. The tolerant decoder already documented this hazard and named where it must not be used; due state was one of those places. The read now returns a batch carrying the rows that decoded and the identities that did not, so the count and its coverage travel together. The due-state screen says how many records could not be read and refuses to show an empty list as 'no classified completion yet' when the population is short; the home screen's headline is marked incomplete through the mechanism it already had; and the operations report raises an incomplete-evidence signal whatever the overdue count says, including zero. Registering the new read changed four governance inventories, which are re-pinned. |
| R-05 a plan can claim a nonexistent due-state source and reach Ready (11) | **repaired** | A plan could name any due-state id as the counter it was raised from, and the plan then scheduled and reached Ready carrying provenance nobody could follow back. A named source is now checked against what the plan itself says: it must be one of the counters this plan's own maintenance class resets, on this plan's own asset, and it must exist. The check is derived from the contract that writes due state - the same asset identity key and counter key the producer uses - rather than from a second idea of what a due-state id looks like. Planning without a source stays supported, because not every plan comes from an overdue counter. |
| R-06 retired subjects and definitions lack a historical-entry or amendment route (11) | **repaired** | Filed with the correction family, wrongly: this asks to record a true past fact, not to amend a record. Historical maintenance required a currently active asset, so work genuinely done before a furnace was retired could not be written down - and the audit names the consequence, that whoever holds the register feels pressure to un-retire an asset to record a fact. **Decision: a retired asset is still the asset the work was done on.** The entry is accepted and produces the same immutable completion event and source as any other. What it does not produce is due state: a retired asset has no next service, and writing one would have the schedule claim work on something the plant no longer operates. A deleted record is still refused, because there is no subject, and so is an identity that has moved on. |
| R-07 a deliberately empty active catalogue can return embedded suggestions again (16, knowledge) | **repaired** (client) | An empty active catalogue was read as one situation when it is two. A device that has never held a catalogue needs the embedded safety baseline to have anything at all; a catalogue whose rows the plant has withdrawn is empty on purpose, and substituting the baseline there put a withdrawn rule back in front of someone as current guidance. The store itself says which - a row of any status, including a retired one, means the catalogue exists and its emptiness was decided. That distinction is now one named rule that the loader and the stream both read, and a withdrawn catalogue is described as itself rather than as a fallback. First use is unchanged. |
| R-08 an accepted knowledge update can fail before its audit is recorded (16) | **repaired** (client) | A knowledge revision commits in cloud, and then the device read it back before writing the audit entry. A failed read-back skipped the audit altogether and told the author their change had failed, while the cloud already held a changed authoritative instruction with no account of who changed it or why. The audit is settled first now, and reading the revision back is what it is: this device catching up. A failure there is reported as the rule being saved but not yet shown here, not as a failed change. Both the creation and the update path go through the one rule, and its tests fail against the ordering being replaced. |
| R-09 a stale local diary draft can replace a newer stored revision (16, job diary) | **repaired** (client) | The writer read the stored entry only to take an audit snapshot, then put the whole object over it with the version already advanced, so an edit opened against an older revision was written back under a newer number and the work it never saw was gone without a word. The read is now the precondition for the write, inside the transaction that writes: a save advances the entry only if the store still holds the revision it was opened against, and otherwise is refused with a message that says the note is still on screen. A removed or withdrawn entry is not recreated by a save. The web writer had the same shape and is corrected through a transaction. Same family as D04-05. |
| R-10 recovery of an existing review proof is coupled to its original reviewer (17) | **repaired** | Retrieving an existing saved-submission review compared the asking Admin against the one who made it, so a lost response could only be recovered while that one person was available. Inspection now recovers the proof for any approved Admin and returns the original reviewer on it unchanged. Everything identifying the evidence still has to match exactly, and finalization still requires the complete original binding with its reviewer, so retrieval never becomes re-execution under a new name. The permanent cancellation and acceptance holds are untouched. |


## Correcting a record that is no longer current

I grouped seven findings here as one question — what it means to correct a
record the plant has already acted on, and who may do it — and treated the whole
group as an owner decision. That grouping was wrong, and re-reading each dossier
entry rather than my own summary of it showed why. Four of the seven were not
correction problems at all:

| Finding | What it actually asked for | Status |
|---|---|---|
| D07-01 | a way to *finish*: a meeting that was held could never have its minutes closed | repaired |
| D08-03 | a way *forward*: a retained concern with nowhere to be worked | repaired |
| R-06 | a way to record a true past fact about a now-retired subject | repaired |
| D03-01 | assurance freshness: a cover returning to service on pre-damage evidence | partly repaired |

Three are genuinely retrospective amendment, and they are one contract:

| Finding | The record that is wrong |
|---|---|
| D04-06 | an installation recorded on the wrong date |
| D05-03 | an inspection reading that is no longer the current one |
| D06-03 | a closed disruption interval that never happened, or ended at the wrong time |

**Decision: build one governed amendment operation, modelled on
`RECONCILE_QUALITY_CASE`, which already does this shape in this branch.** Its
terms, which both audits arrive at independently:

- It is separately authorised and separately named. It is never the ordinary
  correction path with a guard relaxed, because the ordinary path's refusals are
  right for the current record.
- The original stays exactly as recorded, with who recorded it and when. The
  amendment is a successor that names what it supersedes, not an edit.
- It carries the reason, the author, the reviewed versions of every record it
  touched, and the episode or baseline affected.
- It recomputes only the projections whose meaning changes, and where a decision
  it supported is no longer supported, it returns that decision for review
  rather than erasing or re-certifying it.
- It distinguishes the four cases the sixth domain names: a duplicate recording,
  a withdrawn erroneous entry, a corrected value, and a true recurrence — which
  already works and must not be the workaround for the other three.

Why it is not built here: each instance is a full governed command — authority,
audit, receipt, replay derivation, consumer recomputation — and the value of
this contract is entirely in getting those right. Two of the mistakes this
branch had to correct came from moving fast on exactly that kind of surface. The
contract above is the decision; implementing it is the next unit of work, and it
is mechanical from here.

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

## What is left, and what it is waiting on

Every finding in the dossier and the three later domain audits has now been read
against the current source. What is not repaired is not unexamined; each item
below is blocked on something this work cannot supply for itself.

**Decided, not yet built.** The one governed amendment operation above, for
D04-06, D05-03 and D06-03. The contract is settled; the work is a full governed
command each time.

**Waiting on the plant owner.** What deploying equipment is meant to assert
(D10-03's remainder): a workflow release, or an operational return to service
with a readiness contract behind it. The board already stopped claiming the
second.

**Waiting on a design decision that changes stored shapes.**

| Remainder | What it needs |
|---|---|
| D04-02 carrying an observation forward with its own time, observer and evidence episode | a sparse compliance event, or field-level provenance on a round. Today a round is eight positions or nothing, which is why compliance had to copy values it did not observe. The worst of it — a round recorded before UV and draft-seal evidence existed being read as eight serviceable positions — is repaired. |
| D06-02 a durable occurrence identity | a link identity that does not derive from the editable start, plus a migration that does not reassign existing link identities by recomputation. Both stranding routes are now held rather than committed. |
| D08-01 component and tag against the retained governed reference | the owner to say whether `component` and `tag` are canonical subject fields or a narrative alias. Both readings are coherent and they need opposite repairs: resolve the text against the hierarchy, or stop presenting it as the canonical target. Refusing corrections without deciding would strand ordinary work. |

**Not blocked, and deliberately not attempted here:** the client-side work the
audits list as ordinary product change rather than defect, and the integrated
device campaign that would turn source repair into demonstrated delivery. Both
are named in the audits' own roadmaps.

## What a repair here has to keep

Every item above sits behind the same constraints the quality-case work
established, and they are not negotiable in a later pass:

- Nothing rewrites an immutable audit, a stored command's bytes or a receipt
  fingerprint to make a comparison succeed.
- A repair of damaged data is a reviewed operation that derives its values from
  a stated source of truth; it never invents evidence.
- A test proves the defect before it proves the fix, and it is built against the
  real producer rather than a hand-written fixture of what the consumer expects.
