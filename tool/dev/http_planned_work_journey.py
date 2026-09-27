"""Actual loopback-only planned-work publication, assignment and closure journey.

Business writes use signed-in callable/Firestore Rules transports. No resets,
production endpoints, owner-written publication or manufactured acceptance.
--phone-fixture-only creates/reuses one draft for normal phone UI publication.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import uuid

from http_journey import Journey, instant, wire
from http_journey_operations import workflow_call, workflow_command
from seed_usability_phone_fixture import actor, PROJECT, require

OUT = Path("output/dev-planned-validation-20260927")
CLASS_ID = "seed-class-annealing-furnace"
ASSET_ID = "seed-asset-furnace-01"


def compact(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def content_hash(version):
    code = "let s='';process.stdin.on('data',c=>s+=c);process.stdin.on('end',()=>process.stdout.write(require('./functions/lib/publishedTemplateAssignment').computeTemplateVersionContentHash(JSON.parse(s))));"
    return subprocess.run(["node", "-e", code], input=compact(version), text=True,
                          capture_output=True, check=True).stdout.strip()


def patch(j, role, path, fields, *, create=False):
    query = "?currentDocument.exists=false" if create else "?" + "&".join(
        "updateMask.fieldPaths=" + key for key in fields)
    return j.http("PATCH", j.fs + "/" + path + query,
                  {"fields": {k: wire(v) for k, v in fields.items()}}, j.users[role]["token"])


def commit(j, role, records):
    writes = [{"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/{path}",
                           "fields": {k: wire(v) for k, v in fields.items()}},
               "updateMask": {"fieldPaths": list(fields)}} for path, fields in records]
    return j.http("POST", j.fs + ":commit", {"writes": writes}, j.users[role]["token"])


def draft(j, package_id, version_id, title, *, two_lanes=False):
    si = j.users["si"]
    at = instant()
    metadata = {"schemaVersion": 1, "version": 1, "isDeleted": False,
                "createdByUid": si["uid"], "createdByName": si["name"],
                "updatedByUid": si["uid"], "updatedByName": si["name"],
                "createdAt": at, "updatedAt": at}
    package = {**metadata, "firestoreId": package_id, "packageCode": "DEV-PLANNED",
               "title": title, "description": "Explicit DEV business validation work.",
               "assetType": "furnace", "disciplineScope": "multiAgency" if two_lanes else "mechanical",
               "lifecycleStatus": "active", "latestVersionNumber": 0,
               "activeVersionFirestoreId": None}
    modules = [{"moduleCode": "DEV-MECH", "moduleTitle": "Furnace inspection",
                "discipline": "mechanical", "requiredForClosure": True, "isRequired": True}]
    fields = [{"key": "inspection", "label": "Inspection findings", "moduleCode": "DEV-MECH",
               "type": "text", "isRequired": True}]
    if two_lanes:
        modules.append({"moduleCode": "DEV-ELEC", "moduleTitle": "Electrical inspection",
                        "discipline": "electrical", "requiredForClosure": True, "isRequired": True})
        fields.append({"key": "electrical", "label": "Electrical findings", "moduleCode": "DEV-ELEC",
                       "type": "text", "isRequired": True})
    review = {"closureReviewConfirmed": True, "closureReviewConfirmedByUid": si["uid"],
              "closureReviewConfirmedByName": si["name"], "closureReviewConfirmedAt": at}
    version = {**metadata, "firestoreId": version_id, "packageFirestoreId": package_id,
               "versionNumber": 1, "versionLabel": "v1", "status": "draft",
               "jobTemplateSnapshotJson": compact({"jobName": title, "assetType": "furnace",
                   "composer": review, "closureCriticalCount": len(modules)}),
               "moduleSnapshotsJson": compact(modules), "fieldDefinitionsJson": compact(fields),
               "checklistJson": "[]", **review, "closureCriticalModuleCount": len(modules),
               "targetRefs": [], "deviceTagRefs": [], "safetyClass": None,
               "safetyGatePolicyJson": None, "procedureRefs": [], "operationalStatePreconditions": [],
               "publishedAt": None, "publishedByUid": None, "publishedByName": None,
               "retiredAt": None, "metadataJson": None}
    version["contentHash"] = content_hash(version)
    for path, value in [("template_packages/" + package_id, package), ("template_versions/" + version_id, version)]:
        existing = j.read(path, "si")
        if existing is None:
            patch(j, "si", path, value, create=True)
        else:
            j.check(existing.get("firestoreId") == value["firestoreId"] and
                    existing.get("createdByUid") == si["uid"], "Existing fixture differs; no overwrite")
        j.business_paths.append(path)
    return j.read("template_packages/" + package_id, "si"), j.read("template_versions/" + version_id, "si")


def publish(j, package, version):
    actor = j.users["si"]
    at = instant()
    published = {"status": "published", "version": version["version"] + 1,
                 "publishedAt": at, "publishedByUid": actor["uid"], "publishedByName": actor["name"],
                 "updatedAt": at, "updatedByUid": actor["uid"], "updatedByName": actor["name"]}
    audit_id = j.prefix + "-publication-audit"
    audit = {"firestoreId": audit_id, "packageFirestoreId": package["firestoreId"],
             "versionFirestoreId": version["firestoreId"], "action": "published",
             "performedByUid": actor["uid"], "performedByName": actor["name"], "performedAt": at,
             "beforeHash": version["contentHash"], "afterHash": version["contentHash"],
             "reason": "DEV: reviewed published maintenance work.", "payloadSnapshotJson": compact(version),
             "isDeleted": False, "version": 1, "schemaVersion": 1, "createdAt": at, "updatedAt": at}
    records = [("template_versions/" + version["firestoreId"], published),
               ("template_packages/" + package["firestoreId"], {
                   "activeVersionFirestoreId": version["firestoreId"], "latestVersionNumber": 1,
                   "version": package["version"] + 1, "updatedAt": at,
                   "updatedByUid": actor["uid"], "updatedByName": actor["name"]}),
               ("template_publish_audits/" + audit_id, audit)]
    j.step("Operations cannot publish reviewed maintenance work", lambda: j.refuse(
        lambda: commit(j, "operations", records), ("PERMISSION_DENIED",), tuple(path for path, _ in records)))
    j.step("SI publishes version, active package pointer and audit atomically under Rules",
           lambda: commit(j, "si", records))
    return j.read("template_versions/" + version["firestoreId"], "si")


def journey(j):
    package, version = draft(j, j.prefix + "-package", j.prefix + "-version", "DEV two-agency planned inspection", two_lanes=True)
    request = {"requestId": str(uuid.uuid4()), "packageId": package["firestoreId"],
               "versionId": version["firestoreId"], "expectedVersionNumber": 1,
               "expectedContentHash": version["contentHash"], "assetType": "furnace", "assetNumber": 1,
               "assetClassId": CLASS_ID, "assetInstanceId": ASSET_ID,
               "chargeNoAtEvent": None, "remarks": j.prefix + ": actual planned work journey"}
    call_assignment = lambda data=request, role="supervisor": j.call(role, "assignPublishedTemplateVersionV2", data, v2=True)
    j.step("Draft version cannot be assigned", lambda: j.refuse(lambda: call_assignment(), ("FAILED_PRECONDITION",)))
    publish(j, package, version)
    accepted = {}
    def assign():
        accepted.update(call_assignment())
        j.check(accepted.get("execution") is not None, "Assignment returned no canonical execution")
    j.step("Supervisor assigns exact registered Furnace through V2 callable", assign)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "latest-assignment.json").write_text(json.dumps(accepted, indent=2) + "\n")
    work(j, accepted)
    def replay_assignment():
        closed = j.read("job_executions/" + accepted["executionId"])
        before = j.read("equipment_status/furnace_1")
        replay = call_assignment()
        j.check(replay["idempotentReplay"] and replay["executionId"] == accepted["executionId"],
                "Assignment replay created another execution")
        j.check(j.read("job_executions/" + accepted["executionId"])["version"] == closed["version"] and
                j.read("job_executions/" + accepted["executionId"])["isCompleted"] is True and
                j.read("equipment_status/furnace_1")["activeNonRedMaintenanceCount"] == before["activeNonRedMaintenanceCount"],
                "Assignment replay resurrected completed work or added a counter")
    j.step("Historical assignment replay preserves completed job and current counters", replay_assignment)


def work(j, accepted):
    execution_id = accepted["executionId"]
    execution_path = "job_executions/" + execution_id
    workflow_path = "maintenance_workflows/" + execution_id
    j.business_paths.extend([execution_path, workflow_path, "equipment_status/furnace_1"])
    modules = {m["moduleCode"]: m["firestoreId"] for m in accepted["modules"]}
    def command(kind, payload, role="si"):
        return workflow_call(j, role, workflow_command(kind, execution_id,
                             j.read(workflow_path)["version"], payload))
    def module_update(code, role, **values):
        path = "job_modules/" + modules[code]
        old = j.read(path, role)
        return patch(j, role, path, {**values, "version": old["version"] + 1,
                    "updatedAt": instant(), "updatedByUid": j.users[role]["uid"],
                    "updatedByName": j.users[role]["name"]})
    def close(lane):
        return command("closeLane", {"laneKey": lane, "note": "DEV witnessed work complete."},
                       "mechanical" if lane == "mech" else "electrical")

    if j.read(workflow_path)["status"] == "pendingLaneClassification":
        j.step("Module work is blocked before accountable lane acknowledgement", lambda: j.refuse(
            lambda: module_update("DEV-MECH", "mechanical", status="inProgress", isOpenForWork=True),
            ("PERMISSION_DENIED",)))
        j.step("SI finalizes mechanical and electrical lanes from published modules",
               lambda: command("finalizeLaneSet", {"laneKeys": ["mech", "elec"]}))
    for lane, role in [("mech", "mechanical"), ("elec", "electrical")]:
        if j.read(f"job_lanes/{execution_id}_{lane}_1")["status"] == "pending":
            j.step(f"Responsible {role} acknowledges its lane", lambda lane=lane, role=role:
                   command("acknowledgeLane", {"laneKey": lane}, role))

    for code, role, field in [("DEV-MECH", "mechanical", "inspection"), ("DEV-ELEC", "electrical", "electrical")]:
        path = "job_modules/" + modules[code]
        current = j.read(path)
        if current["status"] not in ("submitted", "accepted"):
            j.step(f"Operations cannot replace {role} module evidence", lambda code=code:
                   j.refuse(lambda: module_update(code, "operations", status="inProgress", isOpenForWork=True),
                            ("PERMISSION_DENIED",), (path,)))
            j.step(f"{role} records and submits required structured evidence", lambda code=code, role=role, field=field:
                module_update(code, role, status="submitted", isOpenForWork=False,
                    responsesJson=compact([{"key": field, "value": "DEV witnessed inspection satisfactory."}]),
                    submittedByUid=j.users[role]["uid"], submittedByName=j.users[role]["name"], submittedAt=instant()))
        if j.read(path)["status"] == "submitted":
            j.step(f"Lane cannot close while {role} submission awaits acceptance", lambda role=role:
                   j.refuse(lambda: close("mech" if role == "mechanical" else "elec"), ("FAILED_PRECONDITION",)))
            j.step(f"Supervisor accepts the {role} module", lambda code=code:
                module_update(code, "supervisor", status="accepted", isOpenForWork=False,
                    acceptedByUid=j.users["supervisor"]["uid"], acceptedByName=j.users["supervisor"]["name"], acceptedAt=instant()))

    diary_id = j.prefix + "-diary"
    diary_path = "job_diary_entries/" + diary_id
    if j.read(diary_path) is None:
        def diary():
            user = j.users["mechanical"]
            at = instant()
            row = {"firestoreId": diary_id, "jobExecutionFirestoreId": execution_id,
                   "assetType": "furnace", "assetNumber": 1, "title": "DEV shift handover",
                   "note": "Inspections witnessed; record retained separately from acceptance.",
                   "kind": "handover", "severity": "low", "discipline": "mechanical", "laneKey": "mech",
                   "isBlocker": False, "isHandover": True, "blockerStatus": None, "requiresFollowUp": False,
                   "createdAt": at, "updatedAt": at, "createdByUid": user["uid"], "createdByName": user["name"],
                   "updatedByUid": user["uid"], "updatedByName": user["name"], "version": 1,
                   "reviewedServerVersion": 0, "isDeleted": False, "metadataJson": None}
            audit = {"entityType": "planned_job_diary_entry", "entityId": diary_id, "action": "create",
                     "performedByUid": user["uid"], "performedByName": user["name"], "severity": "low",
                     "summary": "Accepted diary revision 1", "reasonNotes": None, "beforeJson": None,
                     "afterJson": compact(row), "beforeState": None, "afterState": row}
            def write(path, fields):
                return {"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/{path}",
                                   "fields": {k: wire(v) for k, v in fields.items()}},
                        "currentDocument": {"exists": False}}
            audit_write = write("audit_logs/diary_revision_" + diary_id + "_1", audit)
            audit_write["updateTransforms"] = [{"fieldPath": "timestamp", "setToServerValue": "REQUEST_TIME"}]
            j.http("POST", j.fs + ":commit", {"writes": [write(diary_path, row), audit_write]}, user["token"])
            j.check(j.read(diary_path, "si")["note"] == row["note"], "Diary canonical readback differs")
        j.step("Signed-in mechanical author saves handover and exact revision audit atomically", diary)

    compliance_id = j.prefix + "-assurance"
    compliance_path = "compliance_requests/" + compliance_id
    if j.read(compliance_path) is None:
        j.step("Mechanical raises blocking electrical assurance", lambda: command("raiseCompliance", {
            "complianceId": compliance_id, "originLaneKey": "mech", "targetLaneKey": "elec",
            "title": "DEV confirm isolation", "description": "Witnessed electrical isolation required before release.",
            "conditionTypeKey": "manual", "requestPurposeKey": "assurance",
            "gatesLaneFirestoreId": f"job_lanes/{execution_id}_mech_1"}, "mechanical"))
    status = j.read(compliance_path)["status"]
    if status == "raised":
        j.step("Electrical acknowledges the requested assurance", lambda: command("acknowledgeCompliance", {"complianceId": compliance_id}, "electrical"))
    if j.read(compliance_path)["status"] == "acknowledged":
        j.step("Blocking assurance prevents physical lane closure", lambda:
               j.refuse(lambda: close("mech"), ("FAILED_PRECONDITION",)))
        j.step("Electrical provides preserved compliance attempt", lambda: command("markComplianceComplied", {
            "complianceId": compliance_id, "note": "Isolation witnessed and verified."}, "electrical"))
    if j.read(compliance_path)["status"] == "complied":
        j.step("Originating mechanical side confirms assurance", lambda: command("confirmComplianceClosed", {
            "complianceId": compliance_id, "note": "Verified supporting evidence."}, "mechanical"))
    for lane in ["mech", "elec"]:
        if j.read(f"job_lanes/{execution_id}_{lane}_1")["status"] != "closed":
            j.step(f"Accepted evidence and cleared gates permit {lane} lane closure", lambda lane=lane: close(lane))

    if j.read(workflow_path)["status"] != "completed":
        def reopen_and_close():
            module_path = "job_modules/" + modules["DEV-MECH"]
            original = j.read(module_path)
            command("reopenWorkflowModule", {"moduleFirestoreId": modules["DEV-MECH"],
                    "reason": "DEV reinspection before final closure."})
            reopened = j.read(module_path)
            j.check(reopened["status"] == "reopened" and reopened["responsesJson"] == original["responsesJson"] and
                    j.read(f"job_lanes/{execution_id}_mech_1")["status"] == "acknowledged",
                    "Reopen lost evidence or left newly active work behind a closed lane")
            module_update("DEV-MECH", "mechanical", status="submitted", isOpenForWork=False,
                          submissionNote="Reinspection confirmed the retained findings.",
                          submittedByUid=j.users["mechanical"]["uid"], submittedByName=j.users["mechanical"]["name"], submittedAt=instant())
            module_update("DEV-MECH", "supervisor", status="accepted", isOpenForWork=False,
                          acceptedByUid=j.users["supervisor"]["uid"], acceptedByName=j.users["supervisor"]["name"], acceptedAt=instant())
            close("mech")
        j.step("Reopening accepted work reactivates its lane and preserves evidence for reacceptance", reopen_and_close)

    if j.read(workflow_path)["status"] != "completed":
        j.step("Operations cannot perform supervised final closure", lambda: j.refuse(lambda:
            command("finalizeJob", {"redRequired": False, "teamsInvolved": ["mechanical", "electrical"]}, "operations"),
            ("PERMISSION_DENIED",), (execution_path, workflow_path)))
        before_count = j.read("equipment_status/furnace_1")["activeNonRedMaintenanceCount"]
        final = workflow_command("finalizeJob", execution_id, j.read(workflow_path)["version"], {
            "redRequired": False, "remarks": "DEV witnessed two-agency inspection and handover complete.",
            "teamsInvolved": ["mechanical", "electrical"], "responsesJson": "[]", "actionsJson": "[]"})
        def finalize():
            result = workflow_call(j, "si", final)
            execution = j.read(execution_path, "si")
            j.check(execution["isCompleted"] and j.read(workflow_path)["status"] == "completed", "Closure projections disagree")
            j.check(j.read("equipment_status/furnace_1")["activeNonRedMaintenanceCount"] == before_count - 1,
                    "Closure did not remove exactly this workflow contribution")
            j.check(json.loads(execution["metadataJson"])["closureAttestation"]["hash"], "Missing frozen closure attestation")
            replay = workflow_call(j, "si", final)
            j.check(replay == result, "Lost closure reply replay changed original receipt")
            j.check(j.read(execution_path)["version"] == execution["version"], "Replay modified completed execution")
        j.step("SI finalizes canonical work, decrements counter once, freezes history and replays safely", finalize)
    snapshot = {"execution": j.read(execution_path, "si"), "workflow": j.read(workflow_path, "si"),
                "modules": [j.read("job_modules/" + identity, "si") for identity in modules.values()],
                "diary": j.read(diary_path, "si"), "compliance": j.read(compliance_path, "si"),
                "equipment": j.read("equipment_status/furnace_1", "si")}
    (OUT / "latest-completed-readback.json").write_text(json.dumps(snapshot, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phone-fixture-only", action="store_true")
    parser.add_argument("--resume-latest", action="store_true")
    args = parser.parse_args()
    require(PROJECT == "demo-crm3-baf-ops", "Only fixed demo project permitted")
    prefix = "hj-planned-" + uuid.uuid4().hex[:12]
    j = Journey(PROJECT, prefix, OUT / ("phone-draft.json" if args.phone_fixture_only else "http-planned-work.json"))
    j.users = {name: actor(role) for name, role in {
        "admin": "admin", "si": "si", "supervisor": "contractSupervisor",
        "operations": "operations", "mechanical": "seniorMechanical", "electrical": "seniorElectrical"}.items()}
    if args.phone_fixture_only:
        package, version = draft(j, "dev-usability-planned-package", "dev-usability-planned-version-1",
                                 "DEV Furnace planned inspection")
        print(json.dumps({"packageId": package["firestoreId"], "versionId": version["firestoreId"],
                          "title": package["title"], "status": version["status"]}, indent=2))
    else:
        if args.resume_latest:
            accepted = json.loads((OUT / "latest-assignment.json").read_text())
            j.prefix = accepted["execution"]["templateVersionId"].removesuffix("-version")
            work(j, accepted)
        else:
            journey(j)
    j.write_report()


if __name__ == "__main__":
    main()
