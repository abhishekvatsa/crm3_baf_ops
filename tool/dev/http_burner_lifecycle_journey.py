"""Local-only burner/UV installation chronology through authenticated commands.

No business result is seeded: only run-prefixed component definitions are setup.
Replacements originate in actual issue closure; audited corrections keep source
events immutable. Uses an existing registered Furnace and an explicit position.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import uuid

from http_journey import Journey, unwire
from http_journey_operations import workflow_call, workflow_command
from seed_usability_phone_fixture import actor, PROJECT, require


def at(value):
    return value.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def compact(value):
    return json.dumps(value, separators=(",", ":"))


def source_events(j, collection, source_id):
    query = {"structuredQuery": {"from": [{"collectionId": collection}], "where": {
        "fieldFilter": {"field": {"fieldPath": "sourceId"}, "op": "EQUAL",
                        "value": {"stringValue": source_id}}}}}
    return [{key: unwire(value) for key, value in row["document"]["fields"].items()}
            for row in j.http("POST", j.fs + ":runQuery", query, j.users["operations"]["token"])
            if "document" in row]


def fixture_asset(j):
    class_id = "seed-class-annealing-furnace"
    asset_id = str(uuid.uuid5(uuid.NAMESPACE_URL, "demo-crm3-baf-ops:dev-burner-lifecycle-furnace-02"))
    path = "asset_instances/" + asset_id
    query = {"structuredQuery": {"from": [{"collectionId": "asset_instances"}],
        "where": {"compositeFilter": {"op": "AND", "filters": [
            {"fieldFilter": {"field": {"fieldPath": "assetClassId"}, "op": "EQUAL", "value": {"stringValue": class_id}}},
            {"fieldFilter": {"field": {"fieldPath": "assetNumber"}, "op": "EQUAL", "value": {"integerValue": "2"}}},
        ]}}}}
    rows = [row["document"] for row in j.http("POST", j.fs + ":runQuery", query,
            j.users["operations"]["token"]) if "document" in row]
    require(len(rows) <= 1 and all(row["name"].endswith("/" + asset_id) for row in rows),
            "Furnace02 already belongs to another record; refusing an overlapping fixture")
    existing = j.read(path, "operations")
    require(existing is None or (existing["assetClassId"] == class_id and existing["assetNumber"] == 2
            and existing["name"] == "DEV lifecycle Furnace 02" and existing["status"] == "active"),
            "Existing fixture differs; no overwrite")
    j.business_paths.append(path)
    if existing is None:
        asset_class = j.read("asset_classes/" + class_id, "operations")
        request = {"requestId": str(uuid.uuid4()), "operation": "CREATE_ASSET_INSTANCE",
            "assetClassId": class_id, "assetInstanceId": asset_id,
            "expectedAssetClassVersion": asset_class["version"],
            "reason": "DEV: dedicated additive Furnace02 for burner and UV lifecycle verification.",
            "assetDraft": {"assetNumber": 2, "name": "DEV lifecycle Furnace 02", "plantTag": "DEV-FR-02",
                "location": "Local emulator verification only", "manufacturer": None, "model": None,
                "serialNumber": None, "commissionedOn": None, "serviceState": "inService",
                "ownershipStatus": "confirmed", "ownerDiscipline": "Operations", "accountableRoleKeys": ["operations"]}}
        j.step("Admin registers dedicated DEV Furnace02 with unique number custody", lambda:
            j.call("admin", "mutateAssetHierarchyV2", request, v2=True))
    return asset_id


def replacement(j, asset, node, label, performed_at, kind, position):
    ticket_id = j.prefix + "-" + kind + "-" + label
    path = "maintenance_records/" + ticket_id
    j.business_paths.append(path)
    lane = "mechanical" if kind == "burner" else "instrumentation"
    reference = {"schemaVersion": 4, "scope": "componentDefinitionOnAsset",
                 "assetClassId": asset["assetClassId"], "nodeId": node["nodeId"],
                 "nodeVersion": node["version"], "assetInstanceId": asset["assetInstanceId"],
                 "assetInstanceVersion": asset["version"]}
    ticket = {"schemaVersion": 1, "version": 1, "assetType": "furnace",
              "assetNumber": asset["assetNumber"], "component": node["name"],
              "subsystem": None, "tag": None, "hierarchyPath": node["hierarchyPath"],
              "assetHierarchyRefJson": compact(reference), "maintenanceType": "breakdown",
              "classification": None, "description": f"DEV lifecycle evidence {ticket_id}.",
              "routedTo": lane, "otherDepartment": None, "isCritical": False,
              "startDate": at(performed_at - timedelta(minutes=10)), "chargeNoAtEvent": None,
              "qualityIntentSchemaVersion": 2, "qualityImpactAssessment": "notSuspected",
              "qualityWarningReason": None, "qualityAbnormalityTypeId": None}
    workflow_call(j, "operations", workflow_command("createMaintenanceTicket", ticket_id, 0, {"ticket": ticket}))
    reference = json.loads(j.read(path, "operations")["assetHierarchyRefJson"])
    action = {"schemaVersion": 1, "id": ticket_id + "-replacement",
              "asset": asset["name"], "component": node["name"], "hierarchyPath": node["hierarchyPath"],
              "assetHierarchyRef": reference, "system": asset["assetClassName"], "subsystem": None,
              "subComponent": None, "tag": None, "instance": None, "actionType": "replacement",
              "replacement": "newPart", "issue": "DEV replacement chronology verification.",
              "resolution": "DEV physical installation completed and verified.", "remarks": None,
              "templateFieldKey": None, "isAutoResolved": True, "status": "resolved",
              "createdAt": at(performed_at), "severity": "medium", "performedBy": j.users["si"]["name"],
              "updatedAt": None, "version": 1, "metadataJson": None, "attendanceSessionId": None,
              "burnerPosition": position, "burnerActionCode": None, "burnerOutcome": None,
              "burnerMicroampReading": None, "burnerBlockSupplyMode": "sailRed" if kind == "burner" else None,
              "burnerBlockSupplierName": None, "burnerBlockPurchaseOrderNumber": None}
    close = workflow_command("resolveMaintenanceTicket", ticket_id, 1, {
        "endDate": at(performed_at + timedelta(minutes=5)),
        "remarks": "DEV actual work completed earlier; entered now for chronology verification.",
        "teamsInvolved": [lane], "actionsJson": compact([action]), "actionTargetContractVersion": 1})
    j.refuse(lambda: workflow_call(j, "operations", close), ("PERMISSION_DENIED",), (path,))
    result = workflow_call(j, "si", close)
    stored = j.read(path, "operations")
    j.check(stored["isResolved"] is True and stored["endDate"] == close["payload"]["endDate"],
            "Physical issue closure did not persist the user-supplied occurrence time")
    return close, result


def lifecycle(j, asset_id, position):
    asset = j.read("asset_instances/" + asset_id, "operations")
    require(asset is not None and asset["status"] == "active", "An existing active registered Furnace is required")
    asset_class = j.read("asset_classes/" + asset["assetClassId"], "operations")
    require(asset_class["status"] == "active" and asset_class["legacyAssetTypeKey"] == "furnace", "Wrong asset class")
    times = {"first": datetime.now(timezone.utc) - timedelta(hours=3),
             "second": datetime.now(timezone.utc) - timedelta(hours=2),
             "late": datetime.now(timezone.utc) - timedelta(hours=4)}
    corrected = datetime.now(timezone.utc) - timedelta(hours=5)
    suffix = hashlib.sha256(f"{asset_id}|{position}".encode()).hexdigest()[:40]
    for kind, collection, short, title, owner in [
        ("burner", "burner_block", "bblc", "Burner blocks and firing tubes", "mechanical"),
        ("uv", "uv_detector", "uvlc", "UV flame scanner and peep sight", "instrumentation"),
    ]:
        current_path = f"{collection}_lifecycle_current/{short}_{suffix}"
        previous = j.read(current_path)
        require(previous is None or datetime.fromisoformat(previous["actionPerformedAt"].replace("Z", "+00:00")) < times["late"],
                "The target has recent installation evidence; choose another position instead of overwriting its chronology")
        node_id = j.prefix + "-" + kind + "-component"
        now = datetime.now(timezone.utc)
        node = {"schemaVersion": 1, "nodeId": node_id, "assetClassId": asset["assetClassId"],
                "parentNodeId": None, "nodeType": "component", "name": title,
                "componentTag": None, "contactArrangement": "notApplicable", "ownershipStatus": "confirmed",
                "ownerDiscipline": owner, "accountableRoleKeys": ["seniorMechanical" if kind == "burner" else "seniorInstrumentation"],
                "sortOrder": 999, "ancestorNodeIds": [], "hierarchyPath": [title], "activeChildCount": 0,
                "status": "active", "version": 1, "createdAt": now, "updatedAt": now,
                "createdByUid": j.users["admin"]["uid"], "createdByName": j.users["admin"]["name"],
                "updatedByUid": j.users["admin"]["uid"], "updatedByName": j.users["admin"]["name"],
                "lastMutationId": j.prefix + "-fixture"}
        j.seed("asset_hierarchy_nodes/" + node_id, node)
        j.business_paths.append(current_path)
        events, closures = {}, {}
        for label in ("first", "second", "late"):
            def installed(label=label):
                closures[label] = replacement(j, asset, node, label, times[label], kind, position)
                current = j.read(current_path, "operations")
                expected = "second" if label == "late" else label
                j.check(current["actionPerformedAt"] == at(times[expected]), "Recorded order replaced physical installation chronology")
                retained = source_events(j, f"{collection}_lifecycle_events", closures[label][0]["aggregateId"])
                j.check(len(retained) == 1, "Accepted replacement did not retain exactly one physical event")
                events[label] = retained[0]
                j.check(events[label]["actionPerformedAt"] == at(times[label]) and
                        events[label]["completedAt"] == at(times[label] + timedelta(minutes=5)) and
                        events[label]["recordedAt"] > events[label]["completedAt"], "Late entry lost distinct physical, completion and recording times")
                j.business_paths.append(f"{collection}_lifecycle_events/" + events[label]["eventId"])
            j.step(f"{kind}: {label} issue replacement follows physical time; operator cannot close", installed)
        first, second = events["first"], events["second"]
        frozen = copy.deepcopy(events)
        correction_id = j.prefix + "-" + kind + "-correction"
        payload = {"eventId": second["eventId"], "expectedCurrentEventId": second["eventId"],
                   "correctedActionPerformedAt": at(corrected), "reason": "DEV reviewed installation log shows earlier actual date.",
                   "supersedesCorrectionId": None}
        if kind == "uv":
            payload["expectedCurrentActionPerformedAt"] = second["actionPerformedAt"]
        correction = workflow_command("correctBurnerBlockInstallation" if kind == "burner" else "correctUvDetectorInstallation",
                                      correction_id, 0, payload)
        correction_path = f"{collection}_lifecycle_corrections/{correction_id}"
        j.business_paths.append(correction_path)
        j.step(f"{kind}: Operations cannot adjudicate installation history", lambda: j.refuse(
            lambda: workflow_call(j, "operations", correction), ("PERMISSION_DENIED",), (current_path, correction_path)))
        def corrected_history():
            result = workflow_call(j, "si", correction)
            current = j.read(current_path, "operations")
            j.check(current["currentEventId"] == first["eventId"] and current["actionPerformedAt"] == first["actionPerformedAt"],
                    "Corrected chronology did not restore the latest surviving physical installation")
            for label, value in frozen.items():
                j.check(j.read(f"{collection}_lifecycle_events/" + value["eventId"]) == value,
                        "Correction modified original physical event evidence")
            j.check(j.read(correction_path, "si")["correctedActionPerformedAt"] == at(corrected), "Audited correction is not readable by its reviewer")
            j.refuse(lambda: j.read(correction_path, "operations"), ("PERMISSION_DENIED",), (correction_path,))
            replay = workflow_call(j, "si", correction)
            if replay != result:
                (j.output.parent / f"{kind}-correction-replay-diff.json").write_text(
                    json.dumps({"accepted": result, "replay": replay}, indent=2) + "\n")
            j.check(replay == result, "Correction acceptance did not replay")
            for command, accepted in closures.values():
                j.check(workflow_call(j, "si", command) == accepted, "Historical closure acceptance did not replay")
            j.check(j.read(current_path) == current, "Historical replay changed the corrected current installation")
        j.step(f"{kind}: SI correction reorders projection, retains originals and survives historical replay", corrected_history)
        stale = copy.deepcopy(correction)
        stale["commandId"] = str(uuid.uuid4())
        stale["aggregateId"] += "-stale"
        stale["payload"]["correctedActionPerformedAt"] = at(corrected - timedelta(minutes=5))
        j.step(f"{kind}: stale reviewer cannot overwrite the corrected installation", lambda: j.refuse(
            lambda: workflow_call(j, "si", stale), ("ABORTED", "FAILED_PRECONDITION"), (current_path, correction_path)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--position", type=int, default=8, choices=range(1, 9))
    args = parser.parse_args()
    require(PROJECT == "demo-crm3-baf-ops", "Only the fixed loopback demo project is permitted")
    j = Journey(PROJECT, "hj-burner-life-" + uuid.uuid4().hex[:12],
                Path("output/dev-burner-validation-20260927/http-burner-lifecycle.json"))
    j.users = {role: actor(role) for role in ("admin", "si", "operations", "seniorInstrumentation", "seniorMechanical")}
    try:
        lifecycle(j, fixture_asset(j), args.position)
    finally:
        j.write_report()


if __name__ == "__main__":
    main()
