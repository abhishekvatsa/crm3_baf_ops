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
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/dev"))
from http_journey import unwire, wire
from http_planned_work_journey import draft
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
