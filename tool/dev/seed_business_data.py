"""Seed the development Firestore emulator with the master data a journey needs.

Setup is administrative on purpose: this writes through the emulator's owner
credential, bypassing Rules, exactly as an administrator or an import would have
created the records. The action under test must still go through the real
screen, the real Rules and the actual callable transport, or the test proves
nothing about the path being investigated.

Every field here is taken from the strict decoder in
lib/features/abnormalities/data/remote_abnormality_reader.dart. That decoder
fails closed, so a seeded document with a missing or mistyped field is rejected
during sync rather than silently ignored.

Requires tool/dev/emulators.ps1 to be running.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
import urllib.parse
from datetime import datetime, timezone

PROJECT = os.environ.get("CRM_DEMO_PROJECT_ID", "demo-crm3-baf-ops")
if not PROJECT.startswith("demo-"):
    raise SystemExit(f"CRM_DEMO_PROJECT_ID must start with 'demo-'. Received: {PROJECT}")

HOST = os.environ.get("CRM_FIRESTORE_EMULATOR", "127.0.0.1:8080")
_endpoint = urllib.parse.urlsplit(f"http://{HOST}")
if (_endpoint.hostname not in {"127.0.0.1", "localhost", "::1"}
        or _endpoint.username or _endpoint.password or _endpoint.path
        or _endpoint.query or _endpoint.fragment or not _endpoint.port):
    raise SystemExit("CRM_FIRESTORE_EMULATOR must be a loopback host:port.")
BASE = f"http://{HOST}/v1/projects/{PROJECT}/databases/(default)/documents"
HEADERS = {"Authorization": "Bearer owner", "Content-Type": "application/json"}

SEED_UID = "seed-administrator"
SEED_NAME = "Seed Administrator"

NOW = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
COMMIT = "5702b8c8e9014316a41c0af37ddc682851af8695"
RECEIPT = "3f036aa0ec39440b02e4a266ac6404b8c6952716f0ef1a8466bade8ec82caedc"


def s(value: str) -> dict:
    return {"stringValue": value}


def b(value: bool) -> dict:
    return {"booleanValue": value}


def i(value: int) -> dict:
    return {"integerValue": str(value)}


def ts(value: str) -> dict:
    return {"timestampValue": value}


def arr(values: list) -> dict:
    return {"arrayValue": {"values": values}}


def put(path: str, fields: dict) -> None:
    """Create or overwrite a document at an exact path."""
    url = f"{BASE}/{path}"
    request = urllib.request.Request(
        url, data=json.dumps({"fields": fields}).encode("utf-8"),
        headers=HEADERS, method="PATCH")
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            response.read()
    except urllib.error.HTTPError as error:
        raise SystemExit(
            f"Seeding {path} failed: {error.code} {error.read().decode('utf-8', 'replace')}"
        ) from error
    except urllib.error.URLError as error:
        raise SystemExit(
            f"Firestore emulator unreachable at {HOST}. Start tool/dev/emulators.ps1 first. {error}"
        ) from error


def abnormality_type(doc_id: str, code: str, title: str, description: str,
                     category: str, severity: str, reannealing: bool) -> dict:
    return {
        # The server checks data.firestoreId == typeId, so it is not decorative.
        "firestoreId": s(doc_id),
        "code": s(code),
        "title": s(title),
        "description": s(description),
        "category": s(category),
        "severity": s(severity),
        # An empty list is valid; the decoder only rejects a non-list or duplicates.
        "applicableAssetTypes": arr([]),
        "suggestsReannealing": b(reannealing),
        "isActive": b(True),
        "isDeleted": b(False),
        "createdAt": ts(NOW),
        "updatedAt": ts(NOW),
        # The decoder requires each actor uid to be paired with a name.
        "createdByUid": s(SEED_UID),
        "createdByName": s(SEED_NAME),
        "lastEditedByUid": s(SEED_UID),
        "lastEditedByName": s(SEED_NAME),
        "version": i(1),
        # The global pull selects documents by this server stamp. A seeded
        # document without it is invisible to the pull even though it exists.
        "_globalPullServerUpdatedAt": ts(NOW),
    }


TYPES = [
    ("seed-type-surface-scale", "SURF-SCALE", "Surface scale on coil",
     "Scale observed on the coil surface after annealing.",
     "resultQuality", "medium", False),
    ("seed-type-coil-stickup", "COIL-STICK", "Coil stick-up",
     "Adjacent laps adhering after the annealing cycle.",
     "process", "high", True),
    ("seed-type-burner-fault", "BURN-FAULT", "Burner fault during cycle",
     "Burner instability observed during the heating cycle.",
     "equipment", "high", False),
]


GLOBAL_PULL_COLLECTIONS = [
    "abnormality_types", "charge_abnormalities", "directives",
    "job_diary_entries", "job_executions", "job_modules", "job_templates",
    "knowledge_base", "maintenance_records", "template_packages",
    "template_publish_audits", "template_versions",
]


def global_pull_contract() -> dict:
    """The runtime contract beginGlobalPullRun requires before it will run.

    requireActiveContract accepts exactly these nine keys - no more, no fewer -
    and compares four of them against constants compiled into the backend. A
    production project has this document; an empty emulator does not, which is
    why the pull returns not-found until it is seeded.
    """
    return {
        "state": s("ACTIVE"),
        "protocolVersion": i(1),
        "protocolFingerprint": s(
            "cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321"),
        "writerVersion": s("global-pull-server-stamp-v1"),
        "serverStampField": s("_globalPullServerUpdatedAt"),
        "collections": arr([s(name) for name in GLOBAL_PULL_COLLECTIONS]),
        # Must not be later than the server anchor, so anchor it in the past.
        "activatedAt": ts("2026-01-01T00:00:00.000000Z"),
        "sourceCommit": s(COMMIT),
        "backfillReceiptSha256": s(RECEIPT),
    }



# ---------------------------------------------------------------------------
# Governed asset register.
#
# The abnormality form refuses to log without at least one governed affected
# asset, and it lists asset CLASSES first. Field names and types below come from
# AssetClassRecord.fromMap and AssetInstanceRecord.fromMap, both of which pin
# schemaVersion to 1 and fail closed on anything unexpected.
# ---------------------------------------------------------------------------

ASSET_CLASS_ID = "seed-class-annealing-furnace"
ASSET_INSTANCE_ID = "seed-asset-furnace-01"


def asset_class() -> dict:
    return {
        "assetClassId": s(ASSET_CLASS_ID),
        "schemaVersion": i(1),
        "code": s("FURN"),
        "name": s("Annealing furnace"),
        "majorArea": s("BAF"),
        "shortDescription": s("Bell annealing furnace"),
        "longDescription": s("Seeded development asset class for the BAF line."),
        # Routes the class onto the AssetType the abnormality form reasons about.
        "legacyAssetTypeKey": s("furnace"),
        "status": s("active"),
        "version": i(1),
        "createdAt": ts(NOW),
        "createdByUid": s(SEED_UID),
        "createdByName": s(SEED_NAME),
        "updatedAt": ts(NOW),
        "updatedByUid": s(SEED_UID),
        "updatedByName": s(SEED_NAME),
        # Required by AssetClassRecord.fromMap; omitting it makes the whole
        # asset register stream fail, which the form reports as "could not be
        # loaded" rather than as a missing field.
        "lastMutationId": s("seed-mutation-0001"),
        "_globalPullServerUpdatedAt": ts(NOW),
    }


def asset_instance() -> dict:
    return {
        "assetInstanceId": s(ASSET_INSTANCE_ID),
        "schemaVersion": i(1),
        "assetClassId": s(ASSET_CLASS_ID),
        "assetClassCode": s("FURN"),
        "assetClassName": s("Annealing furnace"),
        "assetNumber": i(1),
        "name": s("Furnace 01"),
        "plantTag": s("BAF-FURN-01"),
        "location": s("BAF bay 1"),
        "serviceState": s("inService"),
        "ownershipStatus": s("confirmed"),
        "ownerDiscipline": s("operations"),
        "accountableRoleKeys": arr([s("operations")]),
        "status": s("active"),
        "activeComponentCount": i(0),
        "version": i(1),
        "createdAt": ts(NOW),
        "updatedAt": ts(NOW),
        "lastMutationId": s("seed-mutation-0001"),
        "_globalPullServerUpdatedAt": ts(NOW),
    }


def main() -> int:
    put("runtime_contracts/global_pull_v1", global_pull_contract())
    print("  seeded runtime_contracts/global_pull_v1  [ACTIVE]")
    put(f"asset_classes/{ASSET_CLASS_ID}", asset_class())
    print(f"  seeded asset_classes/{ASSET_CLASS_ID}  [FURN] Annealing furnace")
    put(f"asset_instances/{ASSET_INSTANCE_ID}", asset_instance())
    print(f"  seeded asset_instances/{ASSET_INSTANCE_ID}  Furnace 01")

    for doc_id, code, title, description, category, severity, reannealing in TYPES:
        put(f"abnormality_types/{doc_id}",
            abnormality_type(doc_id, code, title, description,
                             category, severity, reannealing))
        print(f"  seeded abnormality_types/{doc_id}  [{code}] {title}")

    request = urllib.request.Request(f"{BASE}/abnormality_types", headers=HEADERS)
    with urllib.request.urlopen(request, timeout=15) as response:
        documents = json.load(response).get("documents", [])
    active = [d for d in documents
              if d.get("fields", {}).get("isActive", {}).get("booleanValue")]
    print(f"\nabnormality_types in the emulator: {len(documents)} "
          f"({len(active)} active)")
    if len(active) < len(TYPES):
        print("Seeding did not produce the expected active types.", file=sys.stderr)
        return 1
    print("\nThe app pulls these into Isar through its ordinary sync; "
          "getActiveTypes() reads the local box, not Firestore.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
