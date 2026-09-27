"""Add two DEV report Bases and an actually accepted/installed Inner Cover.

Fixed demo project and literal loopback only. Existing fixture documents are
verified, never overwritten. Physical lifecycle changes use authenticated V2
callables; this script does not manufacture installation evidence.
"""
from datetime import datetime, timezone
from pathlib import Path
import json
import uuid

from seed_usability_phone_fixture import actor, read, request, require, FS, PROJECT
from http_journey import Journey, complete_asset_fixture, wire

PREFIX = "dev-usability-"
BASE_CLASS = PREFIX + "base-class"
COVER_CLASS = PREFIX + "inner-cover-class"
BASE_LINKED = PREFIX + "base-901"
BASE_UNRECORDED = PREFIX + "base-902"
SERIAL = "DEV-USABILITY-IC-901"
OUT = Path("output/dev-usability-20260926/base-report-fixture.json")


def identity(label):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, PREFIX + "base-report:" + label))


def create_only(path, fields, admin):
    require(path.split("/")[-1].startswith(PREFIX), "Unscoped fixture path")
    fields = complete_asset_fixture(path.split("/")[0], fields, admin)
    existing = read(path)
    if existing is None:
        request("PATCH", FS + "/" + path + "?currentDocument.exists=false",
                {"fields": {k: wire(v) for k, v in fields.items()}}, token="owner")
        existing = read(path)
    ignored = {"createdAt", "updatedAt", "lastMutationId"}
    require(all(existing.get(k) == v for k, v in fields.items() if k not in ignored),
            "Existing fixture differs; refusing overwrite: " + path)


def main():
    require(PROJECT == "demo-crm3-baf-ops", "Fixed demo project required")
    admin = actor("admin")
    j = Journey(PROJECT, "hj-usability-base-report", OUT)
    j.users = {"admin": admin}
    now = datetime.now(timezone.utc)
    for class_id, key, name, code in [
        (BASE_CLASS, "base", "DEV report Base", "DEVBASE"),
        (COVER_CLASS, "innerCover", "DEV report Inner Cover", "DEVIC")]:
        create_only("asset_classes/" + class_id, {
            "schemaVersion": 1, "assetClassId": class_id, "code": code,
            "name": name, "legacyAssetTypeKey": key, "status": "active",
            "createdAt": now, "updatedAt": now}, admin)
        j.fixture_paths.append("asset_classes/" + class_id)
    for base_id, number in [(BASE_LINKED, 901), (BASE_UNRECORDED, 902)]:
        create_only("asset_instances/" + base_id, {
            "schemaVersion": 1, "assetInstanceId": base_id,
            "assetClassId": BASE_CLASS, "assetClassCode": "DEVBASE",
            "assetClassName": "DEV report Base", "assetNumber": number,
            "name": f"DEV Base {number}", "status": "active",
            "createdByUid": admin["uid"], "createdByName": admin["name"],
            "updatedByUid": admin["uid"], "updatedByName": admin["name"],
            "createdAt": now, "updatedAt": now}, admin)
        j.fixture_paths.append("asset_instances/" + base_id)

    cover_id = identity("cover")
    path = "inner_cover_profiles/" + cover_id
    j.business_paths.extend([path, "base_inner_cover_assignments/" + BASE_LINKED])
    commands = [
        {"requestId": identity("register"), "operation": "REGISTER_INNER_COVER",
         "innerCoverId": cover_id, "innerCoverAssetClassId": COVER_CLASS,
         "reason": "DEV report fixture: register the documented example cover.",
         "registrationDraft": {"serialNumber": SERIAL, "sourceType": "purchased",
             "originClassification": "documentedPurchase", "supplierOrFabricator": "DEV fixture supplier",
             "receivedOrCompletedOn": "2026-09-23T06:00:00.000Z",
             "incorporatedOn": "2026-09-24T06:00:00.000Z", "drawingReference": "DEV-IC-901",
             "materialGrade": "SS 321", "notes": "Explicit DEV report example", "fabricationSections": []}},
        {"requestId": identity("accept"), "operation": "ACCEPT_INNER_COVER",
         "innerCoverId": cover_id, "expectedVersion": 1,
         "reason": "DEV report fixture: reviewed example inspection and leak-test evidence.",
         "acceptanceDraft": {"inspectedOn": "2026-09-25T06:00:00.000Z",
             "acceptanceReference": "DEV-USABILITY-INSPECTION-901",
             "leakTestReference": "DEV-USABILITY-LEAK-901", "ndtReference": None, "notes": None}},
        {"requestId": identity("link"), "operation": "LINK_INNER_COVER",
         "innerCoverId": cover_id, "expectedVersion": 2,
         "targetBaseAssetInstanceId": BASE_LINKED,
         "reason": "DEV report fixture: install the accepted example on DEV Base 901."}]
    for command in commands:
        j.step(command["operation"], lambda command=command:
               j.call("admin", "mutateAssetHierarchyV2", command, v2=True))

    def verify():
        profile = j.read(path, "admin")
        assignment = j.read("base_inner_cover_assignments/" + BASE_LINKED, "admin")
        linkage_path = "inner_cover_linkages/" + profile["currentLinkageId"]
        j.business_paths.append(linkage_path)
        linkage = j.read(linkage_path, "admin")
        j.check(profile["serialNumber"] == SERIAL and profile["version"] == 3 and
                profile["lifecycleState"] == "installed" and profile["currentBaseAssetInstanceId"] == BASE_LINKED and
                assignment["innerCoverId"] == cover_id and linkage["active"] is True and
                linkage["innerCoverId"] == cover_id and linkage["baseAssetInstanceId"] == BASE_LINKED,
                "Profile/assignment/linkage evidence disagrees")
        j.check(j.read("base_inner_cover_assignments/" + BASE_UNRECORDED, "admin") is None,
                "Base 902 unexpectedly has recorded linkage")
        for command in commands:
            audit = j.read("inner_cover_lifecycle_audits/inner_cover_" + command["requestId"], "admin")
            j.check(audit is not None, "Missing lifecycle audit")
        summary = {"project": PROJECT, "baseClassId": BASE_CLASS, "innerCoverClassId": COVER_CLASS,
                   "linkedBaseId": BASE_LINKED, "linkedBaseNumber": 901,
                   "unrecordedBaseId": BASE_UNRECORDED, "unrecordedBaseNumber": 902,
                   "innerCoverId": cover_id, "serial": SERIAL, "linkageId": profile["currentLinkageId"]}
        OUT.with_name("base-report-fixture-identities.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary, indent=2))
    j.step("Persisted readable installation, original audits, and absent Base 902 linkage", verify)


if __name__ == "__main__":
    main()
