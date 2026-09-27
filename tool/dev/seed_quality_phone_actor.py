"""Create/reuse one verified SI identity in the local development emulators.

Run with Python while tool/dev/emulators.ps1 is running. This is administrative
fixture setup, not a business action or a production approval mechanism. Only
the dedicated Auth account and its complete users/{uid} profile may be created;
existing identities/profiles are verified, never repaired or overwritten.
"""

from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

PROJECT = "demo-crm3-baf-ops"
EMAIL = "dev.quality-si@example.invalid"
PASSWORD = "emulator-local-only"
DISPLAY = "Dev Quality SI"
AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1"
FS = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Emulator redirects are not permitted")


def request(method, url, data=None, token="owner", missing_ok=False):
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1"
            or parsed.port not in (9099, 8080) or parsed.username or parsed.password
            or not (url.startswith(AUTH + "/") or url.startswith(FS + "/")
                    or url == FS + ":runQuery")):
        raise RuntimeError("Only the fixed literal-loopback demo emulator URLs are permitted")
    headers = {"Content-Type": "application/json"}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, method=method, headers=headers,
                                 data=None if data is None else json.dumps(data).encode())
    try:
        # Do not allow environment proxy settings to forward local credentials.
        with urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()).open(
                req, timeout=15) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            return None
        # Never emit an Auth response body (it can contain session credentials).
        raise RuntimeError(f"Local emulator request failed with HTTP {error.code}") from None


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def validate_account(account):
    require(account.get("email") == EMAIL and account.get("displayName") == DISPLAY
            and account.get("emailVerified") is True and not account.get("disabled", False)
            and isinstance(account.get("localId"), str) and account["localId"]
            and "/" not in account["localId"],
            "Existing Auth account has an unexpected identity or verification state; refusing changes")
    require(not account.get("tenantId") and not account.get("phoneNumber")
            and not account.get("mfaInfo") and account.get("customAttributes", "{}") in ("{}", ""),
            "Existing Auth account has unexpected identity claims; refusing changes")
    for provider in account.get("providerUserInfo", []):
        require(provider.get("providerId") == "password" and provider.get("email") == EMAIL,
                "Existing Auth account has an unexpected linked provider; refusing changes")


def validate_profile(doc, uid):
    require(doc.get("name") == f"projects/{PROJECT}/databases/(default)/documents/users/{uid}",
            "Existing profile has an unexpected identity; refusing changes")
    fields = doc.get("fields", {})
    expected = {"name": {"stringValue": DISPLAY}, "email": {"stringValue": EMAIL},
                "roles": {"arrayValue": {"values": [{"stringValue": "si"}]}},
                "isApproved": {"booleanValue": True},
                "accessDisposition": {"stringValue": "approved"}}
    require(all(fields.get(key) == value for key, value in expected.items()),
            "Existing profile has unexpected identity, approval, or roles; refusing changes")
    require(set(fields) <= {"name", "email", "roles", "isApproved", "accessDisposition",
                           "authorityRevision", "createdAt", "photoUrl", "fcmToken",
                           "lastAuthorityDecision"},
            "Existing profile contains unsupported fields; refusing changes")
    created = fields.get("createdAt", {}).get("timestampValue")
    require(isinstance(created, str), "Existing profile lacks its required creation timestamp")
    datetime.fromisoformat(created.replace("Z", "+00:00"))
    revision = fields.get("authorityRevision", {}).get("integerValue")
    require(isinstance(revision, str) and revision.isdigit(),
            "Existing profile lacks a valid authority revision")
    for field in ("photoUrl", "fcmToken"):
        value = fields.get(field, {"nullValue": None})
        require("nullValue" in value or isinstance(value.get("stringValue"), str),
                f"Existing profile has an invalid {field}")


def main():
    require(os.environ.get("CRM_DEMO_PROJECT_ID", PROJECT) == PROJECT,
            f"This fixture supports only {PROJECT}")
    accounts = request("POST", f"{AUTH}/projects/{PROJECT}/accounts:lookup",
                       {"email": [EMAIL]}).get("users", [])
    require(len(accounts) <= 1, "Multiple matching Auth identities; refusing changes")
    matches = request("POST", FS + ":runQuery", {"structuredQuery": {
        "from": [{"collectionId": "users"}],
        "where": {"fieldFilter": {"field": {"fieldPath": "email"}, "op": "EQUAL",
                                  "value": {"stringValue": EMAIL}}}}})
    profiles = [row["document"] for row in matches if "document" in row]
    require(len(profiles) <= 1, "Multiple matching user profiles; refusing changes")
    if accounts:
        account = accounts[0]
        validate_account(account)
        uid = account["localId"]
        profile = request("GET", f"{FS}/users/{urllib.parse.quote(uid, safe='')}", missing_ok=True)
        if profile:
            validate_profile(profile, uid)
        if profiles:
            validate_profile(profiles[0], uid)
            require(profile is not None, "Matching profile does not belong to this Auth identity")
        account_action = "reused"
    else:
        require(not profiles, "An orphaned matching profile exists; refusing to create another identity")
        account = request("POST", f"{AUTH}/accounts:signUp?key=emulator", {
            "targetProjectId": PROJECT, "email": EMAIL, "password": PASSWORD,
            "displayName": DISPLAY, "emailVerified": True})
        uid, profile, account_action = account["localId"], None, "created"
        validate_account(request("POST", f"{AUTH}/projects/{PROJECT}/accounts:lookup",
                                 {"localId": [uid]})["users"][0])

    # Verify the configured password without replacing an existing password.
    signed = request("POST", f"{AUTH}/accounts:signInWithPassword?key=emulator", {
        "targetProjectId": PROJECT, "email": EMAIL, "password": PASSWORD,
        "returnSecureToken": True})
    token = signed["idToken"]
    payload = token.split(".")[1]
    claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
    require(signed.get("localId") == uid and claims.get("aud") == PROJECT
            and claims.get("email") == EMAIL and claims.get("email_verified") is True,
            "Password sign-in returned an unexpected identity or project")
    profile_action = "reused"
    if profile is None:
        fields = {"name": {"stringValue": DISPLAY}, "email": {"stringValue": EMAIL},
                  "photoUrl": {"nullValue": None}, "fcmToken": {"nullValue": None},
                  "roles": {"arrayValue": {"values": [{"stringValue": "si"}]}},
                  "isApproved": {"booleanValue": True},
                  "authorityRevision": {"integerValue": "0"},
                  "accessDisposition": {"stringValue": "approved"},
                  "createdAt": {"timestampValue": datetime.now(timezone.utc).isoformat()}}
        # Precondition prevents a concurrent app/admin write from being replaced.
        request("PATCH", f"{FS}/users/{urllib.parse.quote(uid, safe='')}?currentDocument.exists=false",
                {"fields": fields})
        profile_action = "created"
    validate_profile(request("GET", f"{FS}/users/{urllib.parse.quote(uid, safe='')}", token=token), uid)
    print(json.dumps({"project": PROJECT, "email": EMAIL, "uid": uid,
                      "emailVerified": True, "roles": ["si"], "isApproved": True,
                      "account": account_action, "profile": profile_action,
                      "passwordSignIn": "verified", "profileRulesRead": "verified"}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, KeyError, urllib.error.URLError) as error:
        print(f"Quality SI fixture refused: {error}", file=sys.stderr)
        sys.exit(1)
