#!/usr/bin/env python3
"""Fail-closed source audit for the R-01/R-02 global-pull protocol."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_COLLECTIONS = [
    "abnormality_types",
    "charge_abnormalities",
    "directives",
    "job_diary_entries",
    "job_executions",
    "job_modules",
    "job_templates",
    "knowledge_base",
    "maintenance_records",
    "template_packages",
    "template_publish_audits",
    "template_versions",
]
STAMP_FIELD = "_globalPullServerUpdatedAt"
WRITER_VERSION = "global-pull-server-stamp-v1"

failures: list[str] = []
passes: list[str] = []


def source(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def check(name: str, condition: bool) -> None:
    (passes if condition else failures).append(name)
    print(f"{'PASS' if condition else 'FAIL'} | {name}")


def quoted_list_after(text: str, marker: str) -> list[str]:
    start = text.find(marker)
    if start < 0:
        return []
    open_bracket = text.find("[", start + len(marker))
    close_bracket = text.find("]", open_bracket + 1)
    if open_bracket < 0 or close_bracket < 0:
        return []
    return re.findall(r"""["']([a-z_]+)["']""", text[open_bracket:close_bracket])


def brace_block(text: str, marker: str) -> str:
    start = text.find(marker)
    if start < 0:
        return ""
    open_brace = text.find("{", start + len(marker))
    if open_brace < 0:
        return ""
    depth = 0
    for index in range(open_brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start : index + 1]
    return ""


manifest = json.loads(source("governance/global-pull-protocol-v1.json"))
fingerprinted_contract = manifest.get("fingerprintedContract", {})
FINGERPRINT = manifest.get("protocolFingerprint", "")
calculated_fingerprint = hashlib.sha256(
    json.dumps(
        fingerprinted_contract,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
backend = source("functions/src/globalPullServerClock.ts")
backend_index = source("functions/src/index.ts")
client_protocol = source("lib/core/services/global_pull_protocol.dart")
cursor_store = source("lib/core/services/global_pull_cursor_store.dart")
pull_shell = source("lib/core/services/global_pull_service.dart")
rules = source("firestore.rules")
governance_tool = source("functions/tools/global-pull-server-clock.mjs")
runtime_security = source("functions/src/globalPullSecurityConfig.ts")
runtime_identity_source = source("functions/src/functionFleetRuntimeIdentity.ts")
runtime_identity_policy_source = source(
    "release/global-pull-runtime-identity-policy.json"
)
runtime_identity_policy = json.loads(runtime_identity_policy_source)
function_fleet_policy = json.loads(
    source("release/function-fleet-runtime-identity-policy.json")
)

backend_collections = quoted_list_after(
    backend, "export const GLOBAL_PULL_COLLECTIONS"
)
client_collections = quoted_list_after(
    client_protocol, "globalPullProtocolCollections"
)
tool_collections = quoted_list_after(governance_tool, "const COLLECTIONS")
check(
    "Canonical manifest reproduces the admitted protocol fingerprint",
    manifest.get("schemaVersion") == 1
    and manifest.get("fingerprintAlgorithm") == "SHA256_CANONICAL_JSON"
    and re.fullmatch(r"[0-9a-f]{64}", FINGERPRINT) is not None
    and calculated_fingerprint == FINGERPRINT
    and fingerprinted_contract.get("collections") == EXPECTED_COLLECTIONS
    and fingerprinted_contract.get("serverStampField") == STAMP_FIELD
    and fingerprinted_contract.get("writerVersion") == WRITER_VERSION,
)
check(
    "Protocol collection set is exact and ordered across backend, client and tool",
    backend_collections == EXPECTED_COLLECTIONS
    and client_collections == EXPECTED_COLLECTIONS
    and tool_collections == EXPECTED_COLLECTIONS,
)
check(
    "Protocol fingerprint, stamp field and writer version agree",
    all(
        FINGERPRINT in text and STAMP_FIELD in text and WRITER_VERSION in text
        for text in (backend, client_protocol, governance_tool)
    ),
)
check(
    "Authenticated callable requires an active evidence-bound runtime contract",
    "canonicalApprovedUserAuthority(" in backend
    and "canonicalUserAuthorityDigest(" in backend
    and 'data.state !== "ACTIVE"' in backend
    and "SOURCE_COMMIT_PATTERN.test(data.sourceCommit)" in backend
    and "SHA256_PATTERN.test(data.backfillReceiptSha256)" in backend
    and "serverAnchor.getTime() < contract.activatedAt.getTime()" in backend,
)
check(
    "Retrying top-level trigger stamps writes and restores hard deletes",
    'document: "{collectionId}/{documentId}"' in backend_index
    and "retry: true" in backend_index
    and "applyGlobalPullServerClock(" in backend_index
    and '"restored-tombstone"' in backend
    and "isDeleted: true" in backend
    and "deletedAt: before.deletedAt ?? timestamp" in backend,
)
check(
    "Restored ticket and assignment tombstones cannot emit create notifications",
    "if (ticket == null || ticket.isDeleted === true) return;" in backend_index
    and "if (execution == null || execution.isDeleted === true) return;"
    in backend_index,
)
check(
    "Client query uses one inclusive lower cursor and inclusive server anchor",
    "globalPullServerWindowQuery(" in client_protocol
    and "isGreaterThanOrEqualTo:" in client_protocol
    and "isLessThanOrEqualTo:" in client_protocol
    and ".orderBy(globalPullServerUpdatedAtField)" in client_protocol,
)

query_files = [
    "lib/features/abnormalities/providers/abnormality_provider.dart",
    "lib/features/directives/providers/operational_directive_provider.dart",
    "lib/features/maintenance/providers/maintenance_provider.dart",
    "lib/features/planned_maintenance/domain/baf_knowledge_repository.dart",
    "lib/features/planned_maintenance/providers/job_diary_provider.dart",
    "lib/features/planned_maintenance/providers/job_module_provider.dart",
    "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/template_governance_provider.dart",
]
query_source = "\n".join(source(path) for path in query_files)
check(
    "All twelve domain pull paths use the shared bounded server-window query",
    query_source.count("globalPullServerWindowQuery(") == len(EXPECTED_COLLECTIONS)
    and query_source.count("throughInclusive: through") == len(EXPECTED_COLLECTIONS),
)
check(
    "Run envelope is partitioned by actor, authority and database generation",
    "baf_global_pull_cursor_v1" in cursor_store
    and "'actorUid'" in cursor_store
    and "'authorityDigest'" in cursor_store
    and "'databaseGenerationId'" in cursor_store
    and "GlobalPullRunState.prepared" in cursor_store
    and "GlobalPullRunState.committed" in cursor_store
    and "cursor-domain-set-mismatch" in cursor_store
    and "domain-cursor-regression" in cursor_store,
)
commit_block = brace_block(
    cursor_store, "Future<GlobalPullRunEnvelope> commit("
)
check(
    "Legacy client-time cursor retires only after durable full-run commit",
    "final committed = envelope.commit();" in commit_block
    and "await write(committed);" in commit_block
    and "await preferences.remove(legacyGlobalCursorKey);" in commit_block
    and commit_block.index("final committed = envelope.commit();")
    < commit_block.index("await write(committed);")
    < commit_block.index("await preferences.remove(legacyGlobalCursorKey);")
    and "prefs.getString('last_global_pull')" not in pull_shell
    and "_pullTokenSafetyMargin" not in pull_shell,
)
check(
    "Pull requires authenticated actor and committed P-06 generation before cursor use",
    "FirebaseAuth.instance.currentUser?.uid" in pull_shell
    and "IsarSchemaMigrator.readCommittedMarker(" in pull_shell
    and "_authorityReader.beginRun(expectedUid: actorUid)" in pull_shell
    and "databaseGenerationId: provenance.databaseGenerationId" in pull_shell,
)

rules_complete = True
for collection in EXPECTED_COLLECTIONS:
    block = brace_block(rules, f"match /{collection}/{{docId}}")
    rules_complete = rules_complete and bool(block)
    create_denied = "allow create: if false;" in block
    update_denied = (
        "allow update: if false;" in block
        or "allow update, delete: if false;" in block
    )
    rules_complete = rules_complete and (
        create_denied or "globalPullStampAbsentOnCreate()" in block
    )
    rules_complete = rules_complete and (
        update_denied or "globalPullStampValidOnUpdate()" in block
    )
check(
    "Rules reserve the server stamp on every protocol collection",
    rules_complete
    and "request.resource.data.keys().hasAny([" in rules
    and "request.resource.data.get('_globalPullServerUpdatedAt', null)" in rules
    and "!request.resource.data.diff(resource.data).affectedKeys().hasOnly(["
        in rules,
)
check(
    "Governance defaults read-only and gates both write modes",
    'const mode = values.get("--mode") ?? "inventory";' in governance_tool
    and 'if (mode !== "inventory")' in governance_tool
    and "options.confirmProjectId !== projectId" in governance_tool
    and '"--operator is required for a write mode."' in governance_tool
    and '"--output is required for a write mode."' in governance_tool,
)
check(
    "Global-pull functions use separate least-privilege runtime identities",
    "GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS" in backend_index
    and "GLOBAL_PULL_TRIGGER_SECURITY_OPTIONS" in backend_index
    and "FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.beginGlobalPullRun"
        in runtime_security
    and "FUNCTION_RUNTIME_SERVICE_ACCOUNT_IDS.stampGlobalPullServerClock"
        in runtime_security
    and 'beginGlobalPullRun: "crm3-global-pull-reader"'
        in runtime_identity_source
    and 'stampGlobalPullServerClock: "crm3-global-pull-writer"'
        in runtime_identity_source
    and 'import {expr, projectID} from "firebase-functions/params"'
        in runtime_identity_source
    and "@${projectID}.iam.gserviceaccount.com" in runtime_identity_source
    and "@crm3-baf-ops-b8638.iam.gserviceaccount.com"
        not in runtime_security + runtime_identity_source
    and "compute@developer.gserviceaccount.com"
        not in runtime_security + runtime_identity_source
    and runtime_identity_policy.get("schemaVersion") == 3
    and runtime_identity_policy.get("policyId")
        == "GLOBAL-PULL-RUNTIME-IDENTITY-POLICY-V3"
    and runtime_identity_policy.get("declarationStatus")
        == "DEPLOYED_SUBSET_SUBSUMED_BY_PROVED_COMPLETE_FLEET"
    and runtime_identity_policy.get("completeFleetPolicy")
        == "release/function-fleet-runtime-identity-policy.json"
    and runtime_identity_policy.get("targetProjectBinding") == {
        "builtInParameter": "PROJECT_ID",
        "serviceAccountDomain": "iam.gserviceaccount.com",
        "sameProjectRequired": True,
        "crossProjectResolutionAllowed": False,
    }
    and runtime_identity_policy.get("functionBindings", {})
        .get("beginGlobalPullRun", {}).get("runtimeServiceAccountTemplate")
        == "crm3-global-pull-reader@${PROJECT_ID}.iam.gserviceaccount.com"
    and runtime_identity_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {})
        .get("runtimeServiceAccountTemplate")
        == "crm3-global-pull-writer@${PROJECT_ID}.iam.gserviceaccount.com"
    and runtime_identity_policy.get("productionProjectId")
        == "crm3-baf-ops-b8638"
    and runtime_identity_policy.get("functionBindings", {})
        .get("beginGlobalPullRun", {})
        .get("productionResolvedRuntimeServiceAccount")
        == "crm3-global-pull-reader@crm3-baf-ops-b8638.iam.gserviceaccount.com"
    and runtime_identity_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {})
        .get("productionResolvedRuntimeServiceAccount")
        == "crm3-global-pull-writer@crm3-baf-ops-b8638.iam.gserviceaccount.com"
    and runtime_identity_policy.get("functionBindings", {})
        .get("beginGlobalPullRun", {}).get("requiredProjectRoles")
        == ["roles/datastore.viewer"]
    and runtime_identity_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {}).get("requiredProjectRoles")
        == [
            "roles/datastore.user",
            "roles/eventarc.eventReceiver",
        ]
    and runtime_identity_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {})
        .get("requiredCloudRunServiceRoles") == ["roles/run.invoker"]
    and "roles/logging.logWriter" not in runtime_identity_policy_source
    and function_fleet_policy.get("schemaVersion") == 1
    and function_fleet_policy.get("declarationStatus")
        == "DEPLOYED_AND_LIVE_READBACK_PROVED"
    and function_fleet_policy.get("productionProjectId")
        == runtime_identity_policy.get("productionProjectId")
    and function_fleet_policy.get("functionBindings", {})
        .get("beginGlobalPullRun", {}).get("runtimeServiceAccountId")
        == "crm3-global-pull-reader"
    and function_fleet_policy.get("functionBindings", {})
        .get("beginGlobalPullRun", {}).get("requiredProjectRoles")
        == ["roles/datastore.viewer"]
    and function_fleet_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {}).get("runtimeServiceAccountId")
        == "crm3-global-pull-writer"
    and function_fleet_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {}).get("requiredProjectRoles")
        == ["roles/datastore.user", "roles/eventarc.eventReceiver"]
    and function_fleet_policy.get("functionBindings", {})
        .get("stampGlobalPullServerClock", {})
        .get("requiredCloudRunServiceRoles") == ["roles/run.invoker"]
    and runtime_identity_policy.get("existingFunctionFleetMutationAuthorized")
        is False
    and runtime_identity_policy.get("defaultComputeRoleMutationAuthorized")
        is False
    and runtime_identity_policy.get("crossProjectGrantAuthorized") is False,
)
check(
    "Governance evidence omits document IDs by default and keeps stdout count-only",
    '"--include-document-ids is valid only for inventory."' in governance_tool
    and '"--include-document-ids requires --output."' in governance_tool
    and "documentIdsRetained: includeDocumentIds" in governance_tool
    and "consoleContainsDocumentIds: false" in governance_tool
    and "options.includeDocumentIds" in governance_tool
    and "missingExamples != null" in governance_tool
    and "malformedExamples != null" in governance_tool
    and "result.receipt.inventory.collections.map(" in governance_tool,
)
check(
    "Backfill refuses malformed stamps and verifies a zero-gap receipt",
    "before.malformed !== 0" in governance_tool
    and "malformed server stamps require adjudication" in governance_tool
    and "assertZeroGap(after" in governance_tool
    and "updated !== before.missing" in governance_tool
    and "receiptSha256" in governance_tool,
)
check(
    "Activation requires a sealed matching receipt and fresh zero-gap inventory",
    "verifyReceiptSeal(receipt);" in governance_tool
    and "assertProtocolEvidence(receipt);" in governance_tool
    and 'assertZeroGap(preActivation, "Pre-activation inventory")' in governance_tool
    and "contractRef.create({" in governance_tool
    and "contractRef.get()" in governance_tool,
)

print(
    f"SUMMARY | pass={len(passes)} fail={len(failures)} "
    f"total={len(passes) + len(failures)}"
)
if failures:
    for failure in failures:
        print(f"FAILED | {failure}", file=sys.stderr)
raise SystemExit(1 if failures else 0)
