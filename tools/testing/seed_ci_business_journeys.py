"""Fresh synthetic CI setup only; never business acceptance or database reset.

Fixed non-production namespace and dedicated loopback ports avoid the developer's
interactive demo. Reuses the strict catalogue and planned draft fixture builders.
Publication, assignment and completion remain actions of the Android application.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone, timedelta

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/dev"))
from http_journey import complete_asset_fixture, unwire, wire
from http_planned_work_journey import compact, content_hash, draft
import seed_business_data as catalogue

PROJECT = "demo-crm3-ci-journeys"
AUTH = "http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1"
FS = f"http://127.0.0.1:18080/v1/projects/{PROJECT}/databases/(default)/documents"
READINESS = f"http://127.0.0.1:15001/{PROJECT}/asia-south1/beginGlobalPullRun"
PASSWORD = "emulator-local-only"
PACKAGE = "dev-usability-planned-final-package"
VERSION = "dev-usability-planned-final-version-1"
ACTORS = (
    ("operations", "dev.operations@example.invalid", "Dev Operations"),
    ("si", "dev.usability-si@example.invalid", "DEV Usability si"),
    ("contractSupervisor", "dev.usability-contractsupervisor@example.invalid",
     "DEV Usability contractSupervisor"),
    ("seniorInstrumentation", "dev.usability-seniorinstrumentation@example.invalid",
     "DEV Usability seniorInstrumentation"),
    ("refractory", "dev.required-red-refractory@example.invalid", "DEV Required RED Refractory"),
    ("seniorElectrical", "dev.required-red-electrical@example.invalid", "DEV Required RED Electrical"),
    ("admin", "dev.cf01-a@example.invalid", "DEV CF01 Admin A"),
    ("admin", "dev.cf01-b@example.invalid", "DEV CF01 Admin B"),
)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("CI fixture redirects are forbidden")


def validate_request(method, url, data):
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1"
            or parsed.username or parsed.password or parsed.fragment
            or not (url.startswith(FS + "/") or url == FS + ":commit"
                    or url.startswith(AUTH + "/") or url == READINESS)):
        raise ValueError("Only the dedicated CI loopback namespace is permitted")
    if method not in {"GET", "POST", "PATCH"}:
        raise ValueError("Fixture deletion/reset is forbidden")
    if url.startswith(AUTH + "/") and method != "GET":
        if data.get("targetProjectId") != PROJECT:
            raise ValueError("Auth fixture must target the exact CI project")


def request(method, url, data=None, token="owner"):
    validate_request(method, url, data)
    headers = {"Content-Type": "application/json"}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, method=method, headers=headers,
        data=None if data is None else json.dumps(data).encode())
    try:
        with urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()).open(
                req, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if method == "GET" and error.code == 404:
            return None
        # Auth bodies can contain credentials; log only the operation/status.
        raise RuntimeError(f"CI fixture {method} failed: HTTP {error.code}") from None


def read(path, token="owner"):
    row = request("GET", FS + "/" + path, token=token)
    return None if row is None else {k: unwire(v) for k, v in row.get("fields", {}).items()}


def create(path, fields, token="owner"):
    return request("PATCH", FS + "/" + path + "?currentDocument.exists=false",
                   {"fields": fields}, token)


def seed_actor(role, email, name):
    created = request("POST", AUTH + "/accounts:signUp?key=emulator", {
        "targetProjectId": PROJECT, "email": email, "password": PASSWORD,
        "displayName": name, "emailVerified": True})
    signed = request("POST", AUTH + "/accounts:signInWithPassword?key=emulator", {
        "targetProjectId": PROJECT, "email": email, "password": PASSWORD,
        "returnSecureToken": True})
    token = signed["idToken"]
    payload = token.split(".")[1]
    claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
    if (created["localId"] != signed["localId"] or claims.get("aud") != PROJECT
            or claims.get("email") != email or claims.get("email_verified") is not True):
        raise RuntimeError("CI Auth identity or verification mismatch")
    profile = {"name": name, "email": email, "roles": [role],
               "isApproved": True, "accessDisposition": "approved", "authorityRevision": 0,
               "photoUrl": None, "fcmToken": None, "createdAt": datetime.now(timezone.utc)}
    create("users/" + signed["localId"], {k: wire(v) for k, v in profile.items()})
    if read("users/" + signed["localId"], token)["roles"] != [role]:
        raise RuntimeError("CI actor profile is not readable through ordinary Rules")
    return {"uid": signed["localId"], "name": name, "email": email, "token": token}


class DraftTransport:
    """Adapter for the shared draft builder, retaining its authenticated writes."""
    fs = FS

    def __init__(self, si):
        self.users = {"si": si}
        self.business_paths = []

    def http(self, method, url, data=None, token="owner"):
        if token == "owner":
            raise ValueError("Planned draft must use the signed-in SI, not fixture authority")
        return request(method, url, data, token)

    def read(self, path, role):
        return read(path, self.users[role]["token"])

    @staticmethod
    def check(value, message):
        if not value:
            raise RuntimeError(message)



def required_red_drafts(transport):
    """Only unpublished synthetic templates; the Android UI performs all work."""
    parent, parent_version = draft(
        transport, "ci-required-red-parent-package", "ci-required-red-parent-version-1",
        "DEV required RED parent inspection")
    if parent.get("activeVersionFirestoreId") is not None or parent_version["status"] != "draft":
        raise RuntimeError("Required RED parent must be an unpublished draft")
    si = transport.users["si"]
    at = datetime.now(timezone.utc).isoformat()
    metadata = {"schemaVersion": 1, "version": 1, "isDeleted": False,
        "createdByUid": si["uid"], "createdByName": si["name"],
        "updatedByUid": si["uid"], "updatedByName": si["name"],
        "createdAt": at, "updatedAt": at}
    package_id = "ci-required-red-successor-package"
    version_id = "ci-required-red-successor-version-1"
    title = "DEV required RED refractory inspection"
    package = {**metadata, "firestoreId": package_id,
        "packageCode": "CI-REQUIRED-RED-FURNACE", "title": title,
        "description": "Synthetic required RED Android journey draft.",
        "assetType": "furnace", "disciplineScope": "refractory",
        "lifecycleStatus": "active", "latestVersionNumber": 0,
        "activeVersionFirestoreId": None}
    review = {"closureReviewConfirmed": True, "closureReviewConfirmedByUid": si["uid"],
        "closureReviewConfirmedByName": si["name"], "closureReviewConfirmedAt": at}
    version = {**metadata, "firestoreId": version_id, "packageFirestoreId": package_id,
        "versionNumber": 1, "versionLabel": "v1", "status": "draft",
        "jobTemplateSnapshotJson": compact({"jobName": title, "assetType": "furnace",
            "composer": review, "closureCriticalCount": 1}),
        "moduleSnapshotsJson": compact([{"moduleCode": "CI-RED-01",
            "moduleTitle": "Refractory inspection", "discipline": "refractory",
            "requiredForClosure": True, "isRequired": True}]),
        "fieldDefinitionsJson": compact([{"key": "redInspection", "label": "Refractory findings",
            "moduleCode": "CI-RED-01", "type": "text", "isRequired": True}]),
        "checklistJson": "[]", **review, "closureCriticalModuleCount": 1,
        "targetRefs": [], "deviceTagRefs": [], "safetyClass": None,
        "safetyGatePolicyJson": None, "procedureRefs": [], "operationalStatePreconditions": [],
        "publishedAt": None, "publishedByUid": None, "publishedByName": None,
        "retiredAt": None, "metadataJson": None}
    version["contentHash"] = content_hash(version)
    for path, value in (("template_packages/" + package_id, package),
                        ("template_versions/" + version_id, version)):
        if read(path) is not None:
            raise RuntimeError("Required RED fixture exists; preserving it without overwrite")
        create(path, {key: wire(value) for key, value in value.items()}, si["token"])
        actual = read(path, si["token"])
        if actual.get("firestoreId") != value["firestoreId"]:
            raise RuntimeError("Required RED draft authenticated readback failed")
    prompt = {"firestoreId": "ci-required-red-furnace", "assetTypeKey": "furnace",
        "promptKey": "redRequirement", "promptTypeKey": "question", "active": True,
        "question": "Is RED required after this maintenance?", "version": 1,
        "redSuccessorTemplateCode": "CI-REQUIRED-RED-FURNACE",
        "createdAt": at, "updatedAt": at}
    create("equipment_prompt_master/ci-required-red-furnace",
        {key: wire(value) for key, value in prompt.items()})


def inner_cover_fixture_documents(at, actor):
    """Fresh synthetic inventory only. Cases and business outcomes are never seeded."""
    base_class = "dev-ic-fitness-base-class"
    cover_class = "dev-ic-fitness-inner-cover-class"
    installed = at - timedelta(days=1)
    received = at - timedelta(days=3)
    accepted = at - timedelta(days=2)
    result = {}
    for cid, key, code, name in ((base_class, "base", "BASE", "Base"),
            (cover_class, "innerCover", "INNER_COVER", "Inner Cover")):
        result["asset_classes/" + cid] = complete_asset_fixture("asset_classes", {
            "schemaVersion": 1, "assetClassId": cid, "code": code, "name": name,
            "legacyAssetTypeKey": key, "status": "active", "createdAt": received,
            "updatedAt": at, "lastMutationId": cid + "-synthetic-setup"}, actor)
    covers = ((101, "515a060f-400d-568e-bad3-b03f1a287c95", "DEV-IC-FITNESS-31"),
              (102, "f43b7a65-bb12-4781-861c-c52853b93e68", "DEV-IC-COMPARISON-31"))
    for number, cover_id, serial in covers:
        base_id = f"dev-ic-fitness-base-{number}"
        base_name = f"Base {number}"
        link_id = f"dev-ic-fitness-link-{number}"
        result["asset_instances/" + base_id] = complete_asset_fixture("asset_instances", {
            "schemaVersion": 1, "assetInstanceId": base_id, "assetClassId": base_class,
            "assetClassCode": "BASE", "assetClassName": "Base", "assetNumber": number,
            "name": base_name, "status": "active", "createdAt": received, "updatedAt": at,
            "lastMutationId": base_id + "-synthetic-setup"}, actor)
        result[f"equipment_status/base_{number}"] = {
            "version": 1, "assetTypeKey": "base", "assetNumber": number,
            "assetClassId": base_class, "assetInstanceId": base_id,
            "state": "inService", "previousState": "inService",
            "activeNonRedMaintenanceCount": 0, "activeRedWorkCount": 0,
            "awaitingPreparationCount": 0, "updatedAt": at}
        result["asset_availability_current/" + base_id] = {
            "schemaVersion": 1, "assetType": "base", "assetClassId": base_class,
            "assetInstanceId": base_id, "assetNumber": number,
            "availabilityState": "clear", "activeConstraintId": None,
            "reasonType": None, "linkedCaseId": None, "linkedTicketId": None,
            "since": None, "updatedAt": at, "version": 1}
        result["inner_cover_profiles/" + cover_id] = {
            "schemaVersion": 1, "innerCoverId": cover_id, "assetClassId": cover_class,
            "assetClassCode": "INNER_COVER", "assetClassName": "Inner Cover",
            "serialNumber": serial, "normalizedSerialNumber": serial.replace("-", ""),
            "sourceType": "purchased", "originClassification": "documentedPurchase",
            "lifecycleState": "installed", "traceabilityGrade": "T3",
            "supplierOrFabricator": "Synthetic CI fixture", "drawingReference": "CI-SYNTHETIC-IC",
            "materialGrade": "SS 321", "receivedOrCompletedOn": received,
            "incorporatedOn": installed,
            "acceptanceReference": "SYNTHETIC-NOT-PHYSICAL-CERTIFICATION",
            "acceptedAt": accepted, "acceptedByUid": actor["uid"], "acceptedByName": actor["name"],
            "currentBaseAssetInstanceId": base_id, "currentBaseAssetNumber": number,
            "currentBaseAssetName": base_name, "currentLinkageId": link_id,
            "version": 3, "createdAt": received, "updatedAt": installed,
            "lastMutationId": cover_id + "-synthetic-setup"}
        result["base_inner_cover_assignments/" + base_id] = {
            "schemaVersion": 1, "baseAssetInstanceId": base_id, "baseAssetClassId": base_class,
            "baseAssetNumber": number, "baseAssetName": base_name, "innerCoverId": cover_id,
            "innerCoverSerialNumber": serial, "linkageId": link_id, "linkedAt": installed,
            "version": 1, "updatedAt": installed, "lastMutationId": link_id}
        result["inner_cover_linkages/" + link_id] = {
            "schemaVersion": 1, "linkageId": link_id, "baseAssetInstanceId": base_id,
            "baseAssetNumber": number, "baseAssetName": base_name, "innerCoverId": cover_id,
            "innerCoverSerialNumber": serial, "installedAt": installed,
            "installedByUid": actor["uid"], "installedByName": actor["name"],
            "active": True, "version": 1}
    return result


def seed_inner_cover_inventory(operations):
    documents = inner_cover_fixture_documents(datetime.now(timezone.utc), {
        "uid": "ci-inner-cover-fixture-author", "name": "Synthetic CI inventory setup"})
    # Establish all absences before the first new write; per-write preconditions
    # also preserve any concurrently created record rather than overwriting it.
    if any(read(path) is not None for path in documents):
        raise RuntimeError("IC inventory already exists; preserving it without overwrite")
    for path, value in documents.items():
        create(path, {key: wire(item) for key, item in value.items()})
        actual = read(path, operations["token"])
        if actual is None or actual.keys() != value.keys():
            raise RuntimeError("IC synthetic inventory authenticated readback shape mismatch: " + path)
        for key, expected in value.items():
            observed = actual[key]
            if isinstance(expected, datetime):
                try:
                    observed = datetime.fromisoformat(observed.replace("Z", "+00:00"))
                except (AttributeError, TypeError, ValueError):
                    raise RuntimeError("IC synthetic timestamp readback mismatch: " + path) from None
            if observed != expected:
                raise RuntimeError("IC synthetic inventory authenticated readback mismatch: " + path)


def main():
    if read("ci_journey_runs/seed") is not None:
        raise RuntimeError("CI namespace is not fresh; refusing to overwrite or reset evidence")
    create("ci_journey_runs/seed", {"startedAt": wire(datetime.now(timezone.utc))})
    actors = {role: seed_actor(role, email, name) for role, email, name in ACTORS}
    create("runtime_contracts/global_pull_v1", catalogue.global_pull_contract())
    create("asset_classes/" + catalogue.ASSET_CLASS_ID, catalogue.asset_class())
    create("asset_instances/" + catalogue.ASSET_INSTANCE_ID, catalogue.asset_instance())
    for values in catalogue.TYPES:
        create("abnormality_types/" + values[0], catalogue.abnormality_type(*values))
    transport = DraftTransport(actors["si"])
    package, version = draft(transport, PACKAGE, VERSION, "DEV Furnace planned final inspection")
    if (package["activeVersionFirestoreId"] is not None or version["status"] != "draft"
            or version["publishedAt"] is not None):
        raise RuntimeError("The CI fixture must not pre-publish or accept work")
    required_red_drafts(transport)
    seed_inner_cover_inventory(actors["operations"])
    # A running emulator process alone does not prove Functions loaded. Verify
    # the actual authenticated read-only callable before starting Android.
    readiness = request("POST", READINESS, {"data": {}}, actors["operations"]["token"])
    result = readiness.get("result", {})
    if (result.get("actorUid") != actors["operations"]["uid"]
            or result.get("protocolVersion") != 1 or not result.get("serverAnchor")):
        raise RuntimeError("Actual global-pull callable readiness/readback failed")
    print(json.dumps({"project": PROJECT, "actors": [a[0] for a in ACTORS],
                      "package": PACKAGE, "version": VERSION, "status": "draft",
                      "businessAcceptanceSeeded": False, "authenticatedCallableReady": True}))


if __name__ == "__main__":
    main()
