"""Create guarded, additive fixtures for operational UX phone acceptance.

Only the fixed demo emulator is reachable. Catalogue/account setup is administrative;
issue creation, identification and Quality actions under test use real app commands.
Existing profiles or catalogue entries are checked, never overwritten.
"""
from __future__ import annotations

import base64
import json
from datetime import datetime, timezone
from pathlib import Path

from seed_quality_phone_actor import AUTH, FS, PROJECT, PASSWORD, request, require
from http_journey import Journey, unwire, wire
from http_journey_operations import workflow_call, workflow_command

PREFIX = "dev-usability-"
CLASS_ID = "seed-class-annealing-furnace"
NODE_ID = PREFIX + "furnace-seal"
DEFINITION_ID = PREFIX + "abnormal-noise"


def read(path):
    value = request("GET", FS + "/" + path, token="owner", missing_ok=True)
    return None if value is None else {k: unwire(v) for k, v in value.get("fields", {}).items()}


def actor(role):
    email = f"dev.usability-{role.lower()}@example.invalid"
    name = f"DEV Usability {role}"
    accounts = request("POST", AUTH + f"/projects/{PROJECT}/accounts:lookup", {"email": [email]}).get("users", [])
    require(len(accounts) <= 1, "Ambiguous fixture account")
    if not accounts:
        created = request("POST", AUTH + "/accounts:signUp?key=emulator", {
            "targetProjectId": PROJECT, "email": email, "password": PASSWORD,
            "displayName": name, "emailVerified": True})
        accounts = request("POST", AUTH + f"/projects/{PROJECT}/accounts:lookup", {
            "localId": [created["localId"]]}).get("users", [])
    account = accounts[0]
    require(account.get("email") == email and account.get("displayName") == name
            and account.get("emailVerified") is True and not account.get("disabled", False),
            "Existing fixture identity differs; refusing overwrite")
    signed = request("POST", AUTH + "/accounts:signInWithPassword?key=emulator", {
        "targetProjectId": PROJECT, "email": email, "password": PASSWORD, "returnSecureToken": True})
    uid = account["localId"]
    token = signed["idToken"]
    payload = token.split(".")[1]
    claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
    require(signed["localId"] == uid and claims.get("aud") == PROJECT
            and claims.get("email_verified") is True, "Wrong emulator token identity")
    path = "users/" + uid
    profile = read(path)
    expected = {"name": name, "email": email, "roles": [role], "isApproved": True,
                "accessDisposition": "approved"}
    if profile is None:
        data = {**expected, "photoUrl": None, "fcmToken": None, "authorityRevision": 0,
                "createdAt": datetime.now(timezone.utc)}
        request("PATCH", FS + "/" + path + "?currentDocument.exists=false",
                {"fields": {k: wire(v) for k, v in data.items()}}, token="owner")
        profile = read(path)
    require(all(profile.get(k) == v for k, v in expected.items()),
            "Existing fixture profile differs; refusing overwrite")
    return {"uid": uid, "name": name, "email": email, "token": token}


def main():
    require(PROJECT == "demo-crm3-baf-ops", "Only the fixed demo project is permitted")
    actors = {role: actor(role) for role in ("admin", "contractSupervisor", "shiftSupervisor")}
    admin = actors["admin"]
    asset_class = read("asset_classes/" + CLASS_ID)
    require(asset_class is not None and asset_class.get("status") == "active"
            and asset_class.get("legacyAssetTypeKey") == "furnace", "Seed Furnace class is required")
    now = datetime.now(timezone.utc)
    node = {"schemaVersion": 1, "nodeId": NODE_ID, "assetClassId": CLASS_ID,
            "parentNodeId": None, "nodeType": "component", "name": "Furnace seal",
            "componentTag": None, "contactArrangement": "notApplicable",
            "ownershipStatus": "confirmed", "ownerDiscipline": "mechanical",
            "accountableRoleKeys": ["mechanical"], "sortOrder": 1,
            "ancestorNodeIds": [], "hierarchyPath": [asset_class["name"], "Furnace seal"],
            "activeChildCount": 0, "status": "active", "version": 1,
            "createdAt": now, "updatedAt": now, "createdByUid": admin["uid"],
            "createdByName": admin["name"], "updatedByUid": admin["uid"],
            "updatedByName": admin["name"], "lastMutationId": PREFIX + "fixture-v1"}
    path = "asset_hierarchy_nodes/" + NODE_ID
    existing = read(path)
    if existing is None:
        request("PATCH", FS + "/" + path + "?currentDocument.exists=false",
                {"fields": {k: wire(v) for k, v in node.items()}}, token="owner")
        existing = read(path)
    require(all(existing.get(k) == v for k, v in node.items() if k not in {"createdAt", "updatedAt"}),
            "Existing component fixture differs; refusing overwrite")
    definition = {"schemaVersion": 1, "code": "DEV_ABNORMAL_NOISE",
                  "title": "Unusual noise from Furnace", "description": "Unusual noise observed from the Furnace.",
                  "applicableAssetTypeKeys": ["furnace"], "applicableAssetClassIds": [CLASS_ID],
                  "applicableComponentNodeIds": [], "suggestedSeverityKey": "normal",
                  "suggestedMaintenanceTypeKey": "breakdown", "defaultRouteKey": "mechanical",
                  "requiredEvidenceFields": ["observation"], "aliases": ["noise"],
                  "codeOwnedWorkflowProfile": None}
    j = Journey(PROJECT, "hj-usability-fixtures", Path("output/dev-usability-20260926/fixture-commands.json"))
    j.users = {"admin": admin}
    existing = read("frequent_issue_definitions/" + DEFINITION_ID)
    if existing is None:
        workflow_call(j, "admin", workflow_command("upsertFrequentIssueDefinition", DEFINITION_ID, 0,
                      {"definition": definition, "reason": "DEV acceptance fixture for reporting before diagnosis."}))
        j.write_report()
        existing = read("frequent_issue_definitions/" + DEFINITION_ID)
    require(all(existing.get(k) == v for k, v in definition.items()),
            "Existing frequent-issue fixture differs; refusing overwrite")
    type_id = PREFIX + "result-colour"
    result_type = {"firestoreId": type_id, "code": "DEV-COLOUR", "title": "Colour finding for DEV validation",
                   "description": "A result observation; the suggested RA flag must not make the decision.",
                   "category": "resultQuality", "severity": "medium", "applicableAssetTypes": ["furnace"],
                   "suggestsReannealing": True, "isActive": True, "isDeleted": False,
                   "createdAt": now, "updatedAt": now, "createdByUid": admin["uid"],
                   "createdByName": admin["name"], "lastEditedByUid": admin["uid"],
                   "lastEditedByName": admin["name"], "version": 1,
                   "_globalPullServerUpdatedAt": now}
    type_path = "abnormality_types/" + type_id
    existing_type = read(type_path)
    if existing_type is None:
        request("PATCH", FS + "/" + type_path + "?currentDocument.exists=false",
                {"fields": {k: wire(v) for k, v in result_type.items()}}, token="owner")
        existing_type = read(type_path)
    require(all(existing_type.get(k) == v for k, v in result_type.items()
                if k not in {"createdAt", "updatedAt", "_globalPullServerUpdatedAt"}),
            "Existing result-type fixture differs; refusing overwrite")
    print(json.dumps({"project": PROJECT, "componentId": NODE_ID, "frequentIssueId": DEFINITION_ID,
                      "actors": [{k: v for k, v in item.items() if k != "token"} for item in actors.values()]}, indent=2))


if __name__ == "__main__":
    main()
