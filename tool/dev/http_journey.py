"""Exercise local business journeys through Auth and Functions HTTP transports.

Administrative fixture writes are isolated by a unique hj- run prefix. Business
actions use real signed-in emulator users and actual callable endpoints. No
database reset, production address, fake handler, or success stub is supported.
Results describe backend/Rules integration; they do not certify Android UI,
device offline storage, production IAM, App Check, or release builds.
"""

from __future__ import annotations

import argparse
import base64
import copy
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


EMULATOR_PROFILES = {
    "interactive": (9099, 8080, 5001),
    "isolated-ci": (19099, 18080, 15001),
}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Business-journey emulator redirects are forbidden")


class HttpFailure(RuntimeError):
    def __init__(self, status: int, body: dict):
        self.status, self.body = status, body
        error = body.get("error", body)
        self.code = error.get("status", str(status)) if isinstance(error, dict) else str(status)
        super().__init__(f"HTTP {status}: {json.dumps(error)}")


def instant() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def wire(value):
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, datetime):
        return {"timestampValue": value.isoformat().replace("+00:00", "Z")}
    if isinstance(value, list):
        return {"arrayValue": {"values": [wire(v) for v in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {k: wire(v) for k, v in value.items()}}}
    raise TypeError(f"Unsupported fixture value: {type(value).__name__}")


def unwire(value):
    if "mapValue" in value:
        return {k: unwire(v) for k, v in value["mapValue"].get("fields", {}).items()}
    if "arrayValue" in value:
        return [unwire(v) for v in value["arrayValue"].get("values", [])]
    if "integerValue" in value:
        return int(value["integerValue"])
    return next(iter(value.values()))


def complete_asset_fixture(collection: str, fields: dict, actor: dict) -> dict:
    """Keep owner-created fixtures readable by the phone's strict models.

    Preserve every explicit business value; only fill required creation metadata.
    This applies to fixture setup, never to callable results or persisted reads.
    """
    if collection not in ("asset_classes", "asset_instances"):
        return fields
    at = fields.get("createdAt", fields.get("updatedAt", datetime.now(timezone.utc)))
    defaults = {"version": 1, "createdAt": at, "updatedAt": at,
                "lastMutationId": f"http-fixture-{uuid.uuid4()}"}
    if collection == "asset_classes":
        defaults.update(majorArea="BAF", shortDescription=None, longDescription=None,
                        createdByUid=actor["uid"], createdByName=actor["name"],
                        updatedByUid=actor["uid"], updatedByName=actor["name"])
    else:
        defaults.update(serviceState="inService", activeComponentCount=0,
                        ownershipStatus="confirmed", ownerDiscipline="operations",
                        accountableRoleKeys=["operations"])
    return {**defaults, **fields}


class Journey:
    def __init__(self, project: str, prefix: str, output: Path, *, emulator_profile="interactive"):
        if not re.fullmatch(r"demo-[a-z0-9-]+", project):
            raise ValueError("Only an isolated demo- project is permitted")
        if not re.fullmatch(r"hj-[a-z0-9-]{6,60}", prefix):
            raise ValueError("Fixture prefix must be hj- followed by 6-60 lowercase letters/digits/hyphens")
        if emulator_profile not in EMULATOR_PROFILES:
            raise ValueError("Unknown emulator profile")
        if emulator_profile == "isolated-ci" and project != "demo-crm3-ci-journeys":
            raise ValueError("The isolated CI ports require their exact demo project")
        self.project, self.prefix, self.output = project, prefix, output
        self.emulator_profile = emulator_profile
        auth_port, firestore_port, functions_port = EMULATOR_PROFILES[emulator_profile]
        self.auth = f"http://127.0.0.1:{auth_port}/identitytoolkit.googleapis.com/v1"
        self.fs = f"http://127.0.0.1:{firestore_port}/v1/projects/{project}/databases/(default)/documents"
        self.functions = f"http://127.0.0.1:{functions_port}/{project}/asia-south1"
        self.users: dict[str, dict] = {}
        self.fixture_paths: list[str] = []
        self.business_paths: list[str] = []
        self.results: list[dict] = []
        self.calls: list[dict] = []
        self.started = instant()

    def http(self, method: str, url: str, data=None, token="owner"):
        parsed = urllib.parse.urlsplit(url)
        if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1"
                or parsed.username or parsed.password or parsed.fragment
                or not (url.startswith(self.auth + "/") or url.startswith(self.fs + "/")
                        or url in (self.fs + ":commit", self.fs + ":runQuery")
                        or url.startswith(self.functions + "/"))):
            raise ValueError("Only the selected literal loopback demo namespace is permitted")
        if method not in ("GET", "POST", "PATCH"):
            raise ValueError("Business-journey reset/deletion is forbidden")
        if url.startswith(self.auth + "/") and method == "POST":
            if token == "owner":
                data = {**(data or {}), "targetProjectId": self.project}
            elif data and "targetProjectId" in data:
                raise ValueError("Auth targetProjectId requires an administrative fixture request")
        headers = {"Content-Type": "application/json"}
        if token is not None:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(url, headers=headers, method=method,
                                         data=None if data is None else json.dumps(data).encode())
        try:
            with urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()).open(
                    request, timeout=60) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            raw = error.read().decode("utf-8", "replace")
            try:
                body = json.loads(raw)
            except json.JSONDecodeError:
                body = {"error": {"message": raw}}
            raise HttpFailure(error.code, body) from error

    def seed(self, path: str, fields: dict):
        if not (path.split("/")[-1].startswith(self.prefix) or
                path in [f"users/{u['uid']}" for u in self.users.values()]):
            raise ValueError(f"Refusing unscoped fixture write: {path}")
        fields = complete_asset_fixture(path.split("/")[0], fields, self.users.get("admin", {}))
        self.http("PATCH", f"{self.fs}/{path}", {"fields": {k: wire(v) for k, v in fields.items()}})
        self.fixture_paths.append(path)

    def read(self, path: str, actor: str | None = None):
        token = self.users[actor]["token"] if actor else "owner"
        try:
            result = self.http("GET", f"{self.fs}/{path}", token=token)
        except HttpFailure as error:
            if error.status == 404:
                return None
            raise
        return {k: unwire(v) for k, v in result.get("fields", {}).items()}

    def call(self, actor: str | None, endpoint: str, request: dict, *, v2=False, origin=None, payload_key="request"):
        uid = self.users[actor]["uid"] if actor else None
        token = self.users[actor]["token"] if actor else None
        operation = request.get("operation", request.get("commandType", request.get("probe", "read")))
        intent_id = request.get("requestId", request.get("commandId"))
        record = {"endpoint": endpoint, "operation": operation, "actorRole": actor, "intentId": intent_id}
        if v2:
            request = {"protocolVersion": 2, "originActorUid": origin or uid, payload_key: request}
        try:
            response = self.http("POST", f"{self.functions}/{endpoint}", {"data": request}, token)
        except HttpFailure as error:
            self.calls.append({**record, "outcome": error.code})
            raise
        if "error" in response:
            self.calls.append({**record, "outcome": "error"})
            raise HttpFailure(200, response)
        if "result" not in response:
            raise AssertionError(f"Missing callable result: {response}")
        self.calls.append({**record, "outcome": "accepted"})
        return response["result"]

    def quality(self, actor: str, request: dict, *, v2=False, origin=None):
        return self.call(actor, "mutateChargeAbnormalityV2" if v2 else "mutateChargeAbnormality",
                         request, v2=v2, origin=origin)

    def check(self, condition: bool, message: str):
        if not condition:
            raise AssertionError(message)

    def refuse(self, action, codes: tuple[str, ...], paths=()):
        def business(path):
            record = self.read(path)
            if record:
                record.pop("_globalPullServerUpdatedAt", None)
            return record
        before = {path: business(path) for path in paths}
        try:
            action()
        except HttpFailure as error:
            self.check(error.code in codes, f"Expected {codes}, received {error}")
        else:
            raise AssertionError(f"Expected refusal {codes}, but action succeeded")
        self.check(before == {path: business(path) for path in paths}, "Refused command changed business evidence")

    def step(self, name: str, action):
        started = time.monotonic()
        try:
            action()
            self.results.append({"name": name, "status": "passed", "seconds": round(time.monotonic()-started, 3)})
            print(f"PASS {name}", flush=True)
        except Exception as error:
            self.results.append({"name": name, "status": "failed", "error": str(error),
                                 "seconds": round(time.monotonic()-started, 3)})
            print(f"FAIL {name}: {error}", flush=True)
            raise
        finally:
            self.write_report()

    def write_report(self):
        self.output.parent.mkdir(parents=True, exist_ok=True)
        report = {"schemaVersion": 1, "project": self.project, "prefix": self.prefix,
                  "emulatorProfile": self.emulator_profile,
                  "startedAt": self.started, "updatedAt": instant(),
                  "transport": "Auth emulator sign-in -> Functions callable HTTP -> persisted Firestore REST read",
                  "scope": "Backend and Firestore Rules integration; no Android UI/offline or production certification",
                  "fixturePaths": self.fixture_paths, "businessPaths": self.business_paths, "results": self.results,
                  "callableRequests": self.calls, "endpoints": sorted({c["endpoint"] for c in self.calls}),
                  "passed": sum(r["status"] == "passed" for r in self.results),
                  "failed": sum(r["status"] == "failed" for r in self.results)}
        self.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    def setup(self):
        for role in ("operations", "si", "admin", "pending", "seniorMechanical", "seniorInstrumentation"):
            email, password = f"{self.prefix}.{role}@example.invalid", "emulator-journey-only"
            display = f"HTTP Journey {role} {self.prefix}"
            account = self.http("POST", f"{self.auth}/accounts:signUp?key=emulator",
                                {"email": email, "password": password, "displayName": display})
            uid = account["localId"]
            self.http("POST", f"{self.auth}/accounts:update", {"localId": uid, "emailVerified": True})
            signed = self.http("POST", f"{self.auth}/accounts:signInWithPassword?key=emulator",
                               {"email": email, "password": password, "returnSecureToken": True}, token=None)
            token_payload = signed["idToken"].split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(token_payload + '=' * (-len(token_payload) % 4)))
            self.check(claims.get("aud") == self.project and claims.get("sub") == uid,
                       "Auth emulator returned a different project or fixture identity")
            self.users[role] = {"uid": uid, "name": display, "token": signed["idToken"]}
            self.seed(f"users/{uid}", {"uid": uid, "name": display, "email": email,
                       "isApproved": role != "pending", "roles": ["operations" if role == "pending" else role],
                       "createdAt": datetime.now(timezone.utc), "accessDisposition": "pending" if role == "pending" else "approved"})
        self.type_id = f"{self.prefix}-type"
        self.class_id, self.base_id = f"{self.prefix}-base-class", f"{self.prefix}-base-7"
        at = datetime.now(timezone.utc)
        self.seed(f"abnormality_types/{self.type_id}", {"firestoreId": self.type_id,
                  "code": "HJ-SURFACE", "title": "HTTP journey surface defect", "description": "Isolated development fixture",
                  "category": "resultQuality", "severity": "medium", "applicableAssetTypes": ["base"],
                  "suggestsReannealing": False, "isActive": True, "isDeleted": False,
                  "createdAt": at, "updatedAt": at, "createdByUid": self.users['admin']['uid'],
                  "createdByName": self.users['admin']['name'], "lastEditedByUid": self.users['admin']['uid'],
                  "lastEditedByName": self.users['admin']['name'], "version": 1})
        self.seed(f"asset_classes/{self.class_id}", {"schemaVersion": 1, "assetClassId": self.class_id,
                  "code": "HJBASE", "name": f"Journey Base {self.prefix}", "legacyAssetTypeKey": "base", "status": "active",
                  "majorArea": "BAF", "shortDescription": None, "longDescription": None,
                  "version": 1, "createdAt": at, "updatedAt": at, "createdByUid": self.users['admin']['uid'],
                  "createdByName": self.users['admin']['name'], "updatedByUid": self.users['admin']['uid'],
                  "updatedByName": self.users['admin']['name'], "lastMutationId": str(uuid.uuid4())})
        self.seed(f"asset_instances/{self.base_id}", {"schemaVersion": 1, "assetInstanceId": self.base_id,
                  "assetClassId": self.class_id, "assetClassCode": "HJBASE", "assetClassName": f"Journey Base {self.prefix}",
                  "assetNumber": 7, "name": "Journey Base 7", "status": "active", "version": 1,
                  "serviceState": "inService", "ownershipStatus": "confirmed", "ownerDiscipline": "operations",
                  "accountableRoleKeys": ["operations"], "activeComponentCount": 0,
                  "createdAt": at, "updatedAt": at, "lastMutationId": str(uuid.uuid4())})

    def synchronization_journey(self):
        def clock():
            result = self.call("operations", "beginGlobalPullRun", {})
            self.check(result["actorUid"] == self.users["operations"]["uid"], "Global pull lost actor identity")
            self.check(result["serverStampField"] == "_globalPullServerUpdatedAt" and
                       isinstance(result["serverAnchor"], str), "Global pull clock is missing")
        self.step("approved global pull obtains a real server clock", clock)
        self.step("unapproved global pull is refused", lambda: self.refuse(
            lambda: self.call("pending", "beginGlobalPullRun", {}), ("PERMISSION_DENIED",)))
        def stamp():
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if self.read(f"abnormality_types/{self.type_id}").get("_globalPullServerUpdatedAt"):
                    return
                time.sleep(0.5)
            raise AssertionError("Actual Firestore event trigger did not stamp the new master record")
        self.step("Firestore event trigger stamps new records for device synchronization", stamp)

    def abnormality_journey(self):
        entity_id = f"{self.prefix}-abnormality"
        warning_id = f"abnormality_{entity_id}"
        case_path, warning_path = f"charge_abnormalities/{entity_id}", f"quality_warnings/{warning_id}"
        paths = (case_path, warning_path)
        self.business_paths.extend(paths)
        ops = self.users["operations"]
        at = (datetime.now(timezone.utc)-timedelta(seconds=2)).isoformat(timespec="milliseconds").replace("+00:00", "Z")
        record = {"firestoreId": entity_id, "sourceChargeNo": 91234, "abnormalityTypeId": self.type_id,
                  "abnormalityTypeTitle": "HTTP journey surface defect", "abnormalityTypeCode": "HJ-SURFACE",
                  "category": "resultQuality", "severity": "medium", "affectedAssets": [{"assetType": "base", "assetNumber": 7}],
                  "component": None, "observedReason": "Surface defect observed after the cycle.", "description": None,
                  "possibleRootReasonCategory": "unknown", "possibleRootReasonNotes": None,
                  "reannealingStatus": "notApplicable", "reannealedToChargeNo": None,
                  "loggedAt": at, "updatedAt": at, "loggedByUid": ops['uid'], "loggedByName": ops['name'],
                  "updatedByUid": ops['uid'], "updatedByName": ops['name'], "linkedTicketFirestoreId": None,
                  "linkedExecutionFirestoreId": None, "version": 1, "isDeleted": False,
                  "deletedAt": None, "deletedByUid": None, "deletedByName": None, "deleteReason": None}
        hierarchy = {"schemaVersion": 3, "scope": "physicalAsset", "assetClassId": self.class_id,
                     "assetClassCode": "HJBASE", "assetClassName": f"Journey Base {self.prefix}",
                     "nodeId": self.base_id, "nodeVersion": 1, "nodeName": "Journey Base 7",
                     "assetInstanceId": self.base_id, "assetInstanceVersion": 1, "assetNumber": 7,
                     "assetInstanceName": "Journey Base 7", "componentInstanceId": None,
                     "componentInstanceVersion": None, "componentTag": None,
                     "hierarchyPath": [f"Journey Base {self.prefix}", "Journey Base 7"],
                     "ownershipStatus": "confirmed", "ownerDiscipline": "operations",
                     "accountableRoleKeys": ["operations"], "innerCoverAssociation": None}
        record["affectedAssetHierarchyRefs"] = [{"assetType": "base", "assetNumber": 7, "assetHierarchyRef": hierarchy}]
        create = {"requestId": str(uuid.uuid4()), "operation": "CREATE", "abnormalityId": entity_id,
                  "expectedVersion": 0, "reason": "Operator records isolated development observation.", "abnormality": record}
        self.step("unapproved account cannot create an abnormality", lambda: self.refuse(
            lambda: self.quality("pending", create), ("PERMISSION_DENIED",), paths))
        def create_case():
            result = self.quality("operations", create)
            self.check(result["version"] == 1 and not result["idempotentReplay"], "Creation did not return first acceptance")
            self.check(self.read(case_path, "operations")["version"] == 1, "Approved Rules read cannot see canonical case")
            self.check(self.read(warning_path, "operations")["status"] == "open", "Creation did not publish open warning")
            self.check(self.read(case_path)["affectedAssetHierarchyRefs"][0]["assetHierarchyRef"]["assetInstanceId"] == self.base_id,
                       "Governed physical subject was lost")
            self.check(self.read(f"charge_abnormality_mutation_receipts/{create['requestId']}") is not None, "Creation receipt missing")
        self.step("Operations creates case and visible Quality warning atomically", create_case)
        self.step("unauthenticated callable cannot mutate the case", lambda: self.refuse(
            lambda: self.call(None, "mutateChargeAbnormality", create), ("UNAUTHENTICATED",), paths))
        self.step("unapproved viewer cannot read the Quality warning", lambda: self.refuse(
            lambda: self.read(warning_path, "pending"), ("PERMISSION_DENIED",)))
        self.step("accepted creation replays without a second case", lambda: self.check(
            self.quality("operations", create)["idempotentReplay"] and self.read(case_path)["version"] == 1, "Exact creation replay failed"))
        changed = copy.deepcopy(create); changed["abnormality"]["observedReason"] = "Changed replay must not overwrite accepted evidence."
        self.step("same creation request cannot change its payload", lambda: self.refuse(
            lambda: self.quality("operations", changed), ("ABORTED",), paths))
        def command(operation, version, **extra):
            return {"requestId": str(uuid.uuid4()), "operation": operation, "warningId": warning_id,
                    "expectedVersion": version, "reason": f"HTTP journey verifies {operation}.", **extra}
        premature = command("RECORD_QUALITY_CASE_RA_COMPLETED", 1, linkedReannealingChargeNos=[91235])
        self.step("RA completion requires a prior required decision", lambda: self.refuse(
            lambda: self.quality("operations", premature), ("FAILED_PRECONDITION",), paths))
        required = command("DECLARE_QUALITY_CASE_RA_REQUIRED", 1)
        self.step("Operations declares RA required", lambda: self.check(
            self.quality("operations", required)["version"] == 2 and self.read(case_path)["reannealingStatus"] == "required", "RA required did not converge"))
        completion = command("RECORD_QUALITY_CASE_RA_COMPLETED", 2, linkedReannealingChargeNos=[91235])
        def complete():
            self.quality("operations", completion)
            case, warning = self.read(case_path), self.read(warning_path)
            self.check(case["reannealingStatus"] == "completed" and case["reannealedToChargeNo"] == 91235, "RA physical fact missing")
            self.check(warning["status"] == "closureRequested" and warning["version"] == 3, "RA completion bypassed formal quality review")
        self.step("Operations records physical RA and requests Quality review", complete)
        closure = command("CLOSE_QUALITY_WARNING", 3, disposition="reannealingCompleted", linkedReannealingChargeNos=[91235])
        self.step("Operations cannot make the formal Quality decision", lambda: self.refuse(
            lambda: self.quality("operations", closure), ("PERMISSION_DENIED",), paths))
        stale = {**closure, "requestId": str(uuid.uuid4()), "expectedVersion": 1}
        self.step("stale SI decision cannot overwrite the current revision", lambda: self.refuse(
            lambda: self.quality("si", stale), ("ABORTED",), paths))
        self.step("SI closes Quality with the Operations-recorded RA charge", lambda: self.check(
            self.quality("si", closure)["version"] == 4 and self.read(warning_path)["status"] == "closed", "Formal decision missing"))
        mutable_fields = ("abnormalityTypeId", "severity", "affectedAssets", "affectedAssetHierarchyRefs", "component",
                          "observedReason", "description", "possibleRootReasonCategory", "possibleRootReasonNotes",
                          "reannealingStatus", "reannealedToChargeNo")
        current = self.read(case_path)
        correction = {"requestId": str(uuid.uuid4()), "operation": "UPDATE", "abnormalityId": entity_id,
                      "expectedVersion": current["version"], "reason": "Correct material observation after review.",
                      **{field: current[field] for field in mutable_fields}, "observedReason": "Corrected defect location after evidence review."}
        self.step("Admin material correction requires reopening a closed decision", lambda: self.refuse(
            lambda: self.quality("admin", correction), ("FAILED_PRECONDITION",), paths))
        reopen = command("REOPEN_QUALITY_WARNING", 4)
        self.step("reopen retains completed physical RA evidence", lambda: self.check(
            self.quality("si", reopen)["version"] == 5 and self.read(warning_path)["status"] == "open" and
            self.read(case_path)["reannealedToChargeNo"] == 91235, "Reopen erased physical RA evidence"))
        def recover():
            response = self.quality("si", closure, v2=True)
            self.check(response["idempotentReplay"] and response["version"] == 4, "Historical V2 replay failed")
            self.check(self.read(warning_path)["version"] == 5, "Historical replay rewrote current state")
        self.step("V2 recovers accepted decision after a later reopen", recover)
        self.step("saved V2 command cannot cross accounts", lambda: self.refuse(
            lambda: self.quality("admin", closure, v2=True, origin=self.users['si']['uid']), ("PERMISSION_DENIED",), paths))
        correction.update(requestId=str(uuid.uuid4()), expectedVersion=self.read(case_path)["version"])
        self.step("Operations cannot perform Admin evidence correction", lambda: self.refuse(
            lambda: self.quality("operations", correction), ("PERMISSION_DENIED",), paths))
        def correct_case():
            self.quality("admin", correction)
            case, warning = self.read(case_path), self.read(warning_path)
            self.check(case["observedReason"] == correction["observedReason"] and
                       warning["warningReason"] == correction["observedReason"], "Correction did not update the warning projection")
            self.check(case["reannealedToChargeNo"] == 91235 and case["affectedAssetHierarchyRefs"][0]["assetHierarchyRef"] == hierarchy,
                       "Correction erased physical RA or governed subject evidence")
        self.step("reopened Admin correction converges without erasing RA or asset identity", correct_case)
        deletion = {"requestId": str(uuid.uuid4()), "operation": "SOFT_DELETE", "abnormalityId": entity_id,
                    "expectedVersion": self.read(case_path)["version"], "reason": "Retire isolated duplicate after Quality review."}
        self.step("Admin cannot retire an unresolved Quality case", lambda: self.refuse(
            lambda: self.quality("admin", deletion), ("FAILED_PRECONDITION",), paths))

    def monitoring_journey(self):
        monitoring_id = str(uuid.uuid4())
        path = f"quality_monitoring_requests/{monitoring_id}"
        self.business_paths.append(path)
        create = {"requestId": str(uuid.uuid4()), "operation": "CREATE_QUALITY_MONITORING_REQUEST",
                  "monitoringRequestId": monitoring_id, "expectedVersion": 0,
                  "reason": f"{self.prefix}: monitor an isolated development cycle", "baseNumber": 7,
                  "baseAssetClassId": self.class_id, "baseAssetInstanceId": self.base_id,
                  "baseAssetInstanceVersion": 1, "grade": "HJ Grade A", "cycleReference": self.prefix,
                  "chargeNumbers": [91234, 91235]}
        self.step("Operations cannot create Quality monitoring", lambda: self.refuse(
            lambda: self.quality("operations", create, v2=True), ("PERMISSION_DENIED",), (path,)))
        self.step("SI creates monitoring through origin-bound V2 transport", lambda: self.check(
            self.quality("si", create, v2=True)["version"] == 1 and self.read(path, "si")["status"] == "active", "Monitoring creation failed"))
        self.step("monitoring retry reuses accepted creation", lambda: self.check(
            self.quality("si", create, v2=True)["idempotentReplay"] and self.read(path)["version"] == 1, "Monitoring duplicate risk"))
        correction = {**create, "requestId": str(uuid.uuid4()), "operation": "CORRECT_QUALITY_MONITORING_REQUEST",
                      "expectedVersion": 1, "grade": "HJ Grade B", "chargeNumbers": [91236], "reason": "Correct a transcribed charge and grade."}
        self.step("SI corrects monitoring while retaining original context", lambda: self.check(
            self.quality("si", correction, v2=True)["version"] == 2 and self.read(path)["originalMonitoringContext"]["grade"] == "HJ Grade A", "Monitoring correction lost original context"))
        cancel = {"requestId": str(uuid.uuid4()), "operation": "CANCEL_QUALITY_MONITORING_REQUEST",
                  "monitoringRequestId": monitoring_id, "expectedVersion": 2, "reason": "Entered in error; do not claim physical completion."}
        self.step("cancellation remains distinct from completed monitoring", lambda: self.check(
            self.quality("si", cancel, v2=True)["version"] == 3 and self.read(path)["monitoringDisposition"] == "cancelled", "Cancellation claims completion"))
        self.step("original monitoring acceptance recovers after correction/cancellation", lambda: self.check(
            self.quality("si", create, v2=True)["idempotentReplay"] and self.read(path)["version"] == 3, "Monitoring recovery changed later evidence"))
        stale = {**cancel, "requestId": str(uuid.uuid4()), "operation": "CLOSE_QUALITY_MONITORING_REQUEST"}
        self.step("cancelled monitoring rejects later stale completion", lambda: self.refuse(
            lambda: self.quality("si", stale, v2=True), ("ABORTED", "FAILED_PRECONDITION"), (path,)))
        completion_id = str(uuid.uuid4())
        completion_path = f"quality_monitoring_requests/{completion_id}"
        self.business_paths.append(completion_path)
        deliberate = {**create, "requestId": str(uuid.uuid4()), "monitoringRequestId": completion_id}
        def completed_monitoring():
            self.quality("si", deliberate, v2=True)
            close = {"requestId": str(uuid.uuid4()), "operation": "CLOSE_QUALITY_MONITORING_REQUEST",
                     "monitoringRequestId": completion_id, "expectedVersion": 1, "reason": "Monitoring cycle actually completed."}
            accepted = self.quality("si", close, v2=True)
            stored = self.read(completion_path)
            self.check(accepted["version"] == 2 and stored["status"] == "closed" and
                       stored["visibilityState"] == "recent" and stored["visibleUntil"] is not None,
                       "Completed monitoring lacks bounded recent visibility")
            self.check(self.quality("si", close, v2=True)["idempotentReplay"], "Monitoring close cannot recover after a lost reply")
        self.step("deliberate second monitoring completes and closure replays", completed_monitoring)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="demo-crm3-baf-ops")
    parser.add_argument("--emulator-profile", choices=EMULATOR_PROFILES, default="interactive")
    parser.add_argument("--prefix", default=f"hj-{datetime.now(timezone.utc):%Y%m%d%H%M%S}-{uuid.uuid4().hex[:6]}")
    parser.add_argument("--output", type=Path, default=Path("tmp/http-journey/latest.json"))
    parser.add_argument("--groups", default="quality,directives,workflow,authority,inner_covers,burners,templates,inspections,manual_condition,maintenance_cadence", help="Comma-separated scenario groups")
    args = parser.parse_args()
    groups = set(args.groups.split(","))
    supported = {"quality", "directives", "workflow", "authority", "inner_covers", "burners", "templates",
                 "inspections", "manual_condition", "maintenance_cadence", "morning_review"}
    if not groups or groups - supported:
        parser.error(f"Choose groups from: {', '.join(sorted(supported))}")
    journey = Journey(args.project, args.prefix, args.output, emulator_profile=args.emulator_profile)
    try:
        journey.step("isolated Auth sign-in and scoped master fixtures", journey.setup)
        journey.synchronization_journey()
        if "quality" in groups:
            journey.abnormality_journey()
            journey.monitoring_journey()
        if "directives" in groups:
            from http_journey_operations import directives
            directives(journey)
        if "workflow" in groups:
            from http_journey_operations import maintenance_tickets, critical_alarms
            maintenance_tickets(journey)
            critical_alarms(journey)
        if "authority" in groups:
            from http_other_domains import authority
            authority(journey)
        if "inner_covers" in groups:
            from http_other_domains import inner_covers
            inner_covers(journey)
        if "burners" in groups:
            from http_other_domains import burner_rounds
            burner_rounds(journey)
        if "templates" in groups:
            from http_other_domains import templates
            templates(journey)
        if "inspections" in groups:
            from http_journey_operations import inspections
            inspections(journey)
        if "manual_condition" in groups:
            from http_other_domains import manual_condition
            manual_condition(journey)
        if "maintenance_cadence" in groups:
            from http_other_domains import maintenance_cadence
            maintenance_cadence(journey)
        if "morning_review" in groups:
            from http_journey_operations import morning_review
            morning_review(journey)
    except Exception:
        return 1
    print(f"{len(journey.results)} checks passed; report: {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
