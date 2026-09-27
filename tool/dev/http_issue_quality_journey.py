"""Real demo-emulator HTTP proof of issue-origin Quality and same-charge cases.

This complements http_journey.py: warnings originate in createMaintenanceTicket,
not in direct abnormality creation. All business actions use actual Auth tokens
and callable HTTP. Only unique, fully readable setup masters use owner writes.
The custom fixture class has no legacy mapping, so it cannot make the phone's
Base/Furnace selection ambiguous. No existing fixture is changed or retired.
"""

from __future__ import annotations

import argparse
import copy
import json
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from http_journey import Journey, instant
from http_journey_operations import workflow_call, workflow_command


def setup(j: Journey) -> None:
    for role in ("operations", "si", "admin", "pending"):
        email, password = f"{j.prefix}.{role}@example.invalid", "emulator-journey-only"
        name = f"HTTP issue Quality {role} {j.prefix}"
        account = j.http("POST", f"{j.auth}/accounts:signUp?key=emulator",
                         {"email": email, "password": password, "displayName": name})
        uid = account["localId"]
        j.http("POST", f"{j.auth}/accounts:update", {"localId": uid, "emailVerified": True})
        signed = j.http("POST", f"{j.auth}/accounts:signInWithPassword?key=emulator",
                        {"email": email, "password": password, "returnSecureToken": True}, token=None)
        j.users[role] = {"uid": uid, "name": name, "token": signed["idToken"]}
        j.seed(f"users/{uid}", {"uid": uid, "name": name, "email": email,
               "isApproved": role != "pending", "roles": ["operations" if role == "pending" else role],
               "createdAt": datetime.now(timezone.utc), "accessDisposition": "pending" if role == "pending" else "approved"})
    j.class_id, j.base_id, j.type_id = (f"{j.prefix}-{name}" for name in ("quality-class", "quality-asset", "quality-type"))
    at, admin = datetime.now(timezone.utc), j.users["admin"]
    j.seed(f"asset_classes/{j.class_id}", {"schemaVersion": 1, "assetClassId": j.class_id,
           "code": "HJQUALITY", "name": f"HTTP Quality test rig {j.prefix}", "legacyAssetTypeKey": None, "status": "active"})
    j.seed(f"asset_instances/{j.base_id}", {"schemaVersion": 1, "assetInstanceId": j.base_id,
           "assetClassId": j.class_id, "assetClassCode": "HJQUALITY", "assetClassName": f"HTTP Quality test rig {j.prefix}",
           "assetNumber": 7, "name": f"HTTP Quality test rig 7 {j.prefix}", "status": "active"})
    j.seed(f"abnormality_types/{j.type_id}", {"firestoreId": j.type_id, "code": "HJ-ISSUE-QC",
           "title": "HTTP issue-origin quality evidence", "description": "Isolated demo fixture",
           "category": "process", "severity": "medium", "applicableAssetTypes": ["governedCustom"],
           "suggestsReannealing": False, "isActive": True, "isDeleted": False, "createdAt": at, "updatedAt": at,
           "createdByUid": admin["uid"], "createdByName": admin["name"], "lastEditedByUid": admin["uid"],
           "lastEditedByName": admin["name"], "version": 1})


def journey(j: Journey, charge: int) -> None:
    ra_charge = 10000 + (charge - 10000 + 1) % 90000
    direct_ra_charge = 10000 + (charge - 10000 + 2) % 90000
    physical = {"schemaVersion": 3, "scope": "physicalAsset", "assetClassId": j.class_id,
                "assetClassCode": "HJQUALITY", "assetClassName": f"HTTP Quality test rig {j.prefix}",
                "nodeId": j.base_id, "nodeVersion": 1, "nodeName": f"HTTP Quality test rig 7 {j.prefix}",
                "assetInstanceId": j.base_id, "assetInstanceVersion": 1, "assetNumber": 7,
                "assetInstanceName": f"HTTP Quality test rig 7 {j.prefix}", "componentInstanceId": None,
                "componentInstanceVersion": None, "componentTag": None,
                "hierarchyPath": [f"HTTP Quality test rig {j.prefix}", f"HTTP Quality test rig 7 {j.prefix}"],
                "ownershipStatus": "confirmed", "ownerDiscipline": "operations",
                "accountableRoleKeys": ["operations"], "innerCoverAssociation": None}

    def snapshot(paths):
        result = {}
        for path in paths:
            row = j.read(path)
            if row:
                row.pop("_globalPullServerUpdatedAt", None)
            result[path] = row
        return result

    def issue(label):
        ticket_id = f"{j.prefix}-{label}"
        paths = (f"maintenance_records/{ticket_id}", f"quality_warnings/issue_{ticket_id}",
                 f"charge_abnormalities/issue_quality_{ticket_id}")
        j.business_paths.extend(paths)
        ticket = {"schemaVersion": 1, "version": 1, "assetType": "governedCustom", "assetNumber": 7,
                  "component": f"HTTP Quality test rig 7 {j.prefix}", "subsystem": None, "tag": None, "hierarchyPath": [],
                  "assetHierarchyRefJson": json.dumps(physical), "maintenanceType": "breakdown", "classification": None,
                  "description": f"{j.prefix} {label}: physical maintenance issue with suspected quality impact",
                  "routedTo": "mechanical", "otherDepartment": None, "isCritical": False,
                  "startDate": (datetime.now(timezone.utc)-timedelta(minutes=2)).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
                  "chargeNoAtEvent": charge, "qualityIntentSchemaVersion": 2, "qualityImpactAssessment": "suspected",
                  "qualityWarningReason": f"{j.prefix} {label}: observed process deviation may affect this charge.",
                  "qualityAbnormalityTypeId": j.type_id}
        create = workflow_command("createMaintenanceTicket", ticket_id, 0, {"ticket": ticket})
        def accepted():
            result = workflow_call(j, "operations", create)
            stored, warning, case = (j.read(path, "operations") for path in paths)
            j.check(result["result"]["warningId"] == f"issue_{ticket_id}" and
                    result["result"]["abnormalityId"] == f"issue_quality_{ticket_id}", "Creation lost deterministic linked identities")
            j.check(stored["qualityWarningId"] == warning["warningId"] and stored["qualityAbnormalityId"] == case["firestoreId"] and
                    stored["chargeQualityCaseId"] == f"issue_{ticket_id}", "Ticket warning/case linkage incomplete")
            j.check(warning["sourceType"] == "issue" and warning["sourceId"] == ticket_id and warning["status"] == "open" and
                    case["linkedTicketFirestoreId"] == ticket_id and case["reannealingStatus"] == "pendingDecision" and
                    case["sourceChargeNo"] == warning["sourceChargeNo"] == charge, "Issue did not atomically project pending Quality case")
            j.check(workflow_call(j, "operations", create) == result, "Issue creation retry did not recover accepted identities")
        return paths, create, accepted

    def quality_request(paths, operation, **fields):
        return {"requestId": str(uuid.uuid4()), "operation": operation, "warningId": paths[1].split("/")[-1],
                "expectedVersion": j.read(paths[1])["version"], "reason": f"{j.prefix}: {operation} reviewed evidence.", **fields}

    first, first_create, create_first = issue("adjudication")
    j.step("issue Quality: unapproved actor cannot create linked issue evidence", lambda: j.refuse(
        lambda: workflow_call(j, "pending", first_create), ("PERMISSION_DENIED",), first))
    invalid = copy.deepcopy(first_create)
    invalid["commandId"] = str(uuid.uuid4())
    invalid["payload"]["ticket"]["qualityAbnormalityTypeId"] = None
    j.step("issue Quality: suspected impact requires governed classification", lambda: j.refuse(
        lambda: workflow_call(j, "operations", invalid), ("INVALID_ARGUMENT", "FAILED_PRECONDITION"), first))
    j.step("issue Quality: Operations raises maintenance issue and linked pending Quality case atomically", create_first)
    first_close = quality_request(first, "CLOSE_QUALITY_WARNING", disposition="coilFoundAcceptable", linkedReannealingChargeNos=[])
    j.step("issue Quality: Operations cannot formally adjudicate its warning", lambda: j.refuse(
        lambda: j.quality("operations", {**first_close, "requestId": str(uuid.uuid4())}, v2=True), ("PERMISSION_DENIED",), first))
    def close_first():
        j.quality("si", first_close, v2=True)
        warning, case, ticket = j.read(first[1]), j.read(first[2]), j.read(first[0])
        j.check(warning["status"] == "closed" and warning["closureDisposition"] == "coilFoundAcceptable" and
                case["reannealingStatus"] == "notRequired" and case["reannealedToChargeNo"] is None,
                "Non-RA adjudication did not converge to notRequired")
        j.check(ticket["isResolved"] is False, "Quality adjudication incorrectly resolved physical maintenance")
        j.check(j.quality("si", first_close, v2=True)["idempotentReplay"], "Adjudication cannot recover after lost reply")
    j.step("issue Quality: SI adjudicates acceptable coil while the physical maintenance issue remains open", close_first)
    original_first = snapshot(first)

    second, second_create, create_second = issue("reannealing")
    j.step("issue Quality: a second issue on the same charge creates a separate pending case", create_second)
    required = quality_request(second, "DECLARE_QUALITY_CASE_RA_REQUIRED")
    def require_ra():
        j.quality("operations", required, v2=True)
        j.check(j.read(second[2])["reannealingStatus"] == "required" and j.read(second[1])["status"] == "open",
                "Operational RA requirement did not remain distinct from warning closure")
    j.step("issue Quality: Operations declares RA required on only the second case", require_ra)
    no_ra_close = quality_request(second, "CLOSE_QUALITY_WARNING", disposition="qualityAdjudication", linkedReannealingChargeNos=[])
    j.step("issue Quality: SI cannot discard an outstanding required RA during adjudication", lambda: j.refuse(
        lambda: j.quality("si", no_ra_close, v2=True), ("FAILED_PRECONDITION",), second))
    invalid_charge = quality_request(second, "RECORD_QUALITY_CASE_RA_COMPLETED", linkedReannealingChargeNos=[charge])
    j.step("issue Quality: resulting RA charge must differ from the original charge", lambda: j.refuse(
        lambda: j.quality("operations", invalid_charge, v2=True), ("FAILED_PRECONDITION", "INVALID_ARGUMENT"), second))
    completion = quality_request(second, "RECORD_QUALITY_CASE_RA_COMPLETED", linkedReannealingChargeNos=[ra_charge])
    def complete_ra():
        j.quality("operations", completion, v2=True)
        warning, case = j.read(second[1]), j.read(second[2])
        j.check(case["reannealingStatus"] == "completed" and case["reannealedToChargeNo"] == ra_charge and
                warning["status"] == "closureRequested" and warning["closureDisposition"] is None,
                "Physical RA completion bypassed formal Quality review")
        j.check(j.quality("operations", completion, v2=True)["idempotentReplay"], "Physical RA acceptance cannot recover")
    j.step("issue Quality: Operations records physical RA and warning moves to review", complete_ra)
    wrong_ra = quality_request(second, "CLOSE_QUALITY_WARNING", disposition="reannealingCompleted", linkedReannealingChargeNos=[direct_ra_charge])
    j.step("issue Quality: adjudicator cannot replace the already recorded RA charge", lambda: j.refuse(
        lambda: j.quality("si", wrong_ra, v2=True), ("FAILED_PRECONDITION",), second))
    second_close = quality_request(second, "CLOSE_QUALITY_WARNING", disposition="reannealingCompleted", linkedReannealingChargeNos=[ra_charge])
    def close_second():
        j.quality("si", second_close, v2=True)
        warning, case = j.read(second[1]), j.read(second[2])
        j.check(warning["status"] == "closed" and warning["linkedReannealingChargeNos"] == [ra_charge] and
                case["reannealedToChargeNo"] == ra_charge and j.read(second[0])["isResolved"] is False,
                "Final Quality decision lost RA evidence or resolved the physical issue")
        j.check(j.quality("si", second_close, v2=True)["idempotentReplay"], "RA decision acceptance cannot recover")
    j.step("issue Quality: SI closes the RA case using the Operations-recorded charge", close_second)
    original_second = snapshot(second)

    for label, state, new_charge in (("standalone-no-ra", "notApplicable", None), ("standalone-completed-ra", "completed", direct_ra_charge)):
        case_id = f"{j.prefix}-{label}"
        paths = (f"charge_abnormalities/{case_id}", f"quality_warnings/abnormality_{case_id}")
        j.business_paths.extend(paths)
        at, actor = instant(), j.users["operations"]
        record = {"firestoreId": case_id, "sourceChargeNo": charge, "abnormalityTypeId": j.type_id,
                  "abnormalityTypeTitle": "HTTP issue-origin quality evidence", "abnormalityTypeCode": "HJ-ISSUE-QC",
                  "category": "process", "severity": "medium", "affectedAssets": [{"assetType": "governedCustom", "assetNumber": 7}],
                  "affectedAssetHierarchyRefs": [{"assetType": "governedCustom", "assetNumber": 7, "assetHierarchyRef": physical}],
                  "component": None, "observedReason": f"{j.prefix} {label}: distinct observation on the same charge.",
                  "description": None, "possibleRootReasonCategory": "unknown", "possibleRootReasonNotes": None,
                  "reannealingStatus": state, "reannealedToChargeNo": new_charge,
                  "loggedAt": at, "updatedAt": at, "loggedByUid": actor["uid"], "loggedByName": actor["name"],
                  "updatedByUid": actor["uid"], "updatedByName": actor["name"], "linkedTicketFirestoreId": None,
                  "linkedExecutionFirestoreId": None, "version": 1, "isDeleted": False,
                  "deletedAt": None, "deletedByUid": None, "deletedByName": None, "deleteReason": None}
        create = {"requestId": str(uuid.uuid4()), "operation": "CREATE", "abnormalityId": case_id,
                  "expectedVersion": 0, "reason": "Record an independent development observation on the same charge.", "abnormality": record}
        def standalone(create=create, paths=paths, state=state, new_charge=new_charge):
            j.quality("operations", create, v2=True)
            case, warning = (j.read(path, "operations") for path in paths)
            j.check(case["sourceChargeNo"] == charge and case["linkedTicketFirestoreId"] is None and
                    case["reannealingStatus"] == state and case["reannealedToChargeNo"] == new_charge,
                    "Independent abnormality lost explicit RA context or linked itself to another issue")
            j.check(warning["sourceType"] == "abnormality" and warning["sourceId"] == case["firestoreId"] and
                    warning["status"] == "open", "Logging independent RA evidence falsely adjudicated a warning")
            j.check(j.quality("operations", create, v2=True)["idempotentReplay"], "Independent abnormality creation cannot recover")
            j.check(snapshot(first) == original_first and snapshot(second) == original_second,
                    "A same-charge independent abnormality overwrote another case's decision or physical evidence")
        j.step(f"same charge: independent {state} abnormality retains its own open warning and preserves both issue decisions", standalone)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="demo-crm3-baf-ops")
    parser.add_argument("--prefix", default=f"hj-{datetime.now(timezone.utc):%Y%m%d%H%M%S}-{uuid.uuid4().hex[:6]}")
    parser.add_argument("--charge", type=int, default=91341)
    parser.add_argument("--output", type=Path, default=Path("output/dev-business-validation-20260926/http-issue-quality-journey.json"))
    args = parser.parse_args()
    if not 10000 <= args.charge <= 99999:
        parser.error("--charge must have exactly five digits")
    j = Journey(args.project, args.prefix, args.output)
    try:
        j.step("isolated Auth actors and fully readable custom-class Quality fixtures", lambda: setup(j))
        journey(j, args.charge)
    except Exception:
        return 1
    print(f"{len(j.results)} checks passed; same source charge {args.charge}; report: {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
