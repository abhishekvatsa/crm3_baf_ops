"""Prepare a separate, unpublished DEV draft for fresh phone publication.

Uses the approved SI identity and ordinary Firestore Rules on local emulators.
Existing fixtures are never overwritten; this performs no publication or work.
"""
import json

from http_planned_work_journey import Journey, OUT, PROJECT, actor, draft, require


def main():
    require(PROJECT == "demo-crm3-baf-ops", "Only the fixed DEV project is allowed")
    OUT.mkdir(parents=True, exist_ok=True)
    journey = Journey(PROJECT, "hj-phone-planned-final-fixture", OUT / "phone-final-fixture.json")
    journey.users = {"si": actor("si")}
    package, version = draft(
        journey,
        "dev-usability-planned-final-package",
        "dev-usability-planned-final-version-1",
        "DEV Furnace planned final inspection",
    )
    require(version["status"] == "draft", "The prepared source must remain a draft")
    print(json.dumps({
        "packageId": package["firestoreId"],
        "versionId": version["firestoreId"],
        "title": package["title"],
        "sourceStatus": version["status"],
        "publishedByThisScript": False,
    }, indent=2))
    journey.write_report()


if __name__ == "__main__":
    main()
