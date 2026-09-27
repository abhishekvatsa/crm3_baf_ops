"""Authenticated, additive DEV Rules proof for immutable creation-time custody.

Only uniquely prefixed synthetic packages are written. No actual phone fixture,
publication, assignment, production endpoint, owner token or Rules override.
"""
import json
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from http_journey import HttpFailure, Journey, instant, wire
from seed_usability_phone_fixture import PROJECT, actor, require


def main():
    require(PROJECT == "demo-crm3-baf-ops", "Fixed local demo project only")
    prefix = "hj-package-time-" + uuid.uuid4().hex[:12]
    out = Path("output/dev-planned-validation-20260927/package-timestamp-rules") / prefix
    j = Journey(PROJECT, prefix, out / "report.json")
    si = actor("si")
    results = []
    out.mkdir(parents=True, exist_ok=False)

    def read(doc):
        require(doc.startswith(prefix + "-"), "Unscoped package identity")
        return j.http("GET", j.fs + "/template_packages/" + doc, token=si["token"])

    def commit(doc, fields, *, current):
        require(doc.startswith(prefix + "-"), "Unscoped package identity")
        return j.http("POST", j.fs + ":commit", {"writes": [{
            "update": {"name": f"projects/{PROJECT}/databases/(default)/documents/template_packages/{doc}",
                       "fields": fields},
            "updateMask": {"fieldPaths": list(fields)},
            "currentDocument": current,
        }]}, si["token"])

    def refused(doc, fields, before, label):
        try:
            commit(doc, fields, current={"updateTime": before["updateTime"]})
        except HttpFailure as error:
            require(error.code == "PERMISSION_DENIED", "Unexpected refusal")
        else:
            raise AssertionError("Forbidden creation-time edit unexpectedly accepted")
        after = read(doc)
        require(after["fields"] == before["fields"], "Rejected write changed evidence")
        require(after["updateTime"] == before["updateTime"], "Rejected write changed revision")
        results.append({"case": label, "status": "passed", "docId": doc,
                        "submittedCreatedAt": fields["createdAt"],
                        "retainedCreatedAt": after["fields"]["createdAt"]})

    created = datetime(2026, 9, 26, 19, 14, 1, 887000, tzinfo=timezone.utc)
    local_iso = created.astimezone(timezone(timedelta(hours=5, minutes=30))).replace(tzinfo=None).isoformat(timespec="milliseconds")
    for encoding in ["utc-string", "native-timestamp"]:
        doc = prefix + "-" + encoding
        original = created.isoformat(timespec="milliseconds").replace("+00:00", "Z") if encoding == "utc-string" else created
        package = {
            "schemaVersion": 1, "version": 1, "isDeleted": False,
            "firestoreId": doc, "packageCode": "DEV-TIMESTAMP-PROBE",
            "title": "DEV synthetic timestamp Rules probe",
            "description": "Isolated authorization test; never assigned or published.",
            "assetType": "furnace", "assetNumberScope": None,
            "disciplineScope": "mechanical", "lifecycleStatus": "active",
            "activeVersionFirestoreId": None, "latestVersionNumber": 0,
            "createdByUid": si["uid"], "createdByName": si["name"],
            "updatedByUid": si["uid"], "updatedByName": si["name"],
            "createdAt": original, "updatedAt": instant(),
            "retiredByUid": None, "retiredByName": None, "retiredAt": None, "retireReason": None,
            "deletedAt": None, "deletedByUid": None, "deletedByName": None, "deleteReason": None,
            "targetRefs": [], "deviceTagRefs": [], "procedureRefs": [], "operationalStatePreconditions": [],
            "metadataJson": None,
        }
        commit(doc, {k: wire(v) for k, v in package.items()}, current={"exists": False})
        # Read after the asynchronous server clock stamp settles before asserting
        # zero writes for rejected candidates; preserve both raw encodings.
        import time
        time.sleep(0.3)
        before = read(doc)
        (out / (encoding + "-before.json")).write_text(json.dumps(before, indent=2) + "\n")
        update = {"version": wire(2), "updatedAt": wire(instant()),
                  "updatedByUid": wire(si["uid"]), "updatedByName": wire(si["name"]),
                  "title": wire("DEV timestamp custody verified"), "createdAt": wire(local_iso)}
        refused(doc, update, before, encoding + ": equivalent local ISO is refused")
        update["createdAt"] = before["fields"]["createdAt"]
        commit(doc, update, current={"updateTime": before["updateTime"]})
        time.sleep(0.3)
        accepted = read(doc)
        require(accepted["fields"]["createdAt"] == before["fields"]["createdAt"], "Creation encoding changed")
        require(accepted["fields"]["version"] == wire(2), "Update not accepted")
        results.append({"case": encoding + ": original wire encoding accepted", "status": "passed", "docId": doc,
                        "retainedCreatedAt": accepted["fields"]["createdAt"]})
        update["version"] = wire(3)
        update["createdAt"] = wire(created + timedelta(seconds=1))
        refused(doc, update, accepted, encoding + ": different creation instant is refused")
        (out / (encoding + "-after.json")).write_text(json.dumps(read(doc), indent=2) + "\n")
    report = {"project": PROJECT, "transport": "actual Auth + Firestore Rules HTTP", "prefix": prefix,
              "passed": len(results), "failed": 0, "results": results}
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": len(results), "failed": 0, "report": str(out / "report.json")}))


if __name__ == "__main__":
    main()
