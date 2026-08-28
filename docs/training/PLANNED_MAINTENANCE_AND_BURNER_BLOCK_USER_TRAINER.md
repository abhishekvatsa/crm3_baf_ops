# CRM-III BAF Ops

## Planned Maintenance and Furnace Burner-Block User Trainer

**Product:** CRM-III BAF Ops

**Plant context:** SAIL Bokaro Steel Plant, Batch Annealing Facility

**Prepared for:** Operations, Mechanical, I&A, Electrical, RED, supervisors, SI and Admin

**Maker:** A ManMithas Productions
**Source status:** Current-source training guide. Production availability depends on the next governed build and deployment campaign.

## 1. What this guide teaches

This guide explains how to:

- find and use the planned-maintenance workspace;
- understand Jobs, Workflow and Templates;
- select the exact governed asset rather than rely on free text;
- record component-level work from the active asset hierarchy;
- use an installed component tag or a governed hierarchy component;
- complete ordinary and governed planned work;
- record Furnace burner-block investigation and replacement correctly;
- distinguish RED manufacture, purchased supply, Mechanical installation and I&A investigation;
- understand the automatic burner-block lifecycle and condition update; and
- recover from validation or synchronization blocks without manufacturing evidence.

The guide is operational training, not a substitute for plant safety procedure, permit-to-work requirements, isolation practice or approved maintenance instructions.

## 2. Role model

### Operations

- Provides operating context, equipment availability and required support.
- May raise or observe maintenance needs according to assigned authority.
- Does not record a physical burner-block installation unless acting within an authorized Mechanical work context.

### Mechanical

- Investigates the physical burner block and firing tube.
- Installs or replaces burner blocks.
- Records the replacement component action and its physical provenance.
- Must be present in the work evidence when a burner-block replacement is closed.

### I&A

- Investigates UV detection, flame supervision, ignition and burner-control evidence.
- Records microamp observations where available.
- Observes burner-block condition at the UV/flame interface and can raise red-hot evidence.
- Does not become the physical installer merely because it first detected the condition.

### RED

- Manufactures the SAIL-made burner-block route.
- Is the source of a `SAIL-made by RED` block, not the installing discipline.

### Electrical

- Handles electrical evidence such as relay, supply and wiring work when included in the planned job or requested through coordination.

### Shift Supervisor, SI and Admin

- Exercise only the powers visible for their approved role.
- Review workflow, evidence completeness and closure readiness.
- Administer governed templates, hierarchy and corrections where authorized.
- Never use correction powers to fabricate field evidence.

## 3. Find the planned-maintenance workspace

1. Open the app and sign in with the approved account.
2. Check the sync indicator before starting connected work.
3. Open **Work** and choose **Planned maintenance**.
4. Use the three views shown for your role:
   - **Jobs**: open planned jobs assigned to physical assets.
   - **Workflow**: lane obligations, support requests and compliance work.
   - **Templates**: reusable plans, visible only to authorized users.
5. Use search to find a job, asset, lane or template.

Do not start a second job merely because a connected item is temporarily absent. Refresh and check Workflow before creating or assigning more work.

## 4. Understand the planning routes

### Route A: Existing or normal planned job

Use the assigned job, complete its modules, add structured component actions and close it through the server-authoritative completion step.

### Route B: Published governed template

An authorized planner selects a published immutable template version and assigns it to an eligible active physical asset. The server revalidates the asset class, asset identity and published snapshot before creation.

### Route C: Governed custom template

The template carries an explicit governed hierarchy class. Assignment cannot fall back to a freely typed legacy asset number.

### Route D: Runtime-added module

An authorized user may add a permitted module to an existing execution. The module becomes part of the same governed execution and closure evidence.

### Route E: Historical maintenance addition

Historical addition is for prior work that did not originate as a live app execution. It is not a shortcut for bypassing a current job, module, approval or closure path.

## 5. Choose the exact asset

1. Confirm the asset class.
2. Choose the active physical asset offered by the app.
3. Confirm the visible asset number and hierarchy context.
4. For Inner Cover work, choose the Base currently carrying the cover. Confirm the frozen Inner Cover serial shown at assignment.
5. Stop if the expected asset is retired, missing, duplicated or linked differently from the field condition.

The app binds new governed work to both an asset-class identity and a physical-asset identity. A typed display number alone is not sufficient authority.

## 6. Work through a planned job

### Before field work

1. Open the job dossier.
2. Read its asset, template, module and team context.
3. Confirm the job is the right physical asset.
4. Review every required module and evidence field.
5. Resolve any outstanding Workflow obligations or coordination requests.

### During field work

1. Open the relevant module.
2. Enter observations honestly and in the intended units.
3. Add a component action for inspection, repair, revision or replacement.
4. Use the hierarchy picker to move from subsystem to component or subcomponent.
5. Use the exact installed tag when known, or settle on the governed hierarchy component when no tag is required.
6. Record notes that explain the evidence, not a guessed diagnosis.
7. Submit the module through the available governed action.

### Before closure

1. Confirm all required modules are complete.
2. Confirm each physical replacement has a structured replacement action.
3. Confirm the involved teams are accurate.
4. Run the connected preflight/full sync when prompted.
5. Resolve unsynchronized current-job modules instead of closing around them.
6. Complete the job and wait for the server receipt.

## 7. Component actions and hierarchy selection

When adding **Repair / replacement / inspection action**:

1. Select the action type.
2. Choose **Asset hierarchy**.
3. Progress through the hierarchy until the actual component is selected.
4. If you know a tag, use tag resolution only for a tag belonging to the job's asset class and exact governed component.
5. Confirm the displayed hierarchy path.
6. For replacement, choose the replacement disposition and enter the physical evidence requested.
7. Add a concise result or observation.

### Tag behavior

- An installed physical component tag identifies one claimed component and is revalidated by the server.
- A hierarchy definition tag identifies a governed component definition in the selected asset context.
- If a definition tag is ambiguous, the app fails closed and Admin must reconcile the hierarchy.
- Clearing an installed tag does not invent a component identity. The action remains bound to the selected governed hierarchy definition.
- Never reuse a tag to force a match with the wrong asset.

## 8. Furnace burner routes

### F-03: I&A burner, UV and flame-supervision investigation

Use F-03 for:

- UV detector and flame-signal investigation;
- ignition and flame-supervision evidence;
- burner-control observations;
- microamp readings;
- observation of red heat, missing castable or cracking; and
- identifying the need for Mechanical physical investigation.

F-03 does not itself prove that Mechanical replaced a burner block.

### F-03M: Mechanical burner-block investigation and replacement

Use F-03M for:

- Mechanical inspection of the selected burner block and firing tube;
- red heat, missing castable, cracking and physical damage;
- deciding whether the block was changed;
- recording the numbered replacement action; and
- closing Mechanical installation evidence.

Do not add F-03M merely because the planned job is for a Furnace. Planned
maintenance can close without burner-block work. If F-03M is used and `Burner
block changed` is No, no replacement action is required and the burner-block
lifecycle and current-condition projection remain unchanged.

If `Burner block changed` is Yes, the server requires the matching structured replacement action. A narrative statement alone is insufficient.

## 9. Record a burner-block replacement

1. Work within a Furnace planned job or governed maintenance issue.
2. Ensure Mechanical is included in the work evidence.
3. Add a **Replacement** component action.
4. Select the Furnace burner-block hierarchy component.
5. Choose Burner position 1 through 8.
6. Set the action outcome to resolved/completed as required by the form.
7. Choose the source:
   - **SAIL-made by RED**; or
   - **Purchased**.
8. For a purchased block, optionally enter Supplier name and Purchase Order number.
9. Record the replacement disposition and useful field notes.
10. Complete the relevant module and parent job or issue.

At closure, the server revalidates the Furnace, hierarchy node, tag evidence, Mechanical work context, burner number and supply-source fields. Valid evidence appends an immutable lifecycle event and updates the server-controlled current condition for that Furnace and burner position.

### Record a UV-detector installation or replacement

1. Work within a Furnace maintenance issue or any planned-maintenance route.
2. Ensure I&A / Instrumentation is included in the work evidence.
3. Add a **Replacement** component action.
4. Select the governed UV detector, flame detector, sensor or scanner component from the Furnace hierarchy.
5. Choose the physical Burner / UV position 1 through 8.
6. Choose whether the installed detector is new, repaired or revised.
7. Mark the action resolved and complete the parent issue, module or job.

At closure, the server revalidates the Furnace and hierarchy identities, numbered position, optional tag, I&A work context and chronology. It appends immutable UV lifecycle history and projects that UV position to **In service**. This works for issue resolution, legacy planned maintenance and governed planned workflows. A later condition audit remains authoritative for the subsequently observed condition.

## 10. What changes the burner audit

### Condition round

- Records the observed state of all eight burner positions.
- Can record flame state, red-hot evidence, microamp reading and notes.
- Does not reset component life or claim replacement.

### Burner-lockout issue

- Records a fault on one or more burner positions.
- Routes I&A investigation and can include additional Mechanical help.
- Captures attendance, microamp evidence and a terminal outcome.
- A repair or reset does not automatically mean the burner block was replaced.

### Planned-maintenance replacement

- Records physical replacement through Mechanical work.
- Captures RED-made or purchased provenance.
- Updates the burner-block lifecycle and current condition only after governed closure.

### UV-detector replacement

- Records physical detector installation through I&A work.
- Requires the governed Furnace UV component and Burner / UV position.
- Updates the UV lifecycle and current condition only after governed closure.
- Does not imply that a burner block was changed.

### Re-audit

A later authoritative condition round may record the observed condition again. It does not erase immutable replacement history.

## 11. View burner condition and lifecycle

1. Open the Furnace component condition audit.
2. Select the Furnace or relevant view.
3. Review the condition tabs for burner blocks and UV status.
4. Open **Block lifecycle** to see replacement history and current installed-state evidence.
5. Open **UV lifecycle** to see detector installation history, position,
   disposition, performer and originating issue or planned-maintenance route.
6. Confirm:
   - Furnace and burner position;
   - event time;
   - replacement source;
   - supplier/PO when recorded;
   - Mechanical installation evidence;
   - performer and closure actor; and
   - linked issue or planned-work origin.

The current condition projection is server controlled. The history feed is bounded for display, while the current state is maintained separately so an old delayed record cannot replace a newer physical event.

## 12. Sync and closure behavior

- Server receipts are the authority for connected assignment and closure.
- A local success message is not a substitute for the server receipt.
- The completion screen refreshes current module state after preflight sync.
- A current job with unsynchronized modules is blocked from closure.
- Exact retries are expected to replay safely rather than duplicate work.
- If the asset, hierarchy or component changed after the form was opened, refresh and select the current evidence again.

### If completion is blocked

1. Read the exact message.
2. Check network and account authority.
3. Run Sync now.
4. Reopen the job and verify current modules.
5. Correct the missing or conflicting field.
6. Retry the same intended command; do not create a duplicate job.
7. Use diagnostics or supervisor support only when the block persists.

## 13. Supervisor review checklist

- Correct active physical asset selected.
- Required module route is present.
- Required teams match the work actually performed.
- Component action points to the exact hierarchy component.
- Installed tag, if used, belongs to that component and asset.
- Burner position is present for burner-block replacement.
- Replacement source is RED-made or Purchased.
- Supplier/PO is sensible when supplied.
- Mechanical installation evidence is present.
- I&A evidence is not misrepresented as physical installation.
- Required modules and workflow obligations are complete.
- Closure receipt is returned and the dossier shows the retained evidence.

## 14. Common mistakes

### `Burner block changed` selected without replacement action

Add a resolved Replacement component action for the same Furnace and burner position.

### I&A investigation used as installation proof

Include Mechanical work and record the physical replacement through the Mechanical route.

### Wrong or ambiguous tag

Return to hierarchy selection. Ask Admin to reconcile duplicate or incorrectly scoped hierarchy/tag data.

### Purchased source selected without supplier or PO

Supplier and PO are optional, but enter them when known because they strengthen lifecycle, supplier-performance and cost analysis.

### Red-hot observation treated as automatic replacement

Red-hot evidence is a condition/fault signal. Replacement requires a separate physical action and closure evidence.

### Microamp value treated as a universal pass/fail threshold

Record the observation. The app does not invent a plant acceptance threshold from the manuals.

## 15. Worked example

**Situation:** Furnace 06, Burner 3 shows red heat and weak flame supervision during planned maintenance.

1. I&A completes F-03 evidence for UV/flame supervision and records the available microamp observation.
2. I&A records the red-hot observation and requests/uses Mechanical involvement.
3. Mechanical opens F-03M, inspects Burner 3 and finds damaged burner-block castable.
4. Mechanical chooses `Burner block changed = Yes`.
5. Mechanical adds a Replacement action against Furnace 06, Burner 3.
6. The replacement source is selected as `SAIL-made by RED` or `Purchased`.
7. If Purchased, supplier and PO may be entered.
8. Mechanical completes its module with the physical result.
9. Remaining modules and workflow obligations are completed.
10. The supervisor performs the closure checklist and completes the job.
11. The server appends the immutable lifecycle event and updates Furnace 06, Burner 3 current condition.
12. The evidence appears in the planned-job dossier and Block lifecycle view.

## 16. Manual basis and deliberate limits

The maintenance manual requires inspection of burners, burner blocks and firing tubes for missing castable/cracking and repair or replacement. It separately identifies weak UV output and UV/lens investigation. The safety and operations manual distinguishes burner, shutoff, ignition and UV/flame-supervision elements.

Accordingly, this workflow deliberately keeps:

- UV/flame investigation distinct from physical burner-block installation;
- RED manufacture distinct from Mechanical installation;
- observation distinct from component replacement;
- immutable lifecycle history distinct from current condition; and
- server authority distinct from optimistic local form state.

## 17. Reusable pattern across the app

The same pattern should govern other critical component work:

1. select the exact physical asset;
2. select the exact hierarchy component;
3. record the discipline that performed the work;
4. retain as-found and as-left evidence;
5. capture repair/revision/replacement disposition;
6. retain supplier, purchase, fabrication or lineage evidence where relevant;
7. close through server-authoritative validation;
8. append immutable lifecycle history; and
9. update a separate current-state projection for fast operational use.

---

**Training version:** 1.0 | **Source date:** 28 August 2026 | **Current-source verification:** Flutter 1,523 passed; Rules 189 passed; governed backend emulator 87 passed; canonical source audit 147/147 passed. | **Important:** This trainer describes current source. Confirm the governed build and backend deployment identity before pilot use.
