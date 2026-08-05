#!/usr/bin/env python3
"""Fail-closed canonical-main and local-laboratory audit for v4.2_R1."""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARSER = argparse.ArgumentParser()
PARSER.add_argument(
    "--phase",
    choices=("pristine", "post-codegen"),
    default="pristine",
    help="Select whether canonical hashes are checked before or after authentic generated binding regeneration.",
)
ARGS = PARSER.parse_args()
PHASE = ARGS.phase
PASS: list[tuple[str, str]] = []
FAIL: list[tuple[str, str]] = []


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def text_sha_with_eol(path: Path, eol: str) -> str:
    source = path.read_text(encoding="utf-8")
    normalized = source.replace("\r\n", "\n").replace("\r", "\n")
    rendered = normalized.replace("\n", eol).encode("utf-8")
    return hashlib.sha256(rendered).hexdigest().upper()


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def data(rel: str):
    return json.loads(text(rel))


def check(name: str, condition: bool, detail: str = "") -> None:
    (PASS if condition else FAIL).append((name, detail))
    print(f"{'PASS' if condition else 'FAIL'} | {name}" + (f" | {detail}" if detail else ""))


def powershell_balanced(source: str) -> bool:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[str] = []
    quote: str | None = None
    escaped = False
    comment = False
    i = 0
    while i < len(source):
        ch = source[i]
        if comment:
            if ch == "\n":
                comment = False
            i += 1
            continue
        if quote:
            if escaped:
                escaped = False
            elif ch == "`":
                escaped = True
            elif ch == quote:
                if i + 1 < len(source) and source[i + 1] == quote:
                    i += 1
                else:
                    quote = None
            i += 1
            continue
        if ch == "#":
            comment = True
        elif ch in ("'", '"'):
            quote = ch
        elif ch in "([{":
            stack.append(ch)
        elif ch in ")]}":
            if not stack or stack.pop() != pairs[ch]:
                return False
        i += 1
    return quote is None and not stack


def yaml_run_blocks(source: str) -> list[str]:
    lines = source.splitlines()
    blocks: list[str] = []
    index = 0
    while index < len(lines):
        inline = re.fullmatch(r"([ ]*)run:[ ]*(.+)", lines[index])
        if inline is not None and re.fullmatch(
            r"[|>][+-]?[ ]*(?:#.*)?",
            inline.group(2),
        ) is None:
            blocks.append(inline.group(2))
            index += 1
            continue
        marker = re.fullmatch(
            r"([ ]*)run:[ ]*[|>][+-]?[ ]*(?:#.*)?",
            lines[index],
        )
        if marker is None:
            index += 1
            continue

        base_indent = len(marker.group(1))
        body: list[str] = []
        index += 1
        while index < len(lines):
            line = lines[index]
            if not line.strip():
                body.append(line)
                index += 1
                continue
            indent = len(line) - len(line.lstrip(" "))
            if indent <= base_indent:
                break
            body.append(line)
            index += 1
        blocks.append("\n".join(body))
    return blocks


recon = data("docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json")
main = recon["canonicalMain"]
rows = recon["paths"]
successor_refresh = recon.get("successorRefresh", {})
combined_policy = data("release/production-release-policy.json")
combined_receipt_path = ROOT / "release/approvals/firebase-production-signing-restoration-receipt.json"
combined_receipt = data("release/approvals/firebase-production-signing-restoration-receipt.json")
combined_receipt_crlf_sha = text_sha_with_eol(combined_receipt_path, "\r\n")
historical_receipt = data("release/approvals/firebase-registration-receipt.json")
combined_config_path = ROOT / "android/app/google-services.json"
combined_config = data("android/app/google-services.json")
combined_crlf_sha = text_sha_with_eol(combined_config_path, "\r\n")
combined_semantic = hashlib.sha256((json.dumps(combined_config, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")).hexdigest().upper()
permanent_clients = [row for row in combined_config.get("client", []) if row.get("client_info", {}).get("android_client_info", {}).get("package_name") == "in.co.sail.bsl.crm3.bafops"]
android_oauth = [row for row in (permanent_clients[0].get("oauth_client", []) if len(permanent_clients) == 1 else []) if row.get("client_type") == 1]
android_oauth_map = {(row.get("android_info", {}).get("certificate_hash", "").replace(":", "").upper(), row.get("client_id")) for row in android_oauth}
check(
    "Combined Firebase configuration preserves exact repository and restoration representations",
    sha(combined_config_path) == "6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7"
    and combined_crlf_sha == "2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B"
    and combined_semantic == "A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2"
    and len(permanent_clients) == 1
    and android_oauth_map == {
        ("30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31", "894346496105-hmk7941e55ph206e6nr6ifvvqqqf7ee6.apps.googleusercontent.com"),
        ("41C2B828C71683A50EC346D19E1D44048758438D", "894346496105-oljmi6mm7o790ue6o7cgcs20cakanjkg.apps.googleusercontent.com"),
    },
    f"repository={sha(combined_config_path)} restoration={combined_crlf_sha} semantic={combined_semantic} oauth={len(android_oauth)}",
)
check(
    "Production policy binds combined, historical and restored Firebase custody",
    combined_policy["firebaseAndroidApp"]["googleServicesSha256"] == "2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B"
    and combined_policy["firebaseAndroidApp"]["googleServicesSha256Representation"] == "UTF8_CRLF_RESTORATION_ARTIFACT"
    and combined_policy["firebaseAndroidApp"]["repositoryGoogleServicesSha256"] == "6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7"
    and combined_policy["firebaseAndroidApp"]["repositoryGoogleServicesSha256Representation"] == "UTF8_LF_GIT_BLOB"
    and combined_policy["firebaseAndroidApp"]["googleServicesSemanticSha256"] == "A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2"
    and combined_policy["firebaseAndroidApp"]["historicalRegistrationGoogleServicesSha256"] == "730A044FF0A698C2FBCCF3B993EE6964EE5431CA8C6435DDC02AA98A9848646A"
    and combined_policy["firebaseAndroidApp"]["supersededDebugOnlyGoogleServicesSha256"] == "DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D"
    and combined_policy["firebaseAndroidApp"]["restorationReference"] == "CRM3-FB-RESTORE-001-C1"
    and combined_policy["firebaseAndroidApp"]["restorationReceiptSha256Representation"] == "UTF8_CRLF_RESTORATION_ARTIFACT"
    and combined_policy["firebaseAndroidApp"]["repositoryRestorationReceiptSha256"] == "CCE70C3FC7E541C72E29F6732502BDF313633B3AF4A49F1923DD2D440AFBEA13"
    and combined_policy["firebaseAndroidApp"]["repositoryRestorationReceiptSha256Representation"] == "UTF8_LF_GIT_BLOB"
    and combined_policy["firebaseAndroidApp"]["restorationEvidenceSha256"] == "24C335AF607595363F4C1D9E68B81AC9E558D37FB49263DE16EF87136D58E6CF",
)
check(
    "Historical BAF-REF-005 receipt remains immutable and restoration receipt is additive",
    historical_receipt["reference"] == "BAF-REF-005"
    and historical_receipt["googleServicesSha256"] == "730A044FF0A698C2FBCCF3B993EE6964EE5431CA8C6435DDC02AA98A9848646A"
    and combined_receipt["operationReference"] == "CRM3-FB-RESTORE-001-C1"
    and combined_receipt["historicalRegistrationReference"] == "BAF-REF-005"
    and combined_receipt["finalStatus"] == "PASS_FIREBASE_PRODUCTION_SIGNING_RESTORED_HISTORICAL_AUTHORITY"
    and combined_receipt["combinedGoogleServicesSha256"] == "2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B"
    and combined_receipt["combinedGoogleServicesSemanticSha256"] == "A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2"
    and combined_receipt["debugAuthorityPreserved"]["sha1"] == "30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31"
    and combined_receipt["debugAuthorityPreserved"]["sha256"] == "B0B0EF9B348F5D474356AEB79182483B98829012FC25EB3EDCD517D11563C6D5"
    and combined_receipt["debugAuthorityPreserved"]["oauthClientId"] == "894346496105-hmk7941e55ph206e6nr6ifvvqqqf7ee6.apps.googleusercontent.com"
    and combined_receipt["productionAuthorityRestored"]["sha1"] == "41C2B828C71683A50EC346D19E1D44048758438D"
    and combined_receipt["productionAuthorityRestored"]["sha256"] == "6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C"
    and combined_receipt["productionAuthorityRestored"]["historicalOauthClientId"] == "894346496105-oljmi6mm7o790ue6o7cgcs20cakanjkg.apps.googleusercontent.com"
    and sha(combined_receipt_path) == combined_policy["firebaseAndroidApp"]["repositoryRestorationReceiptSha256"]
    and combined_receipt_crlf_sha == combined_policy["firebaseAndroidApp"]["restorationReceiptSha256"]
    and combined_receipt["repositoryModified"] is False
    and combined_receipt["firebaseDeletionPerformed"] is False
    and combined_receipt["adjacentFirebaseMutationPerformed"] is False,
)

check(
    "Canonical repository authority is exact current main",
    main["branch"] == "main"
    and main["commit"] == "633c58bb0d936011e391b42627f8b8f02c510e95"
    and main["tree"] == "2f547a79e79076c70dd15ae8b85a7ad70c9fa018",
)
check(
    "Successor reconciliation preserves main authority through the R-01/R-02 source tranche",
    successor_refresh.get("throughMainCommit") == "96c2a09563389cba177998482ac090f39d16bb88"
    and successor_refresh.get("throughMainTree") == "41324fd041dcb6bb5b536d49225b9aa4f450317e"
    and successor_refresh.get("adjudicatedPullRequests")
        == [40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53]
    and successor_refresh.get("preExistingDriftPathCount") == 14
    and successor_refresh.get("crossPlatformRepresentationPathCount") == 19
    and successor_refresh.get("refreshTranche")
        == "R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_SOURCE_IMPLEMENTATION"
    and successor_refresh.get("refreshTrancheTrackedPaths") == [
        "docs/v4_2_r1/R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_REMEDIATION.md",
        "firestore.rules",
        "functions/package.json",
        "functions/src/globalPullServerClock.ts",
        "functions/src/index.ts",
        "functions/test/globalPullServerClock.test.js",
        "functions/test/globalPullServerClockGovernance.firestoreEmulator.test.js",
        "functions/tools/global-pull-server-clock.mjs",
        "governance/global-pull-protocol-v1.json",
        "governance/programme-ledger.json",
        "lib/core/services/global_pull_cursor_store.dart",
        "lib/core/services/global_pull_protocol.dart",
        "lib/core/services/global_pull_service.abnormalities.dart",
        "lib/core/services/global_pull_service.dart",
        "lib/core/services/global_pull_service.directives.dart",
        "lib/core/services/global_pull_service.job_diary.dart",
        "lib/core/services/global_pull_service.job_modules.dart",
        "lib/core/services/global_pull_service.knowledge_base.dart",
        "lib/core/services/global_pull_service.maintenance.dart",
        "lib/core/services/global_pull_service.planned.dart",
        "lib/core/services/global_pull_service.template_governance.dart",
        "lib/core/services/global_pull_service.watermark.dart",
        "lib/features/abnormalities/providers/abnormality_provider.dart",
        "lib/features/directives/providers/operational_directive_provider.dart",
        "lib/features/maintenance/providers/maintenance_provider.dart",
        "lib/features/planned_maintenance/domain/baf_knowledge_repository.dart",
        "lib/features/planned_maintenance/providers/job_diary_provider.dart",
        "lib/features/planned_maintenance/providers/job_module_provider.dart",
        "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart",
        "lib/features/planned_maintenance/providers/template_governance_provider.dart",
        "package.json",
        "test/firestore_rules_expression_budget_contract_test.dart",
        "test/firestore.rules.test.js",
        "test/global_pull_cursor_store_test.dart",
        "test/global_pull_service_decomposition_contract_test.dart",
        "test/maintenance_lifecycle_replay_contract_test.dart",
        "test/r01_r02_programme_ledger_source_contract_test.dart",
        "test/template_governance_70f_archive_test.dart",
        "tools/v4/v4_2_r1_canonical_audit.py",
        "tools/v4/verify_global_pull_server_clock.py",
        "tools/v4/whole_app_reconciliation_audit.py",
    ],
)
post_codegen_register = data("docs/v4_2_r1/AUTHORITATIVE_POST_CODEGEN_BINDINGS.json")
post_codegen_bindings = post_codegen_register.get("bindings", {})
post_codegen_source = post_codegen_register.get("sourceEvidence", {})
post_codegen_register_valid = (
    post_codegen_register.get("schemaVersion") == 1
    and post_codegen_register.get("authority") == "AUTHENTIC_WINDOWS_ISAR_CODEGEN"
    and post_codegen_source.get("sha256")
    == "E2A0F3D38C9A0950922A0B5933A435159E5FA950F361BC8C2B8D6ADB3FEB470A"
    and post_codegen_source.get("codegenResult") == "PASS"
    and post_codegen_source.get("custodyResult") == "PASS"
    and len(post_codegen_bindings) == 19
    and all(
        path.startswith("lib/")
        and path.endswith(".g.dart")
        and isinstance(entry, dict)
        and re.fullmatch(r"[0-9A-F]{64}", str(entry.get("sha256", "")))
        for path, entry in post_codegen_bindings.items()
    )
)
check(
    "Authoritative post-codegen binding register is exact and evidence-bound",
    post_codegen_register_valid,
    f"phase={PHASE} bindings={len(post_codegen_bindings)}",
)

missing: list[str] = []
hash_drift: list[str] = []
generated_phase_paths: list[str] = []
dual_representation_paths: list[str] = []
invalid_representation_rows: list[str] = []
for row in rows:
    rel = row["path"]
    path = ROOT / rel
    if not path.is_file():
        missing.append(rel)
        continue
    actual_sha = sha(path)
    actual_bytes = path.stat().st_size
    if PHASE == "post-codegen" and rel in post_codegen_bindings:
        generated_phase_paths.append(rel)
        if actual_sha != post_codegen_bindings[rel]["sha256"]:
            hash_drift.append(rel)
        continue

    allowed_representations = {
        (row["candidateSha256"], row["candidateBytes"]),
    }
    git_sha = row.get("candidateGitSha256")
    if git_sha is not None:
        dual_representation_paths.append(rel)
        git_bytes = row.get("candidateGitBytes")
        representation_valid = (
            row.get("candidateSha256Representation")
            == "UTF8_CRLF_WINDOWS_WORKTREE"
            and row.get("candidateGitSha256Representation")
            == "UTF8_LF_GIT_BLOB"
            and isinstance(git_bytes, int)
            and git_bytes > 0
            and re.fullmatch(r"[0-9A-F]{64}", str(git_sha)) is not None
            and git_sha != row["candidateSha256"]
            and text_sha_with_eol(path, "\n") == git_sha
        )
        if not representation_valid:
            invalid_representation_rows.append(rel)
        allowed_representations.add((git_sha, git_bytes))
    if (actual_sha, actual_bytes) not in allowed_representations:
        hash_drift.append(rel)

post_codegen_missing: list[str] = []
post_codegen_drift: list[str] = []
if PHASE == "post-codegen":
    for rel, entry in post_codegen_bindings.items():
        path = ROOT / rel
        if not path.is_file():
            post_codegen_missing.append(rel)
        elif sha(path) != entry["sha256"]:
            post_codegen_drift.append(rel)

counts = {key: 0 for key in ("BYTE_IDENTICAL", "SUCCESSOR_MODIFIED", "MISSING")}
for row in rows:
    counts[row["disposition"]] = counts.get(row["disposition"], 0) + 1
check(
    "All 410 captured canonical-main paths are present and phase-pinned",
    len(rows) == 410 and not missing and not hash_drift,
    f"phase={PHASE} generated={len(generated_phase_paths)} missing={len(missing)} drift={len(hash_drift)} paths={','.join(hash_drift[:20])}",
)
check(
    "Windows worktree and Git-blob text representations are exact and semantically identical",
    len(dual_representation_paths) == 19
    and not invalid_representation_rows,
    f"dual={len(dual_representation_paths)} invalid={','.join(invalid_representation_rows)}",
)
check(
    "Authentic generated bindings are exact in post-codegen phase",
    PHASE != "post-codegen" or (not post_codegen_missing and not post_codegen_drift),
    f"phase={PHASE} expected={len(post_codegen_bindings)} missing={len(post_codegen_missing)} drift={len(post_codegen_drift)}",
)
check(
    "Canonical reconciliation is no-loss with explicit successor delta",
    counts.get("BYTE_IDENTICAL") == recon.get("counts", {}).get("BYTE_IDENTICAL")
    and counts.get("SUCCESSOR_MODIFIED") == recon.get("counts", {}).get("SUCCESSOR_MODIFIED")
    and counts.get("BYTE_IDENTICAL") == 232
    and counts.get("SUCCESSOR_MODIFIED") == 178
    and counts.get("MISSING", 0) == 0,
    str(counts),
)

critical_exact = {
    "android/settings.gradle.kts",
    "release/stage2d-f-internal-controlled-deployment-scope.json",
}
row_map = {row["path"]: row for row in rows}
check(
    "Android settings and immutable release authorities remain byte-identical",
    all(
        row_map.get(path, {}).get("disposition") == "BYTE_IDENTICAL"
        for path in critical_exact
    ),
)
check(
    "Mutable workflows, programme-ledger and ledger-contract evolution is explicitly classified",
    all(
        row_map.get(path, {}).get("disposition") == "SUCCESSOR_MODIFIED"
        for path in (
            ".github/workflows/production-artifact.yml",
            ".github/workflows/release-gate.yml",
            ".github/workflows/verification-artifact.yml",
            "governance/programme-ledger.json",
            "test/programme_ledger_contract_test.dart",
            "test/stage2d_f2_programme_ledger_closure_contract_test.dart",
        )
    ),
)
release_gate_source = text(".github/workflows/release-gate.yml")
c02_verification_builder = text(
    "tools/release/New-VerificationArtifact.ps1"
)
c02_production_builder = text(
    "tools/release/New-ProductionArtifact.ps1"
)
c02_verification_verifier = text(
    "tools/release/Test-ReleaseManifest.ps1"
)
c02_production_verifier = text(
    "tools/release/Test-ProductionReleaseManifest.ps1"
)
c02_contract_test = text(
    "test/c02_audit_package_coverage_contract_test.dart"
)
c02_decision = text("docs/v4_2_r1/C02_AUDIT_PACKAGE_COVERAGE.md")
c02_records = [
    record
    for record in data("governance/programme-ledger.json")["technicalFindings"]
    if record.get("findingId") == "C-02"
]
c02_record = c02_records[0] if len(c02_records) == 1 else {}
c02_required_paths = (
    "release_gate.ps1",
    "jest.config.js",
    "governance/programme-ledger.json",
    "tooling/firebase-cli/package.json",
    "tooling/firebase-cli/package-lock.json",
)
check(
    "C-02 governed artifacts bind complete audit-critical source coverage",
    all(
        f"'{path}'" in source
        for path in c02_required_paths
        for source in (
            c02_verification_builder,
            c02_production_builder,
            c02_verification_verifier,
            c02_production_verifier,
        )
    )
    and c02_verification_builder.count(
        "'tooling/firebase-cli/package-lock.json'"
    ) >= 2
    and c02_production_builder.count(
        "'tooling/firebase-cli/package-lock.json'"
    ) >= 2
    and all(
        "Audit-critical source entry is absent from configuration custody"
            in verifier
        and "Governed Firebase CLI lockfile is absent from dependency custody."
            in verifier
        for verifier in (
            c02_verification_verifier,
            c02_production_verifier,
        )
    )
    and "both artifact builders hash-bind every audit-critical source entry"
        in c02_contract_test
    and len(c02_records) == 1
    and c02_record.get("currentStatus") in ("SOURCE_IMPLEMENTED", "CLOSED")
    and len(c02_record.get("requiredExitEvidence", [])) == 4
    and len(c02_record.get("reArmTriggers", [])) >= 5
    and any(
        status in c02_decision
        for status in ("Status: SOURCE_IMPLEMENTED", "Status: CLOSED")
    ),
)
c02_closure_evidence = c02_record.get("evidence", [])
c02_closure_history = [
    entry.get("status")
    for entry in c02_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
c02_closure_receipt_path = (
    ROOT / "release/evidence/c02-audit-package-coverage-closure.json"
)
c02_closure_receipt = data(
    "release/evidence/c02-audit-package-coverage-closure.json"
)
c02_pr_ci = c02_closure_receipt.get("pullRequestCi", {})
c02_postmerge_ci = c02_closure_receipt.get("postMergeCi", {})
c02_boundary = c02_closure_receipt.get("operationalBoundary", {})
check(
    "C-02 audit-package coverage closure is exact and runtime-separated",
    len(c02_records) == 1
    and c02_record.get("currentStatus") == "CLOSED"
    and len(c02_closure_evidence) == 1
    and c02_closure_evidence[0].get("pullRequest") == 154
    and c02_closure_evidence[0].get("headCommit")
        == "06dac6a5b2048592652005f83324b5dc0009dc77"
    and c02_closure_evidence[0].get("sourceTree")
        == "18f1c9881c971132a16a5f092dbc7fc3cd7d40b2"
    and c02_closure_evidence[0].get("mergeCommit")
        == "a3d3a95c44ab788a44952b8de9260fa39b96f462"
    and c02_closure_evidence[0].get("mergeTree")
        == "18f1c9881c971132a16a5f092dbc7fc3cd7d40b2"
    and c02_closure_evidence[0].get("pullRequestWorkflowRun")
        == 30971588062
    and c02_closure_evidence[0].get("postMergeWorkflowRun")
        == 30972062651
    and c02_closure_evidence[0].get("evidenceFile")
        == "release/evidence/c02-audit-package-coverage-closure.json"
    and c02_closure_evidence[0].get("evidenceSha256")
        == sha(c02_closure_receipt_path)
    and c02_closure_history
        == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and c02_closure_receipt.get("decision")
        == "PASS_C02_AUDIT_PACKAGE_COVERAGE_SOURCE_AND_CI_CLOSURE"
    and c02_pr_ci.get("runId") == 30971588062
    and c02_pr_ci.get("event") == "pull_request"
    and c02_pr_ci.get("headSha")
        == "06dac6a5b2048592652005f83324b5dc0009dc77"
    and c02_pr_ci.get("conclusion") == "success"
    and c02_postmerge_ci.get("runId") == 30972062651
    and c02_postmerge_ci.get("event") == "push"
    and c02_postmerge_ci.get("headSha")
        == "a3d3a95c44ab788a44952b8de9260fa39b96f462"
    and c02_postmerge_ci.get("conclusion") == "success"
    and all(
        job.get("conclusion") == "success"
        for section in (c02_pr_ci, c02_postmerge_ci)
        for job in section.get("jobs", [])
    )
    and len(c02_pr_ci.get("jobs", [])) == 4
    and len(c02_postmerge_ci.get("jobs", [])) == 4
    and c02_boundary
    and all(value is False for value in c02_boundary.values())
    and "Status: CLOSED" in c02_decision,
)
c04_catalog = data("governance/test-evidence-taxonomy.json")
c04_validator = text("tools/testing/verify_test_evidence_taxonomy.py")
c04_contract = text("test/c04_test_evidence_taxonomy_contract_test.dart")
c04_integration = text(
    "integration_test/c04_operational_shell_android_test.dart"
)
c04_decision = text("docs/v4_2_r1/C04_TEST_EVIDENCE_TAXONOMY.md")
c04_local_gate = text("release_gate.ps1")
c04_production_policy = text(
    "tools/release/Test-ProductionReleasePolicy.ps1"
)
c04_action_registry = data("release/github-actions-pins.json")
c04_records = [
    record
    for record in data("governance/programme-ledger.json")["technicalFindings"]
    if record.get("findingId") == "C-04"
]
c04_record = c04_records[0] if len(c04_records) == 1 else {}
c04_levels = c04_catalog.get("levels", [])
c04_jobs = c04_catalog.get("ciJobs", [])
c04_critical_paths = c04_catalog.get("criticalPaths", [])
c04_emulator_action = c04_action_registry.get("actions", {}).get(
    "androidEmulatorRunner", {}
)
check(
    "C-04 test levels, critical paths and Android integration are explicit",
    c04_catalog.get("schemaVersion") == 1
    and c04_catalog.get("authority") == "C04_TEST_EVIDENCE_TAXONOMY"
    and len(c04_levels) == 8
    and len({item.get("id") for item in c04_levels}) == 8
    and len(c04_jobs) == 5
    and len({item.get("id") for item in c04_jobs}) == 5
    and len(c04_critical_paths) == 8
    and len({item.get("id") for item in c04_critical_paths}) == 8
    and all(len(item.get("evidence", [])) >= 2 for item in c04_critical_paths)
    and all(
        isinstance(item.get("openEvidenceLevels"), list)
        for item in c04_critical_paths
    )
    and c04_catalog.get("deviceIntegration", {}).get("physicalDeviceEvidence")
        is False
    and c04_catalog.get("deviceIntegration", {}).get("productionCredentialsUsed")
        is False
    and c04_catalog.get("deviceIntegration", {}).get("productionBackendUsed")
        is False
    and "IntegrationTestWidgetsFlutterBinding.ensureInitialized()"
        in c04_integration
    and "TargetPlatform.android" in c04_integration
    and "Templates" in c04_integration
    and "Assign Published" in c04_integration
    and "PASS_C04_TEST_EVIDENCE_TAXONOMY" in c04_validator
    and "GITHUB_STEP_SUMMARY" in c04_validator
    and "levels and critical paths are explicit and evidence-bound"
        in c04_contract
    and "tools/testing/verify_test_evidence_taxonomy.py"
        in release_gate_source
    and "integration_test/c04_operational_shell_android_test.dart"
        in release_gate_source
    and "ReactiveCircus/android-emulator-runner@"
        "a421e43855164a8197daf9d8d40fe71c6996bb0d"
        in release_gate_source
    and "Android emulator app-shell integration (not physical-device evidence)"
        in release_gate_source
    and "Android release package construction (no install)"
        in release_gate_source
    and "Cloud Functions host build + non-emulator tests"
        in release_gate_source
    and "test evidence taxonomy and critical-path coverage" in c04_local_gate
    and "Properties).Count -ne 5" not in c04_production_policy
    and "$requiredProductionActionRepositories" in c04_production_policy
    and "$productionActionReferences" in c04_production_policy
    and c04_emulator_action.get("repository")
        == "ReactiveCircus/android-emulator-runner"
    and c04_emulator_action.get("commitSha")
        == "a421e43855164a8197daf9d8d40fe71c6996bb0d"
    and len(c04_records) == 1
    and c04_record.get("currentStatus") in ("SOURCE_IMPLEMENTED", "CLOSED")
    and len(c04_record.get("requiredExitEvidence", [])) == 4
    and len(c04_record.get("reArmTriggers", [])) >= 8
    and any(
        status in c04_decision
        for status in ("Status: SOURCE_IMPLEMENTED", "Status: CLOSED")
    ),
)
c04_closure_evidence = c04_record.get("evidence", [])
c04_closure_history = [
    entry.get("status")
    for entry in c04_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
c04_closure_receipt_path = (
    ROOT / "release/evidence/c04-test-evidence-taxonomy-closure.json"
)
c04_closure_receipt = data(
    "release/evidence/c04-test-evidence-taxonomy-closure.json"
)
c04_pr_ci = c04_closure_receipt.get("pullRequestCi", {})
c04_postmerge_ci = c04_closure_receipt.get("postMergeCi", {})
c04_source_controls = c04_closure_receipt.get("sourceControls", {})
c04_job_names = {
    "Flutter host analysis + tests + no-loss contracts",
    "Android release package construction (no install)",
    "Android emulator app-shell integration (not physical-device evidence)",
    "Firestore Rules + governed callable emulator",
    "Cloud Functions host build + non-emulator tests",
}
c04_nonproduction_boundary = c04_closure_receipt.get(
    "nonProductionBoundary", {}
)
c04_runtime_boundary = c04_closure_receipt.get("runtimeBoundary", {})
c04_android_boundary = c04_closure_receipt.get(
    "androidIntegrationBoundary", {}
)
check(
    "C-04 test evidence taxonomy closure is exact and runtime-separated",
    c04_record.get("currentStatus") == "CLOSED"
    and len(c04_closure_evidence) == 1
    and c04_closure_evidence[0].get("pullRequest") == 156
    and c04_closure_evidence[0].get("headCommit")
        == "f332f4e780ca1ff4e63d696a549020de85c0e3f8"
    and c04_closure_evidence[0].get("sourceTree")
        == "e645b8adf71b35c5c7a8901081efcca46c48cb53"
    and c04_closure_evidence[0].get("mergeCommit")
        == "cf85476e924fe9941a7170d2bd4f4fa68bafc76d"
    and c04_closure_evidence[0].get("mergeTree")
        == "e645b8adf71b35c5c7a8901081efcca46c48cb53"
    and c04_closure_evidence[0].get("pullRequestWorkflowRun")
        == 30976162718
    and c04_closure_evidence[0].get("pullRequestAndroidEmulatorJob")
        == 92210470843
    and c04_closure_evidence[0].get("postMergeWorkflowRun")
        == 30976649141
    and c04_closure_evidence[0].get("postMergeAndroidEmulatorJob")
        == 92211922597
    and c04_closure_evidence[0].get("evidenceFile")
        == "release/evidence/c04-test-evidence-taxonomy-closure.json"
    and c04_closure_evidence[0].get("evidenceSha256")
        == sha(c04_closure_receipt_path)
    and c04_closure_history
        == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and c04_closure_receipt.get("decision")
        == "PASS_C04_TEST_EVIDENCE_TAXONOMY_SOURCE_AND_CI_CLOSURE"
    and c04_pr_ci.get("runId") == 30976162718
    and c04_pr_ci.get("event") == "pull_request"
    and c04_pr_ci.get("headSha")
        == "f332f4e780ca1ff4e63d696a549020de85c0e3f8"
    and c04_pr_ci.get("conclusion") == "success"
    and c04_postmerge_ci.get("runId") == 30976649141
    and c04_postmerge_ci.get("event") == "push"
    and c04_postmerge_ci.get("headSha")
        == "cf85476e924fe9941a7170d2bd4f4fa68bafc76d"
    and c04_postmerge_ci.get("conclusion") == "success"
    and all(
        len(section.get("jobs", [])) == 5
        and {job.get("name") for job in section.get("jobs", [])}
            == c04_job_names
        and all(
            job.get("conclusion") == "success"
            for job in section.get("jobs", [])
        )
        for section in (c04_pr_ci, c04_postmerge_ci)
    )
    and all(
        control.get("sha256") == sha(ROOT / control.get("path", ""))
        for name, control in c04_source_controls.items()
        if name != "sourceDecisionAtMerge"
    )
    and c04_source_controls.get("sourceDecisionAtMerge", {}).get("sha256")
        == "D91D0FD7E14E4099748D64E4F6FE5CF38B8A4C102235889DF05B4EF786011894"
    and c04_android_boundary.get("timeoutMinutes") == 30
    and c04_android_boundary.get("productionCredentialsUsed") is False
    and c04_android_boundary.get("productionBackendUsed") is False
    and c04_android_boundary.get("physicalDeviceEvidence") is False
    and c04_nonproduction_boundary
    and all(value is False for value in c04_nonproduction_boundary.values())
    and c04_runtime_boundary
    and all(value is False for value in c04_runtime_boundary.values())
    and "Status: CLOSED" in c04_decision
    and "PASS_C04_TEST_EVIDENCE_TAXONOMY_SOURCE_AND_CI_CLOSURE"
        in c04_decision,
)
c03_package_script = text(
    "tools/release/Invoke-CIAndroidPackageProof.ps1"
)
c03_package_test = text("test/c03_android_packaging_ci_contract_test.dart")
c03_package_decision = text("docs/v4_2_r1/C03_ANDROID_PR_PACKAGING.md")
c06_android_build = text("android/app/build.gradle.kts")
c06_proguard_rules = text("android/app/proguard-rules.pro")
c06_contract_test = text("test/c06_android_release_shrinking_contract_test.dart")
c06_decision = text("docs/v4_2_r1/C06_ANDROID_RELEASE_SHRINKING.md")
c03_job_start = release_gate_source.find("\n  android-package:")
c03_job_end = release_gate_source.find("\n  firestore-rules:", c03_job_start + 1)
c03_job_source = (
    release_gate_source[c03_job_start:c03_job_end]
    if c03_job_start >= 0 and c03_job_end > c03_job_start
    else ""
)
check(
    "C-03 every-PR Android release packaging is secret-isolated and complete",
    "pull_request:" in release_gate_source
    and "push:" in release_gate_source
    and 'push:\n    branches: ["main"]' in release_gate_source
    and 'pull_request:\n    branches: ["**"]' in release_gate_source
    and 'push:\n    branches: ["**"]' not in release_gate_source
    and "Invoke-CIAndroidPackageProof.ps1" in c03_job_source
    and "${{ secrets." not in c03_job_source
    and "\n    environment:" not in c03_job_source
    and "upload-artifact" not in c03_job_source
    and "CI packaging proof refuses pre-existing signing input"
        in c03_package_script
    and "RandomNumberGenerator]::Create()" in c03_package_script
    and "$generator.GetBytes($bytes)" in c03_package_script
    and "New-Object byte[] 24" in c03_package_script
    and "'appbundle'" in c03_package_script
    and "'apk'" in c03_package_script
    and "'--release'" in c03_package_script
    and "policy.signing.certificateSha256" in c03_package_script
    and "Ephemeral CI signer unexpectedly matches the production certificate."
        in c03_package_script
    and "APK signer does not match" in c03_package_script
    and "AAB signer does not match" in c03_package_script
    and "productionSecretsReferenced=false" in c03_package_script
    and "artifactUploadPerformed=false" in c03_package_script
    and "release gate builds APK and AAB with no production authority"
        in c03_package_test
    and "Status: CLOSED" in c03_package_decision
    and "PASS_C03_ANDROID_PR_PACKAGING_SOURCE_AND_CI_CLOSURE"
        in c03_package_decision,
)
check(
    "C-06 Android release shrinking is enabled and continuously package-proved",
    row_map.get("android/app/build.gradle.kts", {}).get("disposition")
        == "SUCCESSOR_MODIFIED"
    and "isMinifyEnabled = true" in c06_android_build
    and "isShrinkResources = true" in c06_android_build
    and "proguard-android-optimize.txt" in c06_android_build
    and '"proguard-rules.pro"' in c06_android_build
    and "isMinifyEnabled = false" not in c06_android_build
    and "isShrinkResources = false" not in c06_android_build
    and "-dontshrink" not in c06_proguard_rules.lower()
    and "-dontoptimize" not in c06_proguard_rules.lower()
    and "-dontobfuscate" not in c06_proguard_rules.lower()
    and "-keep class **" not in c06_proguard_rules.lower()
    and "outputs/mapping/release/mapping.txt" in c03_package_script
    and "outputs/mapping/release/resources.txt" in c03_package_script
    and "Expected release-shrinking evidence was not created"
        in c03_package_script
    and "Release-shrinking evidence is empty" in c03_package_script
    and "PASS_C06_ANDROID_RELEASE_SHRINKING_PROOF" in c03_package_script
    and "r8MappingSha256=" in c03_package_script
    and "resourceShrinkReportSha256=" in c03_package_script
    and "package proof requires fresh nonempty shrinking evidence"
        in c06_contract_test
    and "Status: CLOSED" in c06_decision
    and "does not transfer its device evidence to a later build"
        in c06_decision,
)
c03_closure_records = [
    record
    for record in data("governance/programme-ledger.json")["technicalFindings"]
    if record.get("findingId") == "C-03"
]
c03_closure_record = (
    c03_closure_records[0] if len(c03_closure_records) == 1 else {}
)
c03_closure_evidence = c03_closure_record.get("evidence", [])
c03_closure_history = [
    entry.get("status")
    for entry in c03_closure_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
c03_closure_receipt_path = (
    ROOT / "release/evidence/c03-android-pr-packaging-closure.json"
)
c03_closure_receipt = data(
    "release/evidence/c03-android-pr-packaging-closure.json"
)
c03_pr_ci = c03_closure_receipt.get("pullRequestCi", {})
c03_postmerge_ci = c03_closure_receipt.get("postMergeCi", {})
c03_boundary = c03_closure_receipt.get("nonProductionBoundary", {})
check(
    "C-03 Android PR packaging closure is exact, evidence-bound and re-armable",
    len(c03_closure_records) == 1
    and c03_closure_record.get("currentStatus") == "CLOSED"
    and len(c03_closure_evidence) == 1
    and c03_closure_evidence[0].get("pullRequest") == 79
    and c03_closure_evidence[0].get("headCommit")
        == "1021ccd0a628112f8e1e50ace1664b721e3ccb88"
    and c03_closure_evidence[0].get("sourceTree")
        == "f0737f16c42d4005d55108dcac3591e64a510b30"
    and c03_closure_evidence[0].get("mergeCommit")
        == "34ff071ee39d55c16cc7578c8898f00a371164c8"
    and c03_closure_evidence[0].get("pullRequestWorkflowRun")
        == 30511076330
    and c03_closure_evidence[0].get("postMergeWorkflowRun")
        == 30524580357
    and c03_closure_evidence[0].get("evidenceFile")
        == "release/evidence/c03-android-pr-packaging-closure.json"
    and c03_closure_evidence[0].get("evidenceSha256")
        == sha(c03_closure_receipt_path)
    and c03_closure_history
        == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and c03_closure_receipt.get("decision")
        == "PASS_C03_ANDROID_PR_PACKAGING_SOURCE_AND_CI_CLOSURE"
    and c03_pr_ci.get("event") == "pull_request"
    and c03_pr_ci.get("headSha")
        == "1021ccd0a628112f8e1e50ace1664b721e3ccb88"
    and c03_pr_ci.get("conclusion") == "success"
    and c03_postmerge_ci.get("event") == "push"
    and c03_postmerge_ci.get("headSha")
        == "34ff071ee39d55c16cc7578c8898f00a371164c8"
    and c03_postmerge_ci.get("conclusion") == "success"
    and all(
        job.get("conclusion") == "success"
        for section in (c03_pr_ci, c03_postmerge_ci)
        for job in section.get("jobs", [])
    )
    and len(c03_pr_ci.get("jobs", [])) == 4
    and len(c03_postmerge_ci.get("jobs", [])) == 4
    and c03_boundary
    and all(value is False for value in c03_boundary.values())
    and len(c03_closure_record.get("requiredExitEvidence", [])) == 4
    and len(c03_closure_record.get("reArmTriggers", [])) >= 6,
)
c06_closure_records = [
    record
    for record in data("governance/programme-ledger.json")["technicalFindings"]
    if record.get("findingId") == "C-06"
]
c06_closure_record = (
    c06_closure_records[0] if len(c06_closure_records) == 1 else {}
)
c06_closure_evidence = c06_closure_record.get("evidence", [])
c06_closure_history = [
    entry.get("status")
    for entry in c06_closure_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
c06_closure_receipt_path = (
    ROOT / "release/evidence/c06-android-release-shrinking-closure.json"
)
c06_closure_receipt = data(
    "release/evidence/c06-android-release-shrinking-closure.json"
)
c06_pr_ci = c06_closure_receipt.get("pullRequestCi", {})
c06_postmerge_ci = c06_closure_receipt.get("postMergeCi", {})
c06_boundaries = (
    c06_closure_receipt.get("nonProductionBoundary", {}),
    c06_closure_receipt.get("runtimeBoundary", {}),
)
check(
    "C-06 Android release shrinking closure is exact and runtime-separated",
    len(c06_closure_records) == 1
    and c06_closure_record.get("currentStatus") == "CLOSED"
    and len(c06_closure_evidence) == 1
    and c06_closure_evidence[0].get("pullRequest") == 152
    and c06_closure_evidence[0].get("headCommit")
        == "6af4bd411a15611f790138c38e35f3918e9f807d"
    and c06_closure_evidence[0].get("sourceTree")
        == "b6c0129e14107d09ea8ffd822b305af177824691"
    and c06_closure_evidence[0].get("mergeCommit")
        == "cacab29a5cf79bdc723a80b9e4a33557f7a1eada"
    and c06_closure_evidence[0].get("mergeTree")
        == "b6c0129e14107d09ea8ffd822b305af177824691"
    and c06_closure_evidence[0].get("pullRequestWorkflowRun")
        == 30942169313
    and c06_closure_evidence[0].get("pullRequestAndroidJob")
        == 92103071831
    and c06_closure_evidence[0].get("postMergeWorkflowRun")
        == 30942876995
    and c06_closure_evidence[0].get("postMergeAndroidJob")
        == 92105447536
    and c06_closure_evidence[0].get("evidenceFile")
        == "release/evidence/c06-android-release-shrinking-closure.json"
    and c06_closure_evidence[0].get("evidenceSha256")
        == sha(c06_closure_receipt_path)
    and c06_closure_history
        == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and c06_closure_receipt.get("decision")
        == "PASS_C06_ANDROID_RELEASE_SHRINKING_SOURCE_AND_CI_CLOSURE"
    and c06_pr_ci.get("runId") == 30942169313
    and c06_pr_ci.get("event") == "pull_request"
    and c06_pr_ci.get("headSha")
        == "6af4bd411a15611f790138c38e35f3918e9f807d"
    and c06_pr_ci.get("conclusion") == "success"
    and c06_postmerge_ci.get("runId") == 30942876995
    and c06_postmerge_ci.get("event") == "push"
    and c06_postmerge_ci.get("headSha")
        == "cacab29a5cf79bdc723a80b9e4a33557f7a1eada"
    and c06_postmerge_ci.get("conclusion") == "success"
    and all(
        job.get("conclusion") == "success"
        for section in (c06_pr_ci, c06_postmerge_ci)
        for job in section.get("jobs", [])
    )
    and len(c06_pr_ci.get("jobs", [])) == 4
    and len(c06_postmerge_ci.get("jobs", [])) == 4
    and all(
        section.get("androidProofMarkers", {}).get("decision")
            == "PASS_C06_ANDROID_RELEASE_SHRINKING_PROOF"
        and section.get("androidProofMarkers", {}).get("r8MappingSha256")
            == "21832BEEC5CD7E812C3559B4CBCDE950A3B9B760A2986217EDAE5B17CEF1E39F"
        and len(
            section.get("androidProofMarkers", {}).get(
                "resourceShrinkReportSha256", ""
            )
        ) == 64
        for section in (c06_pr_ci, c06_postmerge_ci)
    )
    and all(
        boundary and all(value is False for value in boundary.values())
        for boundary in c06_boundaries
    )
    and len(c06_closure_record.get("requiredExitEvidence", [])) == 4
    and len(c06_closure_record.get("reArmTriggers", [])) >= 8
    and "PASS_C06_ANDROID_RELEASE_SHRINKING_SOURCE_AND_CI_CLOSURE"
        in c06_decision,
)
manual_workflows = (
    ".github/workflows/production-artifact.yml",
    ".github/workflows/verification-artifact.yml",
)
unsafe_dispatch_run_blocks = [
    f"{rel}#{index + 1}"
    for rel in manual_workflows
    for index, block in enumerate(yaml_run_blocks(text(rel)))
    if re.search(r"\$\{\{\s*(?:inputs|github\.event\.inputs)\.", block)
]
check(
    "Manual dispatch values remain data and never become shell source",
    not unsafe_dispatch_run_blocks
    and all("CRM_DISPATCH_" in text(rel) for rel in manual_workflows)
    and "test:workflow-input-custody" in text("package.json")
    and "npm run test:workflow-input-custody"
        in text(".github/workflows/release-gate.yml")
    and (ROOT / "tools/release/workflow_dispatch_input_custody.mjs").is_file()
    and (
        ROOT / "tools/release/workflow_dispatch_input_custody.test.mjs"
    ).is_file(),
    ",".join(unsafe_dispatch_run_blocks),
)
workflow_paths = tuple(
    str(path.relative_to(ROOT)).replace("\\", "/")
    for path in sorted((ROOT / ".github" / "workflows").glob("*.y*ml"))
)
workflow_action_refs = [
    (rel, match.group(1))
    for rel in workflow_paths
    for match in re.finditer(
        r"^\s*(?:-\s*)?uses:\s*([^\s#]+)",
        text(rel),
        flags=re.MULTILINE,
    )
]
mutable_workflow_action_refs = [
    f"{rel}:{reference}"
    for rel, reference in workflow_action_refs
    if not reference.startswith("./")
    and re.fullmatch(r"[^@\s]+@[0-9a-fA-F]{40}", reference) is None
    and re.fullmatch(
        r"docker://[^@\s]+@sha256:[0-9a-fA-F]{64}",
        reference,
    ) is None
]
check(
    "Workflow action references are immutable and repository-wide custody is CI-enforced",
    not mutable_workflow_action_refs
    and len(workflow_action_refs) == 25
    and "test:workflow-action-custody" in text("package.json")
    and "npm run test:workflow-action-custody"
        in text(".github/workflows/release-gate.yml")
    and (ROOT / "tools/release/workflow_action_ref_custody.mjs").is_file()
    and (
        ROOT / "tools/release/workflow_action_ref_custody.test.mjs"
    ).is_file(),
    ",".join(mutable_workflow_action_refs),
)
c01_records = [
    record
    for record in data("governance/programme-ledger.json")["technicalFindings"]
    if record.get("findingId") == "C-01"
]
c01_record = c01_records[0] if len(c01_records) == 1 else {}
c01_evidence = c01_record.get("evidence", [])
c01_history = [
    entry.get("status")
    for entry in c01_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
c01_decision = text("docs/v4_2_r1/C01_WORKFLOW_DISPATCH_INPUT_CUSTODY.md")
check(
    "C-01 workflow dispatch custody closure is exact and re-armable",
    len(c01_records) == 1
    and c01_record.get("currentStatus") == "CLOSED"
    and len(c01_evidence) == 1
    and c01_evidence[0].get("pullRequest") == 57
    and c01_evidence[0].get("headCommit")
        == "7b3582768c84fef276b08617212efe1e6a996f38"
    and c01_evidence[0].get("sourceTree")
        == "9508441e7261ca8bdeb80afab31b0a63df2f55f3"
    and c01_evidence[0].get("mergeCommit")
        == "34e8f4a314fcd03991d535d050614b96eeaf3204"
    and c01_evidence[0].get("postMergeWorkflowRun") == 30293820019
    and c01_evidence[0].get("decision")
        == "PASS_C01_WORKFLOW_DISPATCH_INPUT_CUSTODY"
    and c01_evidence[0].get("productionWorkflowDispatched") is False
    and c01_evidence[0].get("productionMutationPerformed") is False
    and c01_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(c01_record.get("requiredExitEvidence", [])) >= 4
    and len(c01_record.get("reArmTriggers", [])) >= 5
    and "Status: CLOSED" in c01_decision
    and "PR #57" in c01_decision
    and "30293820019" in c01_decision
    and "PASS_C01_WORKFLOW_DISPATCH_INPUT_CUSTODY" in c01_decision
    and "No production workflow was dispatched" in c01_decision,
)

for lock_rel in ("package-lock.json", "functions/package-lock.json"):
    lock = data(lock_rel)
    websocket = lock.get("packages", {}).get("node_modules/websocket-driver", {})
    check(
        f"PR39 websocket-driver closure remains present in {lock_rel}",
        websocket.get("version") == "0.7.5"
        and websocket.get("integrity") == "sha512-ZL2+3c7kMBdIRCMz6l8jQMHyGVxj+UL+xVk74Ombiciboca8rHa15L86B19E5oh1pL9Ii/uj54gtsIrZGMo6zA==",
    )

user_authority = text("functions/src/userAuthority.ts")
consumers = {
    "functions/src/maintenanceWorkflow/callable.ts": "canonicalApprovedUserAuthority",
    "functions/src/runtimeJobModulePopulation.ts": "canonicalApprovedUserAuthority",
    "functions/src/publishedTemplateAssignment.ts": "canonicalUserHasAnyRole",
    "functions/src/plannedJobClosure.ts": "canonicalUserHasAnyRole",
    "functions/src/backendReleaseIdentity.ts": "canonicalApprovedUserAuthority",
    "functions/src/notifications.ts": "canonicalApprovedUserAuthority",
}
check(
    "Backend approval authority is singular and generated-policy aligned",
    "WORKFLOW_ROLE_UNIVERSE" in user_authority
    and "const capsule = canonicalUserAuthorityCapsule(data)" in user_authority
    and "capsule == null || !capsule.isApproved" in user_authority
    and all(marker in text(path) for path, marker in consumers.items()),
    f"consumers={len(consumers)}",
)
check(
    "Canonical authority unit tests cover legacy aliases and malformed roles",
    "fails closed for legacy or malformed authority" in text("functions/test/userAuthority.test.js")
    and "role checks cannot bypass malformed authority" in text("functions/test/userAuthority.test.js"),
)
check(
    "Canonical authority returns its validated map and consumers use that narrowed result",
    "readonly data: UserAuthorityJsonMap" in user_authority
    and "return {data, roles: capsule.roles}" in user_authority
    and "tokenLookupsForApprovedUser(db, uid, authority.data)"
        in text("functions/src/notifications.ts")
    and "authorityData.fcmToken" in text("functions/src/notifications.ts")
    and "return {userData: authority.data, roles}" in text("functions/src/runtimeJobModulePopulation.ts")
    and "expect(authority.data).toBe(data)" in text("functions/test/userAuthority.test.js"),
)

harness = text("tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1")
forbidden = ("firebase deploy", "git push", "git merge", "git tag", "adb uninstall", "pm clear")
check(
    "Trial harness uses a disposable workspace and tiered outcomes",
    "Copy-PristineTree" in harness
    and "Disposable workspace" in harness
    and "PASS_AUTHORITATIVE_BUILD_ONLY" in harness
    and "PASS_AUTHORITATIVE_BUILD_AND_EMULATOR" in harness
    and "PASS_DIAGNOSTIC_BUILD_ONLY" in harness
    and "HOLD_TOOLCHAIN_MISMATCH" in harness,
)
check(
    "Trial harness exact-binds both canonical Firebase build inputs",
    "07912823FCC37500C785BE26741B3930087D7A47F02F5E2268F7C7FC1A6031DE" in harness
    and "2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B" in harness
    and "6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7" in harness
    and "Assert-AllowedHash" in harness,
)
check(
    "Trial harness enforces full pinned toolchain and lockfile stability",
    all(item in harness for item in ("22.23.1", "10.9.8", "21.0.11", "3.44.0", "3.12.0"))
    and "Assert-LockfilesStable" in harness
    and "HOLD_LOCKFILE_DRIFT" in harness,
)
check(
    "Functions compiler is an early no-emit gate immediately after dependency installation",
    "08_functions_typecheck" in harness
    and "HOLD_FUNCTIONS_TYPECHECK" in harness
    and "npm run typecheck" in harness
    and harness.index("07_functions_npm_ci") < harness.index("08_functions_typecheck") < harness.index("11_firebase_cli_npm_ci"),
)
functions_package_scripts = data("functions/package.json").get("scripts", {})
emitted_output_custody = text("functions/tools/emitted_output_custody.mjs")
emitted_output_custody_test = text(
    "functions/tools/emitted_output_custody.test.mjs"
)
check(
    "Functions builds clean and prove exact TypeScript emitted-output correspondence",
    functions_package_scripts.get("clean")
        == "node tools/emitted_output_custody.mjs clean"
    and functions_package_scripts.get("typecheck") == "tsc --noEmit --pretty false"
    and functions_package_scripts.get("audit:emitted-output")
        == "node tools/emitted_output_custody.mjs audit"
    and functions_package_scripts.get("build")
        == (
            "npm run clean && tsc --pretty false && "
            "npm run audit:emitted-output && npm run audit:callable-inventory && "
            "npm run audit:notification-inventory"
        )
    and functions_package_scripts.get("test:emitted-output-custody")
        == "node --test tools/emitted_output_custody.test.mjs"
    and "ts.getOutputFileNames" in emitted_output_custody
    and "orphaned emitted files" in emitted_output_custody
    and "a deleted source cannot leave orphaned JavaScript or source maps"
        in emitted_output_custody_test
    and "a missing emitted file fails correspondence" in emitted_output_custody_test,
)
authority_mutation_fingerprint_source = text(
    "functions/src/userAuthorityMutation.ts"
)
authority_mutation_fingerprint_test = text(
    "functions/test/userAuthorityMutation.test.js"
)
authority_mutation_fingerprint_emulator_test = text(
    "functions/test/userAuthorityMutation.firestoreEmulator.test.js"
)
authority_mutation_decision = text(
    "docs/v4_2_r1/S05_ATOMIC_AUTHORITY_MUTATION.md"
)
check(
    "S-05 authority receipts use versioned canonical fingerprints with legacy replay",
    'from "./stableJson"' in authority_mutation_fingerprint_source
    and "authreq2-sha256:" in authority_mutation_fingerprint_source
    and "authreq1-sha256:" in authority_mutation_fingerprint_source
    and "schemaVersion: 2" in authority_mutation_fingerprint_source
    and "authority-receipt-fingerprint-version-unsupported"
        in authority_mutation_fingerprint_source
    and "v2 canonical JSON is independent of object insertion order"
        in authority_mutation_fingerprint_test
    and "v1 and v2 algorithms retain frozen, distinct vectors"
        in authority_mutation_fingerprint_test
    and "historical authreq1 receipts replay through the frozen legacy algorithm"
        in authority_mutation_fingerprint_emulator_test
    and "unknown receipt fingerprint versions fail closed as data loss"
        in authority_mutation_fingerprint_emulator_test
    and "`authreq2-sha256`" in authority_mutation_decision
    and "`authreq1-sha256`" in authority_mutation_decision,
)
functions_package = data("functions/package.json")
functions_root_entrypoint = text("functions/index.js").replace("\r\n", "\n").strip()
functions_entrypoint_test = text("functions/test/functionsEntrypointSource.test.js")
functions_cleanup_decision = text(
    "docs/v4_2_r1/FUNCTIONS_ENTRYPOINT_AND_WORKFLOW_IDENTITY_CLEANUP.md"
)
c05_records = [
    record
    for record in data("governance/programme-ledger.json")["technicalFindings"]
    if record.get("findingId") == "C-05"
]
c05_record = c05_records[0] if len(c05_records) == 1 else {}
c05_evidence = c05_record.get("evidence", [])
c05_history = [
    entry.get("status")
    for entry in c05_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
workflow_types = text("functions/src/maintenanceWorkflow/types.ts")
workflow_callable = text("functions/src/maintenanceWorkflow/callable.ts")
workflow_dispatcher = text("functions/src/maintenanceWorkflow/dispatcher.ts")
workflow_adjudication_emulator = text(
    "functions/test/workflowAuthorityReplayAdjudication.firestoreEmulator.test.js"
)
check(
    "C-05 Functions entrypoint closure is exact and workflow preflight roles cannot enter service context",
    functions_package.get("main") == "lib/index.js"
    and functions_root_entrypoint
        == '"use strict";\n\nmodule.exports = require("./lib/index.js");'
    and "package and root compatibility path resolve to one compiled entrypoint"
        in functions_entrypoint_test
    and "interface CommandActorIdentity" in workflow_types
    and "interface CommandInvocationContext" in workflow_types
    and "readonly actor: CommandActorIdentity" in workflow_types
    and "Promise<CommandActorIdentity>" in workflow_callable
    and "uid: authorizedActor.uid" in workflow_callable
    and "name: authorizedActor.name" in workflow_callable
    and "context: CommandInvocationContext" in workflow_dispatcher
    and "They must pass" in workflow_adjudication_emulator
    and "expected to FAIL" not in workflow_adjudication_emulator
    and len(c05_records) == 1
    and c05_record.get("currentStatus") == "CLOSED"
    and len(c05_evidence) == 1
    and c05_evidence[0].get("pullRequest") == 64
    and c05_evidence[0].get("headCommit")
        == "ee1bfa2b9c448db983a093d6dbbad1f2452eba45"
    and c05_evidence[0].get("sourceTree")
        == "47872d1ba609504e99e354a82147bb7aacacd09e"
    and c05_evidence[0].get("mergeCommit")
        == "023945f45a402202ed61a0f7f7076f50868832f6"
    and c05_evidence[0].get("mergeTree")
        == "47872d1ba609504e99e354a82147bb7aacacd09e"
    and c05_evidence[0].get("postMergeWorkflowRun") == 30377037890
    and c05_evidence[0].get("decision")
        == "PASS_C05_SINGULAR_FUNCTIONS_ENTRYPOINT"
    and c05_evidence[0].get("functionsDeployed") is False
    and c05_evidence[0].get("productionMutationPerformed") is False
    and c05_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(c05_record.get("requiredExitEvidence", [])) >= 5
    and len(c05_record.get("reArmTriggers", [])) >= 4
    and "Status: CLOSED" in functions_cleanup_decision
    and "PASS_C05_SINGULAR_FUNCTIONS_ENTRYPOINT" in functions_cleanup_decision,
)
check(
    "Canonical audit runs in explicit post-codegen phase after custody and Isar release authority",
    "'tools/v4/v4_2_r1_canonical_audit.py' '--phase' 'post-codegen'" in harness
    and harness.index("17_post_codegen_custody")
    < harness.index("18_canonical_isar_semantic_continuity")
    < harness.index("19_isar_release_authority")
    < harness.index("20_v42_r1_audit"),
)
check(
    "Trial harness contains no remote/deploy/destructive command and is structurally balanced",
    all(item not in harness.lower() for item in forbidden)
    and powershell_balanced(harness)
    and 'Private/internal npm registry URL found in ${rel}: $pattern' in harness,
)

implicit_text_io: list[str] = []
for python_path in sorted((ROOT / "tools").rglob("*.py")):
    source = python_path.read_text(encoding="utf-8")
    try:
        tree = ast.parse(source, filename=str(python_path))
    except SyntaxError as exc:
        implicit_text_io.append(
            f"{python_path.relative_to(ROOT).as_posix()}:syntax-error:{exc.lineno}"
        )
        continue
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute):
            continue
        if node.func.attr not in {"read_text", "write_text"}:
            continue
        if not any(keyword.arg == "encoding" for keyword in node.keywords):
            implicit_text_io.append(
                f"{python_path.relative_to(ROOT).as_posix()}:{node.lineno}:{node.func.attr}"
            )
check(
    "Python text-file tooling is locale-independent UTF-8",
    not implicit_text_io,
    f"implicit={len(implicit_text_io)}"
    + (f" paths={implicit_text_io[:5]}" if implicit_text_io else ""),
)

firebase_key_policy = data("release/firebase-client-api-key-policy.json")
firebase_key_source_audit = text(
    "tools/security/firebase_client_api_key_custody.cjs"
)
firebase_key_source_test = text(
    "tools/security/firebase_client_api_key_custody.test.mjs"
)
firebase_key_readback = text(
    "tools/security/collect_firebase_client_api_key_readback.cjs"
)
firebase_key_readback_test = text(
    "tools/security/collect_firebase_client_api_key_readback.test.mjs"
)
firebase_key_security_policy = text("SECURITY.md")
firebase_key_decision = text(
    "docs/v4_2_r1/FIREBASE_CLIENT_API_KEY_CUSTODY.md"
)
root_package = data("package.json")
firebase_key_source_policy = firebase_key_policy.get("sourceCustody", {})
firebase_key_live_policy = firebase_key_policy.get("liveReadback", {})
firebase_key_expected_keys = firebase_key_live_policy.get("expectedKeys", [])
firebase_key_expected_targets = firebase_key_live_policy.get(
    "expectedApiTargets", []
)
firebase_key_approved_targets = [
    "cloudconfig.googleapis.com",
    "datastore.googleapis.com",
    "fcmregistrations.googleapis.com",
    "firebase.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebaseappdistribution.googleapis.com",
    "firebaseapphosting.googleapis.com",
    "firebaseapptesters.googleapis.com",
    "firebasedatabase.googleapis.com",
    "firebasedataconnect.googleapis.com",
    "firebasehosting.googleapis.com",
    "firebaseinappmessaging.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "firebaseml.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "firebaseremoteconfigrealtime.googleapis.com",
    "firebaserules.googleapis.com",
    "firebasestorage.googleapis.com",
    "firebasevertexai.googleapis.com",
    "firestore.googleapis.com",
    "fpnv.googleapis.com",
    "identitytoolkit.googleapis.com",
    "logging.googleapis.com",
    "mlkit.googleapis.com",
    "play.googleapis.com",
    "securetoken.googleapis.com",
    "sqladmin.googleapis.com",
]
check(
    "Firebase client API keys are source-custodied and live-restriction bound",
    firebase_key_policy.get("schemaVersion") == 1
    and firebase_key_policy.get("firebaseProjectId") == "crm3-baf-ops-b8638"
    and firebase_key_policy.get("projectNumber") == "894346496105"
    and firebase_key_source_policy.get("allowedTrackedPaths")
        == [
            "android/app/google-services.json",
            "lib/firebase_options.dart",
        ]
    and firebase_key_source_policy.get("expectedDistinctKeyCount") == 3
    and firebase_key_source_policy.get("firebaseOptionsOccurrenceCount") == 5
    and firebase_key_source_policy.get("googleServicesOccurrenceCount") == 2
    and firebase_key_source_policy.get("googleServicesDistinctKeyCount") == 1
    and sorted(
        key.get("displayName")
        for key in firebase_key_expected_keys
        if isinstance(key, dict)
    )
        == [
            "Android key (auto created by Firebase)",
            "Browser key (auto created by Firebase)",
            "iOS key (auto created by Firebase)",
        ]
    and sorted(
        restriction.get("type")
        for key in firebase_key_expected_keys
        if isinstance(key, dict)
        for restriction in key.get("applicationRestrictions", [])
        if isinstance(restriction, dict)
    ) == ["android", "browser", "ios"]
    and all(
        restriction.get("entryCount") == 0
        for key in firebase_key_expected_keys
        if isinstance(key, dict)
        for restriction in key.get("applicationRestrictions", [])
        if isinstance(restriction, dict)
    )
    and all(
        restriction.get("valueSha256")
            == "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A"
        for key in firebase_key_expected_keys
        if isinstance(key, dict)
        for restriction in key.get("applicationRestrictions", [])
        if isinstance(restriction, dict)
    )
    and firebase_key_expected_targets == firebase_key_approved_targets
    and "generativelanguage.googleapis.com"
        not in firebase_key_expected_targets
    and firebase_key_live_policy.get("forbiddenApiTargets")
        == ["generativelanguage.googleapis.com"]
    and not (ROOT / "tools/direct_completion_denial_check.html").exists()
    and not (ROOT / "tools/direct_completion_denial_check.mjs").exists()
    and "PASS_FIREBASE_CLIENT_API_KEY_SOURCE_CUSTODY"
        in firebase_key_source_audit
    and "keyPathsExact" in firebase_key_source_audit
    and "androidKeysBoundToFlutterOptions" in firebase_key_source_audit
    and "rawKeyValuesEmitted: false" in firebase_key_source_audit
    and "a key copied into any additional tracked file fails closed"
        in firebase_key_source_test
    and "PASS_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY"
        in firebase_key_readback
    and "OBSERVE_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY"
        in firebase_key_readback
    and "getProjectDefaultAccount" in firebase_key_readback
    and "/keyString" in firebase_key_readback
    and "governedSourceClean" in firebase_key_readback
    and "rawKeyValuesRetained: false" in firebase_key_readback
    and "a non-Firebase target or changed application restriction fails closed"
        in firebase_key_readback_test
    and "strict readback cannot pass from a materially dirty source tree"
        in firebase_key_readback_test
    and root_package.get("scripts", {}).get(
        "test:firebase-client-key-custody"
    )
        == "node --test tools/security/firebase_client_api_key_custody.test.mjs tools/security/collect_firebase_client_api_key_readback.test.mjs && node tools/security/firebase_client_api_key_custody.cjs"
    and "npm run test:firebase-client-key-custody" in release_gate_source
    and "https://firebase.google.com/docs/projects/api-keys"
        in firebase_key_security_policy
    and "App Check is a separate anti-abuse control"
        in firebase_key_security_policy
    and "each with zero entries" in firebase_key_decision
    and "No key rotation, API restriction mutation" in firebase_key_decision,
)

firestore_readback_source = text(
    "tools/release/collectFirestoreRulesIndexesReadback.js"
)
firestore_readback_test = text(
    "tools/release/collectFirestoreRulesIndexesReadback.test.mjs"
)
firestore_readback_decision = text(
    "docs/v4_2_r1/FIRESTORE_RULES_INDEXES_LIVE_READBACK.md"
)
check(
    "Firestore Rules and indexes have a read-only fail-closed live-readback collector",
    "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK" in firestore_readback_source
    and "OBSERVE_FIRESTORE_RULES_INDEXES_LIVE_READBACK"
        in firestore_readback_source
    and "getProjectDefaultAccount" in firestore_readback_source
    and "/releases/cloud.firestore" in firestore_readback_source
    and "collectionGroups/-/indexes" in firestore_readback_source
    and '"firestore:indexes"' in firestore_readback_source
    and "sourceCommitMatchesOriginMain" in firestore_readback_source
    and "governedSourceClean" in firestore_readback_source
    and "firestoreDocumentsRead: false" in firestore_readback_source
    and all(
        forbidden not in firestore_readback_source
        for forbidden in (
            ".post(",
            ".put(",
            ".patch(",
            ".delete(",
            "firebase deploy",
            "firestore:delete",
        )
    )
    and "Rules byte drift fails closed without retaining Rules content"
        in firestore_readback_test
    and "strict readback cannot pass from dirty, detached or stale source"
        in firestore_readback_test
    and "collector source contains no production mutation route"
        in firestore_readback_test
    and root_package.get("scripts", {}).get(
        "test:firestore-live-readback-custody"
    )
        == "node --test tools/release/collectFirestoreRulesIndexesReadback.test.mjs"
    and "npm run test:firestore-live-readback-custody" in release_gate_source
    and "does not close `LR-02` or `P-04` by source assertion"
        in firestore_readback_decision
    and "It does not read Firestore documents." in firestore_readback_decision,
)

functions_live_readback_policy = data(
    "release/lr03-lr06-functions-live-readback-policy.json"
)
functions_live_readback_source = text(
    "tools/release/collectFunctionsIamDependenciesReadback.js"
)
functions_live_readback_test = text(
    "tools/release/collectFunctionsIamDependenciesReadback.test.mjs"
)
functions_live_readback_contract = text(
    "test/lr03_lr06_functions_live_readback_collector_contract_test.dart"
)
functions_live_readback_closure_contract = text(
    "test/lr03_lr06_live_readback_closure_contract_test.dart"
)
functions_live_readback_decision = text(
    "docs/v4_2_r1/LR03_LR06_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK.md"
)
functions_live_readback_index = text("functions/src/index.ts")
functions_live_ledger = data("governance/programme-ledger.json")
functions_live_receipt_path = (
    ROOT
    / "release/evidence/lr03-lr06-functions-iam-dependency-live-readback.json"
)
functions_live_closure_path = (
    ROOT / "release/evidence/lr03-lr06-live-readback-closure.json"
)
functions_live_receipt = data(
    "release/evidence/lr03-lr06-functions-iam-dependency-live-readback.json"
)
functions_live_closure = data(
    "release/evidence/lr03-lr06-live-readback-closure.json"
)
functions_live_receipt_body = {
    key: value
    for key, value in functions_live_receipt.items()
    if key != "receiptSha256"
}
functions_live_receipt_seal = hashlib.sha256(
    json.dumps(
        functions_live_receipt_body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
functions_live_expected_exports = [
    "assignPublishedTemplateVersion",
    "beginGlobalPullRun",
    "completePlannedJobExecution",
    "executeMaintenanceWorkflowCommand",
    "getBackendReleaseIdentity",
    "maintenanceWorkflowEscalationSweep",
    "mutateChargeAbnormality",
    "mutateRuntimeJobModulePopulation",
    "mutateUserAuthority",
    "onJobAssigned",
    "onMaintenanceWorkflowEventCreated",
    "onTicketCreated",
    "onTicketResolved",
    "stampGlobalPullServerClock",
]
functions_live_gate_records = {
    record.get("gateId"): record
    for record in functions_live_ledger.get("programmeGates", [])
    if record.get("gateId") in {"LR-03", "LR-06"}
}
functions_live_finding_records = {
    record.get("findingId"): record
    for record in functions_live_ledger.get("technicalFindings", [])
    if record.get("findingId") in {"S-01", "D-01"}
}
check(
    "LR-03 and LR-06 preserve sealed adverse acquisition after remediation",
    functions_live_readback_policy.get("schemaVersion") == 1
    and functions_live_readback_policy.get("collectorStatus")
        == "SOURCE_CI_AND_LIVE_READBACK_PROVED"
    and functions_live_readback_policy.get("productionProjectId")
        == "crm3-baf-ops-b8638"
    and functions_live_readback_policy.get("productionRegion")
        == "asia-south1"
    and functions_live_readback_policy.get("gateIds") == ["LR-03", "LR-06"]
    and functions_live_readback_policy.get("sourceFunctionExports")
        == functions_live_expected_exports
    and len(functions_live_readback_policy.get("trackedRuntimePackages", []))
        == 8
    and set(
        functions_live_readback_policy.get(
            "sourceDeclaredRuntimeBindings", {}
        )
    ) == set(functions_live_expected_exports)
    and all(
        value is False
        for value in functions_live_readback_policy.get(
            "mutationBoundary", {}
        ).values()
    )
    and functions_live_readback_policy.get("privacyBoundary", {}).get(
        "operatorAccountIdentityRetained"
    ) is False
    and functions_live_readback_policy.get("privacyBoundary", {}).get(
        "sourceArchiveContentRetained"
    ) is False
    and all(
        name in functions_live_readback_index
        for name in functions_live_expected_exports
    )
    and "PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK"
        in functions_live_readback_source
    and "OBSERVE_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK"
        in functions_live_readback_source
    and "HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE"
        in functions_live_readback_source
    and "discoverFunctionExports" in functions_live_readback_source
    and "sourceExportInventoryMatchesPolicy"
        in functions_live_readback_source
    and "sourceRuntimeBindingInventoryMatchesPolicy"
        in functions_live_readback_source
    and "resolveCommand" in functions_live_readback_source
    and 'platformPath.join(sdkRoot, "lib", "gcloud.py")'
        in functions_live_readback_source
    and "sourceProvenance?.resolvedStorageSource"
        in functions_live_readback_source
    and "--if-generation-match=" in functions_live_readback_source
    and '"package-lock.json"' in functions_live_readback_source
    and "runtimeIamReducedToDeployedIdentities"
        in functions_live_readback_source
    and "advisoryAssessmentPerformed: false"
        in functions_live_readback_source
    and "s01Closed: false" in functions_live_readback_source
    and "d01Closed: false" in functions_live_readback_source
    and 'flag: "wx"' in functions_live_readback_source
    and all(
        forbidden not in functions_live_readback_source
        for forbidden in (
            '"functions", "deploy"',
            '"functions", "delete"',
            '"projects", "add-iam-policy-binding"',
            '"projects", "remove-iam-policy-binding"',
            "firebase deploy",
            "shell: true",
            "cmd.exe",
        )
    )
    and "adverse posture does not corrupt a valid live-readback acquisition"
        in functions_live_readback_test
    and "AST discovery binds the policy to all current Function exports"
        in functions_live_readback_test
    and "IAM evidence retains only deployed runtime service accounts"
        in functions_live_readback_test
    and "Windows gcloud uses the bundled Python entrypoint without a shell"
        in functions_live_readback_test
    and "collector source contains no production mutation command"
        in functions_live_readback_test
    and "live closure preserves adverse history after later remediation"
        in functions_live_readback_contract
    and "close on sealed acquisition, not posture fiction"
        in functions_live_readback_closure_contract
    and root_package.get("scripts", {}).get(
        "test:functions-live-readback-custody"
    )
        == "node --test tools/release/collectFunctionsIamDependenciesReadback.test.mjs"
    and "npm run test:functions-live-readback-custody" in release_gate_source
    and functions_live_receipt_path.exists()
    and functions_live_closure_path.exists()
    and sha(functions_live_receipt_path)
        == "6B7AE10D01DB8141F0403BE6563AA49C4557A980282BFFAB65DD1548D8B9DDB5"
    and sha(functions_live_closure_path)
        == "6BCD937E7AD77A2C54F532C82C1D8CA681190498F17650C321DAAA8EAA23E7B4"
    and functions_live_receipt_seal
        == functions_live_receipt.get("receiptSha256")
        == "7077afc11478848c2b400afab6e86622a40cc7510fd1abcf24eee3f128f239df"
    and functions_live_receipt.get("mode") == "STRICT"
    and functions_live_receipt.get("projectId") == "crm3-baf-ops-b8638"
    and functions_live_receipt.get("region") == "asia-south1"
    and functions_live_receipt.get("decision")
        == "PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK"
    and functions_live_receipt.get("failedChecks") == []
    and all(functions_live_receipt.get("checks", {}).values())
    and all(
        source.get("branch") == "main"
        and source.get("commit")
            == "b194dfe1a137256c3bfe0e113753a37f796a2e32"
        and source.get("originMain") == source.get("commit")
        and source.get("governedWorktreeClean") is True
        and source.get("materialChangeCount") == 0
        for source in (
            functions_live_receipt.get("source", {}).get("before", {}),
            functions_live_receipt.get("source", {}).get("after", {}),
        )
    )
    and functions_live_receipt.get("posture", {}).get("sourceFunctionCount")
        == 14
    and functions_live_receipt.get("posture", {}).get(
        "deployedFunctionCount"
    ) == 9
    and len(
        functions_live_receipt.get("posture", {}).get(
            "defaultComputeFunctionNames", []
        )
    ) == 7
    and len(
        functions_live_receipt.get("posture", {}).get(
            "dependencyDriftFunctionNames", []
        )
    ) == 9
    and functions_live_receipt.get("posture", {}).get("decision")
        == "HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE"
    and functions_live_receipt.get("outputs", {}).get("iam", {}).get(
        "defaultComputeHasUnconditionalEditor"
    ) is True
    and all(
        value is False
        for value in functions_live_receipt.get("mutationBoundary", {}).values()
    )
    and functions_live_closure.get("decision")
        == "PASS_LR03_LR06_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK_CLOSURE_WITH_ADVERSE_POSTURE"
    and functions_live_closure.get("liveReceipt", {}).get("fileSha256")
        == "6B7AE10D01DB8141F0403BE6563AA49C4557A980282BFFAB65DD1548D8B9DDB5"
    and functions_live_closure.get("liveReceipt", {}).get("receiptSha256")
        == functions_live_receipt.get("receiptSha256")
    and [
        authority.get("pullRequest")
        for authority in functions_live_closure.get("sourceAuthorities", [])
    ] == [136, 137]
    and all(
        value is False
        for value in functions_live_closure.get("closureBoundary", {}).values()
    )
    and set(functions_live_gate_records) == {"LR-03", "LR-06"}
    and all(
        record.get("currentStatus") == "CLOSED"
        and record.get("authorization") == "CLOSED_PASS"
        and [entry.get("status") for entry in record.get("statusHistory", [])]
            == ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"]
        and {
            entry.get("sha256") for entry in record.get("evidence", [])
        } == {
            "6B7AE10D01DB8141F0403BE6563AA49C4557A980282BFFAB65DD1548D8B9DDB5",
            "6BCD937E7AD77A2C54F532C82C1D8CA681190498F17650C321DAAA8EAA23E7B4",
        }
        for record in functions_live_gate_records.values()
    )
    and set(functions_live_finding_records) == {"S-01", "D-01"}
    and all(
        record.get("currentStatus") == "CLOSED"
        and {
            entry.get("sha256") for entry in record.get("evidence", [])
        } == {
            "6B7AE10D01DB8141F0403BE6563AA49C4557A980282BFFAB65DD1548D8B9DDB5",
            "6BCD937E7AD77A2C54F532C82C1D8CA681190498F17650C321DAAA8EAA23E7B4",
            "B9862804EA98080FC4BCD74DC92717C0D47A3DEE8A8DD5B17F20A23E584FC5FA",
        }
        and len(record.get("requiredExitEvidence", [])) > 0
        for record in functions_live_finding_records.values()
    )
    and {
        finding_id: [
            entry.get("status")
            for entry in record.get("statusHistory", [])
        ]
        for finding_id, record in functions_live_finding_records.items()
    } == {
        "S-01": ["OPEN", "CLOSED"],
        "D-01": ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"],
    }
    and "Collector status: SOURCE_CI_AND_LIVE_READBACK_PROVED"
        in functions_live_readback_decision
    and "Live readback evidence: PASS acquisition / HOLD runtime posture"
        in functions_live_readback_decision
    and "`S-01` and `D-01` own remediation"
        in functions_live_readback_decision,
)

function_fleet_identity_policy = data(
    "release/function-fleet-runtime-identity-policy.json"
)
function_fleet_identity_source = text(
    "functions/src/functionFleetRuntimeIdentity.ts"
)
function_fleet_identity_test = text(
    "functions/test/functionFleetRuntimeIdentitySource.test.js"
)
function_fleet_identity_decision = text(
    "docs/v4_2_r1/S01_FUNCTION_FLEET_RUNTIME_IDENTITY_CAMPAIGN.md"
)
function_fleet_campaign_collector = text(
    "tools/release/collectFunctionFleetRuntimeIdentityReadback.js"
)
function_fleet_campaign_collector_test = text(
    "tools/release/collectFunctionFleetRuntimeIdentityReadback.test.mjs"
)
function_fleet_campaign_executor = text(
    "tools/release/Invoke-FunctionFleetRuntimeIdentityCampaign.ps1"
)
function_fleet_campaign_executor_test = text(
    "tools/release/Invoke-FunctionFleetRuntimeIdentityCampaign.test.mjs"
)
function_fleet_bindings = function_fleet_identity_policy.get(
    "functionBindings", {}
)
function_fleet_account_ids = [
    binding.get("runtimeServiceAccountId")
    for binding in function_fleet_bindings.values()
    if isinstance(binding, dict)
]
check(
    "S-01 complete Function fleet has unique target-project identities",
    function_fleet_identity_policy.get("schemaVersion") == 1
    and function_fleet_identity_policy.get("declarationStatus")
        == "DEPLOYED_AND_LIVE_READBACK_PROVED"
    and function_fleet_identity_policy.get("productionProjectId")
        == "crm3-baf-ops-b8638"
    and function_fleet_identity_policy.get("targetProjectBinding") == {
        "builtInParameter": "PROJECT_ID",
        "serviceAccountDomain": "iam.gserviceaccount.com",
        "sameProjectRequired": True,
        "crossProjectResolutionAllowed": False,
    }
    and sorted(function_fleet_bindings) == functions_live_expected_exports
    and len(function_fleet_account_ids) == 14
    and len(set(function_fleet_account_ids)) == 14
    and all(
        isinstance(account_id, str)
        and 6 <= len(account_id) <= 30
        and account_id in function_fleet_identity_source
        for account_id in function_fleet_account_ids
    )
    and function_fleet_identity_policy.get("customRoles", {}).get(
        "notificationSender", {}
    ).get("includedPermissions") == ["cloudmessaging.messages.create"]
    and function_fleet_identity_policy.get("buildIdentity", {}).get(
        "requiredProjectRolesAfterCutover"
    ) == ["roles/cloudbuild.builds.builder"]
    and function_fleet_identity_policy.get("buildIdentity", {}).get(
        "runtimeUseAfterCutover"
    ) == "PROHIBITED"
    and function_fleet_identity_policy.get(
        "temporaryDeploymentProjectRoles", {}
    ) == {
        "eventAndScheduleRuntimeIdentities": ["roles/run.invoker"],
        "removalRequiredBeforeClosure": True,
    }
    and function_fleet_identity_policy.get("roleExactnessRequired") is True
    and all(
        "roles/editor" not in binding.get("requiredProjectRoles", [])
        and "roles/logging.logWriter"
            not in binding.get("requiredProjectRoles", [])
        for binding in function_fleet_bindings.values()
        if isinstance(binding, dict)
    )
    and all(
        value is False
        for value in function_fleet_identity_policy.get(
            "sourceMutationBoundary", {}
        ).values()
    )
    and 'import {expr, projectID} from "firebase-functions/params"'
        in function_fleet_identity_source
    and "@${projectID}.iam.gserviceaccount.com"
        in function_fleet_identity_source
    and "compute@developer.gserviceaccount.com"
        not in function_fleet_identity_source
    and "endpointServiceAccount" in function_fleet_identity_test
    and "accountIds.size" in function_fleet_identity_test
    and "DEPLOYED_AND_LIVE_READBACK_PROVED" in function_fleet_identity_test
    and "Default Compute must receive" in function_fleet_identity_decision
    and "Any failure before step 10 leaves Editor unchanged"
        in function_fleet_identity_decision
    and set(functions_live_finding_records) == {"S-01", "D-01"}
    and all(
        record.get("currentStatus") == "CLOSED"
        for record in functions_live_finding_records.values()
    ),
)

check(
    "S-01 deployment campaign is phased, evidence-bound and rollback-safe",
    root_package.get("scripts", {}).get(
        "test:function-fleet-runtime-campaign"
    )
        == "node --test tools/release/collectFunctionFleetRuntimeIdentityReadback.test.mjs tools/release/Invoke-FunctionFleetRuntimeIdentityCampaign.test.mjs"
    and "npm run test:function-fleet-runtime-campaign" in release_gate_source
    and "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_${label}"
        in function_fleet_campaign_collector
    and "schedulerBacklogZero" in function_fleet_campaign_collector
    and "sourceIsCleanMain" in function_fleet_campaign_collector
    and "defaultComputeRolesReducedToBuildOnly"
        in function_fleet_campaign_collector
    and "unauthenticatedCallableProbesDoNotSucceed"
        in function_fleet_campaign_collector
    and 'flag: "wx"' in function_fleet_campaign_collector
    and all(
        forbidden not in function_fleet_campaign_collector
        for forbidden in (
            "add-iam-policy-binding",
            "remove-iam-policy-binding",
            "service-accounts create",
            "functions deploy",
            "scheduler jobs run",
            "firebase deploy",
        )
    )
    and "final phase proves exact fleet, IAM, scheduler and safe callable probes"
        in function_fleet_campaign_collector_test
    and "preflight and fleet phases stop on an overdue scheduler backlog"
        in function_fleet_campaign_collector_test
    and all(
        f"'{phase}'" in function_fleet_campaign_executor
        for phase in (
            "Preflight",
            "Provision",
            "DeployCallables",
            "DeployEvents",
            "DeployScheduler",
            "Finalize",
            "RestoreEditor",
        )
    )
    and "05-scheduler-preflight.json" in function_fleet_campaign_executor
    and "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false"
        in function_fleet_campaign_executor
    and "Default Compute Editor was restored"
        in function_fleet_campaign_executor
    and "service-accounts delete" not in function_fleet_campaign_executor
    and "functions delete" not in function_fleet_campaign_executor
    and "Editor removal is final, reversible"
        in function_fleet_campaign_executor_test
    and "2026-08-04T10:32:19.779Z" in function_fleet_identity_decision
    and "repeats the same three aggregate counts"
        in function_fleet_identity_decision,
)

function_fleet_finalization_path = (
    ROOT / "release/evidence/s01-d01-h2-runtime-identity-live-finalization.json"
)
function_fleet_finalization = data(
    "release/evidence/s01-d01-h2-runtime-identity-live-finalization.json"
)
function_fleet_finalization_doc = text(
    "docs/v4_2_r1/S01_D01_H2_RUNTIME_IDENTITY_LIVE_FINALIZATION.md"
)
function_fleet_final_receipts = {
    receipt.get("file"): receipt
    for receipt in function_fleet_finalization.get("campaign", {}).get(
        "receipts", []
    )
}
function_fleet_h2_records = [
    record
    for record in functions_live_ledger.get("programmeGates", [])
    if record.get("gateId") == "H2-IAM"
]
function_fleet_h2_record = (
    function_fleet_h2_records[0]
    if len(function_fleet_h2_records) == 1
    else {}
)
check(
    "H2-IAM, S-01 and D-01 close on exact deployment and live authority",
    function_fleet_finalization_path.exists()
    and sha(function_fleet_finalization_path)
        == "B9862804EA98080FC4BCD74DC92717C0D47A3DEE8A8DD5B17F20A23E584FC5FA"
    and function_fleet_finalization.get("schemaVersion") == 1
    and function_fleet_finalization.get("evidenceType")
        == "s01-d01-h2-runtime-identity-live-finalization"
    and function_fleet_finalization.get("authority", {}).get("commit")
        == "bdc5c6ed870e7f947c40ea053cd587a56d77d48a"
    and function_fleet_finalization.get("authority", {}).get("tree")
        == "379353df082bae7fda7f808d1830dc797117513d"
    and function_fleet_finalization.get("authority", {}).get(
        "postMergeWorkflowRun"
    ) == 30913630958
    and function_fleet_finalization.get("authority", {}).get(
        "postMergeWorkflowConclusion"
    ) == "success"
    and {
        (job.get("name"), job.get("jobId"), job.get("conclusion"))
        for job in function_fleet_finalization.get("authority", {}).get(
            "postMergeJobs", []
        )
    } == {
        ("Android release APK + AAB packaging proof", 92006167814, "success"),
        ("Firestore rules + governed transaction emulator", 92006167927, "success"),
        ("Flutter analyze + tests + no-loss spine", 92006167987, "success"),
        ("Cloud Functions build + test", 92006168127, "success"),
    }
    and function_fleet_finalization.get("campaign", {}).get(
        "externalEvidenceDirectory"
    ) == "CRM3_FUNCTION_FLEET_RUNTIME_IDENTITY_CAMPAIGN_20260804_133140Z"
    and {
        name: (
            receipt.get("fileSha256"),
            receipt.get("receiptSha256"),
            receipt.get("decision"),
        )
        for name, receipt in function_fleet_final_receipts.items()
    } == {
        "01-preflight.json": (
            "DA0D4616B2C24A9D48779E58E8811997A60C256A2542FC7FCCCA638B10F3B26D",
            "2d353857ada89d71264e113f44ab60d51ebe3b7c7bbd83190f3a96bdabb358d1",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_PREFLIGHT",
        ),
        "02-provisioned.json": (
            "EAE52AC08DF4B3133748205D99ABD7580B616AECC02789EDDC999173C301CBA4",
            "d076a7932eb85880bc4d029ddbcbc98b1a11a9239d044f3a7e9aeb6a75601d33",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_PROVISIONED",
        ),
        "03-callables.json": (
            "BE226CC4AA092E32CE5F31C922E24BAD76A4249A3F3058CF903DD81BD17101A2",
            "456c2f38be606474d3da0813ff4b492c5c368b587fa75b7ca5de7f5228f1e23d",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_CALLABLES",
        ),
        "04-events.json": (
            "68CE4726322F858F6C1040D2D51D562C37A6CA651303A0434FF75D6762837D2E",
            "c35ffc89811db13a6756cab2724fef018fd340f36e38be2f3601f4ca791d0e1d",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_EVENTS",
        ),
        "05-scheduler-preflight.json": (
            "14EF1AE72C326111F813502E9AF17BCDED3A5CDC9418463E89DF8F0022740CEB",
            "1c66b25361377bfea1a32d184d2c9a935bf5b67466e75ca13fd26a4657149ee3",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_EVENTS",
        ),
        "06-fleet.json": (
            "EDCD2EF459D836DA4B497FFA9AA7EFD3914AE01DBD27A0DF31D3C10BE47A3175",
            "a6b6a117da5893fd836298efc1d8a890c4be5302cbb162ec855f38f5efd7356a",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FLEET",
        ),
        "07-lr03-lr06-prefinal.json": (
            "9C04590A41DBA1AE6084A3F53D3546E948BFD94B8681785FED803E306A82D624",
            "f8be48192c02c5be4373fe27e6dd87e17d0d9268a6b1a695292987db83beed9a",
            "PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK",
        ),
        "08-final.json": (
            "7D3D66F91CBF446D0763E7FB85F3C12D1453CCF1C447DD23D3178E0BCE7E67E7",
            "468675024ae849570255c2d3f17da4067af5176331c3d21c65a7c516fcd8707c",
            "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL",
        ),
        "09-lr03-lr06-final.json": (
            "3BF52BBB50BEF9FE412161AC36385D2498D14D3F51CDDE8F402F51CE9A52F1CD",
            "51b0244c43120cca074974890f3a5eac0166beb44b4ce6c0c2346b57bfd76eab",
            "PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK",
        ),
    }
    and function_fleet_finalization.get("finalPosture") == {
        "deployedFunctionCount": 14,
        "allFunctionsActiveGeneration2": True,
        "allRuntimeIdentitiesExact": True,
        "defaultComputeFunctionCount": 0,
        "broadRuntimeProjectGrantCount": 0,
        "callableProbeCount": 8,
        "schedulerBacklogCount": 0,
        "defaultComputeProjectRoles": ["roles/cloudbuild.builds.builder"],
        "globalPullReaderProjectRoles": ["roles/datastore.viewer"],
        "globalPullWriterProjectRoles": [
            "roles/datastore.user",
            "roles/eventarc.eventReceiver",
        ],
        "dependencyInventoryMatchesCurrentFunctionCount": 14,
        "dependencyVersionMatchesCurrentFunctionCount": 14,
        "dependencyPostureDecision": "PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE",
        "dependencyPostureHoldCount": 0,
    }
    and all(function_fleet_finalization.get("checks", {}).values())
    and function_fleet_finalization.get("mutationBoundary", {}).get(
        "defaultComputeEditorRollbackNeeded"
    ) is False
    and function_fleet_finalization.get("mutationBoundary", {}).get(
        "businessDataMutationPerformed"
    ) is False
    and all(
        value is False
        for value in function_fleet_finalization.get(
            "privacyBoundary", {}
        ).values()
    )
    and function_fleet_finalization.get("sourceAndCiAdjudication") == {
        "status": "PASS_EXACT_HEAD_PULL_REQUEST_CI",
        "pullRequest": 149,
        "workflowRun": 30922839115,
        "workflowEvent": "pull_request",
        "headCommit": "06658f8a2e5d1dca4624094da4938cda94095cf6",
        "headTree": "3de31f1cae2fd91fe8def4d7d3fe72e2f3777ad5",
        "conclusion": "success",
        "jobs": [
            {
                "name": "Android release APK + AAB packaging proof",
                "jobId": 92037560472,
                "conclusion": "success",
            },
            {
                "name": "Cloud Functions build + test",
                "jobId": 92037560487,
                "conclusion": "success",
            },
            {
                "name": "Flutter analyze + tests + no-loss spine",
                "jobId": 92037560507,
                "conclusion": "success",
            },
            {
                "name": "Firestore rules + governed transaction emulator",
                "jobId": 92037560592,
                "conclusion": "success",
            },
        ],
    }
    and function_fleet_finalization.get("programmeBoundary") == {
        "h2IamClosed": True,
        "s01Closed": True,
        "d01Closed": True,
        "stage2dF4Status": "OPEN",
        "pilotHandoutAuthorized": False,
        "distributionAuthorized": False,
    }
    and function_fleet_finalization.get("decision")
        == "PASS_H2_S01_D01_RUNTIME_IDENTITY_AND_DEPENDENCY_CLOSURE"
    and len(function_fleet_h2_records) == 1
    and function_fleet_h2_record.get("currentStatus") == "CLOSED"
    and function_fleet_h2_record.get("authorization") == "CLOSED_PASS"
    and [
        entry.get("status")
        for entry in function_fleet_h2_record.get("statusHistory", [])
    ] == ["OPEN", "CLOSED"]
    and {
        entry.get("sha256")
        for entry in function_fleet_h2_record.get("evidence", [])
    } == {
        "B9862804EA98080FC4BCD74DC92717C0D47A3DEE8A8DD5B17F20A23E584FC5FA"
    }
    and functions_live_ledger.get("programmeDecision", {}).get(
        "leastPrivilegeIam"
    ) == "CLOSED_PASS"
    and functions_live_ledger.get("programmeDecision", {}).get(
        "nextMutation"
    ) == "STAGE2D-F4"
    and "Status: CLOSED PASS" in function_fleet_finalization_doc
    and "does not close `STAGE2D-F4`" in function_fleet_finalization_doc,
)

lr02_receipt_path = ROOT / "release/evidence/lr02-p04-firestore-live-readback.json"
lr02_closure_path = ROOT / "release/evidence/lr02-p04-live-readback-closure.json"
lr02_receipt = data("release/evidence/lr02-p04-firestore-live-readback.json")
lr02_closure = data("release/evidence/lr02-p04-live-readback-closure.json")
lr02_receipt_body = {
    key: value for key, value in lr02_receipt.items() if key != "receiptSha256"
}
lr02_receipt_seal = hashlib.sha256(
    json.dumps(
        lr02_receipt_body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
lr02_ledger = data("governance/programme-ledger.json")
lr02_records = [
    record
    for record in lr02_ledger.get("programmeGates", [])
    if record.get("gateId") == "LR-02"
]
p04_records = [
    record
    for record in lr02_ledger.get("technicalFindings", [])
    if record.get("findingId") == "P-04"
]
lr02_record = lr02_records[0] if len(lr02_records) == 1 else {}
p04_record = p04_records[0] if len(p04_records) == 1 else {}
lr02_expected_evidence_hashes = {
    "F2DB0F6491F427636D18E1CC4EF8C95FA03A8B0E738B74E175BF97C8ECC71815",
    "E8EBE9289F235C645AB791513F5EE394C3999E95801CFC4198C757FFD647E8C6",
}
check(
    "LR-02 and P-04 close on sealed strict clean-main live evidence",
    lr02_receipt.get("mode") == "STRICT"
    and lr02_receipt.get("projectId") == "crm3-baf-ops-b8638"
    and lr02_receipt.get("decision")
        == "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK"
    and lr02_receipt.get("failedChecks") == []
    and all(lr02_receipt.get("checks", {}).values())
    and lr02_receipt_seal == lr02_receipt.get("receiptSha256")
    and lr02_receipt_seal
        == "9215a3d8a7f8b273a67d2088fc9d3121da5f6be1ae8972d8526e535b05d4fae4"
    and all(
        source.get("branch") == "main"
        and source.get("commit")
            == "b6f5838360f46d8f164338164f295b93fe3335ad"
        and source.get("originMain") == source.get("commit")
        and source.get("governedWorktreeClean") is True
        and source.get("materialChangeCount") == 0
        for source in lr02_receipt.get("source", {}).values()
    )
    and lr02_receipt.get("outputs", {}).get("rules", {}).get("byteExact") is True
    and lr02_receipt.get("outputs", {}).get("rules", {}).get("sourceByteCount")
        == 136651
    and lr02_receipt.get("outputs", {}).get("indexes", {}).get("sourceCount")
        == 51
    and lr02_receipt.get("outputs", {}).get("indexes", {}).get("cliCount")
        == 51
    and lr02_receipt.get("outputs", {}).get("indexes", {}).get("apiCount")
        == 51
    and lr02_receipt.get("outputs", {}).get("indexes", {}).get("apiReadyCount")
        == 51
    and lr02_receipt.get("outputs", {}).get("indexes", {}).get(
        "fieldOverridesMatchSource"
    ) is True
    and all(value is False for value in lr02_receipt.get("mutationBoundary", {}).values())
    and lr02_closure.get("decision")
        == "PASS_LR02_P04_FIRESTORE_RULES_INDEXES_LIVE_READBACK_CLOSURE"
    and lr02_closure.get("collectorAuthority", {}).get("pullRequest") == 130
    and lr02_closure.get("collectorAuthority", {}).get("sourceTree")
        == lr02_closure.get("collectorAuthority", {}).get("mergeTree")
    and lr02_closure.get("collectorAuthority", {}).get("pullRequestCi", {}).get(
        "runId"
    ) == 30870605924
    and lr02_closure.get("collectorAuthority", {}).get("pullRequestCi", {}).get(
        "conclusion"
    ) == "success"
    and lr02_closure.get("collectorAuthority", {}).get("postMergeCi", {}).get(
        "runId"
    ) == 30871016815
    and lr02_closure.get("collectorAuthority", {}).get("postMergeCi", {}).get(
        "conclusion"
    ) == "success"
    and sha(lr02_receipt_path)
        == lr02_closure.get("liveReceipt", {}).get("fileSha256")
    and lr02_receipt_path.stat().st_size
        == lr02_closure.get("liveReceipt", {}).get("fileBytes")
    and sha(lr02_closure_path)
        == "E8EBE9289F235C645AB791513F5EE394C3999E95801CFC4198C757FFD647E8C6"
    and all(
        record.get("authorityType") == "LIVE_READBACK"
        and record.get("currentStatus") == "CLOSED"
        and [entry.get("status") for entry in record.get("statusHistory", [])]
            == ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"]
        and {entry.get("sha256") for entry in record.get("evidence", [])}
            == lr02_expected_evidence_hashes
        and len(record.get("reArmTriggers", [])) == 5
        for record in (lr02_record, p04_record)
    )
    and lr02_record.get("authorization") == "CLOSED_PASS"
    and "Status: **CLOSED** for `LR-02` and `P-04`" in firestore_readback_decision
    and "STAGE2D-F4` remains open" in firestore_readback_decision
    and (ROOT / "test/lr02_p04_live_readback_closure_contract_test.dart").is_file(),
)

firebase_cli_package = data("tooling/firebase-cli/package.json")
firebase_cli_lock = data("tooling/firebase-cli/package-lock.json")
firebase_cli_packages = firebase_cli_lock.get("packages", {})
hono = firebase_cli_packages.get("node_modules/@hono/node-server", {})
fast_uri = firebase_cli_packages.get("node_modules/fast-uri", {})
hono_runtime = firebase_cli_packages.get("node_modules/hono", {})
ip_address = firebase_cli_packages.get("node_modules/ip-address", {})
brace_expansion = firebase_cli_packages.get("node_modules/brace-expansion", {})
brace_expansion_upstream = firebase_cli_packages.get("node_modules/brace-expansion-modern", {})
tar = firebase_cli_packages.get("node_modules/tar", {})
re2 = firebase_cli_packages.get("node_modules/re2", {})
firebase_tools = firebase_cli_packages.get("node_modules/firebase-tools", {})
mcp_sdk = firebase_cli_packages.get("node_modules/@modelcontextprotocol/sdk", {})
check(
    "Firebase CLI tooling pins only the bounded patched dependency versions",
    firebase_cli_package.get("dependencies", {}).get("firebase-tools") == "15.22.4"
    and firebase_cli_package.get("overrides", {}).get("@hono/node-server") == "2.0.10"
    and firebase_cli_package.get("overrides", {}).get("fast-uri") == "3.1.5"
    and firebase_cli_package.get("overrides", {}).get("hono") == "4.12.34"
    and firebase_cli_package.get("overrides", {}).get("ip-address") == "10.4.0"
    and firebase_cli_package.get("dependencies", {}).get("brace-expansion") == "file:../brace-expansion-compat"
    and firebase_cli_package.get("overrides", {}).get("brace-expansion") == "$brace-expansion"
    and firebase_cli_package.get("overrides", {}).get("tar") == "7.5.21"
    and firebase_cli_package.get("overrides", {}).get("re2") == "1.25.2"
    and firebase_tools.get("version") == "15.22.4"
    and hono.get("version") == "2.0.10"
    and hono.get("resolved") == "https://registry.npmjs.org/@hono/node-server/-/node-server-2.0.10.tgz"
    and hono.get("integrity") == "sha512-ZcnNVhKTmyDJeg0UlnZjvM73JBsTAuhrH/J4fjwGOw59PwOW51r4J+p6CsKZWXdKSme4MFqU62CZMOsdDrU4CA=="
    and fast_uri.get("version") == "3.1.5"
    and fast_uri.get("resolved") == "https://registry.npmjs.org/fast-uri/-/fast-uri-3.1.5.tgz"
    and fast_uri.get("integrity") == "sha512-gHwA1O9LDIcKunMKhObS/HimwtehO1nPUECKAu5TpKgaO19fcWEl4bliWe1jWxVFvIXztJjjQ4L8XQ1EU9f7Jw=="
    and hono_runtime.get("version") == "4.12.34"
    and hono_runtime.get("resolved") == "https://registry.npmjs.org/hono/-/hono-4.12.34.tgz"
    and hono_runtime.get("integrity") == "sha512-GqXJqY/xJkJmuloTrnV1ZEXG3fqte+VjkUqoRNZXcrUidiUOP4fMSIHHY4tsqZBK++kVyWmt/AAfSUuy57/eSA=="
    and ip_address.get("version") == "10.4.0"
    and ip_address.get("resolved") == "https://registry.npmjs.org/ip-address/-/ip-address-10.4.0.tgz"
    and ip_address.get("integrity") == "sha512-oSK96Grm3aP6OrS263xVxbNDGVL7rzBtYdpGqlDG8iQdoenDoTs/nkki+DflYbAEE8Xl6o5YxhxlrKvI3nqKXQ=="
    and brace_expansion.get("version") == "5.0.9"
    and brace_expansion.get("resolved") == "file:../brace-expansion-compat"
    and brace_expansion_upstream.get("name") == "brace-expansion"
    and brace_expansion_upstream.get("version") == "5.0.9"
    and brace_expansion_upstream.get("resolved") == "https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.9.tgz"
    and brace_expansion_upstream.get("integrity") == "sha512-ScQ4IuvIEF1TMlP7Zt+vjJ//9zlPb2SDcxWxM3bk8s6t6GGdJ7KO1dCcTidOPJKePW30LE/2cT7wCyPho9/Wxg=="
    and tar.get("version") == "7.5.21"
    and tar.get("resolved") == "https://registry.npmjs.org/tar/-/tar-7.5.21.tgz"
    and tar.get("integrity") == "sha512-XdhtCvlMywwxpCW8YEq3lOXBJpUPTR2OHHcwLPO3HwsJqOHa2Ok/oJ7ruGzp+JrKoRPVCzJwAdEjqLW/vNRPHA=="
    and re2.get("version") == "1.25.2"
    and re2.get("resolved") == "https://registry.npmjs.org/re2/-/re2-1.25.2.tgz"
    and re2.get("integrity") == "sha512-t75KS05wrPM0S7IRbM0l/WUYlHftJj3WAzQJAcSH8CrDP/jFYicZbMYTKohJ8w/3kFGwkY/G8/dGtC6CdShDlw=="
    and mcp_sdk.get("dependencies", {}).get("@hono/node-server") == "^1.19.9",
)
brace_adapter_package = data("tooling/brace-expansion-compat/package.json")
brace_adapter_cjs = text("tooling/brace-expansion-compat/index.cjs")
brace_adapter_esm = text("tooling/brace-expansion-compat/index.mjs")
brace_compat_smoke = text("tools/dependencies/verify_brace_expansion_compat.mjs")
check(
    "Patched brace-expansion adapter preserves legacy and modern interfaces",
    brace_adapter_package.get("name") == "brace-expansion"
    and brace_adapter_package.get("version") == "5.0.9"
    and brace_adapter_package.get("dependencies", {}).get("brace-expansion-modern") == "npm:brace-expansion@5.0.9"
    and "module.exports = Object.assign(upstream.expand, upstream)" in brace_adapter_cjs
    and "export default expand" in brace_adapter_esm
    and "PASS_BRACE_EXPANSION_COMPAT" in brace_compat_smoke
    and "PASS_BRACE_EXPANSION_ESM_COMPAT" in brace_compat_smoke
    and all(text(path).strip() == "install-links=true" for path in (
        ".npmrc",
        "functions/.npmrc",
        "tooling/firebase-cli/.npmrc",
    )),
)
check(
    "Firebase CLI tooling contains no private registry resolution",
    "packages.applied-caas-gateway" not in text("tooling/firebase-cli/package-lock.json")
    and all(
        not str(pkg.get("resolved", "")).startswith(("http://", "https://"))
        or str(pkg.get("resolved", "")).startswith("https://registry.npmjs.org/")
        for pkg in firebase_cli_packages.values()
        if isinstance(pkg, dict)
    ),
)
check(
    "Firebase CLI lock-policy parser supports npm's empty root-package key",
    "ConvertFrom-Json -AsHashTable" in harness
    and "[System.Collections.IDictionary]" in harness
    and "Get-JsonPropertyValue -Object $lock -Name 'packages'" in harness
    and "$lock.packages" not in harness,
)

check(
    "Laboratory verifies Firebase CLI lock policy, installed versions and strict audit",
    all(marker in harness for marker in (
        "10_firebase_cli_lock_policy",
        "11_firebase_cli_npm_ci",
        "12_firebase_cli_installed_versions",
        "13_firebase_cli_load_smoke",
        "14_firebase_cli_npm_audit",
        "Assert-FirebaseCliLockPolicy",
        "Assert-FirebaseCliInstalledVersions",
        "HOLD_FIREBASE_CLI_LOCK_POLICY",
        "HOLD_FIREBASE_CLI_DEPENDENCY_VERSION",
        "HOLD_FIREBASE_CLI_DEPENDENCY_AUDIT",
        "2.0.10",
        "3.1.5",
        "4.12.34",
        "10.4.0",
        "5.0.9",
        "1.25.2",
        "7.5.21",
        "verify_brace_expansion_compat.mjs",
    )),
)
check(
    "Firebase CLI dependency compatibility is load-smoked before its advisory verdict",
    "HOLD_FIREBASE_CLI_RUNTIME" in harness
    and "PASS_FIREBASE_CLI_LOAD_SMOKE" in harness
    and "verify_brace_expansion_compat.mjs" in harness
    and harness.index("12_firebase_cli_installed_versions") < harness.index("13_firebase_cli_load_smoke") < harness.index("14_firebase_cli_npm_audit"),
)
check(
    "Tooling advisory verdict is nonblocking for evidence but still prohibits final PASS",
    "function Invoke-RecordedHoldStep" in harness
    and "$recordedHolds" in harness
    and "executionOutcome = $executionOutcome" in harness
    and "HOLD_MULTIPLE_NONBLOCKING_GATES" in harness
    and "final PASS remains prohibited" in harness
    and "Invoke-RecordedHoldStep -Name '14_firebase_cli_npm_audit'" in harness,
)

custody = text("tools/v4/trial_workspace_custody.py")
check(
    "Post-codegen custody permits generated bindings but rejects handwritten drift",
    "generated-binding-modified" in custody
    and "handwritten-or-governed-file-modified" in custody
    and "lockfile-changed" in custody,
)
expected_registrants = {
    "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
    "ios/Runner/GeneratedPluginRegistrant.h",
    "ios/Runner/GeneratedPluginRegistrant.m",
    "linux/flutter/generated_plugin_registrant.cc",
    "linux/flutter/generated_plugin_registrant.h",
    "linux/flutter/generated_plugins.cmake",
    "macos/Flutter/GeneratedPluginRegistrant.swift",
    "windows/flutter/generated_plugin_registrant.cc",
    "windows/flutter/generated_plugin_registrant.h",
    "windows/flutter/generated_plugins.cmake",
}
check(
    "Post-codegen custody explicitly classifies only the ten Flutter platform registrants",
    "FLUTTER_PLATFORM_REGISTRANTS" in custody
    and "flutter-platform-registrant-added" in custody
    and all(f'"{path}"' in custody for path in expected_registrants)
    and "elif rel in FLUTTER_PLATFORM_REGISTRANTS:" in custody,
)
continuity = data("docs/v4_2_r1/CANONICAL_ISAR_SCHEMA_BASELINE.json")
check(
    "Exact canonical-main Isar baseline contains all inherited collections",
    len(continuity.get("collections", {})) == 16
    and continuity.get("canonicalMainCommit") == main["commit"],
)
isar_continuity_source = text("tools/isar/verify_canonical_main_isar_continuity.py")
check(
    "Post-codegen Isar verifier enforces semantic continuity and reports generated position drift",
    all(marker in isar_continuity_source for marker in (
        "collection-id-changed",
        "inherited-property-type-changed",
        "inherited-index-definition-changed",
        "generated-property-position-changed",
        "PASS_CANONICAL_ISAR_SEMANTIC_CONTINUITY",
    ))
    and "inherited-property-definition-changed" not in isar_continuity_source
    and "18_canonical_isar_semantic_continuity" in harness,
)

sweep = text("tools/v4/firestore_integrity_sweep.mjs")
check(
    "Read-only full-collection integrity sweep catches orderBy blind spots",
    ".collection(collection).get()" in sweep
    and "--allow-production-read-only" in sweep
    and "unexpected-top-level-field" in sweep
    and "invalid-firestore-timestamp" in sweep
    and "readOnly: true" in sweep,
)
check(
    "Integrity sweep pure tests pass-source cover users and missing ordered fields",
    "legacy and malformed user fields are reported" in text("tools/v4/firestore_integrity_sweep.test.mjs")
    and "missing ordered fields without orderBy" in text("tools/v4/firestore_integrity_sweep.test.mjs"),
)
check(
    "Gate 1B authority classifier is privacy-safe, Auth-aware and mutation-free",
    all(marker in sweep for marker in (
        "PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY",
        "HOLD_AUTHORITY_FINDINGS_REQUIRE_ADJUDICATION",
        "HOLD_INCOMPLETE_AUTH_OR_FIRESTORE_COVERAGE",
        "HOLD_PRIVACY_OR_CUSTODY_FAILURE",
        "createHmac('sha256'",
        "auth.listUsers(1000, pageToken)",
        "customClaimsPolicy: 'ABSENCE_ASSERTION_NO_TRACKED_WRITER'",
        "cloudMutationCapability: 'NONE'",
    ))
    and all(marker not in sweep for marker in (
        ".doc(",
        "writeBatch(",
        "bulkWriter(",
        "setCustomUserClaims(",
        "runTransaction(",
        "updateUser(",
        "deleteUser(",
        "createUser(",
        "importUsers(",
    )),
)
check(
    "Gate 1B tests prove role parity, privacy, custody and all authority classes",
    all(marker in text("tools/v4/firestore_integrity_sweep.test.mjs") for marker in (
        "role catalogue is identical across policy, Rules, Functions, and Dart",
        "HMAC pseudonyms are stable, namespaced, and omit raw identity data",
        "production reads require exact source, project, coverage, and custody",
        "source custody ignores only bounded untracked operational paths",
        "classifier source contains no Firebase or Firestore mutation API",
        "Auth population, disabled approval, and custom claims fail closed",
        "duplicate canonical roles are a non-blocking data-quality warning",
    )),
)
check(
    "Gate 1B complete Firestore and Auth read path has disposable emulator proof",
    '"auth": {' in text("firebase.json")
    and "firestore_integrity_sweep.emulator.test.mjs" in text("package.json")
    and all(marker in text("tools/v4/firestore_integrity_sweep.emulator.test.mjs") for marker in (
        "actual CLI joins Firestore and Auth into a privacy-safe pass",
        "PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY",
        "reportText.includes(ADMIN_UID), false",
        "reportText.includes(HMAC_KEY), false",
    )),
)

lr01_receipt_path = ROOT / "release/evidence/lr01-auth-roster-live-readback.json"
lr01_closure_path = ROOT / "release/evidence/lr01-auth-roster-live-readback-closure.json"
lr01_receipt = data("release/evidence/lr01-auth-roster-live-readback.json")
lr01_closure = data("release/evidence/lr01-auth-roster-live-readback-closure.json")
lr01_receipt_text = text("release/evidence/lr01-auth-roster-live-readback.json")
lr01_ledger = data("governance/programme-ledger.json")
lr01_records = [
    record
    for record in lr01_ledger.get("programmeGates", [])
    if record.get("gateId") == "LR-01"
]
lr01_record = lr01_records[0] if len(lr01_records) == 1 else {}
lr01_expected_evidence_hashes = {
    "6D7FFAA78A77E2B5A413AB5CCFBF9C4DEF90C00FCFB4133355B0A6E97C6334AC",
    "9B30CDD3403A596510F3FE2AF4370E5AB05F8584D28EDCC7A8A89C555A52B05A",
}
lr01_coverage = lr01_receipt.get("coverage", {})
lr01_summary = lr01_receipt.get("summary", {})
lr01_source = lr01_receipt.get("sourceAuthority", {})
lr01_project = lr01_receipt.get("project", {})
lr01_privacy = lr01_receipt.get("privacy", {})
check(
    "LR-01 closes on complete privacy-safe strict clean-main roster evidence",
    len(lr01_records) == 1
    and sha(lr01_receipt_path)
        == "6D7FFAA78A77E2B5A413AB5CCFBF9C4DEF90C00FCFB4133355B0A6E97C6334AC"
    and lr01_receipt_path.stat().st_size == 4272
    and lr01_receipt.get("decision")
        == "PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY"
    and lr01_receipt.get("readOnly") is True
    and lr01_receipt.get("cloudMutationCapability") == "NONE"
    and lr01_project.get("projectId") == "crm3-baf-ops-b8638"
    and lr01_project.get("production") is True
    and lr01_project.get("firestoreEmulator") is None
    and lr01_project.get("authEmulator") is None
    and lr01_source.get("commit")
        == "5af6d8d3a6f8d7b1c5176b82f1dff68234920371"
    and lr01_source.get("tree")
        == "dcf3a6a4349b29188d715e268f1b6c8394b2367a"
    and lr01_source.get("branch") == "main"
    and lr01_source.get("originMainCommit") == lr01_source.get("commit")
    and lr01_source.get("cleanWorktree") is True
    and lr01_source.get("materialChangeCount") == 0
    and lr01_source.get("materialPathSha256") == []
    and lr01_coverage.get("firestoreUsers") == "COMPLETE"
    and lr01_coverage.get("firebaseAuthUsers") == "COMPLETE"
    and lr01_coverage.get("customClaims") == "COMPLETE"
    and lr01_coverage.get("firestoreUserCount") == 3
    and lr01_coverage.get("firebaseAuthUserCount") == 3
    and lr01_coverage.get("joinedSubjectCount") == 3
    and lr01_summary.get("blockingFindingCount") == 0
    and lr01_summary.get("blockingSubjectCount") == 0
    and lr01_summary.get("canonicalApprovedAdminCount") == 2
    and lr01_summary.get("enabledApprovedAdminCount") == 2
    and lr01_privacy.get("rawIdentifiersEmitted") is False
    and lr01_privacy.get("customClaimValuesEmitted") is False
    and "@" not in lr01_receipt_text
    and all(
        not {"uid", "email", "name"}.intersection(subject)
        for subject in lr01_receipt.get("subjects", [])
    )
    and lr01_closure.get("decision")
        == "PASS_LR01_AUTH_ROSTER_LIVE_READBACK_CLOSURE"
    and lr01_closure.get("collectorAuthority", {}).get("pullRequest") == 132
    and lr01_closure.get("collectorAuthority", {}).get("sourceTree")
        == lr01_closure.get("collectorAuthority", {}).get("mergeTree")
    and lr01_closure.get("collectorAuthority", {}).get("pullRequestCi", {}).get(
        "runId"
    ) == 30873830850
    and lr01_closure.get("collectorAuthority", {}).get("pullRequestCi", {}).get(
        "conclusion"
    ) == "success"
    and lr01_closure.get("collectorAuthority", {}).get("postMergeCi", {}).get(
        "runId"
    ) == 30874252831
    and lr01_closure.get("collectorAuthority", {}).get("postMergeCi", {}).get(
        "conclusion"
    ) == "success"
    and lr01_closure.get("liveReceipt", {}).get("fileSha256")
        == sha(lr01_receipt_path)
    and lr01_closure.get("liveReceipt", {}).get("fileBytes")
        == lr01_receipt_path.stat().st_size
    and sha(lr01_closure_path)
        == "9B30CDD3403A596510F3FE2AF4370E5AB05F8584D28EDCC7A8A89C555A52B05A"
    and all(value is False for value in lr01_closure.get("closureBoundary", {}).values())
    and lr01_record.get("authorityType") == "LIVE_READBACK"
    and lr01_record.get("currentStatus") == "CLOSED"
    and lr01_record.get("authorization") == "CLOSED_PASS"
    and [entry.get("status") for entry in lr01_record.get("statusHistory", [])]
        == ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"]
    and {entry.get("sha256") for entry in lr01_record.get("evidence", [])}
        == lr01_expected_evidence_hashes
    and len(lr01_record.get("reArmTriggers", [])) == 5
    and "Status: **CLOSED** for `LR-01`" in text(
        "docs/v4_2_r1/GATE_1B_READ_ONLY_AUTHORITY_CLASSIFIER.md"
    )
    and "STAGE2D-F4` remains open" in text(
        "docs/v4_2_r1/GATE_1B_READ_ONLY_AUTHORITY_CLASSIFIER.md"
    )
    and (ROOT / "test/lr01_auth_roster_live_readback_closure_contract_test.dart").is_file(),
)

source_reconciliation = text("docs/v4_2/CURRENT_PRE_V4_SOURCE_AUTHORITY_RECONCILIATION.md")
check(
    "Erroneous v4.1-only path count is corrected to file-level count",
    "v4.1-only file paths: 229" in source_reconciliation and "v4.1-only paths: 1083" not in source_reconciliation,
)
check(
    "Clean-cutover policy does not constrain the new architecture to disposable data",
    "does not require an in-place upgrade of the old Isar database" in text("docs/v4_2_r1/CLEAN_CUTOVER_AND_ROLLBACK_POLICY.md")
    and data("governance/v4_successor_programme_authority_v1.json")["initialMigrationDataPolicy"]["oldLocalDatabaseMigrationRequiredForInitialTrial"] is False,
)
check(
    "Local-only 57be731 delta is classified, not merged wholesale",
    "Do not merge or transplant this branch wholesale" in text("docs/v4_2_r1/LOCAL_ONLY_57BE731_ADJUDICATION.md"),
)

isar_migration = text("lib/core/services/isar_schema_migration.dart")
isar_guard = text("lib/core/services/isar_schema_guard_io.dart")
startup = text("lib/main.dart")
workflow_panel = text("lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart")
compliance_dialog = text("lib/features/maintenance_workflow/presentation/widgets/raise_compliance_dialog.dart")
module_provider = text("lib/features/planned_maintenance/providers/job_module_provider.dart")
retry_test = text("test/maintenance_workflow/workflow_retry_policy_test.dart")
red_gate_test = text("test/maintenance_workflow/red_exit_gate_test.dart")
complete_screen = text("lib/features/planned_maintenance/presentation/complete_job_screen.dart")
check(
    "R1.12 analyzer corrections preserve intended workflow semantics",
    "static const IsarSchemaMigrationPlan defaultPlan" in isar_migration
    and "workflow.jobExecutionFirestoreId" in workflow_panel
    and compliance_dialog.count("initialValue:") >= 6
    and "_gatingLaneId = value ?? ''" in compliance_dialog
    and "..isOpenForWork = true" not in module_provider
    and "..isDeleted = false" in module_provider
    and "policy.classify(" in retry_test
    and "WorkflowException(WorkflowErrorCode.unavailable" in retry_test
    and "classifyError(" not in retry_test
    and "activeLaneIds: <MaintenanceLaneId>" in red_gate_test
    and "if (!mounted) return;\n          redAnswers = await showRedExitDialog" in complete_screen,
)
check(
    "P-06 Isar provenance fails closed and commits only after a successful open",
    "baf_isar_schema_provenance_v1" in isar_migration
    and "databaseGenerationId" in isar_migration
    and "existing-store-unmarked" in isar_migration
    and "legacy-marker-incomplete" in isar_migration
    and "_validateMarkerSource(" in isar_migration
    and "commitAfterSuccessfulOpen()" in startup
    and startup.index("ensureIsarSchemaBeforeOpen(")
    < startup.index("Isar.open(")
    < startup.index("repairPlannedJobLocalLinks(")
    < startup.index("commitAfterSuccessfulOpen()")
    and "readIsarSchemaProvenanceSnapshotJson()" in startup
    and '"schemaProvenanceSnapshot": $provenanceSnapshot' in startup
    and ".isar.lock" not in isar_guard,
)

app_database_source = text("lib/core/persistence/app_database.dart")
main_source = text("lib/main.dart")
dart_import_cycle_test = text("test/dart_import_cycle_test.dart")
dart_import_cycle_decision = text("docs/DART_IMPORT_CYCLE_CLOSURE.md")
lib_dart_sources = {
    str(path.relative_to(ROOT)).replace("\\", "/"):
        path.read_text(encoding="utf-8")
    for path in (ROOT / "lib").rglob("*.dart")
}
main_importers = [
    path
    for path, source in lib_dart_sources.items()
    if re.search(r"import\s+['\"][^'\"]*main\.dart['\"]", source)
]
app_database_consumers = [
    path
    for path, source in lib_dart_sources.items()
    if "core/persistence/app_database.dart" in source
]
check(
    "Dart data layer is main-decoupled and guarded against import cycles",
    "late Isar isar;" in app_database_source
    and "late Isar isar;" not in main_source
    and main_importers == []
    and len(app_database_consumers) == 12
    and "lib has no internal Dart import cycles" in dart_import_cycle_test
    and "final lowLinks = <String, int>{};" in dart_import_cycle_test
    and "component.length > 1 || graph[node]!.contains(node)"
        in dart_import_cycle_test
    and "cycles,\n      isEmpty" in dart_import_cycle_test
    and "Largest component:      72 files" in dart_import_cycle_decision
    and "Cyclic components:      0" in dart_import_cycle_decision
    and "Isar schemas,\ndatabase naming, open order" in dart_import_cycle_decision,
    f"mainImporters={main_importers} appDatabaseConsumers="
    f"{len(app_database_consumers)}",
)


sync_job_modules = text("lib/core/services/sync_service.job_modules.dart")
compliance_detail = text(
    "lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart"
)
lifecycle_guard = text("test/lifecycle_static_guardrail_contract_test.dart")
async_guard = text("test/async_mounted_context_safety_contract_test.dart")
rules_guard = text(
    "test/maintenance_workflow/firestore_rules_online_only_contract_test.dart"
)
lane_guard = text("test/maintenance_workflow/maintenance_lane_policy_test.dart")
security_guard = text("test/stage2d_source_security_contract_test.dart")
isar_test_helper = text("tool/test_support/test_isar_core.dart")
isar_stage_helper = text("tools/isar/stage_governed_test_isar_core.py")
check(
    "R1.13 offline replay closes the persisted open-work invariant",
    sync_job_modules.count("'isOpenForWork': false") >= 2
    and "Map<String, dynamic> _jobModuleSubmitReplayStepData" in sync_job_modules
    and "Map<String, dynamic> _jobModuleAcceptReplayStepData" in sync_job_modules
    and "'isOpenForWork': false" in text(
        "test/job_module_lifecycle_replay_contract_test.dart"
    ),
)
check(
    "R1.13 dialog controllers are State-owned without weakening the guard",
    "class _ComplianceTextPromptDialog extends StatefulWidget" in compliance_detail
    and "_controller.dispose();" in compliance_detail
    and "class _WorkflowTextPromptDialog extends StatefulWidget" in workflow_panel
    and "_controller.dispose();" in workflow_panel
    and "class _RaiseComplianceDialog extends StatefulWidget" in compliance_dialog
    and compliance_dialog.count("Controller.dispose();") >= 3
    and "final controller = TextEditingController" not in compliance_detail
    and "final controller = TextEditingController" not in workflow_panel
    and "final titleController = TextEditingController" not in compliance_dialog,
)
check(
    "R1.13 contract tests follow current governed semantics",
    r"RegExp(r'reopenModule\(\s*_transitionId\(\),')" in async_guard
    and "_expectWorkflowCommandAssignmentContract" in async_guard
    and "_functionBodyStartingAtIndex" in lifecycle_guard
    and "(?:read,\\s*)?create" in rules_guard
    and "seven accountable lanes include governed shared work" in lane_guard
    and security_guard.count("'7.6.5'") >= 2
    and "'7.6.4'" not in security_guard,
)
check(
    "R1.13 Flutter tests use a locked, staged, no-download Isar core",
    "CRM_ISAR_CORE_REQUIRED" in isar_test_helper
    and "download: libraries.isEmpty && !configuredCoreRequired" in isar_test_helper
    and "PE_MACHINE_AMD64 = 0x8664" in isar_stage_helper
    and "_package_pubspec_identity" in isar_stage_helper
    and "packageArchiveSha256" in isar_stage_helper
    and "30_isar_test_core_custody" in harness
    and "flutter test --concurrency=1" in harness
    and "CRM_ISAR_CORE_PATH" in harness
    and "CRM_ISAR_CORE_REQUIRED" in harness
    and "BC6768CC4B9C61AABFF77152E7F33B4B17D2FC93134F7AF1C3DD51500FE8D5E8" in harness
    and "bc6768cc4b9c61aabff77152e7f33b4b17d2fc93134f7af1c3dd51500fe8d5e8" in text("pubspec.lock").lower(),
)


rules = text("firestore.rules")
job_module_rules_test = text("test/job_module_rules.test.js")
firestore_rules_test = text("test/firestore.rules.test.js")
expression_budget_guard = text(
    "test/firestore_rules_expression_budget_contract_test.dart"
)
lifecycle_replay_guard = text("test/job_module_lifecycle_replay_contract_test.dart")
check(
    "R1.14 direct job-module transitions persist the open-state invariant",
    module_provider.count("'isOpenForWork': false") >= 3
    and "'isOpenForWork': true" in module_provider
    and "JobModuleStatus.submitted.name" in module_provider
    and "JobModuleStatus.reopened.name" in module_provider
    and "JobModuleStatus.notApplicable.name" in module_provider
    and "JobModuleStatus.accepted.name" in module_provider
    and "direct Firestore lifecycle transitions persist the open-state invariant"
        in lifecycle_replay_guard,
)
authority_capsule_policy = text("docs/v4_2_r1/PR40_FIRESTORE_AUTHORITY_CAPSULE_POLICY.md")
check(
    "R1.14 Rules enforce minimal read authority and full client-write shape",
    "function validApprovedUserAuthority(data)" in rules
    and "data.keys().hasAll(['isApproved', 'roles'])" in rules
    and "validUserRoleList(data.get('roles', null))" in rules
    and "function validPendingUserCreate(userId)" in rules
    and "function validSelfUserUpdate(userId)" in rules
    and "function validAdminUserProfileUpdate(userId)" in rules
    and expression_budget_guard.count(
        "contains('validUserDocumentShape(request.resource.data)')"
    ) >= 3
    and "isNot(contains('validUserDocumentShape'))" in expression_budget_guard
    and "minimal, security-relevant user" in authority_capsule_policy
    and "Every client user-document create and update" in authority_capsule_policy
    and "function validMaintenanceUpdate()" in rules
    and "allow update: if globalPullStampValidOnUpdate()" in rules
    and "!request.resource.data.diff(resource.data).affectedKeys().hasOnly(["
        in rules
    and "&& validMaintenanceUpdate();" in rules
    and "function validTemplateVersionUpdateDelta()" in rules
    and "function validDirectiveUpdateForRoles(roles)" in rules
    and "function validModuleRegistryFamilyPublishDelta(docId)" in rules
    and "function validModuleRegistryRevisionUpdateDelta(" in rules
    and "function validJobModuleUpdatePayload(docId, changedKeys, roles)" in rules
    and "R1.14 Firestore expression-budget contract" in expression_budget_guard,
)
check(
    "R1.14 job-module Rules fixtures materialize open-state transitions",
    "data.isOpenForWork =" in job_module_rules_test
    and job_module_rules_test.count("isOpenForWork: false") >= 5
    and "isOpenForWork: true" in job_module_rules_test
    and "isOpenForWork: true" in firestore_rules_test
    and "isOpenForWork: false" in firestore_rules_test,
)
maintenance_replay_guard = text("test/maintenance_lifecycle_replay_contract_test.dart")
check(
    "R1.15 maintenance replay contract follows the single Rules router",
    "'match /maintenance_records/{docId}'" in maintenance_replay_guard
    and "contains('allow update: if globalPullStampValidOnUpdate()')"
        in maintenance_replay_guard
    and "contains('&& validMaintenanceUpdate();')" in maintenance_replay_guard
    and r"RegExp(r'allow\s+update\s*:')" in maintenance_replay_guard
    and "Maintenance updates are intentionally split into small branch rules"
        not in maintenance_replay_guard
    and "contains('allow update: if validMaintenanceUpdate();')"
        not in maintenance_replay_guard,
)


check(
    "R1.16 maintenance match parser ignores marker-owned braces",
    "final openBrace = source.indexOf('{', markerIndex + marker.length);"
        in maintenance_replay_guard
    and "final openBrace = source.indexOf('{', markerIndex);"
        not in maintenance_replay_guard,
)

check(
    "R1.16 laboratory captures Firebase CLI smoke evidence and exact tier names",
    'CRM3_V42_R1_16_CANONICAL_LOCAL_LAB_$stamp' in harness
    and 'Write-Output "PASS_FIREBASE_CLI_LOAD_SMOKE' in harness
    and "PASS_AUTHORITATIVE_BUILD_ONLY" in harness
    and "PASS_AUTHORITATIVE_BUILD_AND_EMULATOR" in harness
    and "PASS_AUTHORITATIVE_FRESH_INSTALL" in harness,
)

closure_source = text("functions/src/plannedJobClosure.ts")
closure_unit_test = text("functions/test/plannedJobClosure.test.js")
closure_emulator_test = text(
    "functions/test/plannedJobClosure.firestoreEmulator.test.js"
)
closure_decision = text("docs/v4_2_r1/S06_ATOMIC_CLOSURE_AUTHORITY.md")
programme_ledger = data("governance/programme-ledger.json")
build5_runtime_adjudication_path = (
    ROOT / "release/evidence/build-5-runtime-validation-adjudication.json"
)
build5_runtime_adjudication = data(
    "release/evidence/build-5-runtime-validation-adjudication.json"
)
build5_runtime_adjudication_sha = (
    "5401E163E7B0942B3B4FAFD810A2BE45492666CB8E750ABB54FC0741091FE551"
)
p01_runtime_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "P-01"
]
f3_runtime_records = [
    record
    for record in programme_ledger.get("programmeGates", [])
    if record.get("gateId") == "STAGE2D-F3"
]
p01_runtime_record = (
    p01_runtime_records[0] if len(p01_runtime_records) == 1 else {}
)
f3_runtime_record = f3_runtime_records[0] if len(f3_runtime_records) == 1 else {}
check(
    "Build 5 runtime evidence closes P-01 and F3 without authorizing handout",
    sha(build5_runtime_adjudication_path) == build5_runtime_adjudication_sha
    and build5_runtime_adjudication.get("decision")
        == "PASS_P01_AND_STAGE2D_F3_CLOSED_PILOT_HANDOUT_REMAINS_NOT_AUTHORIZED"
    and build5_runtime_adjudication.get(
        "p01Adjudication",
        {},
    ).get("adjudicatedStatus")
        == "CLOSED"
    and build5_runtime_adjudication.get(
        "stage2dF3Adjudication",
        {},
    ).get("adjudicatedStatus")
        == "CLOSED"
    and build5_runtime_adjudication.get(
        "controlledDistributionChannel",
        {},
    ).get("controlledDistributionPerformed")
        is True
    and build5_runtime_adjudication.get(
        "controlledDistributionChannel",
        {},
    ).get("externalDistributionPerformed")
        is False
    and build5_runtime_adjudication.get(
        "controlledDistributionChannel",
        {},
    ).get("pilotHandoutPerformed")
        is False
    and p01_runtime_record.get("currentStatus") == "CLOSED"
    and [
        entry.get("status")
        for entry in p01_runtime_record.get("statusHistory", [])
    ]
        == [
            "OPEN",
            "SOURCE_IMPLEMENTED",
            "MERGED",
            "DEPLOYED",
            "DEVICE_PROVED",
            "CLOSED",
        ]
    and any(
        entry.get("sha256") == build5_runtime_adjudication_sha
        and entry.get("productionSignedRuntimeGoogleSignInProved") is True
        and entry.get("futurePilotArtifactMustContainRemediation") is True
        for entry in p01_runtime_record.get("evidence", [])
    )
    and f3_runtime_record.get("currentStatus") == "CLOSED"
    and f3_runtime_record.get("authorization") == "CLOSED_PASS"
    and [
        entry.get("status")
        for entry in f3_runtime_record.get("statusHistory", [])
    ]
        == ["OPEN", "CLOSED"]
    and any(
        entry.get("sha256") == build5_runtime_adjudication_sha
        and entry.get("completedExitDimensions") == 3
        and entry.get("requiredExitDimensions") == 3
        and entry.get("controlledDistributionPerformed") is True
        and entry.get("externalDistributionPerformed") is False
        and entry.get("pilotHandoutPerformed") is False
        for entry in f3_runtime_record.get("evidence", [])
    )
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "STAGE2D-F4"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "NOT_AUTHORIZED",
)
auth_profile_source = text("lib/features/auth/providers/auth_provider.dart")
auth_profile_test = text("test/auth_profile_token_race_test.dart")
auth_profile_decision = text(
    "docs/70I_B11_AUTH_PROFILE_RETRY_SESSION_BOUND.md"
)
check(
    "Auth profile permission retry is bounded to one per authenticated session",
    "final retryBudget = CurrentAppUserPermissionRetryBudget();"
        in auth_profile_source
    and "retryBudget.observeAuthEvent(user?.uid);" in auth_profile_source
    and "retryBudget: retryBudget" in auth_profile_source
    and "_authSessionUid == expectedUid" in auth_profile_source
    and "_retryConsumed = true;" in auth_profile_source
    and "var retriedAfterTokenRefresh" not in auth_profile_source
    and "Stream<String?>.fromIterable" in auth_profile_test
    and "same-uid token re-emission cannot reopen the retry budget"
        in auth_profile_test
    and "sign-out starts a new retry budget" in auth_profile_test
    and "ineligible errors fail closed without consuming the retry"
        in auth_profile_test
    and "Status: SOURCE_IMPLEMENTED" in auth_profile_decision
    and "does not authorize pilot handout or distribution"
        in auth_profile_decision,
)
build6_approval_path = (
    ROOT / "release/approvals/build-number-6-rollover-approval.json"
)
build6_exception_path = (
    ROOT
    / "release/approvals/"
    / "private-repository-environment-reviewer-exception-build-6.json"
)
build6_completion_path = (
    ROOT / "release/evidence/build-6-finalization-closure.json"
)
build6_approval = data(
    "release/approvals/build-number-6-rollover-approval.json"
)
build6_exception = data(
    "release/approvals/"
    "private-repository-environment-reviewer-exception-build-6.json"
)
build6_completion = data(
    "release/evidence/build-6-finalization-closure.json"
)
build7_approval_path = (
    ROOT / "release/approvals/build-number-7-rollover-approval.json"
)
build7_exception_path = (
    ROOT
    / "release/approvals/"
    / "private-repository-environment-reviewer-exception-build-7.json"
)
build7_completion_path = (
    ROOT / "release/evidence/build-7-finalization-closure.json"
)
build7_approval = data(
    "release/approvals/build-number-7-rollover-approval.json"
)
build7_exception = data(
    "release/approvals/"
    "private-repository-environment-reviewer-exception-build-7.json"
)
build7_completion = data(
    "release/evidence/build-7-finalization-closure.json"
)
build8_approval_path = (
    ROOT / "release/approvals/build-number-8-rollover-approval.json"
)
build8_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-8.json"
)
build8_approval = data(
    "release/approvals/build-number-8-rollover-approval.json"
)
build8_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-8.json"
)
build8_completion_path = (
    ROOT / "release/evidence/build-8-finalization-closure.json"
)
build8_completion = data(
    "release/evidence/build-8-finalization-closure.json"
)
build8_backend_readiness_path = (
    ROOT
    / "release/evidence/build-8-f4-production-backend-readiness.json"
)
build8_backend_readiness = data(
    "release/evidence/build-8-f4-production-backend-readiness.json"
)
build8_sync_promotion_path = (
    ROOT
    / "release/approvals/build-8-f4-physical-sync-retry-promotion.json"
)
build8_sync_promotion = data(
    "release/approvals/build-8-f4-physical-sync-retry-promotion.json"
)
build8_sync_harness_path = (
    ROOT / "tools/release/Invoke-Build8F4PhysicalSyncRetry.ps1"
)
build8_sync_harness = build8_sync_harness_path.read_text(encoding="utf-8")
build8_sync_doc_path = (
    ROOT / "docs/v4_2_r1/BUILD8_F4_BACKEND_READY_AND_SYNC_RETRY.md"
)
build8_sync_doc = build8_sync_doc_path.read_text(encoding="utf-8")
build8_sync_adjudication_path = (
    ROOT / "release/evidence/build-8-f4-sync-marker-adjudication.json"
)
build8_sync_adjudication = data(
    "release/evidence/build-8-f4-sync-marker-adjudication.json"
)
build8_offline_promotion_path = (
    ROOT / "release/approvals/build-8-f4-offline-reconnect-promotion.json"
)
build8_offline_promotion = data(
    "release/approvals/build-8-f4-offline-reconnect-promotion.json"
)
build8_offline_harness_path = (
    ROOT / "tools/release/Invoke-Build8F4OfflineReconnect.ps1"
)
build8_offline_harness = build8_offline_harness_path.read_text(
    encoding="utf-8"
)
build8_offline_doc_path = (
    ROOT
    / "docs/v4_2_r1/BUILD8_F4_SYNC_MARKER_AND_OFFLINE_RECONNECT.md"
)
build8_offline_doc = build8_offline_doc_path.read_text(encoding="utf-8")
build8_offline_result_path = (
    ROOT / "release/evidence/build-8-f4-offline-reconnect-adjudication.json"
)
build8_offline_result = data(
    "release/evidence/build-8-f4-offline-reconnect-adjudication.json"
)
build8_offline_result_doc_path = (
    ROOT / "docs/v4_2_r1/BUILD8_F4_OFFLINE_RECONNECT_RESULT.md"
)
build8_offline_result_doc = build8_offline_result_doc_path.read_text(
    encoding="utf-8"
)
version_policy_approval = data(
    "release/approvals/version-policy-approval.json"
)
build_number_ledger = data("release/build-number-ledger.json")
build6_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 6
]
build6_entry = build6_entries[0] if len(build6_entries) == 1 else {}
build7_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 7
]
build7_entry = build7_entries[0] if len(build7_entries) == 1 else {}
build8_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 8
]
build8_entry = build8_entries[0] if len(build8_entries) == 1 else {}
check(
    "Builds 6 through 8 are finalized and remain non-distributable",
    sha(build6_approval_path)
        == "3BEF74A8976E2D01F04E49F38DB4D59EAC05C68EC2C44D603BCBF014A6542141"
    and sha(build6_exception_path)
        == "B3B8F50593CB13D94FE269E97BDD2C46EF7E1E3A7822F52B79A75328EDED4C02"
    and build6_approval.get("approvalReference") == "BAF-REF-003-C5"
    and build6_approval.get("approved") is True
    and build6_approval.get("distributionApproved") is False
    and build6_approval.get("unrestrictedPlantReleaseApproved") is False
    and build6_approval.get("consumedBuild", {}).get("buildNumber") == 5
    and build6_approval.get("consumedBuild", {}).get(
        "closureFinalizationCompleted"
    )
        is True
    and build6_approval.get("consumedBuild", {}).get(
        "distributionPerformed"
    )
        is False
    and build6_approval.get("nextBuild", {}).get("buildNumber") == 6
    and build6_approval.get("requiredSource", {}).get(
        "tokenRaceRemediationMergeCommit"
    )
        == "416fe777ffd52162de5666a860e185167ecf9e23"
    and build6_approval.get("requiredSource", {}).get(
        "c03ClosureMergeCommit"
    )
        == "f6ddd3cd2e64af4e4a2c987fefee3af5e8eca2fc"
    and build6_exception.get("approvalReference") == "BAF-GH-ENV-002"
    and build6_exception.get("scope", {}).get("buildNumber") == 6
    and build6_exception.get("scope", {}).get("singleBuildOnly") is True
    and build6_exception.get("liveStateEvidence", {}).get(
        "requiredReviewerRulePresent"
    )
        is False
    and build6_exception.get("liveStateEvidence", {}).get(
        "secretValuesInspected"
    )
        is False
    and build6_exception.get("liveStateEvidence", {}).get(
        "environmentApprovalHistoryObserved"
    )
        == "not-inspected"
    and sha(build7_approval_path)
        == "E2D25FAFB29D1EAB42E8BF8C03D38F60FDF75D4C2A8CE5037D9DA61E56C89C76"
    and sha(build7_exception_path)
        == "9430D7D23568C7BCD25248790F47E18D9A4C464336C50D4C76D36E97DF68D800"
    and build7_approval.get("approvalReference") == "BAF-REF-003-C6"
    and build7_approval.get("approved") is True
    and build7_approval.get("distributionApproved") is False
    and build7_approval.get("unrestrictedPlantReleaseApproved") is False
    and build7_approval.get("consumedBuild", {}).get("buildNumber") == 6
    and build7_approval.get("consumedBuild", {}).get(
        "closureFinalizationCompleted"
    )
        is True
    and build7_approval.get("consumedBuild", {}).get(
        "distributionPerformed"
    )
        is False
    and build7_approval.get("nextBuild", {}).get("buildNumber") == 7
    and build7_approval.get("requiredSource", {}).get(
        "firestoreValueNormalizationMergeCommit"
    )
        == "53b10006bc8e34240e2ec94b861ef907311071c0"
    and build7_approval.get("requiredSource", {}).get(
        "tokenRaceRemediationMergeCommit"
    )
        == "416fe777ffd52162de5666a860e185167ecf9e23"
    and build7_approval.get("requiredSource", {}).get(
        "c03ClosureMergeCommit"
    )
        == "f6ddd3cd2e64af4e4a2c987fefee3af5e8eca2fc"
    and build7_approval.get("controls", {}).get(
        "androidPrPackagingProofRequired"
    )
        is True
    and build7_approval.get("controls", {}).get(
        "tokenRaceRemediationRequired"
    )
        is True
    and build7_approval.get("runtimeFinding", {}).get(
        "build6CanSatisfyF4"
    )
        is False
    and build7_approval.get("controls", {}).get(
        "productionBackfillAuthorized"
    )
        is False
    and build7_approval.get("controls", {}).get(
        "globalPullRuntimeContractActivationAuthorized"
    )
        is False
    and build7_approval.get("controls", {}).get(
        "productionDataMutationAuthorized"
    )
        is False
    and build7_exception.get("approvalReference") == "BAF-GH-ENV-003"
    and build7_exception.get("scope", {}).get("buildNumber") == 7
    and build7_exception.get("scope", {}).get("singleBuildOnly") is True
    and build7_exception.get("liveStateEvidence", {}).get(
        "requiredReviewerRulePresent"
    )
        is False
    and build7_exception.get("liveStateEvidence", {}).get(
        "secretValuesInspected"
    )
        is False
    and sha(build8_approval_path)
        == combined_policy.get("versionPolicy", {}).get(
            "sourceDocumentSha256"
        )
    and sha(build8_approval_path)
        == "5060D9CC53FB9F65CCA888F913A45A1C7D4B5629FF93350138DB8C4E605A7335"
    and build8_approval.get("approvalReference") == "BAF-REF-003-C7"
    and build8_approval.get("approved") is True
    and build8_approval.get("consumedBuild", {}).get("buildNumber") == 7
    and build8_approval.get("nextBuild", {}).get("buildNumber") == 8
    and build8_approval.get("requiredSource", {}).get(
        "integratedSuccessorPullRequest"
    )
        == 117
    and build8_approval.get("requiredSource", {}).get(
        "integratedSuccessorMergeCommit"
    )
        == "45ebd9c853798f88fedd2e4d72d6022dc389097f"
    and build8_approval.get("requiredSource", {}).get(
        "integratedSuccessorTree"
    )
        == "24487330756ea9933be5bf81181fde4d607e375d"
    and build8_approval.get("requiredSource", {}).get(
        "postMergeGithubRunId"
    )
        == 30796250694
    and build8_approval.get("requiredSource", {}).get(
        "postMergeGithubRunConclusion"
    )
        == "success"
    and build8_approval.get("controls", {}).get(
        "publicRepositoryRequiredReviewerApproved"
    )
        is True
    and build8_approval.get("controls", {}).get(
        "approvedEnvironmentReviewHistoryRequired"
    )
        is True
    and build8_approval.get("controls", {}).get("adminBypassProhibited")
        is True
    and build8_approval.get("controls", {}).get(
        "mainOnlyEnvironmentDeploymentRequired"
    )
        is True
    and build8_approval.get("distributionApproved") is False
    and build8_approval.get("unrestrictedPlantReleaseApproved") is False
    and sha(build8_environment_approval_path)
        == combined_policy.get("github", {})
        .get("environmentReviewControl", {})
        .get("approvalReceiptSha256")
    and sha(build8_environment_approval_path)
        == "B763824728626C23F12C5DAC76428F803CF37E2433DD041E1157F8EDCEF391DE"
    and build8_environment_approval.get("receiptType")
        == "public-repository-required-reviewer-control"
    and build8_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-004"
    and build8_environment_approval.get("scope", {}).get(
        "repositoryVisibility"
    )
        == "public"
    and build8_environment_approval.get("scope", {}).get("buildNumber")
        == 8
    and build8_environment_approval.get("liveStateEvidence", {}).get(
        "requiredReviewerRulePresent"
    )
        is True
    and build8_environment_approval.get("liveStateEvidence", {}).get(
        "requiredReviewer", {}
    ).get("id")
        == 213690022
    and build8_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    )
        is False
    and build8_environment_approval.get("liveStateEvidence", {}).get(
        "deploymentBranchPolicy", {}
    ).get("allowedBranches")
        == [{"name": "main", "type": "branch"}]
    and build8_environment_approval.get("singleOperatorConstraint", {}).get(
        "independentSecondPartyReviewerAvailable"
    )
        is False
    and build8_environment_approval.get("singleOperatorConstraint", {}).get(
        "explicitEnvironmentApprovalStillRequired"
    )
        is True
    and combined_policy.get("github", {}).get(
        "environmentReviewControl", {}
    ).get("mode")
        == "public-repository-required-reviewer"
    and combined_policy.get("github", {}).get(
        "environmentReviewControl", {}
    ).get("adminBypassAllowed")
        is False
    and version_policy_approval.get("reference") == "BAF-REF-003-C7"
    and version_policy_approval.get("buildNumber") == 8
    and combined_policy.get("release", {}).get("buildNumber") == 8
    and combined_policy.get("finalization", {}).get("status")
        == "completed-non-distributable"
    and sha(build8_completion_path)
        == combined_policy.get("finalization", {}).get(
            "completionReceiptSha256"
        )
    and combined_policy.get("finalization", {}).get("sourceCommit")
        == "731a02980d38e4e3a8f61ff2bca74a1e85771478"
    and combined_policy.get("finalization", {}).get("githubRunId")
        == 30839125687
    and combined_policy.get("finalization", {}).get(
        "governedPackageSha256"
    )
        == "75362F9875CC5067012B4A5768720CB4AE0AD2C6A94B38C1F174E0FD1E1CA91F"
    and combined_policy.get("finalization", {}).get(
        "dualCustodyCompleted"
    )
        is True
    and combined_policy.get("finalization", {}).get(
        "firebaseBackendDeploymentPerformed"
    )
        is False
    and combined_policy.get("finalization", {}).get(
        "controlledPilotApproved"
    )
        is False
    and combined_policy.get("finalization", {}).get(
        "unrestrictedPlantReleaseApproved"
    )
        is False
    and combined_policy.get("distribution", {}).get("approved") is False
    and combined_policy.get("distribution", {}).get(
        "unrestrictedPlantReleaseApproved"
    )
        is False
    and build8_completion.get("status") == "passed-non-distributable"
    and build8_completion.get("sourceAuthority", {}).get("commit")
        == "731a02980d38e4e3a8f61ff2bca74a1e85771478"
    and build8_completion.get("sourceAuthority", {}).get(
        "pullRequestNumber"
    )
        == 118
    and build8_completion.get("workflow", {}).get("runId")
        == 30839125687
    and build8_completion.get("workflow", {}).get("actorId")
        == 213690022
    and build8_completion.get("governedPackage", {}).get("sha256")
        == "75362F9875CC5067012B4A5768720CB4AE0AD2C6A94B38C1F174E0FD1E1CA91F"
    and build8_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    )
        == "f9f6f3fbacd33d824bf4b5213b0b28f6d7e29feb"
    and build8_completion.get("dualCustody", {}).get("distinctVolumes")
        is True
    and build8_completion.get("dualCustody", {}).get(
        "allFileHashesMatched"
    )
        is True
    and build8_completion.get("recoveryIncident", {}).get("occurred")
        is False
    and build8_completion.get("releaseBoundary", {}).get(
        "firebaseBackendDeploymentPerformed"
    )
        is False
    and build8_completion.get("releaseBoundary", {}).get(
        "controlledPilotApproved"
    )
        is False
    and build8_completion.get("releaseBoundary", {}).get(
        "distributionPerformed"
    )
        is False
    and build7_completion.get("status") == "passed-non-distributable"
    and build7_completion.get("sourceAuthority", {}).get("commit")
        == "d8619ef1a9c7bf53828523c4bca3efe33e4074f0"
    and build7_completion.get("sourceAuthority", {}).get(
        "pullRequestNumber"
    )
        == 112
    and build7_completion.get("workflow", {}).get("runId")
        == 30757692948
    and build7_completion.get("governedPackage", {}).get("sha256")
        == "D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7"
    and build7_completion.get("remoteAuthority", {}).get(
        "reservationTagObjectSha"
    )
        == "5e351f0b5acf1f887e14c5ad70c60864a5d6c470"
    and build7_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    )
        == "b06edcbcd4fdb2d27fc4b844dd16f54340aa0c3d"
    and build7_completion.get("dualCustody", {}).get("distinctVolumes")
        is True
    and build7_completion.get("dualCustody", {}).get(
        "allFileHashesMatched"
    )
        is True
    and build7_completion.get("localPreflightIncidents", {}).get(
        "occurred"
    )
        is True
    and len(
        build7_completion.get("localPreflightIncidents", {}).get(
            "incidents", []
        )
    )
        == 2
    and build6_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and len(build6_entry.get("preReservationDispatchFailures", [])) == 1
    and build6_entry.get("preReservationDispatchFailures", [{}])[0].get(
        "githubRunId"
    )
        == 30531942779
    and build6_entry.get("preReservationDispatchFailures", [{}])[0].get(
        "failureBoundary"
    )
        == (
            "java-distribution-resolution-before-secret-preflight-"
            "and-reservation"
        )
    and build6_entry.get("preReservationDispatchFailures", [{}])[0].get(
        "remoteReservationTagCreated"
    )
        is False
    and build6_entry.get("preReservationDispatchFailures", [{}])[0].get(
        "numberConsumed"
    )
        is False
    and build6_completion.get("status") == "passed-non-distributable"
    and build6_completion.get("sourceAuthority", {}).get("commit")
        == "f6fccc662119790bcc742ff91e00934117030948"
    and build6_completion.get("workflow", {}).get("runId")
        == 30572342725
    and build6_completion.get("governedPackage", {}).get("sha256")
        == "E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E"
    and build6_completion.get("remoteAuthority", {}).get(
        "reservationTagObjectSha"
    )
        == "9c82843b84194c9eeef9a4d7ec7b81d1d0c8caa7"
    and build6_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    )
        == "189f668f8f59f934b1baec0b9bdf723dc7960b6c"
    and build6_completion.get("dualCustody", {}).get("distinctVolumes")
        is True
    and build6_completion.get("dualCustody", {}).get(
        "allFileHashesMatched"
    )
        is True
    and build6_completion.get("finalizationRetryIncident", {}).get(
        "occurred"
    )
        is True
    and build6_completion.get("recoveryIncident", {}).get("occurred")
        is False
    and build6_completion.get("releaseBoundary", {}).get(
        "firebaseBackendDeploymentPerformed"
    )
        is False
    and build6_completion.get("releaseBoundary", {}).get(
        "controlledPilotApproved"
    )
        is False
    and build6_completion.get("releaseBoundary", {}).get(
        "distributionPerformed"
    )
        is False
    and build6_entry.get("githubRunId") == 30572342725
    and build6_entry.get("remoteReservationTagObject")
        == "9c82843b84194c9eeef9a4d7ec7b81d1d0c8caa7"
    and build6_entry.get("remoteBuiltTagObject")
        == "189f668f8f59f934b1baec0b9bdf723dc7960b6c"
    and build6_entry.get("closureFinalizationCompleted") is True
    and build6_entry.get("dualCustodyCompleted") is True
    and build6_entry.get("distributionPerformed") is False
    and build7_completion.get("finalizationRetryIncident", {}).get(
        "occurred"
    )
        is True
    and build7_completion.get("recoveryIncident", {}).get("occurred")
        is False
    and build7_completion.get("releaseBoundary", {}).get(
        "firebaseBackendDeploymentPerformed"
    )
        is False
    and build7_completion.get("releaseBoundary", {}).get(
        "controlledPilotApproved"
    )
        is False
    and build7_completion.get("releaseBoundary", {}).get(
        "distributionPerformed"
    )
        is False
    and build7_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build7_entry.get("versionApprovalReference") == "BAF-REF-003-C6"
    and build7_entry.get("versionApprovalDocumentSha256")
        == sha(build7_approval_path)
    and build7_entry.get("remoteReservationTag")
        == "crm3-build-reserved/7"
    and build7_entry.get("remoteBuiltTag") == "crm3-build-built/7"
    and build7_entry.get("githubRunId") == 30757692948
    and build7_entry.get("remoteReservationTagObject")
        == "5e351f0b5acf1f887e14c5ad70c60864a5d6c470"
    and build7_entry.get("remoteBuiltTagObject")
        == "b06edcbcd4fdb2d27fc4b844dd16f54340aa0c3d"
    and build7_entry.get("closureFinalizationCompleted") is True
    and build7_entry.get("dualCustodyCompleted") is True
    and build7_entry.get("localFinalizerPreflightIncidentCount") == 2
    and build7_entry.get("finalizationRetryRequired") is True
    and build7_entry.get("distributionPerformed") is False
    and build8_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build8_entry.get("baselineCommit")
        == "45ebd9c853798f88fedd2e4d72d6022dc389097f"
    and build8_entry.get("versionApprovalReference") == "BAF-REF-003-C7"
    and build8_entry.get("versionApprovalDocumentSha256")
        == sha(build8_approval_path)
    and build8_entry.get("remoteReservationTag")
        == "crm3-build-reserved/8"
    and build8_entry.get("remoteBuiltTag") == "crm3-build-built/8"
    and build8_entry.get("failedOrWithdrawnBuildConsumesNumber") is True
    and build8_entry.get("githubRunId") == 30839125687
    and build8_entry.get("remoteReservationTagObject")
        == "e0a50955db970ddd2c93e6bda6dc0517eaca150f"
    and build8_entry.get("remoteBuiltTagObject")
        == "f9f6f3fbacd33d824bf4b5213b0b28f6d7e29feb"
    and build8_entry.get("governedPackageSha256")
        == "75362F9875CC5067012B4A5768720CB4AE0AD2C6A94B38C1F174E0FD1E1CA91F"
    and build8_entry.get("completionReceiptSha256")
        == sha(build8_completion_path)
    and build8_entry.get("closureFinalizationCompleted") is True
    and build8_entry.get("dualCustodyCompleted") is True
    and build8_entry.get("remoteBuiltTagCreated") is True
    and build8_entry.get("remoteTagPushRecoveryRequired") is False
    and build8_entry.get("firebaseBackendDeploymentPerformed") is False
    and build8_entry.get("controlledPilotApproved") is False
    and build8_entry.get("distributionPerformed") is False,
)
check(
    "Build 8 backend is ready and its one physical sync retry stays bounded",
    sha(build8_sync_promotion_path)
        == "C453E38385A4405B0C44E66272DDC038C3E56C33F7793A7D7A17F89D11EF4E64"
    and sha(build8_sync_harness_path)
        == "C8381F1A6547924B14DD8B72258116A8756C8153700F7200D0B81B340FC9401E"
    and sha(build8_sync_doc_path)
        == "3D87B906FBD9714849D26FF8B7BCCA7E2079545B1E440239BCD26095A0A507D7"
    and "Status: BACKEND READY; ONE EXACT-TARGET SYNC RETRY PROPOSED"
        in build8_sync_doc
    and sha(build8_backend_readiness_path)
        == combined_policy.get("finalization", {})
        .get("backendActivation", {})
        .get("evidenceSha256")
    and build8_backend_readiness.get("decision")
        == "PASS_BUILD8_F4_BACKEND_READY"
    and build8_backend_readiness.get("sourceAuthority", {}).get(
        "deploymentCommit"
    )
        == "34dd01511ffd0ca4aba37735b6dfd710d2964b46"
    and build8_backend_readiness.get("sourceAuthority", {}).get(
        "postMergeReleaseGateRunId"
    )
        == 30850203589
    and build8_backend_readiness.get("sourceAuthority", {}).get(
        "postMergeReleaseGateConclusion"
    )
        == "success"
    and build8_backend_readiness.get("liveReadback", {}).get(
        "globalPullContractState"
    )
        == "ACTIVE"
    and build8_backend_readiness.get("liveReadback", {}).get(
        "inventoryTotal"
    )
        == 42
    and build8_backend_readiness.get("liveReadback", {}).get(
        "inventoryStamped"
    )
        == 42
    and build8_backend_readiness.get("liveReadback", {}).get(
        "inventoryMissing"
    )
        == 0
    and build8_backend_readiness.get("liveReadback", {}).get(
        "inventoryMalformed"
    )
        == 0
    and build8_backend_readiness.get("mutationAdjudication", {}).get(
        "watermarkFieldsCreated"
    )
        == 41
    and build8_backend_readiness.get("mutationAdjudication", {}).get(
        "businessFieldsMutated"
    )
        is False
    and build8_backend_readiness.get("mutationAdjudication", {}).get(
        "distributionPerformed"
    )
        is False
    and build8_backend_readiness.get("programmeBoundary", {}).get(
        "stage2dF4Status"
    )
        == "OPEN"
    and build8_backend_readiness.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build8_backend_readiness.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False
    and build8_sync_promotion.get("approved") is True
    and build8_sync_promotion.get("approvalClass")
        == "CONTROLLED_EXACT_TARGET_BUILD8_POST_ACTIVATION_SYNC_RETRY"
    and build8_sync_promotion.get("backendAuthority", {}).get(
        "evidenceSha256"
    )
        == sha(build8_backend_readiness_path)
    and build8_sync_promotion.get("artifactAuthority", {}).get(
        "finalizationEvidenceSha256"
    )
        == sha(build8_completion_path)
    and build8_sync_promotion.get("artifactAuthority", {})
        .get("apk", {})
        .get("versionCode")
        == 8
    and build8_sync_promotion.get("artifactAuthority", {})
        .get("apk", {})
        .get("debuggable")
        is False
    and build8_sync_promotion.get("targetAuthority", {}).get(
        "maxTargetCount"
    )
        == 1
    and build8_sync_promotion.get("targetAuthority", {}).get(
        "physicalDeviceRequired"
    )
        is True
    and build8_sync_promotion.get("targetAuthority", {}).get(
        "rawAdbSerialRetained"
    )
        is False
    and build8_sync_promotion.get("authorizedMutations", {}).get(
        "applicationInstallOrUpgrade"
    )
        == "PROHIBITED_ALREADY_EXACT"
    and build8_sync_promotion.get("authorizedMutations", {}).get(
        "inAppManualSync"
    )
        == "ONE_ATTEMPT"
    and build8_sync_promotion.get("authorizedMutations", {}).get(
        "firebaseBackend"
    )
        == "PROHIBITED"
    and build8_sync_promotion.get("authorizedMutations", {}).get(
        "deviceDataClearOrUninstall"
    )
        == "PROHIBITED"
    and build8_sync_promotion.get("authorizedMutations", {}).get(
        "distribution"
    )
        == "PROHIBITED"
    and build8_sync_promotion.get("passCriteria", {}).get(
        "pendingLocalBusinessWritesBefore"
    )
        == 0
    and build8_sync_promotion.get("passCriteria", {}).get(
        "manualSyncOutcome"
    )
        == "SUCCESS"
    and build8_sync_promotion.get("programmeBoundary", {}).get(
        "stage2dF4Status"
    )
        == "OPEN"
    and build8_sync_promotion.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build8_sync_promotion.get("programmeBoundary", {}).get(
        "offlineReconnectAuthorized"
    )
        is False
    and build8_sync_promotion.get("programmeBoundary", {}).get(
        "weakNetworkAuthorized"
    )
        is False
    and all(
        marker in build8_sync_harness
        for marker in [
            "Physical sync retry requires exact tracked-clean main equal to origin/main.",
            "Pending local business writes are nonzero; sync retry is prohibited.",
            "PASS_BUILD8_F4_POST_ACTIVATION_SYNC_MARKER",
            "stage2dF4ClosureAuthorized = $false",
            "pilotHandoutAuthorized = $false",
            "rawUiRetained = $false",
        ]
    )
    and all(
        marker not in build8_sync_harness.lower()
        for marker in [
            "'pm', 'clear'",
            "'uninstall'",
            "firebase deploy",
            "appdistribution:distribute",
        ]
    ),
)
build8_f4_gate_records = [
    record
    for record in programme_ledger.get("programmeGates", [])
    if record.get("gateId") == "STAGE2D-F4"
]
check(
    "Build 8 sync is adjudicated and offline reconnect restores exact transport",
    sha(build8_sync_adjudication_path)
        == "A165DFD44ED2B2BE9DDC27F20D4D982585EA7C0DC5749915BEE1C545DFAB5F5C"
    and sha(build8_offline_promotion_path)
        == "84B42ED1950AE31717410DBB8ACFE210B30ED12D8D5DC844B43A7E8D99B3F2DE"
    and sha(build8_offline_harness_path)
        == "E2E966760A9E29E0E1C1487B1D236D5A66B2EC2647C89730D6305E57F948DC42"
    and sha(build8_offline_doc_path)
        == "55D55F28FB38C4B42B0486FB4521129240CC11E60F01289C287389FE494438E6"
    and build8_sync_adjudication.get("decision")
        == "PASS_BUILD8_F4_SYNC_MARKER_ADJUDICATED"
    and build8_sync_adjudication.get("externalReceipt", {}).get("sha256")
        == "304F9F4D9CBA6DAD71B2FBF9B26B17F32C2830C1AFD74316B283E44A83ED9E8E"
    and build8_sync_adjudication.get("externalReceipt", {}).get("bytes")
        == 4775
    and build8_sync_adjudication.get("externalReceipt", {}).get(
        "sourceCommit"
    )
        == build8_sync_adjudication.get("externalReceipt", {}).get(
            "sourceOriginMain"
        )
    and build8_sync_adjudication.get("externalReceipt", {}).get(
        "postMergeRunId"
    )
        == 30864309478
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "backendInventoryMissing"
    )
        == 0
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "backendInventoryMalformed"
    )
        == 0
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "installedVersionCode"
    )
        == 8
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "manualSyncOutcome"
    )
        == "SUCCESS"
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "pendingLocalBusinessWritesBefore"
    )
        == 0
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "pendingLocalBusinessWritesAfter"
    )
        == 0
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "unresolvedLocalRejectionsBefore"
    )
        == 0
    and build8_sync_adjudication.get("verifiedFacts", {}).get(
        "unresolvedLocalRejectionsAfter"
    )
        == 0
    and all(
        value is False
        for value in build8_sync_adjudication.get(
            "privacyBoundary", {}
        ).values()
    )
    and build8_sync_adjudication.get("programmeBoundary", {}).get(
        "stage2dF4Status"
    )
        == "OPEN"
    and build8_sync_adjudication.get("programmeBoundary", {}).get(
        "syncMarkerCriterionProved"
    )
        is True
    and build8_sync_adjudication.get("programmeBoundary", {}).get(
        "offlineReconnectCriterionProved"
    )
        is False
    and build8_offline_promotion.get("approved") is True
    and build8_offline_promotion.get("approvalClass")
        == "CONTROLLED_EXACT_TARGET_BUILD8_OFFLINE_RECONNECT"
    and build8_offline_promotion.get("approvalAuthority", {}).get(
        "baselineCommit"
    )
        == "f038cbe90ef0d85d99dc4f6be28b06b893a5ed69"
    and build8_offline_promotion.get("syncAuthority", {}).get(
        "adjudicationSha256"
    )
        == sha(build8_sync_adjudication_path)
    and build8_offline_promotion.get("syncAuthority", {}).get(
        "externalReceiptSha256"
    )
        == build8_sync_adjudication.get("externalReceipt", {}).get("sha256")
    and build8_offline_promotion.get("artifactAuthority", {})
        .get("apk", {})
        .get("versionCode")
        == 8
    and build8_offline_promotion.get("targetAuthority", {}).get(
        "maxTargetCount"
    )
        == 1
    and build8_offline_promotion.get("authorizedMutations", {}).get(
        "wifiAndMobileData"
    )
        == "TEMPORARY_DISABLE_THEN_EXACT_RESTORE"
    and build8_offline_promotion.get("authorizedMutations", {}).get(
        "airplaneMode"
    )
        == "READ_ONLY_UNCHANGED"
    and build8_offline_promotion.get("authorizedMutations", {}).get(
        "firebaseBackend"
    )
        == "PROHIBITED"
    and build8_offline_promotion.get("authorizedMutations", {}).get(
        "deviceDataClearOrUninstall"
    )
        == "PROHIBITED"
    and build8_offline_promotion.get("authorizedMutations", {}).get(
        "distribution"
    )
        == "PROHIBITED"
    and build8_offline_promotion.get("passCriteria", {}).get(
        "offlineManualSyncMustNotReportSuccess"
    )
        is True
    and build8_offline_promotion.get("passCriteria", {}).get(
        "exactInitialTransportStateRestored"
    )
        is True
    and build8_offline_promotion.get("programmeBoundary", {}).get(
        "offlineReconnectAuthorized"
    )
        is True
    and build8_offline_promotion.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build8_offline_promotion.get("programmeBoundary", {}).get(
        "weakNetworkAuthorized"
    )
        is False
    and build8_offline_promotion.get("failurePolicy", {}).get(
        "restoreTransportInFinally"
    )
        is True
    and all(
        marker in build8_offline_harness
        for marker in [
            "External sync-marker receipt SHA-256",
            "Pre-offline pending local business writes",
            "FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED",
            "TRANSPORT_RESTORATION_FAILED",
            "POST_RECONNECT_VALIDATION_FAILED",
            "failedPhaseMayNotBeRelabelledPass = $true",
            "PASS_BUILD8_F4_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY",
            "stage2dF4Status = 'OPEN'",
            "stage2dF4ClosureAuthorized = $false",
            "pilotHandoutAuthorized = $false",
            "rawUiRetained = $false",
        ]
    )
    and all(
        marker not in build8_offline_harness.lower()
        for marker in [
            "'pm', 'clear'",
            "'uninstall'",
            "firebase deploy",
            "appdistribution:distribute",
            "'svc', 'airplane'",
        ]
    )
    and "Status: SYNC MARKER PROVED; EXACT-TARGET OFFLINE/RECONNECT PROPOSED"
        in build8_offline_doc
    and "It does not close F4 or authorize distribution."
        in build8_offline_doc
    and len(build8_f4_gate_records) == 1
    and build8_f4_gate_records[0].get("currentStatus") == "OPEN"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "STAGE2D-F4"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "NOT_AUTHORIZED",
)
check(
    "Build 8 offline reconnect is evidence-proved without a throttle claim",
    sha(build8_offline_result_path)
        == "95A5B0C0524B98104E47A69EDA1EFC7D827D9A5E8125042F83C20A742D7A0394"
    and sha(build8_offline_result_doc_path)
        == "55F1CBD5163EC5C3C95F2EE8560C3CB04DEB9EB1E827A1E1DE8260A79B6BE1D0"
    and build8_offline_result.get("decision")
        == "PASS_BUILD8_F4_OFFLINE_RECONNECT_ADJUDICATED"
    and build8_offline_result.get("externalReceipt", {}).get("sha256")
        == "BE414FFFD556F0F5DEC741BF5598EFC9670524DF6DDCC68833572A192C8A3A77"
    and build8_offline_result.get("externalReceipt", {}).get("bytes")
        == 6542
    and build8_offline_result.get("externalReceipt", {}).get("sourceCommit")
        == build8_offline_result.get("externalReceipt", {}).get(
            "sourceOriginMain"
        )
    and build8_offline_result.get("externalReceipt", {}).get(
        "postMergeRunId"
    )
        == 30932769330
    and build8_offline_result.get("externalReceipt", {}).get("decision")
        == "PASS_BUILD8_F4_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY"
    and build8_offline_result.get("verifiedFacts", {}).get(
        "pendingLocalBusinessWritesBefore"
    )
        == 0
    and build8_offline_result.get("verifiedFacts", {}).get(
        "unresolvedLocalRejectionsBefore"
    )
        == 0
    and build8_offline_result.get("verifiedFacts", {}).get(
        "allTransportsDisabledDuringObservation"
    )
        is True
    and build8_offline_result.get("verifiedFacts", {}).get(
        "falseSuccessObserved"
    )
        is False
    and build8_offline_result.get("verifiedFacts", {}).get(
        "exactTransportStateRestored"
    )
        is True
    and build8_offline_result.get("verifiedFacts", {}).get("initialWifiOn")
        == build8_offline_result.get("verifiedFacts", {}).get(
            "restoredWifiOn"
        )
    and build8_offline_result.get("verifiedFacts", {}).get(
        "initialMobileDataOn"
    )
        == build8_offline_result.get("verifiedFacts", {}).get(
            "restoredMobileDataOn"
        )
    and build8_offline_result.get("verifiedFacts", {}).get(
        "initialAirplaneModeOn"
    )
        == build8_offline_result.get("verifiedFacts", {}).get(
            "restoredAirplaneModeOn"
        )
    and build8_offline_result.get("verifiedFacts", {}).get(
        "postReconnectManualSyncOutcome"
    )
        == "SUCCESS"
    and build8_offline_result.get("verifiedFacts", {}).get(
        "pendingLocalBusinessWritesAfter"
    )
        == 0
    and build8_offline_result.get("verifiedFacts", {}).get(
        "unresolvedLocalRejectionsAfter"
    )
        == 0
    and build8_offline_result.get("verifiedFacts", {}).get(
        "failureReceiptPresent"
    )
        is False
    and build8_offline_result.get("verifiedFacts", {}).get(
        "temporaryArtifactCountAfterExecution"
    )
        == 0
    and build8_offline_result.get("executionBoundary", {}).get(
        "networkStateTemporarilyChanged"
    )
        is True
    and build8_offline_result.get("executionBoundary", {}).get(
        "exactNetworkStateRestored"
    )
        is True
    and all(
        value is False
        for key, value in build8_offline_result.get(
            "executionBoundary", {}
        ).items()
        if key not in {
            "networkStateTemporarilyChanged",
            "exactNetworkStateRestored",
        }
    )
    and all(
        value is False
        for value in build8_offline_result.get(
            "privacyBoundary", {}
        ).values()
    )
    and build8_offline_result.get("methodQualification", {}).get(
        "offlineReconnectClaim"
    )
        == "PROVED"
    and build8_offline_result.get("methodQualification", {}).get(
        "bandwidthOrLatencyDegradationClaim"
    )
        == "NOT_TESTED"
    and build8_offline_result.get("methodQualification", {}).get(
        "nextMethodIsBandwidthThrottle"
    )
        is False
    and build8_offline_result.get("programmeBoundary", {}).get(
        "stage2dF4Status"
    )
        == "OPEN"
    and build8_offline_result.get("programmeBoundary", {}).get(
        "approvedSignInCriterionProved"
    )
        is True
    and build8_offline_result.get("programmeBoundary", {}).get(
        "syncMarkerCriterionProved"
    )
        is True
    and build8_offline_result.get("programmeBoundary", {}).get(
        "offlineReconnectCriterionProved"
    )
        is True
    and build8_offline_result.get("programmeBoundary", {}).get(
        "weakNetworkCriterionProved"
    )
        is False
    and build8_offline_result.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build8_offline_result.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False
    and build8_offline_result.get("programmeBoundary", {}).get(
        "distributionAuthorized"
    )
        is False
    and "Status: OFFLINE/RECONNECT PROVED; F4 REMAINS OPEN"
        in build8_offline_result_doc
    and "does not claim measured low bandwidth"
        in build8_offline_result_doc
    and "bandwidth-throttling result." in build8_offline_result_doc
    and len(build8_f4_gate_records) == 1
    and build8_f4_gate_records[0].get("currentStatus") == "OPEN"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "NOT_AUTHORIZED",
)
build7_f4_compatibility = data(
    "release/approvals/build-7-f4-firestore-compatibility-promotion.json"
)
build7_f4_compatibility_harness = text(
    "tools/release/Invoke-Build7F4FirestoreCompatibilityCampaign.ps1"
)
build7_f4_compatibility_doc = text(
    "docs/v4_2_r1/BUILD7_F4_PHYSICAL_FIRESTORE_COMPATIBILITY_PROMOTION.md"
)
build7_f4_phase_ids = {
    phase.get("id")
    for phase in build7_f4_compatibility.get("requiredPhases", [])
}
build7_f4_prohibited = "\n".join(
    build7_f4_compatibility.get("prohibitedOperations", [])
)
build7_f4_gate = next(
    (
        record
        for record in programme_ledger.get("programmeGates", [])
        if record.get("gateId") == "STAGE2D-F4"
    ),
    {},
)
check(
    "Build 7 physical Timestamp compatibility is exact-target and one-row bounded",
    build7_f4_compatibility.get("approvalClass")
        == "CONTROLLED_EXACT_TARGET_BUILD7_FIRESTORE_COMPATIBILITY_EXECUTION"
    and build7_f4_compatibility.get("approvalAuthority", {}).get(
        "baselineCommit"
    )
        == "9b6bb0c27f8585470e743f352ccd2922561344a3"
    and build7_f4_compatibility.get("build6Lineage", {}).get(
        "installedApkSha256"
    )
        == "01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755"
    and build7_f4_compatibility.get("build7ArtifactAuthority", {}).get(
        "sourceCommit"
    )
        == "d8619ef1a9c7bf53828523c4bca3efe33e4074f0"
    and build7_f4_compatibility.get("build7ArtifactAuthority", {}).get(
        "governedPackage", {}
    ).get("sha256")
        == "D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7"
    and build7_f4_compatibility.get("build7ArtifactAuthority", {}).get(
        "apk", {}
    ).get("sha256")
        == "EE5B5B7205A37F1FEF1F1B4C98CB1446ED544A123E130D7F3A4134E6A5E6DD56"
    and build7_f4_compatibility.get("targetAuthority", {}).get("model")
        == "SM-G990E"
    and len(
        build7_f4_compatibility.get("targetAuthority", {}).get(
            "adbSerialSha256", ""
        )
    )
        == 64
    and build7_f4_compatibility.get("channel", {}).get(
        "inPlaceUpgradeAuthorized"
    )
        is True
    and build7_f4_compatibility.get("channel", {}).get(
        "freshInstallAuthorized"
    )
        is False
    and build7_f4_phase_ids
        == {"preflight", "upgrade", "prove-read", "retire-row"}
    and build7_f4_compatibility.get("controlledRecordAuthority", {}).get(
        "documentId"
    )
        == "zz-f4-global-pull-compat-v1"
    and build7_f4_compatibility.get("controlledRecordAuthority", {}).get(
        "maximumKnowledgeDocumentUpdates"
    )
        == 1
    and build7_f4_compatibility.get("controlledRecordAuthority", {}).get(
        "authorizedFinalLifecycle"
    )
        == "retired"
    and "any knowledge row other than zz-f4-global-pull-compat-v1"
        in build7_f4_prohibited
    and "claim DEVICE_PROVED" in build7_f4_prohibited
    and "'install', '--no-streaming', '-r', $apkPath"
        in build7_f4_compatibility_harness
    and "PASS_BUILD7_CONTROLLED_ROW_ACTIVE_PRECONDITION"
        in build7_f4_compatibility_harness
    and "firestoreTimestampDecodeClaimed = $false"
        in build7_f4_compatibility_harness
    and "postWriteCloudPullCompleted = $true"
        in build7_f4_compatibility_harness
    and "PASS_BUILD7_GOVERNED_RETIREMENT_PULL_AUDIT_AND_RENDER"
        in build7_f4_compatibility_harness
    and build7_f4_compatibility.get("failurePolicy", {}).get(
        "retirementFinalizationRequiresCompletionWitness"
    )
        is True
    and "PASS_BUILD7_CONTROLLED_TIMESTAMP_ROW_RETIRED_POST_WRITE_RENDERED"
        in build7_f4_compatibility_harness
    and "FinalizeUpgrade" in build7_f4_compatibility_harness
    and "FinalizeRetirement" in build7_f4_compatibility_harness
    and "does not activate the global-pull runtime contract"
        in build7_f4_compatibility_doc
    and build7_f4_compatibility.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build7_f4_compatibility.get("programmeBoundary", {}).get(
        "p07ClosureAuthorized"
    )
        is False
    and build7_f4_compatibility.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False
    and build7_f4_gate.get("currentStatus") == "OPEN"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "STAGE2D-F4",
)
build7_f4_locator_recovery_path = (
    "release/approvals/build-7-f4-prove-read-locator-recovery.json"
)
build7_f4_locator_recovery = data(build7_f4_locator_recovery_path)
build7_f4_locator_recovery_doc = text(
    "docs/v4_2_r1/BUILD7_F4_PROVE_READ_LOCATOR_RECOVERY.md"
)
check(
    "Build 7 prove-read locator recovery preserves receipts and is read-only",
    build7_f4_locator_recovery.get("approvalClass")
        == "CONTROLLED_BUILD7_PROVE_READ_LOCATOR_RECOVERY"
    and build7_f4_locator_recovery.get("originalPromotion", {}).get("sha256")
        == sha(
            ROOT
            / "release/approvals/build-7-f4-firestore-compatibility-promotion.json"
        )
        == "39818BA2550AB962F87992467D0BD0AD7DD4B1D8CAE6D65CC738B80B6CB689F9"
    and build7_f4_locator_recovery.get("originalPromotion", {}).get(
        "remainsUnmodified"
    )
        is True
    and build7_f4_locator_recovery.get("authorizedSourceCorrection", {}).get(
        "failedHarnessCommit"
    )
        == "59489c25ff5e43faa6cca2fed6d9de1ff88cd126"
    and build7_f4_locator_recovery.get("campaignAuthority", {}).get(
        "preflightReceiptSha256"
    )
        == "11B8AD068F6ED082B7D8FCE430C9A1D0329465DD13E009253E52E13945F8599D"
    and build7_f4_locator_recovery.get("campaignAuthority", {}).get(
        "upgradeReceiptSha256"
    )
        == "CB36DBBBACE68175782E55EA7509AF2B91D449D786D7B733A9F6768DFEBFB716"
    and build7_f4_locator_recovery.get("failureAdjudication", {}).get(
        "markerPresentInHint"
    )
        is True
    and build7_f4_locator_recovery.get("failureAdjudication", {}).get(
        "oldLocatorCouldResolve"
    )
        is False
    and build7_f4_locator_recovery.get("failureAdjudication", {}).get(
        "preWitnessRecoveryStop", {}
    ).get("observedKnowledgeGovernance")
        is True
    and build7_f4_locator_recovery.get("failureAdjudication", {}).get(
        "preWitnessRecoveryStop", {}
    ).get("failureWitnessCreated")
        is False
    and build7_f4_locator_recovery.get("retryAuthority", {}).get(
        "maximumAttempts"
    )
        == 1
    and build7_f4_locator_recovery.get("retryAuthority", {}).get("readOnly")
        is True
    and build7_f4_locator_recovery.get("retryAuthority", {}).get(
        "remoteMutationAuthorized"
    )
        is False
    and build7_f4_locator_recovery.get("retryAuthority", {}).get(
        "preWitnessNavigationStopConsumesRetry"
    )
        is False
    and build7_f4_locator_recovery.get(
        "narrowFailurePolicyOverride", {}
    ).get("scope")
        == "READ_ONLY_UI_LOCATOR_RECOVERY_ONLY"
    and build7_f4_compatibility.get("failurePolicy", {}).get(
        "newEvidenceDirectoryRequiredForRestart"
    )
        is True
    and "RecoverProveReadLocator" in build7_f4_compatibility_harness
    and "contains(@hint,'Search rowCode')"
        in build7_f4_compatibility_harness
    and "PASS_BUILD7_PROVE_READ_LOCATOR_FAILURE_REPRODUCED_PRIVACY_SAFE"
        in build7_f4_compatibility_harness
    and build7_f4_compatibility_harness.count("= Move-ToApprovedHome") == 4
    and "$approvedHome = Get-ApprovedHomeEvidence"
        not in build7_f4_compatibility_harness
    and "$null = Get-ApprovedHomeEvidence"
        not in build7_f4_compatibility_harness
    and "does not relabel the failed `ProveRead` attempt as passing"
        in build7_f4_locator_recovery_doc
    and build7_f4_locator_recovery.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build7_f4_locator_recovery.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False,
)
build6_f4_rehearsal = data(
    "release/approvals/build-6-f4-emulator-rehearsal-promotion.json"
)
f4_rehearsal_gate = next(
    (
        record
        for record in programme_ledger.get("programmeGates", [])
        if record.get("gateId") == "STAGE2D-F4"
    ),
    {},
)
check(
    "Build 6 emulator rehearsal is exact and carries no F4 closure authority",
    build6_f4_rehearsal.get("approvalClass")
        == "CONTROLLED_INTERNAL_RUNTIME_REHEARSAL_ONLY"
    and build6_f4_rehearsal.get("artifactAuthority", {}).get(
        "sourceCommit"
    )
        == "f6fccc662119790bcc742ff91e00934117030948"
    and build6_f4_rehearsal.get("artifactAuthority", {}).get(
        "governedPackage",
        {},
    ).get("sha256")
        == "E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E"
    and build6_f4_rehearsal.get("artifactAuthority", {}).get(
        "apk",
        {},
    ).get("sha256")
        == "01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755"
    and build6_f4_rehearsal.get("artifactAuthority", {}).get(
        "sourceRemediation",
        {},
    ).get("containedInArtifact")
        is True
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "priorPromotionSha256"
    )
        == "C85F139AFCDD499354DC44AA9E3AF57E6216C3BB4A98D2DD570014C978BCAAED"
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "evidenceOnlyFinalizationAuthorized"
    )
        is True
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "reinstallAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "uninstallOrDataClearAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "artifactOrTargetExpansion"
    )
        is False
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "remoteMutationExpansion"
    )
        is False
    and build6_f4_rehearsal.get("upgradeFinalizationAmendment", {}).get(
        "pilotOrPhysicalDeviceExpansion"
    )
        is False
    and build6_f4_rehearsal.get("channel", {}).get("maxTargetCount") == 1
    and build6_f4_rehearsal.get("channel", {}).get(
        "physicalDeviceInstallationAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("channel", {}).get("target", {}).get(
        "kind"
    )
        == "ANDROID_VIRTUAL_DEVICE"
    and build6_f4_rehearsal.get("deviceProvenance", {}).get(
        "requiredPriorPackage",
        {},
    ).get("versionCode")
        == 5
    and build6_f4_rehearsal.get("deviceProvenance", {}).get(
        "appDataClearAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("deviceProvenance", {}).get(
        "uninstallAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("expectedRemoteMutationBoundary", {}).get(
        "otherFirestoreBusinessWritesAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("expectedRemoteMutationBoundary", {}).get(
        "userAuthorityMutationAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("programmeBoundary", {}).get(
        "stage2dF4RehearsalAuthorized"
    )
        is True
    and build6_f4_rehearsal.get("programmeBoundary", {}).get(
        "stage2dF4DeviceEvidenceCreated"
    )
        is False
    and build6_f4_rehearsal.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build6_f4_rehearsal.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False
    and f4_rehearsal_gate.get("currentStatus") == "OPEN"
    and f4_rehearsal_gate.get("evidence") == []
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "STAGE2D-F4"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "NOT_AUTHORIZED",
)
build6_f4_physical = data(
    "release/approvals/build-6-f4-physical-device-execution-promotion.json"
)
build6_f4_physical_harness = text(
    "tools/release/Invoke-Build6F4PhysicalDeviceCampaign.ps1"
)
build6_f4_backend_blocker = text(
    "docs/v4_2_r1/BUILD6_F4_BACKEND_READINESS_BLOCKER.md"
)
open_pr_87_93_hold = text(
    "docs/v4_2_r1/OPEN_PR_87_93_HOLD_REGISTER.md"
)
pr87_93_integration = text(
    "docs/v4_2_r1/PR87_93_CURRENT_INTEGRATION_PACKAGE.md"
)
physical_phase_ids = {
    phase.get("id")
    for phase in build6_f4_physical.get("requiredPhases", [])
}
physical_prohibited = "\n".join(
    build6_f4_physical.get("prohibitedOperations", [])
)
check(
    "Build 6 physical F4 execution is exact-target, six-phase and non-closing",
    build6_f4_physical.get("approvalClass")
        == "CONTROLLED_EXACT_TARGET_PHYSICAL_DEVICE_F4_EXECUTION"
    and build6_f4_physical.get("approvalAuthority", {}).get(
        "baselineCommit"
    )
        == "999600ce02045afa7806645020292f3036535ce3"
    and build6_f4_physical.get(
        "apiLevelBindingCompatibilityAmendment",
        {},
    ).get("priorPromotionSha256")
        == "4E3ACCB9AFAFE59FED02B9904A4B2A108D9194834366860908327DCAEBBEABC5"
    and build6_f4_physical.get(
        "apiLevelBindingCompatibilityAmendment",
        {},
    ).get("priorHarnessSha256")
        == "EAF1F5B39195F006817290415EAD568376F7E5648348F80214DC578610CD1E8D"
    and build6_f4_physical.get(
        "apiLevelBindingCompatibilityAmendment",
        {},
    ).get("evidenceDirectoryCreated")
        is False
    and build6_f4_physical.get(
        "apiLevelBindingCompatibilityAmendment",
        {},
    ).get("packageInstallationPerformed")
        is False
    and build6_f4_physical.get(
        "apiLevelBindingCompatibilityAmendment",
        {},
    ).get("remoteMutationPerformed")
        is False
    and build6_f4_physical.get(
        "apiLevelBindingCompatibilityAmendment",
        {},
    ).get("stage2dF4AuthorityExpansion")
        is False
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("priorPromotionSha256")
        == "AA4EDD61A69AD26BBE38CBA123DCF9526A5775B3D333327D72F9AE02382907BE"
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("priorHarnessSha256")
        == "6CA9EECF9F394C2ECFAB90EF871A41B7FE4132A9970A1E59ACD01B4CDFEBD4E4"
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("privateEvidence", {}).get("approvedSigninReceiptSha256")
        == "00F8A27452E27CA38A7D67C452AF53584FFBC617D80A04B69F0C75DBD4BD90A0"
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("privateEvidence", {}).get("rawIdentityRetainedInRepository")
        is False
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("runtimeWitness", {}).get(
        "sameApplicationProcessFromChooserToApprovedHome"
    )
        is True
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("controlledStopsBeforePassingChooser", {}).get(
        "chooserReceiptCreatedByStoppedAttempts"
    )
        is False
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("authorizedHarnessPhases")
        == [
            "CaptureSyncBaseline",
            "RunSyncMarker",
            "RunOfflineReconnect",
            "RunWeakNetwork",
        ]
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("networkProfile", {}).get("restoreInFinally")
        is True
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("networkProfile", {}).get("falseOfflineSuccessFailsClosed")
        is True
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("networkProfile", {}).get("actualWindowDurationsRecorded")
        is True
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("networkProfile", {}).get("maximumIntermittentProfileSeconds")
        == 120
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("safetyBoundary", {}).get(
        "zeroPendingLocalBusinessWritesRequiredBeforeAndAfter"
    )
        is True
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("safetyBoundary", {}).get(
        "authorityMutationAuthorizedByThisAmendment"
    )
        is False
    and build6_f4_physical.get(
        "syncNetworkTrancheAmendment",
        {},
    ).get("safetyBoundary", {}).get("exactTransportRestorationRequired")
        is True
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("executionSourceMergeCommit")
        == "05f35fc61ac378c1273326760b664ced95c62287"
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("priorPromotionSha256")
        == "B7382D737430F428832B59B39DEE0656B3E8993FF861FB4E01A66229F45036CE"
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("priorHarnessSha256")
        == "F417A3BD6EB029B303B29705CED87A0EBBFD2BB9CAE9D05FBB42046721AC7463"
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("controlledStopAdjudicationSha256")
        == "63EA1D4BF8A5012A1E98F866D5763AD085AA1F10F41C99A1DFDCF7808CE1517D"
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("syncBaselineReceiptCreated")
        is False
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("networkStateMutationPerformed")
        is False
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("remoteBusinessMutationPerformed")
        is False
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("failedAttemptMayNotBeRelabelledPass")
        is True
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("stage2dF4AuthorityExpansion")
        is False
    and build6_f4_physical.get(
        "approvedHomeAutomaticVariableCompatibilityAmendment",
        {},
    ).get("pilotOrDistributionExpansion")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("executionSourceMergeCommit")
        == "feeb7f1c010c134d5f9938da2ad8c76093ba06b0"
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("priorPromotionSha256")
        == "52FFB67CB43F501645F172B851FA3C0E1BBC59AB366CA4C1550EB43134EA92F1"
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("priorHarnessSha256")
        == "F638782278027500593FBACF2EE63480AA2CEE96CB876672CC26F37492073AFC"
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("passingSyncBaselineReceiptSha256")
        == "FF07D7CF1A10204823CD85C939AA569FD793740412837986ED828F18EFCA6CDF"
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("passingBaselineAcceptedAfterPromotionAmendment")
        is True
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("acceptanceRequiresExactBaselineReceiptSha256")
        is True
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("futureUnlistedPromotionLineageAccepted")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("stoppedSyncMarkerStderrSha256")
        == "C6BBC7F67A0E68D346AE0FE90E4C0D4D4C821476AAB2A932D19A87B22B704D33"
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("syncBaselineReceiptCreated")
        is True
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("syncMarkerReceiptCreated")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("manualSyncInvoked")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("networkStateMutationPerformed")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("remoteBusinessMutationPerformed")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("temporaryDiagnosticScreenshotDeleted")
        is True
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("rawUiRetained")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("failedAttemptMayNotBeRelabelledPass")
        is True
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("stage2dF4AuthorityExpansion")
        is False
    and build6_f4_physical.get(
        "retainedMoreScrollNavigationCompatibilityAmendment",
        {},
    ).get("pilotOrDistributionExpansion")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("executionSourceMergeCommit")
        == "e9cd2ecf858c958f3e3c236dc9e483e8cb5293f4"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("priorPromotionSha256")
        == "DD6F930A230CCF2A2E1DDFBF69E5A8A59C5A1ACD4D8B2DA78A2A958546CFFA87"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("priorHarnessSha256")
        == "4D41B2AA7E152F1F5DA4BD1F8B239F19B1A3ADC616295FEFCD50585897A4A168"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("passingSyncBaselineReceiptSha256")
        == "FF07D7CF1A10204823CD85C939AA569FD793740412837986ED828F18EFCA6CDF"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("stoppedSyncMarkerStdoutSha256")
        == "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("stoppedSyncMarkerStderrSha256")
        == "440E2157943E6E2F2443D72E9E72394D1BEB29E24B2B35752E0A3B9960C29427"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("postStopAdjudicationUiSha256")
        == "2B574C233F6060026F7DF55ED3DE22D87CD10989564B06440E914BD87838E732"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("ownerReportedExternalRouterInterruption")
        is True
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("postStopNetworkValidated")
        is True
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("observedActionLabel")
        == "Retry sync"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("absentActionLabel")
        == "Sync now"
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("syncBaselineReceiptCreated")
        is True
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("syncMarkerReceiptCreated")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("manualSyncInvoked")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("harnessNetworkStateMutationPerformed")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("remoteBusinessMutationPerformed")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("rawUiRetained")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("retryRequiresFreshLogNames")
        is True
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("retryAuthorizedOnlyAfterMergedCorrection")
        is True
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("failedAttemptMayNotBeRelabelledPass")
        is True
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("artifactOrTargetExpansion")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("stage2dF4AuthorityExpansion")
        is False
    and build6_f4_physical.get(
        "manualSyncRetryLabelCompatibilityAmendment",
        {},
    ).get("pilotOrDistributionExpansion")
        is False
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("executionSourceMergeCommit")
        == "a929b1437ac411bf57baa050b188829d0398a9c4"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("priorPromotionSha256")
        == "1D7A2939528F925B3D549033E04F22C9AFFF371FCB86F998EE5E378EB7B5458D"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("priorHarnessSha256")
        == "07F1AC23AC83BF486BA999B6D4B97684CABB31FCB6D5B06A1F8D2A2479775F91"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("stoppedSyncMarkerStderrSha256")
        == "0E2FC4678343DD9B746F6AF03131B2F63EAD4B37AB6C24D8B87CDDC05FF7E208"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("manualSyncInvoked")
        is True
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("observedSanitizedFailure")
        == "firebase_functions/not-found"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("liveReadback", {}).get("firestoreRules", {}).get(
        "exactRepositoryCommit"
    )
        == "f8308c99e0fbf836a550e50e01d9ff93d4587111"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("liveReadback", {}).get("firestoreIndexes", {}).get(
        "exactRepositoryCommit"
    )
        == "33f599d90d3ff1057c3c8dd90f2b0d5f9ee941b7"
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("liveReadback", {}).get("functions", {}).get(
        "beginGlobalPullRunActive"
    )
        is False
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("furtherDeviceSyncAuthorizedByThisAmendment")
        is False
    and build6_f4_physical.get(
        "backendReadinessControlledStopAmendment",
        {},
    ).get("decision")
        == "STOP_F4_BACKEND_DEPLOYMENT_PREREQUISITE_UNMET"
    and "backendReadinessActivationAmendment" in build6_f4_physical_harness
    and "PASS_BUILD6_F4_BACKEND_READY" in build6_f4_physical_harness
    and "Deploying only `beginGlobalPullRun` is insufficient"
        in build6_f4_backend_blocker
    and "perform no Firebase deployment" in build6_f4_backend_blocker
    and "Status: CONSOLIDATED SOURCE CANDIDATE" in open_pr_87_93_hold
    and "The dependent order was preserved as #87, #88, #89, then #92."
        in open_pr_87_93_hold
    and "The original PRs are" in open_pr_87_93_hold
    and "not merged by this action." in open_pr_87_93_hold
    and "No phone was available" in open_pr_87_93_hold
    and "Status: SOURCE_INTEGRATION_CANDIDATE" in pr87_93_integration
    and "No physical phone was available" in pr87_93_integration
    and "does not deploy Firebase Rules or Functions" in pr87_93_integration
    and build6_f4_physical.get("discoveryAuthority", {}).get(
        "receiptSha256"
    )
        == "440874E51450BABA99ADD59AB47D19BF8D240F07BE9323373822E2FD81DB2825"
    and build6_f4_physical.get("discoveryAuthority", {}).get(
        "zeroMutationBoundaryProved"
    )
        is True
    and build6_f4_physical.get("artifactAuthority", {}).get(
        "governedPackage",
        {},
    ).get("sha256")
        == "E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E"
    and build6_f4_physical.get("artifactAuthority", {}).get(
        "apk",
        {},
    ).get("sha256")
        == "01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755"
    and build6_f4_physical.get("targetAuthority", {}).get("kind")
        == "ANDROID_PHYSICAL_DEVICE"
    and len(
        build6_f4_physical.get("targetAuthority", {}).get(
            "adbSerialSha256",
            "",
        )
    )
        == 64
    and len(
        build6_f4_physical.get("targetAuthority", {}).get(
            "buildFingerprintSha256",
            "",
        )
    )
        == 64
    and build6_f4_physical.get("targetAuthority", {}).get(
        "rawAdbSerialRetained"
    )
        is False
    and build6_f4_physical.get("targetAuthority", {}).get(
        "rawBuildFingerprintRetained"
    )
        is False
    and build6_f4_physical.get("channel", {}).get("maxTargetCount") == 1
    and build6_f4_physical.get("channel", {}).get(
        "physicalDeviceInstallationAuthorized"
    )
        is True
    and build6_f4_physical.get("channel", {}).get(
        "externalDistributionAuthorized"
    )
        is False
    and build6_f4_physical.get("identitySeparation", {}).get(
        "subjectMustNotBeLastApprovedAdmin"
    )
        is True
    and build6_f4_physical.get("identitySeparation", {}).get(
        "subjectRequiredRolesInclude"
    )
        == ["si"]
    and build6_f4_physical.get("identitySeparation", {}).get(
        "subjectProhibitedRoles"
    )
        == ["admin"]
    and build6_f4_physical.get("identitySeparation", {}).get(
        "stopIfSeparationCannotBeProved"
    )
        is True
    and physical_phase_ids
        == {
            "approved-sign-in",
            "sync-marker",
            "offline-reconnect",
            "weak-network",
            "revocation-next-operation-denial",
            "wrong-role-denials",
        }
    and "synthetic production tickets" in physical_prohibited
    and "direct Firestore write" in physical_prohibited
    and "leave the subject revoked" in physical_prohibited
    and build6_f4_physical.get("failurePolicy", {}).get(
        "interruptedInstallEvidenceFinalizationAuthorized"
    )
        is True
    and build6_f4_physical.get("failurePolicy", {}).get(
        "finalizationRequiresExactInstalledApkHash"
    )
        is True
    and build6_f4_physical.get("failurePolicy", {}).get(
        "reinstallDuringFinalizationAuthorized"
    )
        is False
    and build6_f4_physical.get("programmeBoundary", {}).get(
        "stage2dF4ExecutionAuthorized"
    )
        is True
    and build6_f4_physical.get("programmeBoundary", {}).get(
        "stage2dF4DeviceEvidenceCreated"
    )
        is True
    and build6_f4_physical.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build6_f4_physical.get("programmeBoundary", {}).get(
        "p07ClosureAuthorized"
    )
        is False
    and build6_f4_physical.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False
    and f4_rehearsal_gate.get("currentStatus") == "OPEN"
    and f4_rehearsal_gate.get("evidence") == []
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "STAGE2D-F4"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "NOT_AUTHORIZED",
)
global_pull_manifest = data("governance/global-pull-protocol-v1.json")
global_pull_contract = global_pull_manifest.get("fingerprintedContract", {})
global_pull_fingerprint = hashlib.sha256(
    json.dumps(
        global_pull_contract,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
global_pull_backend = text("functions/src/globalPullServerClock.ts")
global_pull_client = text("lib/core/services/global_pull_protocol.dart")
global_pull_cursor = text("lib/core/services/global_pull_cursor_store.dart")
global_pull_governance = text("functions/tools/global-pull-server-clock.mjs")
global_pull_runtime_security = text(
    "functions/src/globalPullSecurityConfig.ts"
)
function_fleet_runtime_security = text(
    "functions/src/functionFleetRuntimeIdentity.ts"
)
global_pull_runtime_identity_policy = data(
    "release/global-pull-runtime-identity-policy.json"
)
global_pull_remediation = text(
    "docs/v4_2_r1/R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_REMEDIATION.md"
)
global_pull_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") in {"R-01", "R-02"}
]
global_pull_evidence = [
    record.get("evidence", [])
    for record in global_pull_records
]
check(
    "R-01/R-02 server clock and scoped cursor closure is exact and evidence-bound",
    global_pull_manifest.get("schemaVersion") == 1
    and global_pull_manifest.get("fingerprintAlgorithm")
        == "SHA256_CANONICAL_JSON"
    and global_pull_manifest.get("protocolFingerprint")
        == global_pull_fingerprint
    and all(
        global_pull_fingerprint in source
        for source in (
            global_pull_backend,
            global_pull_client,
            global_pull_governance,
        )
    )
    and "_globalPullServerUpdatedAt" in global_pull_backend
    and "isGreaterThanOrEqualTo:" in global_pull_client
    and "isLessThanOrEqualTo:" in global_pull_client
    and "'databaseGenerationId'" in global_pull_cursor
    and "'authorityDigest'" in global_pull_cursor
    and "before.malformed !== 0" in global_pull_governance
    and "Pre-activation inventory" in global_pull_governance
    and "documentIdsRetained: includeDocumentIds" in global_pull_governance
    and '"--include-document-ids is valid only for inventory."'
        in global_pull_governance
    and "consoleContainsDocumentIds: false" in global_pull_governance
    and '"crm3-global-pull-reader"' in function_fleet_runtime_security
    and '"crm3-global-pull-writer"' in function_fleet_runtime_security
    and 'import {expr, projectID} from "firebase-functions/params"'
        in function_fleet_runtime_security
    and "@${projectID}.iam.gserviceaccount.com"
        in function_fleet_runtime_security
    and "@crm3-baf-ops-b8638.iam.gserviceaccount.com"
        not in function_fleet_runtime_security
    and "compute@developer.gserviceaccount.com"
        not in function_fleet_runtime_security
    and global_pull_runtime_identity_policy.get("schemaVersion") == 3
    and global_pull_runtime_identity_policy.get("targetProjectBinding") == {
        "builtInParameter": "PROJECT_ID",
        "serviceAccountDomain": "iam.gserviceaccount.com",
        "sameProjectRequired": True,
        "crossProjectResolutionAllowed": False,
    }
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("beginGlobalPullRun", {}).get("runtimeServiceAccountTemplate")
        == "crm3-global-pull-reader@${PROJECT_ID}.iam.gserviceaccount.com"
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("stampGlobalPullServerClock", {}).get(
        "runtimeServiceAccountTemplate"
    ) == "crm3-global-pull-writer@${PROJECT_ID}.iam.gserviceaccount.com"
    and global_pull_runtime_identity_policy.get("productionProjectId")
        == "crm3-baf-ops-b8638"
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("beginGlobalPullRun", {}).get(
        "productionResolvedRuntimeServiceAccount"
    ) == "crm3-global-pull-reader@crm3-baf-ops-b8638.iam.gserviceaccount.com"
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("stampGlobalPullServerClock", {}).get(
        "productionResolvedRuntimeServiceAccount"
    ) == "crm3-global-pull-writer@crm3-baf-ops-b8638.iam.gserviceaccount.com"
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("beginGlobalPullRun", {}).get("requiredProjectRoles")
        == ["roles/datastore.viewer"]
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("stampGlobalPullServerClock", {}).get("requiredProjectRoles")
        == [
            "roles/datastore.user",
            "roles/eventarc.eventReceiver",
        ]
    and global_pull_runtime_identity_policy.get(
        "functionBindings", {}
    ).get("stampGlobalPullServerClock", {}).get(
        "requiredCloudRunServiceRoles"
    ) == ["roles/run.invoker"]
    and global_pull_runtime_identity_policy.get(
        "existingFunctionFleetMutationAuthorized"
    ) is False
    and global_pull_runtime_identity_policy.get(
        "crossProjectGrantAuthorized"
    ) is False
    and len(global_pull_records) == 2
    and all(
        record.get("currentStatus") == "CLOSED"
        and [
            entry.get("status")
            for entry in record.get("statusHistory", [])
            if isinstance(entry, dict)
        ] == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
        for record in global_pull_records
    )
    and all(len(evidence) == 1 for evidence in global_pull_evidence)
    and all(
        evidence[0].get("pullRequest") == 55
        and evidence[0].get("headCommit")
            == "f356835d08711e804de5f591f12794079f064024"
        and evidence[0].get("sourceTree")
            == "f1f5feea68f712ef4ee5e281a4f26790d2d4d2a3"
        and evidence[0].get("mergeCommit")
            == "1bf9f1e3f181e73d9cbf7ee49a14704269ef081b"
        and evidence[0].get("mergeTree")
            == "f1f5feea68f712ef4ee5e281a4f26790d2d4d2a3"
        and evidence[0].get("postMergeWorkflowRun") == 30282720232
        and evidence[0].get("decision")
            == "PASS_R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_SOURCE_CLOSURE"
        and evidence[0].get("runtimeContractActivated") is False
        and evidence[0].get("productionMutationPerformed") is False
        for evidence in global_pull_evidence
    )
    and "Status: CLOSED" in global_pull_remediation
    and "PR #55" in global_pull_remediation
    and "30282720232" in global_pull_remediation
    and "PASS_R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_SOURCE_CLOSURE"
        in global_pull_remediation
    and "pilot/cutover authorization: prohibited" in global_pull_remediation,
)
authority_transaction_read = (
    "const userSnap = asDocumentSnapshot(await transaction.get(userRef));"
)
execution_transaction_read = (
    "const executionSnap = asDocumentSnapshot(await transaction.get(executionRef));"
)
check(
    "S-06 closure authority is transactionally current and fails before business reads",
    'await db.collection("users").doc(authUid).get()' not in closure_source
    and "type DocumentRefLike = {readonly path: string};" in closure_source
    and authority_transaction_read in closure_source
    and execution_transaction_read in closure_source
    and closure_source.index(authority_transaction_read)
        < closure_source.index(execution_transaction_read)
    and '{reasonCode: "closure-authority-denied"}' in closure_source
    and "unapproved user rejects transactionally before execution or module reads"
        in closure_unit_test
    and "expect(writes.executionReads).toBe(0)" in closure_unit_test
    and "expect(writes.moduleQueryReads).toBe(0)" in closure_unit_test
    and "authority revoked before transaction start fails closed"
        in closure_emulator_test
    and "expect(after).toEqual(before)" in closure_emulator_test
    and "# S-06 Atomic Closure Authority" in closure_decision
    and "Idempotent completion replay remains authorization-gated"
        in closure_decision,
)

s06_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-06"
]
s06_record = s06_records[0] if len(s06_records) == 1 else {}
s06_evidence = s06_record.get("evidence", [])
s06_history = [
    entry.get("status")
    for entry in s06_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
check(
    "S-06 ledger closure is exact, evidence-bound and re-armable",
    len(s06_records) == 1
    and s06_record.get("currentStatus") == "CLOSED"
    and len(s06_evidence) == 1
    and s06_evidence[0].get("pullRequest") == 45
    and s06_evidence[0].get("headCommit")
        == "1bf9292cc16c35775f8d005eae477e76ad7135fc"
    and s06_evidence[0].get("mergeCommit")
        == "d48ad31985d98f9415923b36bc5acb8133de7068"
    and s06_evidence[0].get("decision")
        == "PASS_GATE_1A_S06_ATOMIC_CLOSURE_AUTHORITY"
    and s06_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(s06_record.get("requiredExitEvidence", [])) >= 6
    and len(s06_record.get("reArmTriggers", [])) >= 5
    and "Pull request: #45" in closure_decision
    and "Merge commit: d48ad31985d98f9415923b36bc5acb8133de7068"
        in closure_decision,
)

workflow_dispatcher = text(
    "functions/src/maintenanceWorkflow/dispatcher.ts"
)
workflow_idempotency = text(
    "functions/src/maintenanceWorkflow/idempotency.ts"
)
workflow_authority = text(
    "functions/src/maintenanceWorkflow/commandAuthority.ts"
)
workflow_utils = text("functions/src/maintenanceWorkflow/utils.ts")
workflow_replay_unit = text(
    "functions/test/maintenanceWorkflowReplayAuthority.test.js"
)
workflow_replay_emulator = text(
    "functions/test/workflowAuthorityReplayAdjudication.firestoreEmulator.test.js"
)
s09_decision = text(
    "docs/v4_2_r1/S09_ATOMIC_WORKFLOW_AUTHORITY_AND_REPLAY.md"
)
r06_decision = text(
    "docs/v4_2_r1/R06_VERSIONED_WORKFLOW_RECEIPT_FINGERPRINTS.md"
)
workflow_actor_read = (
    "const actorSnapshot = await tx.get(`users/${context.actor.uid}`);"
)
workflow_receipt_read = (
    "const replay = await readExistingReceipt(tx, command, actor);"
)
check(
    "S-09 workflow authority and replay are transactionally current and owner-bound",
    workflow_actor_read in workflow_dispatcher
    and workflow_receipt_read in workflow_dispatcher
    and workflow_dispatcher.index(workflow_actor_read)
        < workflow_dispatcher.index(workflow_receipt_read)
    and "assertWorkflowAuthorityScope(actor, authorityScope);"
        in workflow_idempotency
    and "workflow-receipt-owner-mismatch" in workflow_idempotency
    and workflow_idempotency.index("workflow-receipt-owner-mismatch")
        < workflow_idempotency.index(
            "const expected = payloadFingerprint("
        )
    and "resolveFreshWorkflowAuthorityScope" in workflow_authority
    and "stale preflight actor fails closed" in workflow_replay_unit
    and "cross-actor owner rejection precedes payload fingerprint comparison"
        in workflow_replay_unit
    and "W2: revocation during the in-flight window fails closed"
        in workflow_replay_emulator
    and "W4: replay is refused after the required role is withdrawn"
        in workflow_replay_emulator
    and "# S-09 Atomic Workflow Authority and Replay" in s09_decision
    and "semantic capability, not the role list" in s09_decision,
)

check(
    "R-06 workflow receipts use versioned canonical SHA-256 fingerprints",
    'createHash("sha256")' in workflow_utils
    and "fnv1a64" not in workflow_utils
    and '`sha256:${createHash("sha256")' in workflow_utils
    and "receiptSchemaVersion: 2" in workflow_dispatcher
    and "legacy-workflow-receipt-reconciliation-required"
        in workflow_idempotency
    and "workflow-receipt-fingerprint-malformed" in workflow_idempotency
    and "same owner cannot reuse a command ID with a different payload"
        in workflow_replay_unit
    and "fingerprint is canonical SHA-256 over UTF-8 stable JSON"
        in workflow_replay_unit
    and "# R-06 Versioned Workflow Receipt Fingerprints" in r06_decision
    and "No unsupported collision-resistance estimate is used"
        in r06_decision,
)

s09_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-09"
]
r06_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "R-06"
]
s09_record = s09_records[0] if len(s09_records) == 1 else {}
r06_record = r06_records[0] if len(r06_records) == 1 else {}
source_commit = "e15b9676fc1e6e5c5ef56ff161f8558cac80dadf"
head_commit = "5a2d7e62fc7de810e6edbf8a69e9558c90930c8b"
merge_commit = "3c0861dcfe032ae795833283f9a7d63a45dde7e3"
postmerge_run = 30196339736
s09_evidence = s09_record.get("evidence", [])
r06_evidence = r06_record.get("evidence", [])
s09_history = [
    entry.get("status")
    for entry in s09_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
r06_history = [
    entry.get("status")
    for entry in r06_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
check(
    "S-09 and R-06 ledger closures are exact, evidence-bound and re-armable",
    len(s09_records) == 1
    and len(r06_records) == 1
    and s09_record.get("currentStatus") == "CLOSED"
    and r06_record.get("currentStatus") == "CLOSED"
    and len(s09_evidence) == 2
    and len(r06_evidence) == 2
    and s09_evidence[0].get("sourceCommit") == source_commit
    and r06_evidence[0].get("sourceCommit") == source_commit
    and s09_evidence[1].get("pullRequest") == 47
    and r06_evidence[1].get("pullRequest") == 47
    and s09_evidence[1].get("headCommit") == head_commit
    and r06_evidence[1].get("headCommit") == head_commit
    and s09_evidence[1].get("mergeCommit") == merge_commit
    and r06_evidence[1].get("mergeCommit") == merge_commit
    and s09_evidence[1].get("postMergeWorkflowRun") == postmerge_run
    and r06_evidence[1].get("postMergeWorkflowRun") == postmerge_run
    and s09_evidence[1].get("decision")
        == "PASS_GATE_1A_S09_ATOMIC_WORKFLOW_AUTHORITY_AND_REPLAY"
    and r06_evidence[1].get("decision")
        == "PASS_R06_VERSIONED_WORKFLOW_RECEIPT_FINGERPRINTS"
    and s09_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and r06_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(s09_record.get("requiredExitEvidence", [])) >= 7
    and len(r06_record.get("requiredExitEvidence", [])) >= 7
    and len(s09_record.get("reArmTriggers", [])) >= 5
    and len(r06_record.get("reArmTriggers", [])) >= 5
    and "Pull request:            #47" in s09_decision
    and "Merge commit:            3c0861dcfe032ae795833283f9a7d63a45dde7e3"
        in s09_decision
    and "Post-merge workflow run: 30196339736" in s09_decision
    and "Pull request:            #47" in r06_decision
    and "Merge commit:            3c0861dcfe032ae795833283f9a7d63a45dde7e3"
        in r06_decision
    and "Post-merge workflow run: 30196339736" in r06_decision,
)

s03_decision = text("docs/v4_2_r1/S03_CALLABLE_ABUSE_CONTROL.md")
s03_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-03"
]
s03_record = s03_records[0] if len(s03_records) == 1 else {}
s03_evidence = s03_record.get("evidence", [])
s03_history = [
    entry.get("status")
    for entry in s03_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
abuse_control_source = text("functions/src/callableAbuseControl.ts")
callable_index_source = text("functions/src/index.ts")
workflow_callable_source = text(
    "functions/src/maintenanceWorkflow/callable.ts"
)
abuse_control_unit_test = text(
    "functions/test/callableAbuseControl.test.js"
)
abuse_control_emulator_test = text(
    "functions/test/callableAbuseControl.firestoreEmulator.test.js"
)
abuse_control_source_test = text(
    "functions/test/callableAbuseControlSource.test.js"
)
callable_inventory_source = text("functions/src/callableInventory.ts")
callable_security_source = text("functions/src/callableSecurityConfig.ts")
callable_inventory_audit = text(
    "functions/tools/audit_callable_inventory.mjs"
)
callable_inventory_test = text(
    "functions/tools/audit_callable_inventory.test.mjs"
)
s02_source_policy = text(
    "docs/v4_2_r1/S02_CALLABLE_APP_CHECK_SOURCE_POLICY.md"
)
exported_callable_occurrences = [
    name
    for source_path in (ROOT / "functions" / "src").rglob("*.ts")
    for name in re.findall(
        r"export const ([A-Za-z_][A-Za-z0-9_]*)\s*=\s*onCall\(",
        source_path.read_text(encoding="utf-8"),
    )
]
exported_callable_names = sorted(set(exported_callable_occurrences))
callable_classification = {
    name: kind
    for name, kind in re.findall(
        r'^\s{2}([A-Za-z_][A-Za-z0-9_]*): "(mutating|read-only)",$',
        callable_inventory_source,
        flags=re.MULTILINE,
    )
}
callable_names = sorted(
    name
    for name, kind in callable_classification.items()
    if kind == "mutating"
)
read_only_callable_names = sorted(
    name
    for name, kind in callable_classification.items()
    if kind == "read-only"
)
s02_scope = data(
    "release/s02-callable-app-check-source-policy.json"
)
s02_policy = s02_scope.get("callableAppCheckPolicy", {})
s02_ra07 = [
    trigger
    for trigger in s02_scope.get("sourceReArmTriggers", [])
    if isinstance(trigger, dict) and trigger.get("id") == "RA-07"
]
s02_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-02"
]
s02_record = s02_records[0] if len(s02_records) == 1 else {}
functions_scripts = data("functions/package.json").get("scripts", {})
check(
    "S-02 callable inventory is discovered, policy-complete and default-off",
    len(exported_callable_occurrences) == len(exported_callable_names) == 8
    and set(exported_callable_names) == set(callable_classification)
    and len(callable_names) == 6
    and len(read_only_callable_names) == 2
    and set(callable_names) == set(s02_policy.get("mutatingCallables", []))
    and set(read_only_callable_names)
        == set(
            s02_policy.get(
                "readOnlySecurityOptionsByCallable",
                {},
            )
        )
    and s02_policy.get("activationAuthorized") is False
    and s02_policy.get("sourceDefault") is False
    and s02_policy.get("activationParameter")
        == "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK"
    and "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK"
        in callable_security_source
    and "default: false" in callable_security_source
    and callable_index_source.count(
        "...MUTATING_CALLABLE_SECURITY_OPTIONS"
    ) == 5
    and workflow_callable_source.count(
        "...MUTATING_CALLABLE_SECURITY_OPTIONS"
    ) == 1
    and callable_index_source.count(
        "...GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS"
    ) == 1
    and callable_index_source.count(
        "...BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS"
    ) == 1
    and "checker.getExportsOfModule" in callable_inventory_audit
    and "export-classification-mismatch" in callable_inventory_audit
    and "abuse-control-admission-missing" in callable_inventory_audit
    and "a newly exported callable is discovered and fails closed"
        in callable_inventory_test
    and "a classified mutation cannot bypass security or admission"
        in callable_inventory_test
    and "audit:callable-inventory" in functions_scripts
    and "audit:callable-inventory" in functions_scripts.get("build", "")
    and len(s02_ra07) == 1
    and s02_ra07[0].get("sourceDetectable") is True
    and s02_ra07[0].get("sourceProbe")
        == "npm --prefix functions run audit:callable-inventory"
    and len(s02_records) == 1
    and s02_record.get("currentStatus") == "DEFERRED"
    and "RA-07" in s02_record.get("reArmTriggers", [])
    and len(s02_record.get("requiredExitEvidence", [])) >= 7
    and programme_ledger.get("programmeDecision", {}).get(
        "playIntegrityAndAppCheck"
    ) == "GOVERNED_DEFERRAL"
    and "Status: DEFERRED" in s02_source_policy
    and "This source change does not:" in s02_source_policy
    and "close S-02" in s02_source_policy,
    f"exported={exported_callable_names} "
    f"mutating={callable_names} readOnly={read_only_callable_names}",
)
check(
    "S-03 mutating callables have strict transactional rate and anomaly controls",
    all(name in abuse_control_source for name in callable_names)
    and "const STATE_FIELDS = new Set([" in abuse_control_source
    and "keys.length !== STATE_FIELDS.size" in abuse_control_source
    and "state.burstRequestCount >= policy.burstRequestLimit"
        in abuse_control_source
    and "state.dailyRequestCount >= policy.dailyRequestLimit"
        in abuse_control_source
    and "state.anomalyCount >= policy.anomalyLimit"
        in abuse_control_source
    and "transaction.set(ref, state);" in abuse_control_source
    and '"resource-exhausted"' in abuse_control_source
    and '"callable-burst-limit-exceeded"' in abuse_control_source
    and '"callable-daily-limit-exceeded"' in abuse_control_source
    and '"callable-anomaly-limit-exceeded"' in abuse_control_source
    and '"aborted"' not in abuse_control_source,
)
preflight_actor_read = "const actorSnapshot = await args.db"
preflight_admission = "return executeWithCallableAbuseControl({"
check(
    "S-03 admission is authority-first and excludes read-only callables",
    preflight_actor_read in abuse_control_source
    and preflight_admission in abuse_control_source
    and abuse_control_source.index(preflight_actor_read)
        < abuse_control_source.index(preflight_admission)
    and '.collection("users")' in abuse_control_source
    and '"callable-preflight-authority-denied"' in abuse_control_source
    and all(
        f'callableName: "{name}"' in callable_index_source
        for name in callable_names
        if name != "executeMaintenanceWorkflowCommand"
    )
    and 'const actor = await actorFromRequest(request, db);'
        in workflow_callable_source
    and 'callableName: "executeMaintenanceWorkflowCommand"'
        in workflow_callable_source
    and workflow_callable_source.index(
        'const actor = await actorFromRequest(request, db);'
    ) < workflow_callable_source.index(
        'callableName: "executeMaintenanceWorkflowCommand"'
    )
    and "read-only %s callable is outside mutation quotas"
        in abuse_control_source_test,
)
check(
    "S-03 tests prove concurrency, strict state, Rules denial and hashed principals",
    "atomically admits only the configured burst limit under concurrency"
        in abuse_control_unit_test
    and "fails closed on partial, unknown-field, negative, or future state"
        in abuse_control_unit_test
    and "separates quota state by actor and callable"
        in abuse_control_unit_test
    and "concurrent admission commits exactly the burst limit"
        in abuse_control_emulator_test
    and "partial persisted state fails closed before execution"
        in abuse_control_emulator_test
    and "clients cannot read or mutate admission and anomaly records"
        in text("test/firestore.rules.test.js")
    and "raw UID is not written" in s03_decision
    and "no automatic" in s03_decision,
)
check(
    "S-03 ledger closure is exact, evidence-bound and re-armable",
    len(s03_records) == 1
    and s03_record.get("currentStatus") == "CLOSED"
    and len(s03_evidence) == 1
    and s03_evidence[0].get("pullRequest") == 50
    and s03_evidence[0].get("headCommit")
        == "bb76e167eb27c0b26058c7c514085b0481157aa2"
    and s03_evidence[0].get("mergeCommit")
        == "08336c4e861074fd1284dd8758195c418247c9e8"
    and s03_evidence[0].get("postMergeWorkflowRun") == 30208984633
    and s03_evidence[0].get("decision")
        == "PASS_S03_CALLABLE_ABUSE_CONTROL"
    and s03_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(s03_record.get("requiredExitEvidence", [])) >= 8
    and len(s03_record.get("reArmTriggers", [])) >= 7
    and "Status: CLOSED" in s03_decision
    and "Pull request: #50" in s03_decision
    and "08336c4e861074fd1284dd8758195c418247c9e8" in s03_decision
    and "Post-merge workflow run: `30208984633`" in s03_decision
    and "Decision: `PASS_S03_CALLABLE_ABUSE_CONTROL`" in s03_decision
    and "The control is not deployed live" in s03_decision
    and "closure does not authorize a Functions deployment" in s03_decision,
)

rules_source = text("firestore.rules")
s07_decision = text(
    "docs/v4_2_r1/S07_GOVERNED_CHARGE_ABNORMALITY_MUTATION.md"
)
s07_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-07"
]
s07_record = s07_records[0] if len(s07_records) == 1 else {}
s07_evidence = s07_record.get("evidence", [])
s07_history = [
    entry.get("status")
    for entry in s07_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
s07_source = text("functions/src/chargeAbnormalityMutation.ts")
s07_unit_test = text(
    "functions/test/chargeAbnormalityMutation.test.js"
)
s07_emulator_test = text(
    "functions/test/chargeAbnormalityMutation.firestoreEmulator.test.js"
)
s07_client = text(
    "lib/features/abnormalities/services/"
    "charge_abnormality_command_service.dart"
)
s07_screen = text(
    "lib/features/abnormalities/presentation/"
    "charge_abnormalities_screen.dart"
)
s07_sync = text(
    "lib/core/services/sync_service.directives_abnormalities.dart"
)
s07_dart_test = text(
    "test/charge_abnormality_atomic_mutation_contract_test.dart"
)
check(
    "S-07 Admin abnormality mutations are versioned and audit-coupled",
    'export type ChargeAbnormalityMutationOperation' in s07_source
    and '"UPDATE"' in s07_source
    and '"SOFT_DELETE"' in s07_source
    and "requireActor(await actorRef.get(), actorUid);" in s07_source
    and "const actorSnapshot = await transaction.get(actorRef);"
        in s07_source
    and "existing.version !== request.expectedVersion" in s07_source
    and "const REQUIRED_ABNORMALITY_FIELDS = [...ABNORMALITY_FIELDS];"
        in s07_source
    and "reannealed-charge-matches-source" in s07_source
    and 'transaction.set(abnormalityRef, after);' in s07_source
    and 'transaction.set(auditRef, {' in s07_source
    and 'transaction.set(receiptRef, {' in s07_source
    and 'callableName: "mutateChargeAbnormality"'
        in callable_index_source
    and "authorize: userCanMutateChargeAbnormality"
        in callable_index_source,
)
check(
    "S-07 direct updates are denied and UI plus queued sync use the callable",
    "match /charge_abnormalities/{docId}" in rules_source
    and "match /charge_abnormality_mutation_receipts/{docId}"
        in rules_source
    and "!docId.matches('^server_charge_abnormality_.*')"
        in rules_source
    and "chargeAbnormalityCommandServiceProvider" in s07_screen
    and "repository.updateAbnormality(" not in s07_screen
    and "repository.softDeleteAbnormality(" not in s07_screen
    and "deterministicSyncRequestId" in s07_client
    and "_pushGovernedChargeAbnormalityMutation" in s07_sync
    and "concurrent same-version updates permit exactly one"
        in s07_emulator_test
    and "incomplete existing records fail closed" in s07_unit_test
    and "source contract routes admin mutations only through governed callable"
        in s07_dart_test
    and "client-side creation audit is atomically coupled" in s07_decision
    and "does not authorize Functions or" in s07_decision
    and "Rules deployment" in s07_decision,
)
check(
    "S-07 ledger closure is exact, evidence-bound and re-armable",
    len(s07_records) == 1
    and s07_record.get("currentStatus") == "CLOSED"
    and len(s07_evidence) == 1
    and s07_evidence[0].get("pullRequest") == 52
    and s07_evidence[0].get("headCommit")
        == "880a46f4c2530e5d2d830b5c083ec2688551cb4e"
    and s07_evidence[0].get("sourceTree")
        == "1d10661ed09e14f82352a3c1bf2e0b90ee5d3633"
    and s07_evidence[0].get("mergeCommit")
        == "31c890bb96518365ba0365a0e9b8e2cd79abb9de"
    and s07_evidence[0].get("postMergeWorkflowRun") == 30214251697
    and s07_evidence[0].get("decision")
        == "PASS_GATE_1A_S07_GOVERNED_CHARGE_ABNORMALITY_MUTATION"
    and s07_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(s07_record.get("requiredExitEvidence", [])) >= 10
    and len(s07_record.get("reArmTriggers", [])) >= 9
    and "Status: CLOSED" in s07_decision
    and "Pull request: #52" in s07_decision
    and "31c890bb96518365ba0365a0e9b8e2cd79abb9de" in s07_decision
    and "Post-merge workflow run: `30214251697`" in s07_decision
    and "Decision: `PASS_GATE_1A_S07_GOVERNED_CHARGE_ABNORMALITY_MUTATION`"
        in s07_decision
    and "This closes the S-07 source-and-CI finding" in s07_decision
    and "does not authorize Functions or" in s07_decision
    and "Rules deployment" in s07_decision,
)

s04_decision = text("docs/v4_2_r1/S04_CANONICAL_USER_AUTHORITY_SHAPE.md")
s04_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-04"
]
s04_record = s04_records[0] if len(s04_records) == 1 else {}
s04_evidence = s04_record.get("evidence", [])
s04_history = [
    entry.get("status")
    for entry in s04_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
rules_source = text("firestore.rules")
authority_mutation_source = text("functions/src/userAuthorityMutation.ts")
authority_rules_test = text("test/firestore.rules.test.js")
authority_unit_test = text("functions/test/userAuthority.test.js")
authority_mutation_test = text(
    "functions/test/userAuthorityMutation.firestoreEmulator.test.js"
)
dart_authority_test = text("test/user_authority_schema_test.dart")
check(
    "S-04 user authority roles, client shape and tracked writers are constrained",
    "function validUserRoleList(roles)" in rules_source
    and "roles.hasOnly([" in rules_source
    and "function validUserDocumentShape(data)" in rules_source
    and "data.keys().hasOnly([" in rules_source
    and "function validApprovedUserAuthority(data)" in rules_source
    and "Authorization reads validate only the canonical security capsule. Full"
        in rules_source
    and "user document shape remains enforced on every client create/update"
        in rules_source
    and "validAdminUserProfileUpdate(userId)" in rules_source
    and "normalizeCanonicalUserRoles(value as string[])" in authority_mutation_source
    and "transaction.set(targetRef, {" in authority_mutation_source
    and "}, {merge: true});" in authority_mutation_source
    and "admin client cannot perform direct" in authority_rules_test
    and "admin cannot add ungoverned top-level user fields"
        in authority_rules_test
    and "rejects %s from a privileged writer" in authority_rules_test
    and "fails closed for legacy or malformed authority" in authority_unit_test
    and "malformed target authority fails closed" in authority_mutation_test
    and "unknown roles fail closed instead of becoming Operations"
        in dart_authority_test,
)
check(
    "S-04 ledger closure is exact, policy-explicit and re-armable",
    len(s04_records) == 1
    and s04_record.get("currentStatus") == "CLOSED"
    and len(s04_evidence) == 3
    and s04_evidence[0].get("pullRequest") == 40
    and s04_evidence[0].get("headCommit")
        == "473ed3c25472b27d646c1d75406a22a80ca26cd9"
    and s04_evidence[0].get("mergeCommit")
        == "f88c7e35f1dae95222cdcd57819b091a2f5f56c9"
    and s04_evidence[0].get("postMergeWorkflowRun") == 30170153630
    and s04_evidence[1].get("pullRequest") == 41
    and s04_evidence[1].get("headCommit")
        == "eb8bc9e505f559bc0e9267f56dd23ec4b6180ca2"
    and s04_evidence[1].get("mergeCommit")
        == "96385151d73c04904184b0bfd9c057c23b9f6e84"
    and s04_evidence[1].get("postMergeWorkflowRun") == 30172678080
    and s04_evidence[2].get("currentMainCommit")
        == "466f81e72b033d367da47a2aca4b30850ffbcfc4"
    and s04_evidence[2].get("postMergeWorkflowRun") == 30196942545
    and s04_evidence[2].get("decision")
        == "PASS_S04_CANONICAL_USER_AUTHORITY_SHAPE"
    and s04_history[-3:] == ["SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(s04_record.get("requiredExitEvidence", [])) >= 7
    and len(s04_record.get("reArmTriggers", [])) >= 5
    and "server-written document with a valid capsule remains authorizing"
        in s04_decision
    and "Decision:                PASS_S04_CANONICAL_USER_AUTHORITY_SHAPE"
        in s04_decision
    and "This closure does not authorize deployment" in s04_decision,
)

s08_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "S-08"
]
s08_record = s08_records[0] if len(s08_records) == 1 else {}
s08_history = [
    entry.get("status")
    for entry in s08_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
crash_sanitizer_source = text(
    "lib/core/services/crash_report_sanitizer.dart"
)
app_logger_source = text("lib/core/services/app_logger.dart")
crash_sanitizer_test = text("test/crash_report_sanitizer_test.dart")
s08_decision = text("docs/v4_2_r1/S08_CRASH_REPORT_PRIVACY_BOUNDARY.md")
check(
    "S-08 crash reports fail closed before every Crashlytics error boundary",
    len(s08_records) == 1
    and s08_record.get("currentStatus") == "CLOSED"
    and s08_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(s08_record.get("evidence", [])) == 1
    and s08_record["evidence"][0].get("pullRequest") == 65
    and s08_record["evidence"][0].get("headCommit")
        == "29a85772e6f1fa93ae76627cf539050c849b6ba7"
    and s08_record["evidence"][0].get("sourceTree")
        == "c0269dea3753f507eae1034ea3646df7d1c493b2"
    and s08_record["evidence"][0].get("mergeCommit")
        == "1131802af792fef050b3555e50b0b1aa31b6868e"
    and s08_record["evidence"][0].get("mergeTree")
        == "c0269dea3753f507eae1034ea3646df7d1c493b2"
    and s08_record["evidence"][0].get("postMergeWorkflowRun") == 30382196271
    and s08_record["evidence"][0].get("decision")
        == "PASS_S08_CRASH_REPORT_PRIVACY_BOUNDARY"
    and s08_record["evidence"][0].get("clientDeployed") is False
    and s08_record["evidence"][0].get("networkPayloadCaptured") is False
    and s08_record["evidence"][0].get("pilotAuthorized") is False
    and len(s08_record.get("requiredExitEvidence", [])) >= 5
    and len(s08_record.get("reArmTriggers", [])) >= 4
    and "final class SanitizedCrashException" in crash_sanitizer_source
    and "static const int _maxStackFrames = 64" in crash_sanitizer_source
    and "package:" in crash_sanitizer_source
    and "dart:" in crash_sanitizer_source
    and "<redacted-frame>" in crash_sanitizer_source
    and "CrashReportSanitizer.userIdentifier(uid)" in app_logger_source
    and app_logger_source.count(
        "FirebaseCrashlytics.instance.recordError("
    ) == 3
    and app_logger_source.count("CrashReportSanitizer.error(") >= 3
    and app_logger_source.count("CrashReportSanitizer.stackTrace(") >= 3
    and "recordFlutterFatalError" not in app_logger_source
    and "person@example.com" in crash_sanitizer_test
    and "abc12345678901234567890123456789" in crash_sanitizer_test
    and "C:/Users" in crash_sanitizer_test
    and "Status: CLOSED" in s08_decision
    and "PASS_S08_CRASH_REPORT_PRIVACY_BOUNDARY" in s08_decision
    and "does not claim a deployed client" in s08_decision,
)

r03_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "R-03"
]
r03_record = r03_records[0] if len(r03_records) == 1 else {}
r03_history = [
    entry.get("status")
    for entry in r03_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
r03_evidence = r03_record.get("evidence", [])
r03_r05_closure_path = (
    ROOT / "release/evidence/r03-r05-source-and-ci-closure.json"
)
r03_r05_closure = data(
    "release/evidence/r03-r05-source-and-ci-closure.json"
)
r03_r05_source_authority = r03_r05_closure.get("sourceAuthority", {})
r03_r05_finding_commits = {
    entry.get("findingId"): (entry.get("commit"), entry.get("tree"))
    for entry in r03_r05_source_authority.get("findingCommits", [])
    if isinstance(entry, dict)
}
r03_r05_pr_ci = r03_r05_closure.get("pullRequestCi", {})
r03_r05_postmerge_ci = r03_r05_closure.get("postMergeCi", {})
r03_r05_boundary = r03_r05_closure.get("closureBoundary", {})
r03_r05_expected_jobs = {
    "Android release APK + AAB packaging proof",
    "Cloud Functions build + test",
    "Firestore rules + governed transaction emulator",
    "Flutter analyze + tests + no-loss spine",
}
r03_sync_source = text("lib/core/services/sync_coordinator.dart")
r03_auto_source = text("lib/core/services/auto_sync_service.dart")
r03_indicator_source = text("lib/core/widgets/sync_status_indicator.dart")
r03_decision = text("docs/v4_2_r1/R03_SYNC_REQUEST_OUTCOME_REMEDIATION.md")
check(
    "R-03 queued and throttled sync admission is distinct and source-and-CI closed",
    len(r03_records) == 1
    and r03_record.get("currentStatus") == "CLOSED"
    and r03_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(r03_evidence) == 1
    and r03_evidence[0].get("evidenceFile")
        == "release/evidence/r03-r05-source-and-ci-closure.json"
    and r03_evidence[0].get("evidenceSha256") == sha(r03_r05_closure_path)
    and r03_evidence[0].get("pullRequest") == 117
    and r03_evidence[0].get("headCommit")
        == "946c414fee7605f590253dc630a0205095f3b44d"
    and r03_evidence[0].get("sourceTree")
        == "24487330756ea9933be5bf81181fde4d607e375d"
    and r03_evidence[0].get("mergeCommit")
        == "45ebd9c853798f88fedd2e4d72d6022dc389097f"
    and r03_evidence[0].get("mergeTree")
        == "24487330756ea9933be5bf81181fde4d607e375d"
    and r03_evidence[0].get("pullRequestWorkflowRun") == 30795773566
    and r03_evidence[0].get("postMergeWorkflowRun") == 30796250694
    and r03_evidence[0].get("decision")
        == "PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE"
    and r03_evidence[0].get("productionDeploymentPerformed") is False
    and r03_evidence[0].get("deviceEvidenceClaimed") is False
    and r03_evidence[0].get("pilotAuthorizationCreated") is False
    and r03_r05_closure.get("schemaVersion") == 1
    and r03_r05_closure.get("findingIds") == ["R-03", "R-05"]
    and r03_r05_closure.get("authorityType") == "SOURCE_AND_CI"
    and r03_r05_closure.get("decision")
        == "PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE"
    and r03_r05_source_authority.get("repository")
        == "abhishekvatsa/crm3_baf_ops"
    and r03_r05_source_authority.get("pullRequest") == 117
    and r03_r05_source_authority.get("headCommit")
        == "946c414fee7605f590253dc630a0205095f3b44d"
    and r03_r05_source_authority.get("sourceTree")
        == "24487330756ea9933be5bf81181fde4d607e375d"
    and r03_r05_source_authority.get("mergeCommit")
        == "45ebd9c853798f88fedd2e4d72d6022dc389097f"
    and r03_r05_source_authority.get("mergeTree")
        == "24487330756ea9933be5bf81181fde4d607e375d"
    and r03_r05_finding_commits == {
        "R-03": (
            "269e911c76ffd677d64b2dc99e3467056cb7ab48",
            "573efd0813777e4a3ef7d5e21a4d0c3d977df5a7",
        ),
        "R-05": (
            "e24f6f3c3885f345475ddb0c1faa3b597f1823a5",
            "347988ff8a154138f7585b221784360b3b6376bb",
        ),
    }
    and r03_r05_pr_ci.get("runId") == 30795773566
    and r03_r05_pr_ci.get("event") == "pull_request"
    and r03_r05_pr_ci.get("headSha")
        == "946c414fee7605f590253dc630a0205095f3b44d"
    and r03_r05_pr_ci.get("conclusion") == "success"
    and {
        job.get("name")
        for job in r03_r05_pr_ci.get("jobs", [])
        if isinstance(job, dict)
    } == r03_r05_expected_jobs
    and all(
        job.get("conclusion") == "success"
        for job in r03_r05_pr_ci.get("jobs", [])
        if isinstance(job, dict)
    )
    and r03_r05_postmerge_ci.get("runId") == 30796250694
    and r03_r05_postmerge_ci.get("event") == "push"
    and r03_r05_postmerge_ci.get("headSha")
        == "45ebd9c853798f88fedd2e4d72d6022dc389097f"
    and r03_r05_postmerge_ci.get("conclusion") == "success"
    and {
        job.get("name")
        for job in r03_r05_postmerge_ci.get("jobs", [])
        if isinstance(job, dict)
    } == r03_r05_expected_jobs
    and all(
        job.get("conclusion") == "success"
        for job in r03_r05_postmerge_ci.get("jobs", [])
        if isinstance(job, dict)
    )
    and set(r03_r05_boundary) == {
        "productionDeploymentPerformed",
        "runtimeActivationClaimed",
        "deviceEvidenceClaimed",
        "notificationDeliveryClaimed",
        "pilotAuthorizationCreated",
        "cutoverAuthorizationCreated",
    }
    and all(value is False for value in r03_r05_boundary.values())
    and len(r03_record.get("requiredExitEvidence", [])) >= 4
    and len(r03_record.get("reArmTriggers", [])) >= 4
    and "enum SyncRequestOutcome" in r03_sync_source
    and "return SyncRequestOutcome.queued" in r03_sync_source
    and "return SyncRequestOutcome.throttled" in r03_sync_source
    and "return SyncRequestOutcome.failed" in r03_sync_source
    and "return SyncRequestOutcome.succeeded" in r03_sync_source
    and "final SyncRequestOutcome? lastAutomaticOutcome" in r03_auto_source
    and "lastAutomaticSucceeded" not in r03_auto_source
    and "outcome.manualSyncMessage" in r03_indicator_source
    and "Status: CLOSED" in r03_decision
    and "Merge and exact-head CI evidence: PASS" in r03_decision
    and "PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE" in r03_decision
    and "production deployment, device proof, F4 closure" in r03_decision,
)

ui_alignment_decision = text(
    "docs/v4_2_r1/UI_BUSINESS_LOGIC_ALIGNMENT.md"
)
ui_home_source = text("lib/home_screen.dart")
ui_user_source = text("lib/features/auth/data/user_model.dart")
ui_equipment_source = text(
    "lib/features/maintenance_workflow/presentation/screens/"
    "equipment_status_board.dart"
)
ui_workflow_provider_source = text(
    "lib/features/maintenance_workflow/providers/workflow_providers.dart"
)
ui_planned_detail_source = text(
    "lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart"
)
ui_completion_source = text(
    "lib/features/planned_maintenance/presentation/complete_job_screen.dart"
)
ui_abnormality_source = text(
    "lib/features/abnormalities/presentation/abnormalities_home_screen.dart"
)
ui_audit_source = text(
    "lib/features/audit/presentation/audit_timeline_screen.dart"
)
ui_diagnostics_source = text(
    "lib/features/maintenance_workflow/presentation/screens/"
    "workflow_diagnostics_screen.dart"
)
ui_alignment_test = text("test/ui_business_alignment_test.dart")
diagnostics_guard = ui_diagnostics_source.find(
    "!actor.canViewMaintenanceWorkflowDiagnostics"
)
diagnostics_read = ui_diagnostics_source.find("_future ??= _load()")
check(
    "Cross-app UI authority and workflow semantics remain policy-aligned",
    "Status: SOURCE_IMPLEMENTED" in ui_alignment_decision
    and "Merge and exact-head CI evidence: PENDING" in ui_alignment_decision
    and "message.data['complianceId']" in ui_home_source
    and "ComplianceNotificationScreen(" in ui_home_source
    and "module: BafModules.charges" not in ui_home_source
    and "canDeployMaintenanceEquipment" in ui_user_source
    and "row.stateKey == 'available' && canDeploy" in ui_equipment_source
    and "final local = await repository.getComplianceById(id)"
        in ui_workflow_provider_source
    and "await ref.read(workflowPullServiceProvider).pull()"
        in ui_workflow_provider_source
    and "final showBottomActions =" in ui_planned_detail_source
    and "if (!execution.isGovernedTemplateAssignment)" in ui_planned_detail_source
    and "if (!widget.execution.isGovernedTemplateAssignment"
        in ui_completion_source
    and "canManageTypes: canManageTypes" in ui_abnormality_source
    and "!actor.canReviewSyncConflicts" in ui_audit_source
    and diagnostics_guard >= 0
    and diagnostics_read > diagnostics_guard
    and "diagnostics rejects before reading privileged local data"
        in ui_alignment_test
    and "authorized governed dossier is stable" in ui_alignment_test
    and "does not prove the F4 physical-device matrix" in ui_alignment_decision,
)

operational_ux_decision = text(
    "docs/v4_2_r1/OPERATIONAL_UX_RESTRUCTURE.md"
)
operational_ux_home = text("lib/home_screen.dart")
operational_ux_issues = text(
    "lib/features/maintenance/presentation/ticket_screen.dart"
)
operational_ux_work = text(
    "lib/features/planned_maintenance/presentation/templates_screen.dart"
)
operational_ux_workflow = text(
    "lib/features/maintenance_workflow/presentation/screens/"
    "workflow_queue_view.dart"
)
operational_ux_directives = text(
    "lib/features/directives/presentation/directives_screen.dart"
)
operational_ux_theme = text("lib/core/theme/baf_design_system.dart")
operational_ux_test = text("test/operational_ux_restructure_test.dart")
functionality_representation_test = text(
    "test/functionality_representation_ux_test.dart"
)
functionality_representation_user = text(
    "lib/features/auth/data/user_model.dart"
)
functionality_representation_dossiers = text(
    "lib/features/planned_maintenance/presentation/closed_job_dossiers_screen.dart"
)
functionality_representation_provider = text(
    "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart"
)
functionality_representation_audit = text(
    "lib/features/audit/presentation/audit_timeline_screen.dart"
)
functionality_representation_panel = text(
    "lib/features/maintenance_workflow/presentation/widgets/"
    "planned_job_workflow_panel.dart"
)
check(
    "Operational UX is task-first, role-scoped and responsive",
    "Status: SOURCE_IMPLEMENTED" in operational_ux_decision
    and "Merge and exact-head CI evidence: PENDING" in operational_ux_decision
    and "does not replace or modify the immutable" in operational_ux_decision
    and "production-signed" in operational_ux_decision
    and "NavigationRail(" in operational_ux_home
    and "ModeSwitchCard(" not in operational_ux_home
    and "'Needs attention'" in operational_ux_home
    and "title: 'Operations and records'" in operational_ux_home
    and "title: 'Governance'" in operational_ux_home
    and "title: 'Administration and support'" in operational_ux_home
    and "issues-raise-issue" in operational_ux_issues
    and "issues-search" in operational_ux_issues
    and "BoxConstraints(maxWidth: 960)" in operational_ux_issues
    and "_PlannedWorkView.workflow" in operational_ux_work
    and "canSeeTemplates" in operational_ux_work
    and "WorkflowQueueView(" in operational_ux_work
    and "BoxConstraints(maxWidth: 1000)" in operational_ux_work
    and "actor.canAcknowledgeOrWorkMaintenanceLane" in operational_ux_workflow
    and "directives-search" in operational_ux_directives
    and "BoxConstraints(maxWidth: 960)" in operational_ux_directives
    and "static const large = 10.0" in operational_ux_theme
    and "static const xLarge = 12.0" in operational_ux_theme
    and "operations Work is task-first" in operational_ux_test
    and "empty Issues keeps reporting primary" in operational_ux_test
    and "Directives supports immediate search" in operational_ux_test,
)
check(
    "Operational functionality is represented for each entitled role and authorizes before reads",
    "## Functionality Representation Re-audit" in operational_ux_decision
    and "canViewOperationalAssets => isApproved"
        in functionality_representation_user
    and "canViewClosedMaintenanceTickets => isApproved"
        in functionality_representation_user
    and "canViewClosedJobDossiers => isApproved"
        in functionality_representation_user
    and "title: 'Resolved issues'" in operational_ux_home
    and "title: 'Closed job dossiers'" in operational_ux_home
    and "title: 'Audit log'" in operational_ux_home
    and "final closedExecutionsProvider" in functionality_representation_provider
    and "watchAllExecutions(limit: _closedExecutionSourceLimit)"
        in functionality_representation_provider
    and "!actor.canViewClosedJobDossiers"
        in functionality_representation_dossiers
    and "ref.watch(closedExecutionsProvider)"
        in functionality_representation_dossiers
    and "label: const Text('Workflow overview')" in operational_ux_workflow
    and operational_ux_workflow.index("actor == null || !actor.isApproved")
        < operational_ux_workflow.index("ref.watch(workflowAllLanesProvider)")
    and "class RecentAuditLogScreen" in functionality_representation_audit
    and functionality_representation_audit.count("!actor.canViewAuditLogs") >= 2
    and "canViewAuditEvidence: actor.canViewAuditLogs"
        in functionality_representation_panel
    and "closed dossiers reject before starting their data stream"
        in functionality_representation_test
    and "workflow queue rejects before lane and compliance reads"
        in functionality_representation_test
    and "entity audit rejects non-admin before the audit read"
        in functionality_representation_test,
)

r04_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "R-04"
]
r04_record = r04_records[0] if len(r04_records) == 1 else {}
r04_history = [
    entry.get("status")
    for entry in r04_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
r04_evidence = r04_record.get("evidence", [])
r04_closure_path = (
    ROOT / "release/evidence/r04-notification-installation-source-and-ci-closure.json"
)
r04_closure = data(
    "release/evidence/r04-notification-installation-source-and-ci-closure.json"
)
r04_source_authority = r04_closure.get("sourceAuthority", {})
r04_pr_ci = r04_closure.get("pullRequestCi", {})
r04_postmerge_ci = r04_closure.get("postMergeCi", {})
r04_boundary = r04_closure.get("closureBoundary", {})
r04_expected_jobs = {
    "Android release APK + AAB packaging proof",
    "Cloud Functions build + test",
    "Firestore rules + governed transaction emulator",
    "Flutter analyze + tests + no-loss spine",
}
r04_registry = text(
    "lib/features/auth/services/notification_installation_registry.dart"
)
r04_auth = text("lib/features/auth/providers/auth_provider.dart")
r04_main = text("lib/main.dart")
r04_notifications = text("functions/src/notifications.ts")
r04_notification_test = text("functions/test/notifications.test.js")
r04_rules = text("firestore.rules")
r04_rules_test = text("test/firestore.rules.test.js")
r04_client_test = text("test/notification_installation_registry_test.dart")
r04_contract_test = text(
    "test/r04_notification_installation_registry_contract_test.dart"
)
r04_policy = data(
    "release/r04-notification-installation-registry-policy.json"
)
r04_decision = text(
    "docs/v4_2_r1/R04_NOTIFICATION_INSTALLATION_REGISTRY.md"
)
r04_pending_payload_start = r04_auth.index(
    "Map<String, dynamic> _pendingUserPayload"
)
r04_pending_payload_end = r04_auth.index(
    "String _cleanProfileText",
    r04_pending_payload_start,
)
r04_pending_payload = r04_auth[
    r04_pending_payload_start:r04_pending_payload_end
]
r04_sign_out_start = r04_auth.index("Future<void> signOut()")
r04_sign_out_end = r04_auth.index(
    "Map<String, dynamic> _pendingUserPayload",
    r04_sign_out_start,
)
r04_sign_out = r04_auth[r04_sign_out_start:r04_sign_out_end]
r04_remove_start = r04_registry.index("Future<void> remove({")
r04_remove_end = r04_registry.index(
    "abstract interface class NotificationTokenSource",
    r04_remove_start,
)
r04_remove = r04_registry[r04_remove_start:r04_remove_end]
check(
    "R-04 notification registration is source-and-CI closed, private and bounded",
    len(r04_records) == 1
    and r04_record.get("authorityType") == "SOURCE_AND_CI"
    and r04_record.get("currentStatus") == "CLOSED"
    and r04_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(r04_evidence) == 1
    and r04_evidence[0].get("evidenceFile")
        == "release/evidence/r04-notification-installation-source-and-ci-closure.json"
    and r04_evidence[0].get("evidenceSha256") == sha(r04_closure_path)
    and r04_evidence[0].get("pullRequest") == 134
    and r04_evidence[0].get("headCommit")
        == "55869a42aa48fd18e360c499a82825a00eaacd29"
    and r04_evidence[0].get("sourceTree")
        == "dc2ed437922d5f4ebe53def58e6098481687ff48"
    and r04_evidence[0].get("mergeCommit")
        == "0ca1e7610f6151e1bc50fefc699b2dc7f9403eb9"
    and r04_evidence[0].get("mergeTree")
        == "dc2ed437922d5f4ebe53def58e6098481687ff48"
    and r04_evidence[0].get("pullRequestWorkflowRun") == 30880821675
    and r04_evidence[0].get("postMergeWorkflowRun") == 30881331523
    and r04_evidence[0].get("decision")
        == "PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE"
    and r04_evidence[0].get("productionDeploymentPerformed") is False
    and r04_evidence[0].get("deviceEvidenceClaimed") is False
    and r04_evidence[0].get("notificationDeliveryClaimed") is False
    and r04_evidence[0].get("pilotAuthorizationCreated") is False
    and len(r04_record.get("requiredExitEvidence", [])) == 6
    and len(r04_record.get("reArmTriggers", [])) == 6
    and r04_closure.get("schemaVersion") == 1
    and r04_closure.get("findingIds") == ["R-04"]
    and r04_closure.get("authorityType") == "SOURCE_AND_CI"
    and r04_closure.get("decision")
        == "PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE"
    and r04_source_authority.get("repository")
        == "abhishekvatsa/crm3_baf_ops"
    and r04_source_authority.get("pullRequest") == 134
    and r04_source_authority.get("headCommit")
        == "55869a42aa48fd18e360c499a82825a00eaacd29"
    and r04_source_authority.get("sourceTree")
        == "dc2ed437922d5f4ebe53def58e6098481687ff48"
    and r04_source_authority.get("mergeCommit")
        == "0ca1e7610f6151e1bc50fefc699b2dc7f9403eb9"
    and r04_source_authority.get("mergeTree")
        == "dc2ed437922d5f4ebe53def58e6098481687ff48"
    and r04_pr_ci.get("runId") == 30880821675
    and r04_pr_ci.get("event") == "pull_request"
    and r04_pr_ci.get("headSha")
        == "55869a42aa48fd18e360c499a82825a00eaacd29"
    and r04_pr_ci.get("conclusion") == "success"
    and {
        job.get("name")
        for job in r04_pr_ci.get("jobs", [])
        if isinstance(job, dict)
    } == r04_expected_jobs
    and all(
        job.get("conclusion") == "success"
        for job in r04_pr_ci.get("jobs", [])
        if isinstance(job, dict)
    )
    and r04_postmerge_ci.get("runId") == 30881331523
    and r04_postmerge_ci.get("event") == "push"
    and r04_postmerge_ci.get("headSha")
        == "0ca1e7610f6151e1bc50fefc699b2dc7f9403eb9"
    and r04_postmerge_ci.get("conclusion") == "success"
    and {
        job.get("name")
        for job in r04_postmerge_ci.get("jobs", [])
        if isinstance(job, dict)
    } == r04_expected_jobs
    and all(
        job.get("conclusion") == "success"
        for job in r04_postmerge_ci.get("jobs", [])
        if isinstance(job, dict)
    )
    and set(r04_boundary) == {
        "productionDeploymentPerformed",
        "runtimeActivationClaimed",
        "deviceEvidenceClaimed",
        "notificationDeliveryClaimed",
        "pilotAuthorizationCreated",
        "cutoverAuthorizationCreated",
    }
    and all(value is False for value in r04_boundary.values())
    and r04_policy.get("schemaVersion") == 1
    and r04_policy.get("findingId") == "R-04"
    and r04_policy.get("sourceStatus") == "SOURCE_AND_CI_CLOSED"
    and r04_policy.get("privacyAndAuthority", {}).get("clientReads")
        == "DENIED"
    and r04_policy.get("delivery", {}).get(
        "maximumInstallationsReadPerUser"
    ) == 8
    and len(r04_policy.get("reArmTriggers", [])) == 6
    and r04_policy.get("evidenceBoundary", {}).get(
        "productionDeploymentPerformed"
    ) is False
    and "notification_installations" in r04_registry
    and "crm3.notificationInstallationId.v1" in r04_registry
    and "_uuid.v4()" in r04_registry
    and "FieldValue.serverTimestamp()" in r04_registry
    and "registerCurrentToken" in r04_registry
    and "registerToken" in r04_registry
    and "removeCurrentInstallation" in r04_registry
    and "retireMessagingToken" in r04_registry
    and "transaction.delete(installationRef)" in r04_remove
    and "transaction.get(installationRef)" not in r04_remove
    and "registry.tokenRefreshes.listen" in r04_auth
    and "FCM token refresh subscription unavailable" in r04_auth
    and "notificationInstallationSyncProvider" in r04_auth
    and "'fcmToken'" not in r04_pending_payload
    and r04_sign_out.index(
        "await _notificationRegistry.removeCurrentInstallation"
    ) < r04_sign_out.index("await _auth.signOut()")
    and r04_sign_out.index("await _auth.signOut()")
        < r04_sign_out.index("await _googleSignIn.signOut()")
    and "ref.watch(notificationInstallationSyncProvider)" in r04_main
    and "MAX_NOTIFICATION_INSTALLATIONS_PER_USER = 8"
        in r04_notifications
    and '.orderBy("updatedAt", "desc")' in r04_notifications
    and ".limit(MAX_NOTIFICATION_INSTALLATIONS_PER_USER)"
        in r04_notifications
    and "isFirestoreTimestamp" in r04_notifications
    and "tokenToRegistrations" in r04_notifications
    and "txn.delete(ref)" in r04_notifications
    and "does not delete an installation refreshed"
        in r04_notification_test
    and "wrongTimestamp" in r04_notification_test
    and "validNotificationInstallationWrite" in r04_rules
    and "match /notification_installations/{installationId}" in r04_rules
    and "allow read: if false;" in r04_rules[
        r04_rules.index("match /notification_installations/{installationId}"):
        r04_rules.index("match /audit_logs/{docId}")
    ]
    and "R-04 private notification installation registry" in r04_rules_test
    and "sign-out removes only this installation" in r04_client_test
    and "R-04 source and CI closure is exact" in r04_contract_test
    and "Status: CLOSED" in r04_decision
    and "Merge and exact-head CI evidence: PASS" in r04_decision
    and "PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE"
        in r04_decision
    and "`R-04` is closed" in r04_decision
    and "does not claim production Rules or Functions" in r04_decision,
)

r05_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "R-05"
]
r05_record = r05_records[0] if len(r05_records) == 1 else {}
r05_history = [
    entry.get("status")
    for entry in r05_record.get("statusHistory", [])
    if isinstance(entry, dict)
]
r05_evidence = r05_record.get("evidence", [])
r05_receipt_source = text("functions/src/notificationEventReceipt.ts")
r05_index_source = text("functions/src/index.ts")
r05_workflow_source = text(
    "functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts"
)
r05_unit_test = text("functions/test/notificationEventReceipt.test.js")
r05_emulator_test = text(
    "functions/test/notificationEventReceipt.firestoreEmulator.test.js"
)
r05_contract_test = text(
    "test/r05_notification_event_idempotency_contract_test.dart"
)
r05_decision = text("docs/v4_2_r1/R05_NOTIFICATION_EVENT_IDEMPOTENCY.md")
r05_rules = text("firestore.rules")
r05_package = data("functions/package.json")
r05_inventory_policy = data(
    "release/r05-notification-trigger-source-policy.json"
)
r05_inventory_audit = text(
    "functions/tools/audit_notification_trigger_inventory.mjs"
)
r05_inventory_test = text(
    "functions/tools/audit_notification_trigger_inventory.test.mjs"
)
r05_trigger_names = (
    "onTicketCreated",
    "onTicketResolved",
    "onJobAssigned",
)
r05_trigger_starts = [
    r05_index_source.index(f"export const {name}")
    for name in r05_trigger_names
]
r05_trigger_ends = r05_trigger_starts[1:] + [
    r05_index_source.index("Maintenance workflow control plane")
]
r05_trigger_sections = [
    r05_index_source[start:end]
    for start, end in zip(r05_trigger_starts, r05_trigger_ends)
]
check(
    "R-05 notification event idempotency is source-and-CI closed and fail-closed",
    len(r05_records) == 1
    and r05_record.get("authorityType") == "SOURCE_AND_CI"
    and r05_record.get("currentStatus") == "CLOSED"
    and r05_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(r05_evidence) == 1
    and r05_evidence[0] == r03_evidence[0]
    and len(r05_record.get("requiredExitEvidence", [])) == 6
    and len(r05_record.get("reArmTriggers", [])) == 6
    and all(
        section.count("executeIdempotentNotificationEvent({") == 1
        and "retry: true" in section
        and "cloudEventId: event.id" in section
        and section.index("executeIdempotentNotificationEvent({")
            < section.index("getTokenLookup")
        for section in r05_trigger_sections
    )
    and r05_workflow_source.count(
        "executeIdempotentNotificationEvent({"
    ) == 1
    and "retry: true" in r05_workflow_source
    and "cloudEventId: event.id" in r05_workflow_source
    and "workflow_notification_receipts" in r05_workflow_source
    and r05_workflow_source.index("executeIdempotentNotificationEvent({")
        < r05_workflow_source.index("getTokenLookupsForRoles(")
    and "notification-event-receipt-v1\\0" in r05_receipt_source
    and "notification_event_receipts" in r05_receipt_source
    and "failedBeforeDispatch" in r05_receipt_source
    and "deliveryUncertain" in r05_receipt_source
    and "notification-event-receipt-attempt-mismatch" in r05_receipt_source
    and "notification-event-receipt-state-malformed" in r05_receipt_source
    and "reason: \"delivery-uncertain\"" in r05_receipt_source
    and "requiresAdjudication: true" in r05_receipt_source
    and "reportDeliveryUncertain" in r05_receipt_source
    and "Notification delivery requires governed adjudication"
        in r05_index_source
    and "Notification delivery requires governed adjudication"
        in r05_workflow_source
    and "match /notification_event_receipts/{docId}" in r05_rules
    and "allow read, create, update, delete: if false;"
        in r05_rules[
            r05_rules.index("match /notification_event_receipts/{docId}"):
            r05_rules.index("AUDIT LOGS")
        ]
    and "completed replay never prepares or dispatches twice" in r05_unit_test
    and "dispatch failure is surfaced, quarantined" in r05_unit_test
    and "operator reporting failure cannot reopen" in r05_unit_test
    and "concurrent duplicate events perform one delivery" in r05_emulator_test
    and "ambiguous dispatch is quarantined" in r05_emulator_test
    and "R-05 source and CI closure is exact" in r05_contract_test
    and "notificationEventReceipt.firestoreEmulator.test.js"
        in r05_package["scripts"]["test:emulator:governed"]
    and "audit:notification-inventory"
        in r05_package["scripts"]["build"]
    and r05_inventory_policy.get("schemaVersion") == 1
    and r05_inventory_policy.get("receiptCoordinator")
        == "executeIdempotentNotificationEvent"
    and r05_inventory_policy.get("receiptCollection")
        == "notification_event_receipts"
    and sorted(
        trigger.get("name")
        for trigger in r05_inventory_policy.get("notificationTriggers", [])
        if isinstance(trigger, dict)
    ) == sorted((*r05_trigger_names, "onMaintenanceWorkflowEventCreated"))
    and "notification-trigger-policy-mismatch" in r05_inventory_audit
    and "unowned-notification-dispatch-call" in r05_inventory_audit
    and "direct-fcm-dispatch-bypasses-notification-coordinator"
        in r05_inventory_audit
    and "notification-dispatch-outside-receipt-boundary"
        in r05_inventory_audit
    and "a newly added notification trigger is discovered"
        in r05_inventory_test
    and "an aliased notification dispatcher remains discoverable"
        in r05_inventory_test
    and "Status: CLOSED" in r05_decision
    and "This is not an exactly-once delivery claim." in r05_decision
    and "structured error-level signal" in r05_decision
    and "operator-queryable marker" in r05_decision
    and "PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE" in r05_decision
    and "`R-05` is closed" in r05_decision,
)

lr04_policy = data(
    "release/lr04-firestore-recoverability-readback-policy.json"
)
lr04_collector = text(
    "tools/release/collectFirestoreRecoverabilityReadback.js"
)
lr04_collector_test = text(
    "tools/release/collectFirestoreRecoverabilityReadback.test.mjs"
)
lr04_contract_test = text(
    "test/lr04_firestore_recoverability_readback_collector_contract_test.dart"
)
lr04_decision = text(
    "docs/v4_2_r1/LR04_FIRESTORE_RECOVERABILITY_LIVE_READBACK.md"
)
lr04_restore_seal_path = (
    ROOT / "release/evidence/production-prelive-restore-pack-seal.json"
)
lr04_receipt_path = (
    ROOT / "release/evidence/lr04-firestore-recoverability-live-readback.json"
)
lr04_receipt = data(
    "release/evidence/lr04-firestore-recoverability-live-readback.json"
)
lr04_receipt_body = dict(lr04_receipt)
lr04_receipt_body.pop("receiptSha256", None)
lr04_receipt_canonical_sha = hashlib.sha256(
    json.dumps(
        lr04_receipt_body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
lr04_closure_path = (
    ROOT
    / "release/evidence/lr04-firestore-recoverability-live-readback-closure.json"
)
lr04_closure = data(
    "release/evidence/lr04-firestore-recoverability-live-readback-closure.json"
)
lr04_closure_contract = text(
    "test/lr04_firestore_recoverability_live_readback_closure_contract_test.dart"
)
lr04_gate_records = [
    record
    for record in programme_ledger.get("programmeGates", [])
    if record.get("gateId") == "LR-04"
]
lr04_gate_record = lr04_gate_records[0] if len(lr04_gate_records) == 1 else {}
p05_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "P-05"
]
p05_record = p05_records[0] if len(p05_records) == 1 else {}
check(
    "LR-04 Firestore recoverability readback is evidence-closed while adverse posture stays open",
    lr04_policy.get("schemaVersion") == 1
    and lr04_policy.get("policyId")
        == "LR04-FIRESTORE-RECOVERABILITY-READBACK-POLICY-V1"
    and lr04_policy.get("collectorStatus")
        == "SOURCE_CI_AND_LIVE_READBACK_PROVED"
    and lr04_policy.get("productionProjectId") == "crm3-baf-ops-b8638"
    and lr04_policy.get("productionDatabase") == "(default)"
    and lr04_policy.get("productionLocation") == "asia-south1"
    and lr04_policy.get("gateIds") == ["LR-04"]
    and lr04_policy.get("findingIds") == ["P-05"]
    and lr04_policy.get("operationInventoryLimit") == 1000
    and lr04_policy.get("restoreSeal", {}).get("path")
        == "release/evidence/production-prelive-restore-pack-seal.json"
    and lr04_policy.get("restoreSeal", {}).get("sha256")
        == "982040C70DD01325870E877378D74A8A705B1F64576A46B2C98FB244576AE599"
    and lr04_policy.get("restoreSeal", {}).get("bytes") == 4440
    and sha(lr04_restore_seal_path)
        == lr04_policy.get("restoreSeal", {}).get("sha256")
    and lr04_restore_seal_path.stat().st_size
        == lr04_policy.get("restoreSeal", {}).get("bytes")
    and lr04_policy.get("postureSemantics", {}).get(
        "collectionPassMayContainAdversePosture"
    ) is True
    and lr04_policy.get("postureSemantics", {}).get(
        "managedExportIsNotRepresentedAsNativeBackupOrRestoreProof"
    ) is True
    and len(lr04_policy.get("mutationBoundary", {})) == 11
    and all(
        value is False
        for value in lr04_policy.get("mutationBoundary", {}).values()
    )
    and lr04_policy.get("privacyBoundary", {}).get(
        "operatorAccountIdentityRetained"
    ) is False
    and lr04_policy.get("privacyBoundary", {}).get(
        "firestoreDocumentOrBusinessPayloadRetained"
    ) is False
    and lr04_policy.get("privacyBoundary", {}).get(
        "operationNamesOrOutputPrefixesRetained"
    ) is False
    and "PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK" in lr04_collector
    and "HOLD_FIRESTORE_RECOVERABILITY_POSTURE" in lr04_collector
    and "sourceCommitMatchesOriginMain" in lr04_collector
    and "governedSourceClean" in lr04_collector
    and 'collectorAuthorizesClosure: false' in lr04_collector
    and 'sourceAndCiOnly: false' in lr04_collector
    and 'flag: "wx"' in lr04_collector
    and 'platformPath.join(sdkRoot, "lib", "gcloud.py")'
        in lr04_collector
    and all(
        forbidden not in lr04_collector
        for forbidden in (
            '"databases",\n      "update"',
            '"schedules",\n      "create"',
            '"schedules",\n      "update"',
            '"schedules",\n      "delete"',
            '"backups",\n      "delete"',
            '"operations",\n      "cancel"',
            "firestore import",
            "firestore export",
            "shell: true",
            "cmd.exe",
        )
    )
    and "strict acquisition passes while adverse recoverability posture remains explicit"
        in lr04_collector_test
    and "summaries omit schedule, backup, operation and output identifiers"
        in lr04_collector_test
    and "operation inventory at the configured limit fails closed"
        in lr04_collector_test
    and "LR-04 collector is target-bound, private and mutation-free"
        in lr04_contract_test
    and "LR-04 closes only on sealed strict clean-main evidence"
        in lr04_closure_contract
    and root_package.get("scripts", {}).get(
        "test:firestore-recoverability-readback-custody"
    )
        == "node --test tools/release/collectFirestoreRecoverabilityReadback.test.mjs"
    and "npm run test:firestore-recoverability-readback-custody"
        in release_gate_source
    and "Collector status: SOURCE_CI_AND_LIVE_READBACK_PROVED"
        in lr04_decision
    and "Live readback evidence: PASS acquisition / HOLD recoverability posture"
        in lr04_decision
    and "closes evidence gate `LR-04`" in lr04_decision
    and "does not close `P-05`" in lr04_decision
    and sha(lr04_receipt_path)
        == "E339FC49400BA1817084270E4E8503C12797A00A9095FE937A30EE48D8A0F18D"
    and lr04_receipt_path.stat().st_size == 6341
    and lr04_receipt.get("receiptSha256") == lr04_receipt_canonical_sha
    and lr04_receipt.get("decision")
        == "PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK"
    and lr04_receipt.get("mode") == "STRICT"
    and lr04_receipt.get("projectId") == "crm3-baf-ops-b8638"
    and lr04_receipt.get("database") == "(default)"
    and lr04_receipt.get("location") == "asia-south1"
    and lr04_receipt.get("failedChecks") == []
    and all(value is True for value in lr04_receipt.get("checks", {}).values())
    and lr04_receipt.get("source", {}).get("before", {}).get("commit")
        == "0d323449be267849e7043772dbfea0a7dc3bd107"
    and lr04_receipt.get("source", {}).get("before", {}).get("tree")
        == "fbdb9de46305d62af53fd764281fa577e2c94276"
    and lr04_receipt.get("source", {}).get("before")
        == lr04_receipt.get("source", {}).get("after")
    and lr04_receipt.get("outputs", {}).get("database", {}).get(
        "pointInTimeRecoveryEnablement"
    ) == "POINT_IN_TIME_RECOVERY_DISABLED"
    and lr04_receipt.get("outputs", {}).get("database", {}).get(
        "deleteProtectionState"
    ) == "DELETE_PROTECTION_DISABLED"
    and lr04_receipt.get("outputs", {}).get("schedules", {}).get("count") == 0
    and lr04_receipt.get("outputs", {}).get("backups", {}).get("count") == 0
    and lr04_receipt.get("outputs", {}).get("operations", {}).get("count")
        == 24
    and lr04_receipt.get("outputs", {}).get("operations", {}).get(
        "successfulExportOperationCount"
    ) == 1
    and lr04_receipt.get("outputs", {}).get("operations", {}).get(
        "successfulImportOperationCount"
    ) == 0
    and lr04_receipt.get("outputs", {}).get("operations", {}).get(
        "sealedExport", {}
    ).get("exactSuccessfulExport") is True
    and lr04_receipt.get("posture", {}).get("decision")
        == "HOLD_FIRESTORE_RECOVERABILITY_POSTURE"
    and lr04_receipt.get("posture", {}).get("holds") == [
        "pointInTimeRecoveryDisabled",
        "deleteProtectionDisabled",
        "noNativeBackupSchedule",
        "noNativeBackup",
        "noRestoreImportProof",
    ]
    and all(
        value is False
        for value in lr04_receipt.get("mutationBoundary", {}).values()
    )
    and sha(lr04_closure_path)
        == "E760C24874C3905A675C213E1997E6BFFEE9C403683CE0F86B07CABD05A36302"
    and lr04_closure_path.stat().st_size == 5881
    and lr04_closure.get("decision")
        == "PASS_LR04_FIRESTORE_RECOVERABILITY_LIVE_READBACK_CLOSURE_WITH_ADVERSE_POSTURE"
    and lr04_closure.get("liveReceipt", {}).get("fileSha256")
        == sha(lr04_receipt_path)
    and lr04_closure.get("liveReceipt", {}).get("receiptSha256")
        == lr04_receipt.get("receiptSha256")
    and lr04_closure.get("collectorAuthority", {}).get("pullRequest") == 139
    and lr04_closure.get("collectorAuthority", {}).get("sourceTree")
        == lr04_closure.get("collectorAuthority", {}).get("mergeTree")
    and lr04_closure.get("collectorAuthority", {}).get(
        "pullRequestCi", {}
    ).get("runId") == 30892607011
    and lr04_closure.get("collectorAuthority", {}).get(
        "postMergeCi", {}
    ).get("runId") == 30893195416
    and all(
        value is False
        for value in lr04_closure.get("closureBoundary", {}).values()
    )
    and len(lr04_gate_records) == 1
    and lr04_gate_record.get("currentStatus") == "CLOSED"
    and lr04_gate_record.get("authorization") == "CLOSED_PASS"
    and [
        entry.get("status")
        for entry in lr04_gate_record.get("statusHistory", [])
    ] == ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"]
    and {
        entry.get("sha256") for entry in lr04_gate_record.get("evidence", [])
    } == {
        "E339FC49400BA1817084270E4E8503C12797A00A9095FE937A30EE48D8A0F18D",
        "E760C24874C3905A675C213E1997E6BFFEE9C403683CE0F86B07CABD05A36302",
    }
    and len(p05_records) == 1
    and p05_record.get("currentStatus") == "OPEN"
    and p05_record.get("title")
        == "Production Firestore recovery posture lacks PITR, delete protection, native backups and restore proof"
    and len(p05_record.get("evidence", [])) == 2
    and len(p05_record.get("requiredExitEvidence", [])) == 6
    and len(p05_record.get("reArmTriggers", [])) == 7
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "STAGE2D-F4"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "NOT_AUTHORIZED",
)

a05_reader = text("lib/core/serialization/persisted_data_reader.dart")
a05_audit_model = text("lib/features/audit/models/audit_event_model.dart")
a05_audit_repository = text(
    "lib/features/audit/repositories/audit_repository.dart"
)
a05_auth_provider = text("lib/features/auth/providers/auth_provider.dart")
a05_maintenance_model = text(
    "lib/features/maintenance/data/maintenance_model.dart"
)
a05_maintenance_provider = text(
    "lib/features/maintenance/providers/maintenance_provider.dart"
)
a05_resolve_form = text(
    "lib/features/maintenance/presentation/resolve_form.dart"
)
a05_test = text("test/a05_maintenance_audit_integrity_test.dart")
a05_decision = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_1.md"
)
a05_action_model = text(
    "lib/features/planned_maintenance/models/component_action_model.dart"
)
a05_action_server = text("functions/src/persistedActionPayload.ts")
a05_maintenance_bridge = text(
    "functions/src/maintenanceWorkflow/maintenanceBridge.ts"
)
a05_planned_closure = text("functions/src/plannedJobClosure.ts")
a05_runtime_population = text("functions/src/runtimeJobModulePopulation.ts")
a05_live_sync = text("lib/core/services/live_remote_sync_service.dart")
a05_ticket_sync = text("lib/core/services/sync_service.tickets_templates.dart")
a05_admin_browser = text(
    "lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart"
)
a05_action_test = text("test/a05_component_action_integrity_test.dart")
a05_action_server_test = text("functions/test/persistedActionPayload.test.js")
a05_decision_2 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_2.md"
)
a05_work_payload_server = text("functions/src/persistedWorkPayload.ts")
a05_work_payload_server_test = text(
    "functions/test/persistedWorkPayload.test.js"
)
a05_job_model = text(
    "lib/features/planned_maintenance/data/job_template_model.dart"
)
a05_module_model = text(
    "lib/features/planned_maintenance/data/job_module_model.dart"
)
a05_execution_sync = text("lib/core/services/sync_service.executions.dart")
a05_module_sync = text("lib/core/services/sync_service.job_modules.dart")
a05_completion = text(
    "lib/features/planned_maintenance/presentation/complete_job_screen.dart"
)
a05_job_history = text(
    "lib/features/planned_maintenance/presentation/job_history_screen.dart"
)
a05_closure_guard = text(
    "lib/features/planned_maintenance/domain/planned_job_closure_guard.dart"
)
a05_finalize_handler = text(
    "functions/src/maintenanceWorkflow/finalizeJobHandler.ts"
)
a05_red_resolver = text(
    "functions/src/maintenanceWorkflow/redSuccessorTemplateResolver.ts"
)
a05_assignment = text("functions/src/publishedTemplateAssignment.ts")
a05_response_test = text("test/a05_response_payload_integrity_test.dart")
a05_lane_readiness_test = text(
    "test/maintenance_workflow/lane_closure_readiness_test.dart"
)
a05_decision_3 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_3.md"
)
a05_composer_model = text(
    "lib/features/planned_maintenance/domain/module_composer_models.dart"
)
a05_composer_screen = text(
    "lib/features/planned_maintenance/presentation/module_composer_screen.dart"
)
a05_composer_actions = text(
    "lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart"
)
a05_composer_support = text(
    "lib/features/planned_maintenance/presentation/module_composer_screen.support.dart"
)
a05_template_detail = text(
    "lib/features/planned_maintenance/presentation/template_detail_screen.dart"
)
a05_template_designer = text(
    "lib/features/planned_maintenance/presentation/template_designer_screen.dart"
)
a05_template_test = text("test/a05_template_composer_integrity_test.dart")
a05_decision_4 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_4.md"
)
a05_tombstone_guard = text(
    "lib/core/services/remote_tombstone_apply_result.dart"
)
a05_tombstone_models = "\n".join(
    text(path)
    for path in (
        "lib/core/services/live_remote_sync_service.dart",
        "lib/features/abnormalities/data/abnormality_model.dart",
        "lib/features/directives/providers/operational_directive_provider.dart",
        "lib/features/maintenance/providers/maintenance_provider.dart",
        "lib/features/planned_maintenance/data/job_diary_model.dart",
        "lib/features/planned_maintenance/data/job_module_model.dart",
        "lib/features/planned_maintenance/data/job_template_model.dart",
        "lib/features/planned_maintenance/data/template_governance_model.dart",
    )
)
a05_tombstone_provider_paths = (
    "lib/features/abnormalities/providers/abnormality_provider.dart",
    "lib/features/directives/providers/operational_directive_provider.dart",
    "lib/features/maintenance/providers/maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/job_diary_provider.dart",
    "lib/features/planned_maintenance/providers/job_module_provider.dart",
    "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/template_governance_provider.dart",
)
a05_tombstone_providers = "\n".join(
    text(path) for path in a05_tombstone_provider_paths
)
a05_tombstone_test = text("test/a05_remote_tombstone_integrity_test.dart")
a05_tombstone_conflict_test = text(
    "test/issue_1_tombstone_conflict_regression_test.dart"
)
a05_decision_5 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_5.md"
)
a05_timeline_template_model = text(
    "lib/features/planned_maintenance/data/template_governance_model.dart"
)
a05_timeline_registry_model = text(
    "lib/features/planned_maintenance/data/module_registry_model.dart"
)
a05_registry_authoring_screen = text(
    "lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart"
)
a05_template_publisher_screen = text(
    "lib/features/planned_maintenance/presentation/template_publisher_screen.dart"
)
a05_timeline_test = text("test/a05_governance_timeline_integrity_test.dart")
a05_registry_screen_test = text("test/module_registry_authoring_screen_test.dart")
a05_decision_6 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_6.md"
)
a05_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "A-05"
]
a05_record = a05_records[0] if len(a05_records) == 1 else {}
a05_reconciliation_corrections = {
    "lib/features/admin/presentation/local_diagnostics_screen.dart",
    "lib/features/audit/repositories/audit_repository.dart",
    "test/issue_1_tombstone_conflict_regression_test.dart",
    "test/planned_job_server_completion_no_loss_test.dart",
    "test/runtime_module_population_no_loss_test.dart",
}
a05_source_delta_paths = {
    "firestore.rules",
    "functions/src/plannedJobClosure.ts",
    "functions/src/publishedTemplateAssignment.ts",
    "functions/src/runtimeJobModulePopulation.ts",
    "functions/test/plannedJobClosure.test.js",
    "functions/test/publishedTemplateAssignment.test.js",
    "functions/test/runtimeJobModulePopulation.test.js",
    "lib/core/services/live_remote_sync_service.dart",
    "lib/core/services/remote_tombstone_apply_result.dart",
    "lib/core/services/sync_service.executions.dart",
    "lib/core/services/sync_service.job_modules.dart",
    "lib/core/services/sync_service.tickets_templates.dart",
    "lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart",
    "lib/features/admin/presentation/admin_data_browser/admin_templates_browser.dart",
    "lib/features/admin/utils/admin_ticket_helpers.dart",
    "lib/features/abnormalities/data/abnormality_model.dart",
    "lib/features/abnormalities/providers/abnormality_provider.dart",
    "lib/features/audit/models/audit_event_model.dart",
    "lib/features/audit/repositories/audit_repository.dart",
    "lib/features/auth/providers/auth_provider.dart",
    "lib/features/directives/providers/operational_directive_provider.dart",
    "lib/features/maintenance/data/maintenance_model.dart",
    "lib/features/maintenance/presentation/resolve_form.dart",
    "lib/features/maintenance/providers/maintenance_provider.dart",
    "lib/features/planned_maintenance/data/job_module_model.dart",
    "lib/features/planned_maintenance/data/job_diary_model.dart",
    "lib/features/planned_maintenance/data/job_template_model.dart",
    "lib/features/planned_maintenance/data/module_registry_model.dart",
    "lib/features/planned_maintenance/data/template_governance_model.dart",
    "lib/features/planned_maintenance/domain/planned_job_closure_attestation.dart",
    "lib/features/planned_maintenance/domain/planned_job_closure_guard.dart",
    "lib/features/planned_maintenance/domain/module_composer_models.dart",
    "lib/features/planned_maintenance/models/component_action_model.dart",
    "lib/features/planned_maintenance/presentation/complete_job_screen.dart",
    "lib/features/planned_maintenance/presentation/dossier/planned_job_detail_common.dart",
    "lib/features/planned_maintenance/presentation/dossier/planned_job_module_dossier.dart",
    "lib/features/planned_maintenance/presentation/job_history_screen.dart",
    "lib/features/planned_maintenance/presentation/job_module_detail_screen.dart",
    "lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart",
    "lib/features/planned_maintenance/presentation/module_composer_screen.dart",
    "lib/features/planned_maintenance/presentation/module_composer_screen.support.dart",
    "lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart",
    "lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart",
    "lib/features/planned_maintenance/presentation/template_publisher_screen.dart",
    "lib/features/planned_maintenance/presentation/template_publisher_widgets.dart",
    "lib/features/planned_maintenance/presentation/template_designer_screen.dart",
    "lib/features/planned_maintenance/presentation/template_detail_screen.dart",
    "lib/features/planned_maintenance/presentation/templates_screen.dart",
    "lib/features/planned_maintenance/presentation/widgets/job_module_card.dart",
    "lib/features/planned_maintenance/presentation/widgets/job_module_response_summary.dart",
    "lib/features/planned_maintenance/providers/job_module_provider.dart",
    "lib/features/planned_maintenance/providers/job_diary_provider.dart",
    "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/template_governance_provider.dart",
    "test/firestore.rules.test.js",
    "test/complete_job_screen_server_gate_test.dart",
    "test/module_registry_authoring_screen_test.dart",
    "test/planned_job_closure_guard_test.dart",
}
check(
    "A-05 persisted-state tranche fails closed without claiming finding closure",
    len(a05_records) == 1
    and a05_record.get("currentStatus") == "OPEN"
    and a05_record.get("title")
        == "Empty catches and DateTime.now fallbacks manufacture or suppress state"
    and "class PersistedDataFormatException" in a05_reader
    and "readRequiredPersistedDateTime" in a05_reader
    and "readRequiredJsonObjectList" in a05_reader
    and "readRequiredJsonObject" in a05_reader
    and "readOptionalJsonObject" in a05_reader
    and "decodeResolutionHistoryJson" in a05_maintenance_model
    and "resolutionHistoryReadResult" in a05_maintenance_model
    and "readValidatedResolutionHistoryPayload("
        in a05_maintenance_provider
    and "historyPayload.rows.add(" in a05_maintenance_provider
    and "decodePersistedAuditEvent(" in a05_audit_repository
    and a05_audit_repository.count("on PersistedDataFormatException") == 3
    and "_safeDecode" not in a05_audit_repository
    and "readOptionalJsonObject(" in a05_audit_model
    and "catch (_)" not in a05_audit_model
    and "Could not reset the one-shot sync marker after sign-out"
        in a05_auth_provider
    and "Resolution history needs repair" in a05_resolve_form
    and "No history entries were discarded or replaced." in a05_resolve_form
    and "remote audit records require their persisted authority fields"
        in a05_test
    and "local audit snapshots do not erase malformed state" in a05_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision
    and "component-action timestamps and broad JSON decoding" in a05_decision
    and "governed legacy-data inventory" in a05_decision
    and "does not inspect or mutate production documents" in a05_decision
    and "class ComponentActionReadResult" in a05_action_model
    and "createdAt: readRequiredPersistedDateTime(" in a05_action_model
    and "version: readRequiredPersistedInt(" in a05_action_model
    and "return [];" not in a05_action_model
    and "class PersistedActionPayloadError" in a05_action_server
    and "readComponentActionPayload" in a05_action_server
    and "action-payload-invalid" in a05_planned_closure
    and "readComponentActionPayload" in a05_runtime_population
    and "maintenance-resolution-history-invalid" in a05_maintenance_bridge
    and "history = [];" not in a05_maintenance_bridge
    and "ComponentAction.readEncodedPayload(" in a05_live_sync
    and "readEncodedResolutionHistoryPayload(" in a05_live_sync
    and "d['actionsJson']?.toString()" not in a05_live_sync
    and "_maintenanceEvidenceIntegrityError(record)" in a05_ticket_sync
    and "Saved evidence needs repair before editing" in a05_admin_browser
    and "malformed or incomplete saved actions fail closed" in a05_action_test
    and "only an entirely missing legacy payload may initialize empty"
        in a05_action_server_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_2
    and "`A-05` remains open" in a05_decision_2
    and "governed legacy-data inventory and repair path" in a05_decision_2
    and "inspect or mutate production documents" in a05_decision_2
    and "class PersistedWorkPayloadError" in a05_work_payload_server
    and "readFieldDefinitionPayload" in a05_work_payload_server
    and "readFieldResponsePayload" in a05_work_payload_server
    and "only an entirely missing legacy payload may initialize empty"
        in a05_work_payload_server_test
    and "class FieldResponseReadResult" in a05_job_model
    and "class PersistedFieldDefinitionPayload" in a05_job_model
    and "allowMissing: !map.containsKey('actionsJson')" in a05_job_model
    and "fieldDefinitionsReadResult" in a05_module_model
    and "responsesReadResult" in a05_module_model
    and "_safeJsonList" not in a05_module_model
    and "Remote responses or actions need repair" in a05_execution_sync
    and "Remote field definitions, responses, or actions need repair"
        in a05_module_sync
    and "Saved response evidence needs repair" in a05_completion
    and "Saved responses need repair" in a05_job_history
    and "invalidPersistedEvidence" in a05_closure_guard
    and "readFieldResponsePayload" in a05_finalize_handler
    and "readFieldDefinitionPayload" in a05_red_resolver
    and "fieldDefinitionsJson must contain a JSON array when present"
        in a05_red_resolver
    and "readFieldDefinitionPayload" in a05_assignment
    and "canonicalizes aliases and retains unknown response extensions"
        in a05_response_test
    and "only an absent pre-feature action field initializes empty"
        in a05_response_test
    and "malformed saved evidence becomes a visible closure blocker"
        in a05_lane_readiness_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_3
    and "a genuinely absent pre-feature field" in a05_decision_3
    and "`A-05` remains open" in a05_decision_3
    and "does not inspect or mutate production documents" in a05_decision_3
    and "class TemplateFieldReadResult" in a05_job_model
    and "TemplateFieldReadResult get fieldsReadResult" in a05_job_model
    and "A malformed canonical" in a05_job_model
    and "readRequiredJsonObject(" in a05_composer_model
    and "readRequiredJsonObjectList(" in a05_composer_model
    and "_decodeObject(" not in a05_composer_model
    and "Saved composer payload needs repair" in a05_composer_screen
    and a05_composer_actions.index(
        "selectedDraft = TemplateComposerDraft.fromPayloads"
    ) < a05_composer_actions.index("await _clearRecoveryDraft()")
    and "needs repair and was left untouched" in a05_composer_support
    and "Saved template fields need repair" in a05_template_detail
    and "Saved template fields need repair" in a05_template_designer
    and "malformed canonical fields never fall through" in a05_template_test
    and "each malformed payload root fails closed" in a05_template_test
    and "saved-version decode precedes recovery-draft deletion"
        in a05_template_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_4
    and "decoded before the current recovery draft is" in a05_decision_4
    and "`A-05` remains open" in a05_decision_4
    and "does not inspect or mutate production documents" in a05_decision_4
    and "class RemoteTombstoneIntegrityException" in a05_tombstone_guard
    and "DateTime requireRemoteTombstoneDeletedAt(" in a05_tombstone_guard
    and a05_tombstone_models.count("requireRemoteTombstoneDeletedAt(") >= 11
    and all(
        "requireRemoteTombstoneDeletedAt(" in text(path)
        for path in a05_tombstone_provider_paths
    )
    and "remote.deletedAt ??" not in a05_tombstone_providers
    and "function targetTombstoneHasDeletionAuthority()" in rules_source
    and rules_source.count("targetTombstoneHasDeletionAuthority()") >= 6
    and "all deletedAt-bearing remote model decoders fail closed"
        in a05_tombstone_test
    and "provider source contains no remote deletion-time substitution"
        in a05_tombstone_test
    and "incomplete remote tombstones fail before changing local evidence"
        in a05_tombstone_conflict_test
    and "abnormality type tombstone requires an authoritative deletion time"
        in firestore_rules_test
    and "admin directive tombstone requires an authoritative deletion time"
        in firestore_rules_test
    and "job_templates tombstone authority" in firestore_rules_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_5
    and "cursor cannot advance past the invalid record" in a05_decision_5
    and "`A-05` remains open" in a05_decision_5
    and "does not inspect or mutate production documents" in a05_decision_5
    and "readRequiredPersistedDateTime(" in a05_timeline_template_model
    and "_parseTimestamp(map['createdAt'])"
        not in a05_timeline_template_model
    and "_parseTimestamp(map['updatedAt'])"
        not in a05_timeline_template_model
    and "readRequiredPersistedDateTime(" in a05_timeline_registry_model
    and "DateTime? _parseTimestamp" not in a05_timeline_registry_model
    and "_rejectUnsupportedRegistryTombstone"
        in a05_timeline_registry_model
    and "function validTemplateVersionTimeline()" in rules_source
    and "function validModuleRegistryRevisionTimeline()" in rules_source
    and "isPersistedTimestamp(" in rules_source
    and "Governance timeline needs repair" in a05_registry_authoring_screen
    and "_canMutate => _canGovern && _error == null"
        in a05_registry_authoring_screen
    and "Governance timeline needs repair" in a05_template_publisher_screen
    and "Publishing is blocked" in a05_template_publisher_screen
    and "version lifecycle history must be complete and state-consistent"
        in a05_timeline_test
    and "governance decoders do not manufacture timeline timestamps"
        in a05_timeline_test
    and "malformed governance timeline is visible and blocks authoring actions"
        in a05_registry_screen_test
    and "template versions and publication audits reject incomplete timelines"
        in firestore_rules_test
    and "registry family, revision, and audit timelines fail closed"
        in firestore_rules_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_6
    and "`A-05` remains open" in a05_decision_6
    and "does not inspect or mutate production documents" in a05_decision_6
    and recon.get("counts", {}).get("BYTE_IDENTICAL") == 232
    and recon.get("counts", {}).get("SUCCESSOR_MODIFIED") == 178
    and all(
        row_map.get(path, {}).get("disposition") == "SUCCESSOR_MODIFIED"
        for path in a05_reconciliation_corrections
    )
    and all(
        row_map.get(path, {}).get("disposition") == "SUCCESSOR_MODIFIED"
        for path in a05_source_delta_paths
    ),
)

print(f"SUMMARY | pass={len(PASS)} fail={len(FAIL)} total={len(PASS)+len(FAIL)}")
if FAIL:
    for name, detail in FAIL:
        print(f"FAILED | {name}" + (f" | {detail}" if detail else ""), file=sys.stderr)
raise SystemExit(1 if FAIL else 0)
