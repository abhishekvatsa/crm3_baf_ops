"""Additional real callable HTTP journeys for the isolated dev harness.

Only Journey's loopback/demo transport is used. Administrative setup names are
run-prefixed; protocol-required UUIDs are derived from that unique run prefix.
Business results are read back from Firestore rather than assumed from success.
"""

from __future__ import annotations

import copy
import hashlib
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from http_journey import Journey


def _id(j: Journey, label: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"{j.prefix}:{label}"))


def _at(delta: timedelta = timedelta()) -> str:
    return (datetime.now(timezone.utc) + delta).isoformat(
        timespec="milliseconds").replace("+00:00", "Z")


def _digest(approved: bool, roles: list[str]) -> str:
    # Exact canonical capsule from functions/src/userAuthority.ts.
    canonical = json.dumps({"isApproved": approved, "roles": sorted(set(roles))},
                           separators=(",", ":"))
    return "auth1-sha256:" + hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def authority(j: Journey) -> None:
    """Revoke and restore only this run's user, preserving revision and work."""
    target = j.users["operations"]["uid"]
    path = f"users/{target}"
    j.business_paths.append(path)
    reviewed = j.read(path)
    revision = reviewed.get("authorityRevision", 0)
    roles = reviewed["roles"]

    def request(label, operation, approved, version):
        return {"requestId": _id(j, label), "targetUid": target,
                "operation": operation,
                "expectedAuthorityDigest": _digest(approved, roles),
                "expectedAuthorityRevision": version,
                "reason": f"{j.prefix}: reviewed {operation.lower()} for HTTP access validation."}

    revoke = request("authority-revoke", "REVOKE", True, revision)
    stale = request("authority-stale-revoke", "REVOKE", True, revision)
    restore = request("authority-restore", "APPROVE", False, revision + 1)
    audit_path = f"audit_logs/server_authority_{revoke['requestId']}"
    receipt_path = f"user_authority_mutation_receipts/{revoke['requestId']}"
    j.business_paths.extend([audit_path, receipt_path])

    j.step("HTTP authority refuses Operations changing user approval", lambda: j.refuse(
        lambda: j.call("operations", "mutateUserAuthority", revoke, v2=True),
        ("PERMISSION_DENIED",), (path, audit_path, receipt_path)))

    def revoke_and_read():
        accepted = j.call("admin", "mutateUserAuthority", revoke, v2=True)
        stored = j.read(path, "admin")
        j.check(accepted["authorityRevision"] == revision + 1 and
                stored["isApproved"] is False and stored["roles"] == roles and
                stored["accessDisposition"] == "revoked", "Revocation did not preserve reviewed identity/roles")
        audit = j.read(audit_path)
        j.check(audit["reasonNotes"] == revoke["reason"] and j.read(receipt_path) is not None,
                "Authority decision lacks atomic reason/audit/receipt")
    j.step("HTTP Admin revokes access with retained roles and audited reason", revoke_and_read)

    j.step("HTTP revoked user cannot obtain an operational pull clock", lambda: j.refuse(
        lambda: j.call("operations", "beginGlobalPullRun", {}), ("PERMISSION_DENIED",), (path,)))
    j.step("HTTP revoked user cannot restore own access", lambda: j.refuse(
        lambda: j.call("operations", "mutateUserAuthority", restore, v2=True),
        ("PERMISSION_DENIED",), (path,)))

    def restore_and_read():
        accepted = j.call("admin", "mutateUserAuthority", restore, v2=True)
        stored = j.read(path, "operations")
        j.check(accepted["authorityRevision"] == revision + 2 and
                stored["authorityRevision"] == revision + 2 and
                stored["isApproved"] is True and stored["roles"] == roles and
                stored["accessDisposition"] == "approved",
                "Reviewed restoration did not advance authority or retain roles")
        j.check(stored["lastAuthorityDecision"]["reason"] == restore["reason"],
                "Restoration did not retain its independent review reason")
        clock = j.call("operations", "beginGlobalPullRun", {})
        j.check(clock["actorUid"] == target, "Restored authority cannot reach normal operational transport")
    j.step("HTTP reviewed Admin restoration reopens access without deleting identity", restore_and_read)

    j.step("HTTP stale approval capsule cannot cross a revoke and regrant cycle", lambda: j.refuse(
        lambda: j.call("admin", "mutateUserAuthority", stale, v2=True),
        ("ABORTED", "FAILED_PRECONDITION"), (path,)))

    def replay_history():
        before = j.read(path)
        replay = j.call("admin", "mutateUserAuthority", revoke, v2=True)
        j.check(replay["idempotentReplay"] and replay["isApproved"] is False and
                replay["authorityRevision"] == revision + 1 and
                replay["currentAuthorityRevision"] == revision + 2 and
                replay["supersededByLaterChange"], "Replay lost original or later authority evidence")
        after = j.read(path)
        before.pop("_globalPullServerUpdatedAt", None)
        after.pop("_globalPullServerUpdatedAt", None)
        j.check(before == after, "Historical replay reapplied revocation to the restored user")
    j.step("HTTP historical revoke replay preserves later restoration", replay_history)


def inner_covers(j: Journey) -> None:
    """Register, accept, install, return and reinspect through actual onCall."""
    class_id = f"{j.prefix}-inner-cover-class"
    base_id = f"{j.prefix}-inner-cover-base"
    cover_id = _id(j, "inner-cover")
    serial = f"HJ{uuid.UUID(cover_id).hex[:20].upper()}"
    at = datetime.now(timezone.utc)
    actor = j.users["admin"]
    j.seed(f"asset_classes/{class_id}", {
        "schemaVersion": 1, "assetClassId": class_id, "code": "HJIC",
        "name": f"HTTP Inner Cover {j.prefix}", "legacyAssetTypeKey": "innerCover",
        "status": "active", "majorArea": "BAF", "shortDescription": None,
        "longDescription": None, "version": 1, "createdAt": at, "updatedAt": at,
        "createdByUid": actor["uid"], "createdByName": actor["name"],
        "updatedByUid": actor["uid"], "updatedByName": actor["name"],
        "lastMutationId": _id(j, "inner-class-fixture")})
    base = copy.deepcopy(j.read(f"asset_instances/{j.base_id}"))
    base.update({"assetInstanceId": base_id, "assetNumber": 207,
                 "name": f"HTTP Base 207 {j.prefix}"})
    base.pop("_globalPullServerUpdatedAt", None)
    j.seed(f"asset_instances/{base_id}", base)

    profile_path = f"inner_cover_profiles/{cover_id}"
    assignment_path = f"base_inner_cover_assignments/{base_id}"
    j.business_paths.extend([profile_path, assignment_path])
    register = {"requestId": _id(j, "inner-register"), "operation": "REGISTER_INNER_COVER",
                "innerCoverId": cover_id, "innerCoverAssetClassId": class_id,
                "reason": f"{j.prefix}: register documented physical cover for HTTP validation.",
                "registrationDraft": {"serialNumber": serial, "sourceType": "purchased",
                    "originClassification": "documentedPurchase", "supplierOrFabricator": "Dev supplier",
                    "receivedOrCompletedOn": _at(timedelta(days=-3)),
                    "incorporatedOn": _at(timedelta(days=-2)), "drawingReference": "HTTP-IC-001",
                    "materialGrade": "SS 321", "notes": None, "fabricationSections": []}}
    accept = {"requestId": _id(j, "inner-accept"), "operation": "ACCEPT_INNER_COVER",
              "innerCoverId": cover_id, "expectedVersion": 1,
              "reason": f"{j.prefix}: reviewed inspection and leak-test evidence.",
              "acceptanceDraft": {"inspectedOn": _at(timedelta(days=-1)),
                  "acceptanceReference": f"{j.prefix}-inspection-1",
                  "leakTestReference": f"{j.prefix}-leak-1", "ndtReference": None, "notes": None}}
    link = {"requestId": _id(j, "inner-link"), "operation": "LINK_INNER_COVER",
            "innerCoverId": cover_id, "expectedVersion": 2,
            "targetBaseAssetInstanceId": base_id,
            "reason": f"{j.prefix}: install the accepted cover on the reviewed Base."}

    def call(request, actor_name="admin"):
        return j.call(actor_name, "mutateAssetHierarchyV2", request, v2=True)

    j.step("HTTP Operations cannot register an Inner Cover", lambda: j.refuse(
        lambda: call(register, "operations"), ("PERMISSION_DENIED",), (profile_path,)))

    def register_and_read():
        result = call(register)
        stored = j.read(profile_path, "operations")
        j.check(result["version"] == 1 and stored["lifecycleState"] == "awaitingInspection" and
                stored["serialNumber"] == serial, "Newly registered cover falsely entered service")
    j.step("HTTP registration creates a readable awaiting-inspection serial cover", register_and_read)

    def accept_and_read():
        call(accept)
        stored = j.read(profile_path, "operations")
        j.check(stored["version"] == 2 and stored["lifecycleState"] == "available" and
                stored["acceptanceReference"] == accept["acceptanceDraft"]["acceptanceReference"],
                "Acceptance did not retain physical inspection evidence")
    j.step("HTTP inspection acceptance admits the registered serial into the available pool", accept_and_read)

    linkage_path = ""
    def install_and_read():
        nonlocal linkage_path
        call(link)
        profile = j.read(profile_path, "operations")
        assignment = j.read(assignment_path)
        linkage_path = f"inner_cover_linkages/{profile['currentLinkageId']}"
        j.business_paths.append(linkage_path)
        linkage = j.read(linkage_path)
        j.check(profile["version"] == 3 and profile["lifecycleState"] == "installed" and
                profile["currentBaseAssetInstanceId"] == base_id and
                assignment["innerCoverId"] == cover_id and linkage["innerCoverId"] == cover_id and
                linkage["baseAssetInstanceId"] == base_id and linkage["active"] is True,
                "Installation failed the profile/Base/linkage custody triangle")
    j.step("HTTP installation persists consistent serial Base and linkage custody", install_and_read)

    def replay_after_install():
        replay = call(accept)
        j.check(replay["idempotentReplay"] and replay["version"] == 2 and
                j.read(profile_path)["version"] == 3 and
                j.read(profile_path)["lifecycleState"] == "installed",
                "Acceptance replay overwrote later physical installation")
    j.step("HTTP original acceptance replay preserves the later installation", replay_after_install)

    delink = {"requestId": _id(j, "inner-delink"), "operation": "DELINK_INNER_COVER",
              "innerCoverId": cover_id, "expectedVersion": 3,
              "sourceBaseAssetInstanceId": base_id, "expectedSourceAssignmentVersion": 1,
              "targetState": "awaitingInspection", "physicalEventAt": _at(),
              "reason": f"{j.prefix}: physically remove the cover for inspection after service."}
    def return_for_inspection():
        call(delink)
        stored = j.read(profile_path, "operations")
        linkage = j.read(linkage_path)
        j.check(stored["version"] == 4 and stored["lifecycleState"] == "awaitingInspection" and
                stored["currentBaseAssetInstanceId"] is None and
                stored["assuranceInvalidatedAt"] is not None and linkage["active"] is False,
                "Return failed to close physical custody and invalidate old assurance")
    j.step("HTTP physical removal ends custody and invalidates the previous assurance", return_for_inspection)

    old_inspection = copy.deepcopy(accept)
    old_inspection.update({"requestId": _id(j, "inner-stale-inspection"), "expectedVersion": 4})
    j.step("HTTP reacceptance refuses inspection evidence from before the return", lambda: j.refuse(
        lambda: call(old_inspection), ("FAILED_PRECONDITION",), (profile_path,)))

    def reinspection():
        fresh = copy.deepcopy(accept)
        fresh.update({"requestId": _id(j, "inner-reinspect"), "expectedVersion": 4})
        fresh["acceptanceDraft"].update({"inspectedOn": _at(),
                                        "acceptanceReference": f"{j.prefix}-inspection-2"})
        result = call(fresh)
        stored = j.read(profile_path, "operations")
        j.check(result["version"] == 5 and stored["lifecycleState"] == "available" and
                stored["acceptanceReference"] == fresh["acceptanceDraft"]["acceptanceReference"],
                "New physical inspection did not establish a fresh assurance episode")
        old_audit = j.read(f"inner_cover_lifecycle_audits/inner_cover_{accept['requestId']}")
        j.check(old_audit is not None, "Reinspection erased original acceptance audit")
    j.step("HTTP fresh reinspection restores availability and retains original audit", reinspection)


def burner_rounds(j: Journey) -> None:
    """Exercise full and partial observation provenance with a stale competitor."""
    class_id, asset_id = f"{j.prefix}-furnace-class", f"{j.prefix}-furnace-26"
    furnace_class = copy.deepcopy(j.read(f"asset_classes/{j.class_id}"))
    furnace_class.update({"assetClassId": class_id, "code": "HJFURN",
                          "name": f"HTTP Furnace {j.prefix}", "legacyAssetTypeKey": "furnace"})
    furnace_class.pop("_globalPullServerUpdatedAt", None)
    j.seed(f"asset_classes/{class_id}", furnace_class)
    furnace = copy.deepcopy(j.read(f"asset_instances/{j.base_id}"))
    furnace.update({"assetInstanceId": asset_id, "assetClassId": class_id,
                    "assetClassCode": "HJFURN", "assetClassName": furnace_class["name"],
                    "assetNumber": 26, "name": f"HTTP Furnace 26 {j.prefix}"})
    furnace.pop("_globalPullServerUpdatedAt", None)
    j.seed(f"asset_instances/{asset_id}", furnace)
    first_id, partial_id, later_id = (_id(j, label) for label in
                                     ("burner-first", "burner-partial", "burner-later"))
    current_path = f"burner_condition_current/{asset_id}"
    first_path, partial_path = (f"burner_condition_rounds/{identity}"
                               for identity in (first_id, partial_id))
    j.business_paths.extend([first_path, partial_path, current_path])
    full = {"requestId": first_id, "operation": "RECORD_BURNER_CONDITION_ROUND",
            "assetClassId": class_id, "assetInstanceId": asset_id, "expectedAssetVersion": 1,
            "expectedCurrentRoundId": None,
            "observations": [{"position": p, "flameObservation": "seen", "redHotObserved": False,
                              "microampReading": None, "remarks": None} for p in range(1, 9)],
            "uvObservations": [{"position": p, "condition": "serviceable", "remarks": None}
                               for p in range(1, 9)],
            "draftSealRedHotObserved": False, "hotAirAtDraftSealObserved": False,
            "roundNote": f"{j.prefix}: complete witnessed development survey"}

    def call(request, actor="operations"):
        return j.call(actor, "mutateAssetHierarchyV2", request, v2=True)

    j.step("HTTP unapproved user cannot record a Burner round", lambda: j.refuse(
        lambda: call(full, "pending"), ("PERMISSION_DENIED",), (first_path, current_path)))

    def full_round():
        call(full)
        stored = j.read(first_path, "operations")
        j.check(len(stored["observations"]) == 8 and
                j.read(current_path)["roundId"] == first_id,
                "Complete round did not retain eight positions and current identity")
    j.step("HTTP full Burner round persists all eight positions", full_round)

    partial = copy.deepcopy(full)
    partial.update({"requestId": partial_id, "expectedCurrentRoundId": first_id,
                    "observedFields": ["burners.1.redHotObserved"],
                    "expectedInstallationBasis": {"burner": [], "uv": []},
                    "expectedOpenIssueBasis": [],
                    "roundNote": f"{j.prefix}: only position 1 red-hot was observed again"})
    partial["observations"][0]["redHotObserved"] = True

    def partial_round():
        call(partial)
        stored, original = j.read(partial_path, "operations"), j.read(first_path)
        inherited = "burners.2.redHotObserved"
        witnessed = "burners.1.redHotObserved"
        retained = stored["evidenceProvenance"][inherited]
        origin = original["evidenceProvenance"][inherited]
        j.check(stored["observations"][0]["redHotObserved"] is True and
                retained["kind"] == "inherited" and
                all(retained[key] == origin[key] for key in
                    ("sourceRoundId", "observedAt", "observerUid", "observerName")),
                "Partial edit fabricated fresh provenance for an inherited reading")
        j.check(stored["evidenceProvenance"][witnessed] != original["evidenceProvenance"][witnessed],
                "Actually observed changed field did not receive new evidence")
    j.step("HTTP partial Burner update preserves untouched field provenance", partial_round)

    stale = copy.deepcopy(partial)
    stale["requestId"] = _id(j, "burner-stale-competitor")
    stale_path = f"burner_condition_rounds/{stale['requestId']}"
    j.step("HTTP stale partial Burner draft cannot overwrite the newer round", lambda: j.refuse(
        lambda: call(stale), ("ABORTED", "FAILED_PRECONDITION"), (current_path, stale_path)))

    def later_and_replay():
        later = copy.deepcopy(full)
        later.update({"requestId": later_id, "expectedCurrentRoundId": partial_id})
        call(later)
        replay = call(partial)
        j.check(replay["idempotentReplay"] and j.read(current_path)["roundId"] == later_id,
                "Partial-round replay replaced the later complete survey")
        j.check(j.read(partial_path)["observations"][0]["redHotObserved"] is True,
                "Later survey erased the historical red-hot observation")
    j.step("HTTP accepted partial Burner replay retains history after a later survey", later_and_replay)


def templates(j: Journey) -> None:
    """Assign an administratively seeded, hash-valid published version via HTTP."""
    assignment_class_id = f"{j.prefix}-assignment-rig-class"
    assignment_node_id = f"{j.prefix}-assignment-body"
    assignment_class = copy.deepcopy(j.read(f"asset_classes/{j.class_id}"))
    assignment_class.update({"assetClassId": assignment_class_id, "code": "HJRIG",
                             "name": f"HTTP Test Rig {j.prefix}", "legacyAssetTypeKey": None})
    assignment_class.pop("_globalPullServerUpdatedAt", None)
    j.seed(f"asset_classes/{assignment_class_id}", assignment_class)
    assignment_base_id = f"{j.prefix}-assignment-rig-1"
    assignment_base = copy.deepcopy(j.read(f"asset_instances/{j.base_id}"))
    assignment_base.update({"assetInstanceId": assignment_base_id, "assetNumber": 1,
                            "assetClassId": assignment_class_id, "assetClassCode": "HJRIG",
                            "assetClassName": assignment_class["name"],
                            "name": f"HTTP Test Rig 1 {j.prefix}"})
    assignment_base.pop("_globalPullServerUpdatedAt", None)
    j.seed(f"asset_instances/{assignment_base_id}", assignment_base)
    package_id, version_id, audit_id = (f"{j.prefix}-{suffix}"
                                      for suffix in ("template-package", "template-version", "template-audit"))
    si = j.users["si"]
    published_at = _at(timedelta(days=-1))
    compact = lambda value: json.dumps(value, separators=(",", ":"))
    hierarchy = {"schemaVersion": 2, "scope": "definition",
                 "assetClassId": assignment_class_id, "assetClassCode": "HJRIG",
                 "assetClassName": assignment_class["name"], "nodeId": assignment_node_id,
                 "nodeVersion": 1, "nodeName": "Test rig body", "assetInstanceId": None,
                 "assetInstanceVersion": None, "assetNumber": None, "assetInstanceName": None,
                 "componentInstanceId": None, "componentInstanceVersion": None, "componentTag": None,
                 "hierarchyPath": ["Test rig body"], "ownershipStatus": "unassigned",
                 "ownerDiscipline": None, "accountableRoleKeys": []}
    j.seed(f"asset_hierarchy_nodes/{assignment_node_id}", {
        "schemaVersion": 1, "nodeId": assignment_node_id, "assetClassId": assignment_class_id,
        "parentNodeId": None, "nodeType": "component", "name": "Test rig body",
        "contactArrangement": "notApplicable", "ownershipStatus": "unassigned",
        "ownerDiscipline": None, "accountableRoleKeys": [], "sortOrder": 0,
        "ancestorNodeIds": [], "hierarchyPath": ["Test rig body"], "activeChildCount": 0,
        "status": "active", "version": 1, "createdAt": published_at, "updatedAt": published_at,
        "createdByUid": si["uid"], "createdByName": si["name"],
        "updatedByUid": si["uid"], "updatedByName": si["name"],
        "lastMutationId": _id(j, "assignment-body-fixture")})
    job = {"jobName": "HTTP Test Rig PM", "assetType": "governedCustom",
           "assetHierarchyRefJson": compact(hierarchy), "composer": {
        "closureReviewConfirmed": True, "closureReviewConfirmedByUid": si["uid"],
        "closureReviewConfirmedByName": si["name"], "closureReviewConfirmedAt": published_at},
        "closureCriticalCount": 1}
    modules = [{"moduleCode": "M-01", "moduleTitle": "Inspect fan",
                "requiredForClosure": True, "discipline": "mechanical"}]
    fields = [{"key": "vibration", "label": "Vibration", "moduleCode": "M-01",
               "type": "number", "isRequired": True}]
    # Canonical field order matches computeTemplateVersionContentHash. This only
    # builds valid administrative publication fixtures; assignment is real HTTP.
    canonical = {"jobTemplateSnapshotJson": compact(job), "moduleSnapshotsJson": compact(modules),
                 "fieldDefinitionsJson": compact(fields), "checklistJson": "[]",
                 "closureReviewConfirmed": True, "closureCriticalModuleCount": 1,
                 "closureReviewConfirmedByUid": si["uid"], "closureReviewConfirmedByName": si["name"],
                 "closureReviewConfirmedAt": published_at, "targetRefs": [], "deviceTagRefs": [],
                 "safetyClass": None, "safetyGatePolicyJson": None, "procedureRefs": [],
                 "operationalStatePreconditions": [], "schemaVersion": 1}
    content_hash = "tg2-sha256:" + hashlib.sha256(compact(canonical).encode()).hexdigest()
    # Include the client reader's lifecycle/audit fields as well as the server
    # assignment prerequisites; these fixtures share the phone's demo streams.
    client_metadata = {"schemaVersion": 1, "version": 1,
                       "createdAt": published_at, "updatedAt": published_at,
                       "createdByUid": si["uid"], "createdByName": si["name"],
                       "updatedByUid": si["uid"], "updatedByName": si["name"]}
    j.seed(f"template_packages/{package_id}", {
        **client_metadata,
        "firestoreId": package_id, "packageCode": f"HTTP-{j.prefix}",
        "title": "HTTP Test Rig preventive maintenance", "disciplineScope": "mechanical",
        "lifecycleStatus": "active", "activeVersionFirestoreId": version_id,
        "latestVersionNumber": 1, "isDeleted": False})
    j.seed(f"template_versions/{version_id}", {
        **canonical, **client_metadata, "firestoreId": version_id, "packageFirestoreId": package_id,
        "versionNumber": 1, "versionLabel": "v1", "status": "published", "contentHash": content_hash,
        "publishedByUid": si["uid"], "publishedByName": si["name"],
        "publishedAt": published_at, "isDeleted": False})
    j.seed(f"template_publish_audits/{audit_id}", {
        "schemaVersion": 1, "version": 1, "updatedAt": published_at,
        "performedByName": si["name"], "payloadSnapshotJson": compact(canonical),
        "firestoreId": audit_id, "packageFirestoreId": package_id,
        "versionFirestoreId": version_id, "action": "published", "performedByUid": si["uid"],
        "performedAt": published_at, "afterHash": content_hash, "isDeleted": False})
    request = {"requestId": _id(j, "template-assignment"), "packageId": package_id,
               "versionId": version_id, "expectedVersionNumber": 1, "expectedContentHash": content_hash,
               "assetType": "governedCustom", "assetNumber": 1,
               "assetClassId": assignment_class_id, "assetInstanceId": assignment_base_id,
               "chargeNoAtEvent": 91234, "remarks": f"{j.prefix}: planned HTTP assignment"}
    receipt_path = f"published_template_assignment_requests/{request['requestId']}"
    j.business_paths.append(receipt_path)

    def call(data, actor="si"):
        return j.call(actor, "assignPublishedTemplateVersionV2", data, v2=True)

    j.step("HTTP Operations cannot assign a published template", lambda: j.refuse(
        lambda: call(request, "operations"), ("PERMISSION_DENIED",), (receipt_path,)))
    accepted = {}
    def assign_and_read():
        accepted.update(call(request))
        execution_path = f"job_executions/{accepted['executionId']}"
        j.business_paths.append(execution_path)
        execution = j.read(execution_path, "operations")
        j.check(execution["templatePackageId"] == package_id and
                execution["templateVersionId"] == version_id and
                execution["modulePopulationVersion"] == 1 and execution["isCompleted"] is False,
                "Assignment lost frozen template identity or population baseline")
        j.check(len(accepted["modules"]) == 1 and j.read(receipt_path) is not None,
                "Assignment lacks modules or atomic receipt")
        for module in accepted["modules"]:
            module_path = f"job_modules/{module['firestoreId']}"
            j.business_paths.append(module_path)
            stored = j.read(module_path, "operations")
            j.check(stored["requiredForClosure"] is True and stored["templateVersionId"] == version_id,
                    "Assigned module did not retain closure requirement and published identity")
    j.step("HTTP published assignment atomically creates frozen execution modules and receipt", assign_and_read)

    def replay():
        result = call(request)
        j.check(result["idempotentReplay"] and result["executionId"] == accepted["executionId"] and
                [m["firestoreId"] for m in result["modules"]] ==
                [m["firestoreId"] for m in accepted["modules"]],
                "Exact assignment replay created another job or module population")
    j.step("HTTP assignment replay retains the original execution and modules", replay)
    altered = {**request, "remarks": "Changed after the original governed decision."}
    j.step("HTTP accepted assignment request cannot be rebound to changed intent", lambda: j.refuse(
        lambda: call(altered), ("ALREADY_EXISTS", "ABORTED", "FAILED_PRECONDITION"),
        (receipt_path, f"job_executions/{accepted['executionId']}")))


def _custom_asset(j: Journey, label: str) -> tuple[dict, dict]:
    """Scoped class fixture and real registration with an owned number claim."""
    class_id, asset_id = f"{j.prefix}-{label}-class", _id(j, f"{label}-asset")
    asset_class = copy.deepcopy(j.read(f"asset_classes/{j.class_id}"))
    asset_class.update(assetClassId=class_id, code=f"HJ{label.upper()}",
                       name=f"HTTP {label} {j.prefix}", legacyAssetTypeKey=None)
    asset_class.pop("_globalPullServerUpdatedAt", None)
    j.seed(f"asset_classes/{class_id}", asset_class)
    asset_path = f"asset_instances/{asset_id}"
    claim_key = hashlib.sha256(f"{class_id}:1".encode()).hexdigest()
    claim_path = f"asset_instance_numbers/{claim_key}"
    j.business_paths.extend([asset_path, claim_path])
    request = {"requestId": _id(j, f"{label}-register"), "operation": "CREATE_ASSET_INSTANCE",
               "assetClassId": class_id, "assetInstanceId": asset_id, "expectedAssetClassVersion": 1,
               "reason": f"{j.prefix}: register isolated physical equipment for {label} validation.",
               "assetDraft": {"assetNumber": 1, "name": f"HTTP {label} 1 {j.prefix}",
                   "plantTag": None, "location": "Isolated HTTP validation", "manufacturer": None,
                   "model": None, "serialNumber": None, "commissionedOn": None,
                   "serviceState": "inService", "ownershipStatus": "confirmed",
                   "ownerDiscipline": "Operations", "accountableRoleKeys": ["operations"]}}

    def registered():
        j.call("admin", "mutateAssetHierarchyV2", request, v2=True)
        j.check(j.read(asset_path, "operations")["version"] == 1 and j.read(claim_path) is not None,
                "Physical registration did not persist the asset and its number claim")
    j.step(f"{label}: Admin registers exact physical equipment and number custody", registered)
    return asset_class, j.read(asset_path)


def manual_condition(j: Journey) -> None:
    """Reviewed Down -> Unfit replacement and retirement without invented repair."""
    asset_class, asset = _custom_asset(j, "condition")
    class_id, asset_id = asset_class["assetClassId"], asset["assetInstanceId"]
    node_id = f"{j.prefix}-condition-component"
    actor, at = j.users["admin"], _at(timedelta(days=-1))
    node = {"schemaVersion": 1, "nodeId": node_id, "assetClassId": class_id,
            "parentNodeId": None, "nodeType": "component", "name": "Condition test drive",
            "contactArrangement": "notApplicable", "ownershipStatus": "confirmed",
            "ownerDiscipline": "Mechanical", "accountableRoleKeys": ["seniorMechanical"],
            "sortOrder": 0, "ancestorNodeIds": [], "hierarchyPath": ["Condition test drive"],
            "activeChildCount": 0, "status": "active", "version": 1,
            "createdAt": at, "updatedAt": at, "createdByUid": actor["uid"],
            "createdByName": actor["name"], "updatedByUid": actor["uid"],
            "updatedByName": actor["name"], "lastMutationId": _id(j, "condition-node")}
    j.seed(f"asset_hierarchy_nodes/{node_id}", node)
    reference = {"schemaVersion": 4, "scope": "componentDefinitionOnAsset",
                 "assetClassId": class_id, "assetClassCode": asset_class["code"],
                 "assetClassName": asset_class["name"], "nodeId": node_id, "nodeVersion": 1,
                 "nodeName": node["name"], "assetInstanceId": asset_id,
                 "assetInstanceVersion": 1, "assetNumber": 1, "assetInstanceName": asset["name"],
                 "componentInstanceId": None, "componentInstanceVersion": None, "componentTag": None,
                 "hierarchyPath": node["hierarchyPath"], "ownershipStatus": node["ownershipStatus"],
                 "ownerDiscipline": node["ownerDiscipline"], "accountableRoleKeys": node["accountableRoleKeys"],
                 "innerCoverAssociation": None}
    path, asset_path = f"asset_operational_conditions/{asset_id}", f"asset_instances/{asset_id}"
    j.business_paths.append(path)
    declare = {"requestId": _id(j, "condition-down"), "operation": "DECLARE_ASSET_CONDITION",
               "assetClassId": class_id, "assetInstanceId": asset_id, "expectedVersion": 0,
               "condition": "down", "causeKeys": ["breakdown"], "basis": "pendingMaintenance",
               "componentHierarchyRefJson": json.dumps(reference, separators=(",", ":")),
               "reason": f"{j.prefix}: drive failure prevents operation; no repair claimed.", "linkedIssueIds": []}

    def call(data, role="si"):
        return j.call(role, "mutateAssetHierarchyV2", data, v2=True)

    j.step("condition: unapproved actor cannot declare Down", lambda: j.refuse(
        lambda: call(declare, "pending"), ("PERMISSION_DENIED",), (path, asset_path)))

    def declared():
        accepted = call(declare, "operations")
        row = j.read(path, "operations")
        j.check(accepted["version"] == 1 and row["condition"] == "down" and row["active"] is True,
                "Manual Down declaration did not persist its active restriction")
        j.check(json.loads(row["componentHierarchyRefJson"])["assetInstanceId"] == asset_id,
                "Manual declaration changed physical equipment identity")
    j.step("condition: Operations declares complete Down assessment on exact equipment", declared)
    replacement = {**declare, "requestId": _id(j, "condition-unfit"), "expectedVersion": 1,
                   "condition": "unfit", "causeKeys": ["safety"],
                   "reason": f"{j.prefix}: reviewed full assessment identifies unsafe drive; replace earlier Down assessment."}
    j.step("condition: active assessment cannot be silently replaced", lambda: j.refuse(
        lambda: call(replacement), ("FAILED_PRECONDITION",), (path, asset_path)))
    replacement["replacesRequestId"] = declare["requestId"]
    j.step("condition: Operations cannot replace the reviewed active assessment", lambda: j.refuse(
        lambda: call(replacement, "operations"), ("PERMISSION_DENIED",), (path, asset_path)))
    wrong = {**replacement, "requestId": _id(j, "condition-wrong-review"),
             "replacesRequestId": _id(j, "condition-other-assessment")}
    j.step("condition: replacement must review the exact predecessor", lambda: j.refuse(
        lambda: call(wrong), ("FAILED_PRECONDITION", "ABORTED"), (path, asset_path)))
    audit_path = f"asset_operational_condition_audits/asset_condition_{replacement['requestId']}"
    j.business_paths.append(audit_path)

    def replaced():
        accepted = call(replacement)
        row, audit = j.read(path, "operations"), j.read(audit_path, "admin")
        j.check(accepted["version"] == 2 and row["condition"] == "unfit" and row["active"] is True,
                "Reviewed replacement did not persist the new restriction")
        j.check(audit["replacesRequestId"] == declare["requestId"] and
                audit["before"]["condition"] == "down" and audit["after"]["condition"] == "unfit",
                "Replacement lost the original Down assessment or exact review link")
    j.step("condition: SI replacement preserves Down history and reviewed Unfit decision", replaced)
    retire = {"requestId": _id(j, "condition-retire"), "operation": "SET_ASSET_INSTANCE_STATUS",
              "assetClassId": class_id, "assetInstanceId": asset_id, "expectedVersion": 1,
              "status": "retired", "reason": f"{j.prefix}: permanently withdraw unsafe drive; no repair performed."}
    j.step("condition: Operations cannot retire restricted equipment", lambda: j.refuse(
        lambda: call(retire, "operations"), ("PERMISSION_DENIED",), (path, asset_path)))
    retirement_audit = f"asset_hierarchy_audits/asset_registry_{retire['requestId']}"
    j.business_paths.append(retirement_audit)

    def retired():
        before = j.read(path)
        call(retire)
        j.check(j.read(asset_path, "operations")["status"] == "retired", "Equipment retirement not persisted")
        after = j.read(path)
        before.pop("_globalPullServerUpdatedAt", None)
        after.pop("_globalPullServerUpdatedAt", None)
        j.check(before == after, "Retirement changed the active manual restriction")
        audit = j.read(retirement_audit, "admin")
        retained = json.loads(audit["retainedOperationalConditionJson"])
        j.check(audit["conditionDisposition"] == "preserved-unresolved-at-retirement" and
                retained["condition"] == "unfit" and retained["active"] is True,
                "Retirement audit falsely implies repair or loses retained restriction")
    j.step("condition: SI retirement preserves unresolved Unfit state and immutable assessment", retired)

    def history():
        j.check(call(declare, "operations")["idempotentReplay"] and call(retire)["idempotentReplay"],
                "Original condition/retirement acceptance cannot recover")
        j.check(j.read(path)["condition"] == "unfit" and j.read(path)["version"] == 2 and
                j.read(asset_path)["status"] == "retired", "Historical replay reapplied old condition or revived equipment")
    j.step("condition: historical declaration and retirement replay preserve later restriction", history)


def maintenance_cadence(j: Journey) -> None:
    """Real historical producers hold conflicting same-plant-day cadence evidence."""
    asset_class, asset = _custom_asset(j, "cadence")
    class_id, asset_id = asset_class["assetClassId"], asset["assetInstanceId"]

    def command(label, kind, aggregate, payload):
        return {"commandId": _id(j, label), "commandType": kind, "aggregateId": aggregate,
                "expectedVersion": 0, "payload": payload}

    def call(data, role="admin"):
        return j.call(role, "executeMaintenanceWorkflowCommandV2", data, v2=True, payload_key="command")

    counter = "HTTP_SERVICE"
    due_key = hashlib.sha256(f"{class_id}:{asset_id}|{counter}".encode()).hexdigest()[:40]
    due_path = f"maintenance_due_states/mds_{due_key}"
    j.business_paths.append(due_path)
    definitions = {}
    for days in (30, 90):
        definition_id = f"{j.prefix}-cadence-{days}"
        definition = {"schemaVersion": 1, "code": f"HJ_{uuid.UUID(_id(j, 'cadence-code')).hex[:12]}_{days}",
                      "title": f"HTTP {days} day service", "description": f"{j.prefix}: isolated cadence review fixture.",
                      "assetTypeKeys": ["governedCustom"], "assetClassIds": [class_id],
                      "principalLaneKey": "mech", "resetCounters": [
                          {"key": counter, "label": "HTTP service", "thresholdDays": days}]}
        request = command(f"cadence-class-{days}", "upsertMaintenanceClassDefinition", definition_id,
                          {"definition": definition, "reason": f"{j.prefix}: reviewed {days} day service scope."})
        definitions[days] = definition_id
        j.business_paths.append(f"maintenance_class_definitions/{definition_id}")

        def create_definition(request=request, definition_id=definition_id, days=days):
            call(request)
            row = j.read(f"maintenance_class_definitions/{definition_id}", "operations")
            j.check(row["version"] == 1 and row["resetCounters"][0]["thresholdDays"] == days,
                    "Governed maintenance scope was not persisted")
        j.step(f"cadence: Admin governs {days} day service definition through actual HTTP", create_definition)
    # Different UTC dates and clocks, but both fall on the same Indian plant day.
    today = datetime.now(timezone.utc)
    plant_day = (today - timedelta(days=3)).replace(hour=0, minute=0, second=0, microsecond=0)
    early = plant_day - timedelta(hours=5)  # 00:30 in India
    late = plant_day + timedelta(hours=17)  # 22:30 in India
    later = plant_day + timedelta(days=1, hours=6, minutes=30)
    iso = lambda value: value.isoformat(timespec="milliseconds").replace("+00:00", "Z")
    same_instant = lambda left, right: datetime.fromisoformat(left.replace("Z", "+00:00")) == datetime.fromisoformat(right.replace("Z", "+00:00"))

    def history_request(label, days, completed):
        return command(label, "recordHistoricalMaintenance", f"{j.prefix}-{label}", {
            "assetTypeKey": "governedCustom", "assetNumber": 1,
            "assetClassId": class_id, "assetInstanceId": asset_id, "assetInstanceVersion": 1,
            "definitionId": definitions[days], "definitionVersion": 1, "completedAt": iso(completed),
            "performedByName": "HTTP mechanical team", "evidenceNote": f"{j.prefix}: reviewed historical physical service.",
            "sourceReference": f"{j.prefix} register {label}"})
    first = history_request("cadence-early", 30, early)
    second = history_request("cadence-late", 90, late)
    third = history_request("cadence-later-day", 30, later)
    record_paths = [f"historical_maintenance_records/{c['aggregateId']}" for c in (first, second, third)]
    j.business_paths.extend(record_paths)
    j.step("cadence: Operations cannot admit historical maintenance evidence", lambda: j.refuse(
        lambda: call(first, "operations"), ("PERMISSION_DENIED",), (due_path, *record_paths)))
    event_paths = []

    def record_and_read(request):
        accepted = call(request)
        row = j.read(f"historical_maintenance_records/{request['aggregateId']}", "operations")
        j.check(same_instant(row["completedAt"], request["payload"]["completedAt"]),
                "Historical producer changed physical chronology")
        event_path = f"maintenance_completion_events/{row['completionEventId']}"
        event_paths.append(event_path)
        j.business_paths.append(event_path)
        j.check(j.read(event_path, "operations")["sourceId"] == request["aggregateId"],
                "Immutable completion event is not linked to the physical evidence")
        return accepted

    def first_record():
        record_and_read(first)
        row = j.read(due_path, "operations")
        j.check(row["classificationPending"] is False and same_instant(row["nextDueAt"], iso(early + timedelta(days=30))),
                "Single unambiguous service did not establish its due date")
    j.step("cadence: first physical service establishes a traceable due date", first_record)

    def conflict():
        record_and_read(second)
        row = j.read(due_path, "operations")
        j.check(row["classificationPending"] is True and row["nextDueAt"] is None and
                row["reviewReason"] == "conflicting-same-day-evidence" and
                len(row["conflictingCompletionEventIds"]) == 2,
                "Same Indian-day conflict invented a settled due date or discarded evidence")
        j.check(all(j.read(path) is not None for path in record_paths[:2] + event_paths),
                "Conflict handling erased original physical records")
    j.step("cadence: different clocks in one Indian plant day retain both records and require review", conflict)

    def conflict_replay():
        before = j.read(due_path)
        call(first)
        after = j.read(due_path)
        before.pop("_globalPullServerUpdatedAt", None)
        after.pop("_globalPullServerUpdatedAt", None)
        j.check(before == after, "Historical replay settled an unresolved same-day conflict")
    j.step("cadence: earlier accepted replay cannot erase same-day review requirement", conflict_replay)

    def later_basis():
        record_and_read(third)
        row = j.read(due_path, "operations")
        j.check(row["classificationPending"] is False and row["reviewReason"] is None and
                row["conflictingCompletionEventIds"] == [] and
                same_instant(row["nextDueAt"], iso(later + timedelta(days=30))),
                "Later unambiguous physical work did not establish its new cadence basis")
        j.check(all(j.read(path) is not None for path in record_paths + event_paths),
                "New cadence basis deleted earlier conflicting evidence")
    j.step("cadence: later physical day establishes a new basis while all earlier evidence remains", later_basis)
