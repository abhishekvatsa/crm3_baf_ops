"""Preserve and unreview the single malformed draft created by the DEV phone test."""
import json
from pathlib import Path
from http_journey import Journey, instant, unwire, wire
from http_planned_work_journey import content_hash
from seed_usability_phone_fixture import PROJECT, actor, require

DOC = "CIAb5zVyHPQ352VP55yu"
OUT = Path("output/dev-planned-validation-20260927/review-fixture-repair")
require(PROJECT == "demo-crm3-baf-ops", "Fixed local demo project only")
j = Journey(PROJECT, "hj-planned-review-repair", OUT / "journey.json")
j.users = {"si": actor("si")}
token = j.users["si"]["token"]
path = "template_versions/" + DOC
raw = j.http("GET", j.fs + "/" + path, token=token)
record = {k: unwire(v) for k, v in raw["fields"].items()}
require(record["packageFirestoreId"] == "dev-usability-planned-package" and record.get("sourceVersionFirestoreId") == "dev-usability-planned-version-1", "Not our phone artifact")
require(record["status"] == "draft" and not record.get("isDeleted") and not record.get("publishedAt") and not record.get("publishedByUid"), "Never change published or deleted evidence")
package = j.read("template_packages/dev-usability-planned-package", "si")
require(package.get("activeVersionFirestoreId") != DOC, "Package points at this version")
evidence = {"package": package}
for collection, field in [("job_executions", "templateVersionId"), ("template_publish_audits", "versionFirestoreId")]:
    found = j.http("POST", j.fs + ":runQuery", {"structuredQuery": {"from": [{"collectionId": collection}], "where": {"fieldFilter": {"field": {"fieldPath": field}, "op": "EQUAL", "value": {"stringValue": DOC}}}}}, token)
    evidence[collection] = found
    require(not any("document" in row for row in found), "Artifact has business linkage")
OUT.mkdir(parents=True, exist_ok=True)
before = OUT / "original-firestore-document.json"
if not before.exists():
    before.write_text(json.dumps(raw, indent=2) + "\n")
(OUT / "linkage-checks.json").write_text(json.dumps(evidence, indent=2) + "\n")
job = json.loads(record["jobTemplateSnapshotJson"])
composer = job.get("composer", {})
if record.get("closureReviewConfirmed") is False and not record.get("closureReviewConfirmedAt") and composer.get("closureReviewConfirmed") is False:
    print("Already explicitly unreviewed; no update performed")
else:
    require(record["closureReviewConfirmedAt"] < record["createdAt"], "Refuse to clear valid review")
    composer["closureReviewConfirmed"] = False
    for field in ["closureReviewConfirmedByUid", "closureReviewConfirmedByName", "closureReviewConfirmedAt"]:
        composer.pop(field, None)
    job["composer"] = composer
    patch = {"jobTemplateSnapshotJson": json.dumps(job, separators=(",", ":")), "closureReviewConfirmed": False,
             "closureReviewConfirmedByUid": None, "closureReviewConfirmedByName": None, "closureReviewConfirmedAt": None,
             "version": record["version"] + 1, "updatedAt": instant(), "updatedByUid": j.users["si"]["uid"], "updatedByName": j.users["si"]["name"]}
    patch["contentHash"] = content_hash({**record, **patch})
    commit = j.http("POST", j.fs + ":commit", {"writes": [{
        "update": {"name": raw["name"], "fields": {k: wire(v) for k, v in patch.items()}},
        "updateMask": {"fieldPaths": list(patch)},
        "currentDocument": {"updateTime": raw["updateTime"]},
    }]}, token)
    (OUT / "write-acceptance.json").write_text(json.dumps(commit, indent=2) + "\n")
    after = j.http("GET", j.fs + "/" + path, token=token)
    (OUT / "applied-fields.json").write_text(json.dumps(patch, indent=2) + "\n")
    (OUT / "after-firestore-document.json").write_text(json.dumps(after, indent=2) + "\n")
    readback = j.read(path, "si")
    unchanged = set(record) - set(patch) - {"_globalPullServerUpdatedAt"}
    require(all(readback.get(k) == record[k] for k in unchanged), "Unexpected evidence mutation")
    (OUT / "readback.json").write_text(json.dumps(readback, indent=2) + "\n")
    print(json.dumps({"project": PROJECT, "draftId": DOC, "fieldsUpdated": list(patch), "status": readback["status"], "reviewed": readback["closureReviewConfirmed"], "version": readback["version"]}))
