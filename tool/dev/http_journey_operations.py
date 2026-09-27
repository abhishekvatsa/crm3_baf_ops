"""Actual-transport operational scenarios used by http_journey.py."""

import copy
import uuid
from pathlib import Path
import json
from http_journey import instant
from datetime import datetime, timedelta, timezone


def directives(j):
    identity = f"{j.prefix}-directive"
    path = f"directives/{identity}"
    j.business_paths.append(path)
    fixture = json.loads((Path(__file__).resolve().parents[2] / "test/fixtures/ordinary_directive_actual_handler.json").read_text())
    record = copy.deepcopy(fixture[0]["entity"])
    admin, ops = j.users["admin"], j.users["operations"]
    record.update(firestoreId=identity, title=f"Inspect equipment {j.prefix}", createdByUid=admin["uid"],
                  createdByName=admin["name"], issuedByUid=admin["uid"], issuedByName=admin["name"],
                  issuedAt=instant(), createdAt=instant(), updatedAt=instant())
    # Keep the same instant for issuance/creation; independently sampled clocks can differ.
    record["issuedAt"] = record["createdAt"] = record["updatedAt"]
    def request(action, before, after):
        return {"requestId": str(uuid.uuid4()), "operation": "APPLY_ORDINARY_DIRECTIVE", "directiveId": identity,
                "action": action, "expectedVersion": 0 if before is None else before["version"],
                "reason": f"{j.prefix}: {action} current instruction", "before": before, "after": after}
    def call(actor, payload):
        return j.call(actor, "mutateAssetHierarchyV2", payload, v2=True)
    create = request("create", None, record)
    state = {}
    def issue():
        state["current"] = call("admin", create)["entity"]
        j.check(j.read(path, "operations")["status"] == "open", "Issued instruction is not visible to recipient")
    j.step("directive: Admin issues an instruction visible to Operations", issue)
    before = state["current"]
    after = {**before, "version": 2, "status": "acknowledged", "acknowledgedByUid": ops["uid"],
             "acknowledgedByName": ops["name"], "acknowledgedAt": instant(), "updatedAt": instant()}
    after["acknowledgedAt"] = after["updatedAt"]
    acknowledge = request("acknowledge", before, after)
    j.step("directive: a different role cannot acknowledge for Operations", lambda: j.refuse(
        lambda: call("si", acknowledge), ("PERMISSION_DENIED",), (path,)))
    j.step("directive: recipient acknowledges the current wording", lambda: state.update(current=call("operations", acknowledge)["entity"]))
    before = state["current"]
    revised = {**before, "version": 3, "title": "Inspect equipment and record the corrected measurement",
               "status": "open", "acknowledgedAt": None, "acknowledgedByUid": None,
               "acknowledgedByName": None, "updatedAt": instant()}
    amend = request("amend", before, revised)
    def amendment():
        state["current"] = call("admin", amend)["entity"]
        j.check(j.read(path)["acknowledgedAt"] is None and j.read(path)["status"] == "open", "Amendment retained obsolete acknowledgement")
    j.step("directive: Admin amendment requires fresh acknowledgement", amendment)
    stale = {**acknowledge, "requestId": str(uuid.uuid4())}
    j.step("directive: stale recipient action cannot accept superseded wording", lambda: j.refuse(
        lambda: call("operations", stale), ("ABORTED",), (path,)))
    before = state["current"]
    after = {**before, "version": 4, "status": "acknowledged", "acknowledgedByUid": ops["uid"],
             "acknowledgedByName": ops["name"], "acknowledgedAt": instant(), "updatedAt": instant()}
    after["acknowledgedAt"] = after["updatedAt"]
    fresh = request("acknowledge", before, after)
    j.step("directive: Operations acknowledges amended instruction", lambda: state.update(current=call("operations", fresh)["entity"]))
    before = state["current"]
    after = {**before, "version": 5, "status": "closed", "isActive": False, "closedByUid": ops["uid"],
             "closedByName": ops["name"], "closedAt": instant(), "updatedAt": instant(), "remarks": "Required measurement recorded."}
    after["closedAt"] = after["updatedAt"]
    close = request("close", before, after)
    def completion():
        call("operations", close)
        j.check(j.read(path)["status"] == "closed" and j.read(path)["version"] == 5, "Directive did not complete")
        j.check(call("operations", close)["idempotentReplay"], "Lost directive completion reply cannot recover")
    j.step("directive: recipient completes instruction and exact retry recovers", completion)
    def history():
        j.check(call("admin", create)["idempotentReplay"], "Accepted issuance cannot recover after later progress")
        j.check(j.read(path)["version"] == 5, "Issuance recovery resurrected obsolete state")
    j.step("directive: historical acceptance does not reopen completed work", history)


def workflow_call(j, actor, command):
    return j.call(actor, "executeMaintenanceWorkflowCommandV2", command, v2=True, payload_key="command")


def workflow_command(kind, identity, version, payload):
    return {"commandId": str(uuid.uuid4()), "commandType": kind, "aggregateId": identity,
            "expectedVersion": version, "payload": payload}


def maintenance_tickets(j):
    class_id, asset_id, ticket_id = [f"{j.prefix}-{suffix}" for suffix in ("ticket-class", "ticket-furnace", "ticket")]
    j.seed(f"asset_classes/{class_id}", {"schemaVersion": 1, "assetClassId": class_id,
           "legacyAssetTypeKey": "furnace", "code": "HJFR", "name": "Journey Furnace", "status": "active"})
    j.seed(f"asset_instances/{asset_id}", {"schemaVersion": 1, "assetInstanceId": asset_id,
           "assetClassId": class_id, "assetClassCode": "HJFR", "assetClassName": "Journey Furnace",
           "assetNumber": 7, "name": "Journey Furnace 7", "status": "active", "version": 1,
           "ownershipStatus": "confirmed", "ownerDiscipline": "Operations", "accountableRoleKeys": ["operations"]})
    path = f"maintenance_records/{ticket_id}"
    j.business_paths.append(path)
    ticket = {"schemaVersion": 1, "version": 1, "assetType": "furnace", "assetNumber": 7,
              "component": "Journey Furnace 7", "subsystem": None, "tag": None, "hierarchyPath": [],
              "assetHierarchyRefJson": json.dumps({"schemaVersion": 3, "scope": "physicalAsset",
                   "assetClassId": class_id, "assetInstanceId": asset_id, "assetInstanceVersion": 1}),
              "maintenanceType": "breakdown", "classification": None,
              "description": f"{j.prefix}: coordinated mechanical and instrumentation investigation",
              "routedTo": "mechanical", "otherDepartment": None, "isCritical": False,
              "startDate": (datetime.now(timezone.utc)-timedelta(minutes=2)).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
              "chargeNoAtEvent": 91234, "qualityIntentSchemaVersion": 2,
              "qualityImpactAssessment": "notSuspected", "qualityWarningReason": None, "qualityAbnormalityTypeId": None,
              "issueLaneSchemaVersion": 1, "issueLaneRevision": 1,
              "issueAssignedLanes": ["mechanical", "instrumentation"], "issueAcknowledgedLanes": [], "issueCompletedLanes": []}
    create = workflow_command("createMaintenanceTicket", ticket_id, 0, {"ticket": ticket})
    j.step("issue: unapproved actor cannot raise a maintenance ticket", lambda: j.refuse(
        lambda: workflow_call(j, "pending", create), ("PERMISSION_DENIED",), (path,)))
    def created():
        result = workflow_call(j, "operations", create)
        j.check(result["resultKey"] == "maintenance-ticket-created", "Maintenance creation did not accept")
        stored = j.read(path, "operations")
        j.check(stored["issueAssignedLanes"] == ["mechanical", "instrumentation"] and stored["version"] == 1,
                "Created issue lost accountable lanes")
        j.check(workflow_call(j, "operations", create) == result, "Maintenance creation replay changed accepted outcome")
    j.step("issue: Operations creates a governed multi-agency ticket and exact replay", created)
    ack_mech = workflow_command("acknowledgeMaintenanceTicket", ticket_id, 1, {"lane": "mechanical"})
    j.step("issue: another discipline cannot acknowledge Mechanical's lane", lambda: j.refuse(
        lambda: workflow_call(j, "seniorInstrumentation", ack_mech), ("PERMISSION_DENIED",), (path,)))
    j.step("issue: Mechanical acknowledges its own lane", lambda: workflow_call(j, "seniorMechanical", ack_mech))
    complete_mech = workflow_command("completeMaintenanceTicketLane", ticket_id, 2, {"lane": "mechanical"})
    def partial():
        workflow_call(j, "seniorMechanical", complete_mech)
        stored = j.read(path)
        j.check(stored["issueCompletedLanes"] == ["mechanical"] and not stored["isResolved"], "One lane prematurely resolved multi-agency work")
    j.step("issue: Mechanical completion preserves pending instrumentation work", partial)
    finish = workflow_command("resolveMaintenanceTicket", ticket_id, 3,
                              {"endDate": instant(), "remarks": "Both disciplines verified the final condition.",
                               "teamsInvolved": ["mechanical", "instrumentation"], "actionsJson": "[]"})
    j.step("issue: discipline completion cannot finalize multi-agency work", lambda: j.refuse(
        lambda: workflow_call(j, "seniorMechanical", finish), ("PERMISSION_DENIED",), (path,)))
    reconfigure = workflow_command("reconfigureMaintenanceTicketLanes", ticket_id, 3,
                                   {"lanes": ["mechanical", "instrumentation", "operations"], "otherDepartment": None,
                                    "reason": "Operations must witness the release after coordinated work."})
    def recomposed():
        workflow_call(j, "si", reconfigure)
        stored = j.read(path)
        j.check(stored["issueCompletedLanes"] == ["mechanical"] and stored["issueLaneRevision"] == 2,
                "Lane reconfiguration erased prior completion")
    j.step("issue: supervisor adds accountable lane while retaining completed work", recomposed)
    for actor, lane in (("seniorInstrumentation", "instrumentation"), ("operations", "operations")):
        def complete_lane(actor=actor, lane=lane):
            version = j.read(path)["version"]
            workflow_call(j, actor, workflow_command("acknowledgeMaintenanceTicket", ticket_id, version, {"lane": lane}))
            completion = workflow_command("completeMaintenanceTicketLane", ticket_id, version+1, {"lane": lane})
            if actor == "operations":
                j.refuse(lambda: workflow_call(j, actor, completion), ("PERMISSION_DENIED",), (path,))
            workflow_call(j, "si" if actor == "operations" else actor, completion)
            j.check(lane in j.read(path)["issueCompletedLanes"], "Accountable lane completion missing")
        label = ("Operations acknowledges; SI completes its lane after operator closure refusal"
                 if actor == "operations" else f"{lane} acknowledges and completes its current lane")
        j.step(f"issue: {label}", complete_lane)
    finish.update(commandId=str(uuid.uuid4()), expectedVersion=j.read(path)["version"])
    finish["payload"].update(endDate=instant(), teamsInvolved=["mechanical", "instrumentation", "operations"])
    def final():
        result = workflow_call(j, "si", finish)
        j.check(j.read(path)["isResolved"] and j.read(path)["status"] == "resolved", "Supervisor resolution did not persist")
        j.check(workflow_call(j, "si", finish) == result, "Resolution cannot recover after lost reply")
    j.step("issue: SI resolves coordinated work and exact receipt recovers", final)


def critical_alarms(j):
    alarm_id = f"{j.prefix}-alarm"
    path = f"critical_alarms/{alarm_id}"
    j.business_paths.append(path)
    raised = workflow_command("raiseCriticalAlarm", alarm_id, 0,
             {"alarmTypeKey": "fire", "location": f"Isolated emulator bay {j.prefix}", "assetTypeKey": "furnace",
              "assetNumber": 7, "initialDetails": "Emulator-only fire response exercise."})
    j.step("alarm: unapproved actor cannot raise a critical alarm", lambda: j.refuse(
        lambda: workflow_call(j, "pending", raised), ("PERMISSION_DENIED",), (path,)))
    def raise_alarm():
        result = workflow_call(j, "operations", raised)
        j.check(j.read(path, "operations")["status"] == "raised", "Critical alarm not visible")
        j.check(workflow_call(j, "operations", raised) == result, "Raise retry duplicated critical alarm")
    j.step("alarm: Operations raises critical alarm and repeat recovers", raise_alarm)
    supported = workflow_command("confirmCriticalAlarmSupport", alarm_id, 1,
                {"basis": "supportDispatched", "responderNote": "Exercise response team dispatched.", "details": None})
    j.step("alarm: supervisor confirms response support", lambda: workflow_call(j, "si", supported))
    stale = workflow_command("resolveCriticalAlarm", alarm_id, 1, {"resolutionSummary": "Stale exercise decision"})
    j.step("alarm: stale resolution cannot overwrite support evidence", lambda: j.refuse(
        lambda: workflow_call(j, "si", stale), ("ABORTED", "FAILED_PRECONDITION"), (path,)))
    resolved = workflow_command("resolveCriticalAlarm", alarm_id, 2,
               {"resolutionSummary": "Exercise ended after the response team verified the safe condition."})
    def resolve():
        result = workflow_call(j, "si", resolved)
        j.check(j.read(path)["status"] == "resolved" and j.read(path)["version"] == 3, "Critical alarm did not resolve")
        j.check(workflow_call(j, "si", resolved) == result, "Resolution reply cannot recover")
        workflow_call(j, "operations", raised)
        j.check(j.read(path)["status"] == "resolved", "Historical raise replay reactivated resolved alarm")
    j.step("alarm: resolution and historical replay retain terminal state", resolve)


def morning_review(j):
    """Create the daily singleton only when no development meeting exists.

    This explicit group is not a default: subsequent runs must preserve today's
    real or already-tested session. A successful run leaves labelled frozen minutes.
    """
    day = datetime.now(timezone(timedelta(hours=5, minutes=30))).date().isoformat()
    path, document_path = f"morning_review_sessions/{day}", f"morning_review_documents/{day}"
    if j.read(path) is not None:
        raise RuntimeError(f"Preserved existing {path}; Morning Review needs an absent daily session")
    j.business_paths.extend((path, document_path))
    def request(operation, **fields):
        return {"requestId": str(uuid.uuid4()), "operation": operation, "recoveryVersion": 1, **fields}
    def call(actor, payload):
        return j.call(actor, "mutateAssetHierarchyV2", payload, v2=True)
    start = request("START_MORNING_REVIEW", expectedPlantDay=day)
    j.step("meeting: unapproved account cannot start today's review", lambda: j.refuse(
        lambda: call("pending", {**start, "requestId": str(uuid.uuid4())}), ("PERMISSION_DENIED",), (path, document_path)))
    plant_hour = datetime.now(timezone(timedelta(hours=5, minutes=30))).hour
    if plant_hour < 8 or plant_hour >= 11:
        j.step("meeting: SI cannot start outside the approved morning window", lambda: j.refuse(
            lambda: call("si", {**start, "requestId": str(uuid.uuid4())}), ("FAILED_PRECONDITION",), (path, document_path)))
    def started():
        result = call("admin", start)
        j.check(result["sessionId"] == day and j.read(path, "operations")["status"] == "open", "Meeting was not created for intended plant day")
        j.check(call("admin", start)["idempotentReplay"], "Meeting creation does not recover accepted identity")
    j.step("meeting: Admin starts absent daily review with permitted off-hours authority", started)
    for actor in ("si", "operations", "seniorMechanical"):
        j.step(f"meeting: {actor} joins recorded attendance", lambda actor=actor:
               call(actor, request("JOIN_MORNING_REVIEW", sessionId=day)))
    entry = request("ADD_MORNING_REVIEW_ENTRY", sessionId=day, entryDraft={"section": "plantWide", "kind": "update",
                    "text": f"DEVELOPMENT TEST MEETING {j.prefix}. No production operating decisions are represented.",
                    "assetClassId": None, "assetClassName": None, "assetInstanceId": None, "assetNumber": None, "sourceReferences": []})
    j.step("meeting: SI records explicit development-only context", lambda: call("si", entry))
    action = request("CREATE_MORNING_REVIEW_ACTION", sessionId=day, actionDraft={"section": "plantWide",
                     "text": f"{j.prefix}: verify development fixture documentation.", "assigneeUid": j.users["operations"]["uid"],
                     "assigneeRole": None, "assetClassId": None, "assetClassName": None, "assetInstanceId": None,
                     "assetNumber": None, "dueAt": None})
    action_id, action_path = action["requestId"], f"morning_review_actions/{action['requestId']}"
    j.business_paths.append(action_path)
    j.step("meeting: SI assigns an accountable action", lambda: call("si", action))
    def correction(kind, version, **extra):
        return request("AMEND_MORNING_REVIEW_ACTION", sessionId=day, actionId=action_id, expectedVersion=version,
                       reason=f"{j.prefix}: reviewed test action {kind}.", actionCorrection={"kind": kind, **extra})
    reassign = correction("reassign", 1, assigneeRole="seniorMechanical")
    j.step("meeting: Operations cannot change supervised assignment", lambda: j.refuse(
        lambda: call("operations", {**reassign, "requestId": str(uuid.uuid4())}), ("PERMISSION_DENIED",), (action_path,)))
    j.step("meeting: SI reassigns to an accountable role", lambda: call("si", reassign))
    stale = correction("cancel", 1)
    j.step("meeting: stale Admin cancellation cannot overwrite reassignment", lambda: j.refuse(
        lambda: call("admin", stale), ("ABORTED",), (action_path,)))
    done = request("COMPLETE_MORNING_REVIEW_ACTION", sessionId=day, actionId=action_id, expectedVersion=2,
                   reason=f"{j.prefix}: fixture documentation verified by the assigned role.")
    j.step("meeting: assigned Mechanical role completes the action", lambda: call("seniorMechanical", done))
    reopen = correction("reopen", 3)
    def reopened():
        call("si", reopen)
        evidence = j.read(f"morning_review_corrections/{reopen['requestId']}")
        j.check(evidence["before"]["status"] == "completed" and evidence["before"]["completionNote"] == done["reason"],
                "Reopen erased original completed-action evidence")
    j.step("meeting: SI reopens action while immutable correction retains completion", reopened)
    cancel = correction("cancel", 4)
    def cancelled():
        call("si", cancel)
        stored = j.read(action_path)
        j.check(stored["status"] == "cancelled" and stored["cancellation"]["reason"] == cancel["reason"], "Audited cancellation missing")
        j.check(call("si", cancel)["idempotentReplay"], "Cancellation reply cannot recover")
    j.step("meeting: SI cancels reviewed test action and exact retry recovers", cancelled)
    finish = request("FINALIZE_MORNING_REVIEW", sessionId=day, expectedVersion=j.read(path)["version"],
                     summary=f"DEVELOPMENT TEST MEETING {j.prefix}: validated attendance, reassignment, completion, reopening and cancellation; no production decisions.")
    def finalized():
        call("admin", finish)
        stored = j.read(document_path, "operations")
        j.check(j.read(path)["status"] == "finalized" and stored["finalSummary"] == finish["summary"], "Final minutes did not preserve labelled development summary")
        j.check(call("admin", finish)["idempotentReplay"], "Finalization acceptance cannot recover")
        j.check(j.read(document_path) == stored, "Finalization replay changed frozen minutes")
    j.step("meeting: Admin facilitator freezes labelled minutes and retry preserves the document", finalized)


def inspections(j):
    """Close survey scope only after accounting for its still-unresolved finding."""
    definition_id, campaign_id, observation_id, ticket_id, node_id = (
        f"{j.prefix}-{suffix}" for suffix in
        ("inspection-definition", "inspection-campaign", "inspection-reading", "inspection-repair", "inspection-component"))
    campaign_path, observation_path = f"inspection_campaigns/{campaign_id}", f"inspection_observations/{observation_id}"
    finding_id = f"inspection-finding-{observation_id}"
    finding_path, ticket_path = f"inspection_findings/{finding_id}", f"maintenance_records/{ticket_id}"
    j.business_paths.extend((f"inspection_definitions/{definition_id}", campaign_path,
                             observation_path, finding_path, ticket_path))
    admin, at = j.users["admin"], instant()
    j.seed(f"asset_hierarchy_nodes/{node_id}", {
        "schemaVersion": 1, "nodeId": node_id, "assetClassId": j.class_id,
        "parentNodeId": None, "nodeType": "component", "name": "Pressure transmitter",
        "contactArrangement": "notApplicable", "ownershipStatus": "unassigned",
        "ownerDiscipline": None, "accountableRoleKeys": [], "sortOrder": 0,
        "ancestorNodeIds": [], "hierarchyPath": ["Pressure transmitter"], "activeChildCount": 0,
        "status": "active", "version": 1, "createdAt": at, "updatedAt": at,
        "createdByUid": admin["uid"], "createdByName": admin["name"],
        "updatedByUid": admin["uid"], "updatedByName": admin["name"], "lastMutationId": str(uuid.uuid4())})
    definition = workflow_command("upsertInspectionDefinition", definition_id, 0, {
        "definition": {"schemaVersion": 1, "code": f"HJ-{j.prefix}",
                       "title": "Development pressure inspection", "description": "Emulator-only governed reading.",
                       "assetTypeKeys": ["base"], "assetClassIds": [j.class_id], "componentNodeIds": [node_id],
                       "valueType": "number", "unit": "bar", "choiceValues": [], "minimumValue": 2,
                       "maximumValue": 4, "preconditions": ["Equipment isolated"], "requiresChargeNo": False},
        "reason": "Govern the isolated development inspection."})
    campaign = workflow_command("createInspectionCampaign", campaign_id, 0, {
        "definitionId": definition_id, "definitionVersion": 1, "purpose": f"{j.prefix}: survey scope and repair independence",
        "assetTypeKey": "base", "assetClassId": j.class_id, "targetAssetNumbers": [7], "expectedPopulation": 1,
        "physicalPositionLabels": ["Pressure test point"], "baselineCampaignId": None,
        "observerRoleKeys": ["seniorInstrumentation"], "reason": "Open one development-only target."})
    def opened():
        workflow_call(j, "admin", definition)
        workflow_call(j, "si", campaign)
        j.check(j.read(campaign_path, "operations")["status"] == "open", "Governed campaign was not readable")
    j.step("inspection: Admin definition and SI campaign persist exact target population", opened)
    def close_command():
        return workflow_command("setInspectionCampaignStatus", campaign_id, j.read(campaign_path)["version"],
                                {"status": "closed", "reason": "Survey complete; linked corrective work remains tracked."})
    j.step("inspection: campaign cannot close before the target has evidence", lambda: j.refuse(
        lambda: workflow_call(j, "si", close_command()), ("FAILED_PRECONDITION",), (campaign_path,)))
    observed_at = (datetime.now(timezone.utc)-timedelta(minutes=1)).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    observation = workflow_command("recordInspectionObservation", campaign_id, 1, {
        "observationId": observation_id, "definitionVersion": 1, "assetTypeKey": "base", "assetNumber": 7,
        "assetClassId": j.class_id, "assetInstanceId": j.base_id, "componentNodeId": node_id,
        "componentNodeVersion": 1, "componentName": "Pressure transmitter", "hierarchyPath": ["Pressure transmitter"],
        "physicalPosition": "Pressure test point", "observedAt": observed_at,
        "value": {"valueType": "number", "numericValue": 1.8, "booleanValue": None, "textValue": None, "choiceValue": None},
        "unit": "bar", "operatingConditions": {"equipmentState": "isolated", "source": "field gauge"},
        "chargeNo": None, "note": "Emulator-only adverse observation.", "evidenceUrls": [], "supersedesObservationId": None})
    j.step("inspection: Operations cannot substitute for the assigned inspection discipline", lambda: j.refuse(
        lambda: workflow_call(j, "operations", {**observation, "commandId": str(uuid.uuid4())}),
        ("PERMISSION_DENIED",), (campaign_path, observation_path, finding_path)))
    accepted_observation = {}
    def adverse():
        accepted_observation.update(workflow_call(j, "seniorInstrumentation", observation))
        j.check(j.read(finding_path, "operations")["status"] == "open" and
                j.read(observation_path)["value"]["numericValue"] == 1.8, "Adverse reading did not create an open finding")
    j.step("inspection: assigned observer records adverse evidence and creates tracked finding", adverse)
    j.step("inspection: unaccounted adverse finding prevents survey closure", lambda: j.refuse(
        lambda: workflow_call(j, "si", close_command()), ("FAILED_PRECONDITION",), (campaign_path, finding_path)))
    ticket = {"schemaVersion": 1, "version": 1, "assetType": "base", "assetNumber": 7,
              "component": "Pressure transmitter", "subsystem": None, "tag": None, "hierarchyPath": [],
              "assetHierarchyRefJson": json.dumps({"schemaVersion": 3, "scope": "physicalAsset", "assetClassId": j.class_id,
                                                   "assetInstanceId": j.base_id, "assetInstanceVersion": 1}),
              "maintenanceType": "breakdown", "classification": None,
              "description": f"{j.prefix}: repair the inspected pressure transmitter", "routedTo": "instrumentation",
              "otherDepartment": None, "isCritical": False, "startDate": observed_at, "chargeNoAtEvent": None,
              "qualityIntentSchemaVersion": 1, "qualityImpactAssessment": "notSuspected", "qualityWarningReason": None}
    def linked():
        workflow_call(j, "si", workflow_command("createMaintenanceTicket", ticket_id, 0, {"ticket": ticket}))
        workflow_call(j, "si", workflow_command("linkInspectionObservationIssue", campaign_id, j.read(campaign_path)["version"],
            {"observationId": observation_id, "ticketId": ticket_id, "reason": "Track physical corrective work.",
             "scopeReview": {"expectedTicketVersion": 1, "reason": "The whole-asset ticket explicitly includes this pressure transmitter at the test point."}}))
        j.check(j.read(finding_path)["status"] == "correctiveActionLinked" and
                j.read(finding_path)["linkedTicketId"] == ticket_id, "Finding lost reviewed corrective linkage")
    j.step("inspection: SI links an actual unresolved repair through explicit scope review", linked)
    close = close_command()
    closure_path = f"inspection_campaign_audits/{close['commandId']}"
    j.business_paths.append(closure_path)
    def closed():
        result = workflow_call(j, "si", close)
        survey, finding, repair = j.read(campaign_path, "operations"), j.read(finding_path), j.read(ticket_path)
        j.check(survey["status"] == "closed" and finding["status"] == "correctiveActionLinked" and
                repair["isResolved"] is False, "Closing survey incorrectly claimed repair or finding resolution")
        frozen = j.read(closure_path)
        j.check(workflow_call(j, "si", close) == result, "Survey closure acceptance cannot recover")
        j.check(workflow_call(j, "seniorInstrumentation", observation) == accepted_observation,
                "Historical observation acceptance changed after closure")
        j.check(j.read(closure_path) == frozen and j.read(campaign_path)["status"] == "closed" and
                j.read(ticket_path)["isResolved"] is False, "Historical retry changed closure or unresolved repair")
    j.step("inspection: survey closes and retries preserve unresolved repair and frozen closure evidence", closed)
    false_resolution = workflow_command("verifyInspectionFinding", campaign_id, j.read(campaign_path)["version"],
        {"findingId": finding_id, "expectedFindingVersion": j.read(finding_path)["version"],
         "observationId": observation_id, "outcome": "resolved", "reason": "Development negative check using unchanged adverse evidence."})
    j.step("inspection: adverse evidence cannot certify physical resolution after survey closure", lambda: j.refuse(
        lambda: workflow_call(j, "si", false_resolution), ("FAILED_PRECONDITION",), (campaign_path, finding_path, ticket_path)))
