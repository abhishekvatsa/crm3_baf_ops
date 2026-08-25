#!/usr/bin/env python3
"""Fail-closed canonical-main and local-laboratory audit for v4.2_R1."""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import re
import shutil
import subprocess
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


def canonical_receipt_sha(receipt: dict) -> str:
    body = dict(receipt)
    body.pop("receiptSha256", None)
    canonical = json.dumps(
        body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


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
post_codegen_refresh = post_codegen_register.get("currentSourceRefresh", {})
post_codegen_register_valid = (
    post_codegen_register.get("schemaVersion") == 1
    and post_codegen_register.get("authority") == "AUTHENTIC_WINDOWS_ISAR_CODEGEN"
    and post_codegen_source.get("sha256")
    == "E2A0F3D38C9A0950922A0B5933A435159E5FA950F361BC8C2B8D6ADB3FEB470A"
    and post_codegen_source.get("codegenResult") == "PASS"
    and post_codegen_source.get("custodyResult") == "PASS"
    and post_codegen_refresh.get("sourceCommit")
        == "acf8fea58c3689a730d1ef56c61694ff3e618175"
    and post_codegen_refresh.get("sourceTree")
        == "311ac9be55ddc253bc9cf2f220d2c809c292929d"
    and post_codegen_refresh.get("codegenResult") == "PASS"
    and post_codegen_refresh.get("changedBindingPaths") == [
        "lib/features/maintenance/data/maintenance_model.g.dart",
    ]
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
    and counts.get("BYTE_IDENTICAL") == 172
    and counts.get("SUCCESSOR_MODIFIED") == 238
    and counts.get("MISSING", 0) == 0,
    str(counts),
)

critical_exact = {
    "release/stage2d-f-internal-controlled-deployment-scope.json",
}
row_map = {row["path"]: row for row in rows}
check(
    "Immutable release authority remains byte-identical",
    all(
        row_map.get(path, {}).get("disposition") == "BYTE_IDENTICAL"
        for path in critical_exact
    ),
)
check(
    "Android Crashlytics plugin registration is explicit successor authority",
    row_map.get("android/settings.gradle.kts", {}).get("disposition")
        == "SUCCESSOR_MODIFIED"
    and 'id("com.google.firebase.crashlytics") version "3.0.7" apply false'
        in text("android/settings.gradle.kts")
    and 'id("com.google.firebase.crashlytics")'
        in text("android/app/build.gradle.kts"),
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
    and "Android release package + cold-start proof (non-production)"
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
        if name not in {
            "sourceDecisionAtMerge",
            "workflow",
            "productionPolicyVerifier",
            "taxonomy",
            "contractTest",
        }
    )
    and c04_source_controls.get("taxonomy", {}).get("sha256")
        == "9EE7137FDD9F2D933AD4ADF0BEE332DF3F36C56D0E6F8E57D2B1AB931DE7A5E1"
    and c04_source_controls.get("contractTest", {}).get("sha256")
        == "B5262C5B5B1E5AFA51AEDD052AF1BD4F4075E57C478BC239531824C83F35833B"
    and c04_source_controls.get("workflow", {}).get("sha256")
        == "6645809EE26F3E78A937D26D14254AD6A6F3797D3EE3EDD488F4C5DAEC17741E"
    and c04_source_controls.get("productionPolicyVerifier", {}).get(
        "sha256"
    ) == "4DE6956CC9FEBD99ABB62E66975D9ED58F62D6C398927A3015B550FF7B3BF0CB"
    and "Validate and publish test evidence taxonomy" in release_gate_source
    and "Android emulator app-shell integration (not physical-device evidence)"
        in release_gate_source
    and "Production policy and package-verifier runtime gate"
        in release_gate_source
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
c03_startup_script = text(
    "tools/release/Test-CIAndroidReleaseStartup.ps1"
)
c03_package_test = text("test/c03_android_packaging_ci_contract_test.dart")
c03_package_decision = text("docs/v4_2_r1/C03_ANDROID_PR_PACKAGING.md")
c03_android_manifest = text("android/app/src/main/AndroidManifest.xml")
c03_main_source = text("lib/main.dart")
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
    and "com.google.firebase.crashlytics.mapping_file_id"
        in c03_package_script
    and "$crashlyticsMappingIdOutput.Count -ne 1" in c03_package_script
    and "crashlyticsMappingIdPresent=true" in c03_package_script
    and "CRM3_CI_PACKAGE_PROOF=true" in c03_package_script
    and "android/app/src/release/google-services.json" in c03_package_script
    and "isolatedFirebaseIdentity=true" in c03_package_script
    and "productionFirebaseIdentityEmbedded=false" in c03_package_script
    and "firebaseProductionTrafficDisabled=true" in c03_package_script
    and "crashlyticsMappingUploadEnabled=false" in c03_package_script
    and "firebaseAutomaticCollectionEnabled=false" in c03_package_script
    and "firebaseNativeInitProviderEnabled=false" in c03_package_script
    and "mappingFileUploadEnabled = !ciPackageProof" in c06_android_build
    and 'manifestPlaceholders["crm3FirebaseInitProviderEnabled"]'
        in c06_android_build
    and "firebase_data_collection_default_enabled" in c03_android_manifest
    and "firebase_crashlytics_collection_enabled" in c03_android_manifest
    and "firebase_messaging_auto_init_enabled" in c03_android_manifest
    and "firebase_analytics_collection_enabled" in c03_android_manifest
    and "com.google.firebase.provider.FirebaseInitProvider"
        in c03_android_manifest
    and "bool.fromEnvironment('CRM3_CI_PACKAGE_PROOF')" in c03_main_source
    and c03_main_source.index("if (_ciPackageProof) {")
        < c03_main_source.index("runCrashReportingZoned")
    and "PASS_C03_ANDROID_RELEASE_COLD_START_PROOF"
        in c03_startup_script
    and "activity', 'exit-info" in c03_startup_script
    and "logcat', '-b', 'crash" in c03_startup_script
    and "Release process is not alive after cold launch."
        in c03_startup_script
    and "CI proof APK must disable FirebaseInitProvider"
        in c03_startup_script
    and "firebaseNativeInitProviderEnabled=false" in c03_startup_script
    and "firebaseDartInitializationAttempted=false" in c03_startup_script
    and "Test-CIAndroidReleaseStartup.ps1" in c03_job_source
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
    and len(workflow_action_refs) == 27
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
firebase_key_android_mutator = text(
    "tools/security/apply_firebase_android_api_key_restrictions.cjs"
)
firebase_key_android_mutator_test = text(
    "tools/security/apply_firebase_android_api_key_restrictions.test.mjs"
)
firebase_key_security_policy = text("SECURITY.md")
firebase_key_decision = text(
    "docs/v4_2_r1/FIREBASE_CLIENT_API_KEY_CUSTODY.md"
)
firebase_key_android_live_evidence = data(
    "release/evidence/firebase-android-api-key-pilot-hardening-20260822.json"
)
firebase_key_strict_live_evidence = data(
    "release/evidence/firebase-client-api-key-live-custody-20260822.json"
)
root_package = data("package.json")
firebase_key_source_policy = firebase_key_policy.get("sourceCustody", {})
firebase_key_live_policy = firebase_key_policy.get("liveReadback", {})
firebase_key_expected_keys = firebase_key_live_policy.get("expectedKeys", [])
firebase_key_expected_targets = firebase_key_live_policy.get(
    "expectedApiTargets", []
)
firebase_key_android_hardening = firebase_key_policy.get(
    "androidPilotHardening", {}
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
    and {
        key.get("displayName"): key.get("applicationRestrictions")
        for key in firebase_key_expected_keys
        if isinstance(key, dict)
    } == {
        "Android key (auto created by Firebase)": [
            {
                "type": "android",
                "entryCount": 2,
                "valueSha256": "F9B07890AAD52DD6F0593610254F2C1524D58149CCAAA1AA138FD6F956FFD692",
            }
        ],
        "Browser key (auto created by Firebase)": [
            {
                "type": "browser",
                "entryCount": 0,
                "valueSha256": "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A",
            }
        ],
        "iOS key (auto created by Firebase)": [
            {
                "type": "ios",
                "entryCount": 0,
                "valueSha256": "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A",
            }
        ],
    }
    and firebase_key_android_hardening.get("displayName")
        == "Android key (auto created by Firebase)"
    and firebase_key_android_hardening.get("allowedApplications")
        == [
            {
                "packageName": "in.co.sail.bsl.crm3.bafops",
                "sha1Fingerprint": "30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31",
            },
            {
                "packageName": "in.co.sail.bsl.crm3.bafops",
                "sha1Fingerprint": "41C2B828C71683A50EC346D19E1D44048758438D",
            },
        ]
    and firebase_key_android_hardening.get(
        "acceptedPreMutationValueSha256"
    ) == [
        "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A",
        "F9B07890AAD52DD6F0593610254F2C1524D58149CCAAA1AA138FD6F956FFD692",
    ]
    and firebase_key_android_hardening.get(
        "automaticRollbackOnPostVerificationFailure"
    ) is True
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
    and "normalizeSha1Fingerprint" in firebase_key_readback
    and "executeCampaign" in firebase_key_android_mutator
    and "sourceBinding.commit !== sourceBinding.originMain"
        in firebase_key_android_mutator
    and "updateMask: \"restrictions\"" in firebase_key_android_mutator
    and "failed post-readback restores and verifies original restrictions"
        in firebase_key_android_mutator_test
    and root_package.get("scripts", {}).get(
        "test:firebase-client-key-custody"
    )
        == "node --test tools/security/firebase_client_api_key_custody.test.mjs tools/security/collect_firebase_client_api_key_readback.test.mjs tools/security/apply_firebase_android_api_key_restrictions.test.mjs && node tools/security/firebase_client_api_key_custody.cjs"
    and "npm run test:firebase-client-key-custody" in release_gate_source
    and "https://firebase.google.com/docs/projects/api-keys"
        in firebase_key_security_policy
    and "App Check is a separate anti-abuse control"
        in firebase_key_security_policy
    and "both approved Android signing certificates" in firebase_key_decision
    and "Browser and iOS" in firebase_key_decision
    and "application restrictions remain unchanged" in firebase_key_decision,
)
firebase_key_android_evidence_source = firebase_key_android_live_evidence.get(
    "source", {}
)
firebase_key_android_evidence_application = firebase_key_android_live_evidence.get(
    "applicationRestriction", {}
)
firebase_key_android_evidence_restrictions = firebase_key_android_live_evidence.get(
    "restrictions", {}
)
firebase_key_android_evidence_rollback = firebase_key_android_live_evidence.get(
    "rollback", {}
)
firebase_key_android_evidence_privacy = firebase_key_android_live_evidence.get(
    "privacyBoundary", {}
)
check(
    "Firebase Android pilot key binding is live, exact and rollback-protected",
    firebase_key_android_live_evidence.get("schemaVersion") == 1
    and firebase_key_android_live_evidence.get("evidenceType")
        == "firebase-android-api-key-pilot-hardening"
    and firebase_key_android_live_evidence.get("capturedAtUtc")
        == "2026-08-22T00:12:18.062Z"
    and firebase_key_android_live_evidence.get("status")
        == "APPLIED_AND_VERIFIED"
    and firebase_key_android_evidence_source.get("commit")
        == "a78c4723c4a4396c0c9796a5de90486621042514"
    and firebase_key_android_evidence_source.get("originMain")
        == "a78c4723c4a4396c0c9796a5de90486621042514"
    and firebase_key_android_evidence_source.get("policySha256")
        == sha(ROOT / "release/firebase-client-api-key-policy.json")
    and firebase_key_android_evidence_source.get("governedWorktreeClean") is True
    and firebase_key_android_evidence_source.get("materialChangeCount") == 0
    and firebase_key_android_evidence_source.get("materialPathSha256") == []
    and firebase_key_android_evidence_application
        == {
            "entryCount": 2,
            "valueSha256": "F9B07890AAD52DD6F0593610254F2C1524D58149CCAAA1AA138FD6F956FFD692",
        }
    and firebase_key_android_evidence_restrictions
        == {
            "beforeSha256": "D538DA2EEEF15F6A8076AEF2B0FD517D3FEC7DC5A8F67C9C58D174EB6CCF5CDB",
            "targetSha256": "CA408F16F24180613872F8554225E82BCEB62B4BC98892D262732D952EBB858F",
            "apiTargetCount": 27,
            "apiTargetsPreserved": True,
        }
    and firebase_key_android_evidence_rollback
        == {"attempted": False, "succeeded": None}
    and firebase_key_android_evidence_privacy
        == {
            "rawKeyValuesRead": False,
            "rawKeyValuesRetained": False,
            "rawKeyValuesEmitted": False,
            "resourceNameRetained": False,
            "accountIdentityRetained": False,
        }
    and "AIza" not in json.dumps(firebase_key_android_live_evidence)
    and "projects/" not in json.dumps(firebase_key_android_live_evidence),
)
firebase_key_strict_source = firebase_key_strict_live_evidence.get("source", {})
firebase_key_strict_keys = firebase_key_strict_live_evidence.get("keys", [])
firebase_key_strict_key_contract = {
    key.get("displayName"): {
        "keyStringSha256": key.get("keyStringSha256"),
        "apiTargetServices": [
            target.get("service")
            for target in key.get("apiTargets", [])
            if isinstance(target, dict)
        ],
        "apiMethods": [
            target.get("methods")
            for target in key.get("apiTargets", [])
            if isinstance(target, dict)
        ],
        "applicationRestrictionTypes": key.get(
            "applicationRestrictionTypes"
        ),
        "applicationRestrictionEntryCounts": key.get(
            "applicationRestrictionEntryCounts"
        ),
        "deleted": key.get("deleted"),
    }
    for key in firebase_key_strict_keys
    if isinstance(key, dict)
}
check(
    "Firebase client API key strict live custody is clean-main and exact",
    firebase_key_strict_live_evidence.get("schemaVersion") == 1
    and firebase_key_strict_live_evidence.get("evidenceType")
        == "firebase-client-api-key-live-custody"
    and firebase_key_strict_live_evidence.get("policyId")
        == "crm3-firebase-client-api-key-custody-v1"
    and firebase_key_strict_live_evidence.get("firebaseProjectId")
        == "crm3-baf-ops-b8638"
    and firebase_key_strict_live_evidence.get("projectNumber") == "894346496105"
    and firebase_key_strict_live_evidence.get("mode") == "STRICT"
    and firebase_key_strict_live_evidence.get("decision")
        == "PASS_FIREBASE_CLIENT_API_KEY_LIVE_CUSTODY"
    and firebase_key_strict_live_evidence.get("capturedAtUtc")
        == "2026-08-22T00:28:25.392Z"
    and firebase_key_strict_source.get("commit")
        == "4c9b8eb3e5dcf4a7f9be134bffcf56b07e31e332"
    and firebase_key_strict_source.get("originMain")
        == "4c9b8eb3e5dcf4a7f9be134bffcf56b07e31e332"
    and firebase_key_strict_source.get("policySha256")
        == sha(ROOT / "release/firebase-client-api-key-policy.json")
    and firebase_key_strict_source.get("governedWorktreeClean") is True
    and firebase_key_strict_source.get("materialChangeCount") == 0
    and firebase_key_strict_source.get("materialPathSha256") == []
    and set(firebase_key_strict_key_contract)
        == {
            "Android key (auto created by Firebase)",
            "Browser key (auto created by Firebase)",
            "iOS key (auto created by Firebase)",
        }
    and all(
        contract.get("apiTargetServices") == firebase_key_approved_targets
        and contract.get("apiMethods") == [[] for _ in firebase_key_approved_targets]
        and contract.get("deleted") is False
        for contract in firebase_key_strict_key_contract.values()
    )
    and firebase_key_strict_key_contract[
        "Android key (auto created by Firebase)"
    ] == {
        "keyStringSha256": "1D8CA255D2D1370619CBFA84A160451EACD26B3029B76B385049BEBDEB8D02A1",
        "apiTargetServices": firebase_key_approved_targets,
        "apiMethods": [[] for _ in firebase_key_approved_targets],
        "applicationRestrictionTypes": ["android"],
        "applicationRestrictionEntryCounts": [
            {
                "type": "android",
                "entryCount": 2,
                "valueSha256": "F9B07890AAD52DD6F0593610254F2C1524D58149CCAAA1AA138FD6F956FFD692",
            }
        ],
        "deleted": False,
    }
    and firebase_key_strict_key_contract[
        "Browser key (auto created by Firebase)"
    ]["keyStringSha256"]
        == "7E6D14B01F16C804D76184AEC71D7802BD93E349447B489B64ADBC22F4381B55"
    and firebase_key_strict_key_contract[
        "Browser key (auto created by Firebase)"
    ]["applicationRestrictionTypes"] == ["browser"]
    and firebase_key_strict_key_contract[
        "Browser key (auto created by Firebase)"
    ]["applicationRestrictionEntryCounts"] == [
        {
            "type": "browser",
            "entryCount": 0,
            "valueSha256": "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A",
        }
    ]
    and firebase_key_strict_key_contract[
        "iOS key (auto created by Firebase)"
    ]["keyStringSha256"]
        == "9F16CF3F58CFFE3FD92BC15D419CF075090E03CEDDBA966C6E171E6FCDD82097"
    and firebase_key_strict_key_contract[
        "iOS key (auto created by Firebase)"
    ]["applicationRestrictionTypes"] == ["ios"]
    and firebase_key_strict_key_contract[
        "iOS key (auto created by Firebase)"
    ]["applicationRestrictionEntryCounts"] == [
        {
            "type": "ios",
            "entryCount": 0,
            "valueSha256": "44136FA355B3678A1146AD16F7E8649E94FB4FC21FE77E8310C060F61CAAFF8A",
        }
    ]
    and firebase_key_strict_live_evidence.get("checks")
        == {
            "schemaVersion": True,
            "governedSourceClean": True,
            "sourceCustody": True,
            "keyCount": True,
            "displayNamesExact": True,
            "sourceKeySetExact": True,
            "keysActive": True,
            "apiTargetsExact": True,
            "apiMethodsUnscoped": True,
            "forbiddenApiTargetsAbsent": True,
            "applicationRestrictionShapeExact": True,
        }
    and firebase_key_strict_live_evidence.get("privacyBoundary")
        == {
            "clientApiKeyValuesReadForHashBinding": True,
            "rawKeyValuesRetained": False,
            "rawKeyValuesEmitted": False,
            "accountIdentityRetained": False,
        }
    and "AIza" not in json.dumps(firebase_key_strict_live_evidence),
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
functions_live_sealed_exports = [
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
functions_live_expected_exports = sorted(
    functions_live_sealed_exports + ["mutateAssetHierarchy"]
)
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
    and functions_live_readback_policy.get(
        "sourcePendingDeploymentExports"
    ) == ["mutateAssetHierarchy"]
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
    and functions_live_receipt.get("outputs", {}).get(
        "discoveredSourceFunctionExports"
    ) == functions_live_sealed_exports
    and functions_live_receipt.get("outputs", {}).get(
        "policySourceFunctionExports"
    ) == functions_live_sealed_exports
    and sorted(
        set(functions_live_expected_exports)
        - set(functions_live_sealed_exports)
    ) == functions_live_readback_policy.get(
        "sourcePendingDeploymentExports"
    )
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
function_fleet_pending_bindings = function_fleet_identity_policy.get(
    "deploymentPendingFunctionBindings", []
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
        == "SOURCE_POLICY_EXTENDED_DEPLOYMENT_PENDING"
    and function_fleet_identity_policy.get("productionProjectId")
        == "crm3-baf-ops-b8638"
    and function_fleet_identity_policy.get("targetProjectBinding") == {
        "builtInParameter": "PROJECT_ID",
        "serviceAccountDomain": "iam.gserviceaccount.com",
        "sameProjectRequired": True,
        "crossProjectResolutionAllowed": False,
    }
    and function_fleet_pending_bindings == ["mutateAssetHierarchy"]
    and sorted(function_fleet_bindings) == functions_live_expected_exports
    and len(function_fleet_account_ids) == 15
    and len(set(function_fleet_account_ids)) == 15
    and all(
        function_fleet_bindings.get(name, {}).get("runtimeServiceAccountId")
            == live_binding.split("@", 1)[0]
        for name, live_binding in functions_live_readback_policy.get(
            "sourceDeclaredRuntimeBindings", {}
        ).items()
    )
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
    and "SOURCE_POLICY_EXTENDED_DEPLOYMENT_PENDING"
        in function_fleet_identity_test
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
    and "prior Default Compute Editor posture was restored"
        in function_fleet_campaign_executor
    and "exact five-job successful post-merge release gate"
        in function_fleet_campaign_executor
    and "-DifferenceObject $actualJobNames -CaseSensitive"
        in function_fleet_campaign_executor
    and "$defaultComputeAlreadyHardened"
        in function_fleet_campaign_executor
    and "if ($defaultComputeEditorPresentBeforeFinalization)"
        in function_fleet_campaign_executor
    and "service-accounts delete" not in function_fleet_campaign_executor
    and "functions delete" not in function_fleet_campaign_executor
    and "Editor removal is final, conditionally reversible"
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
    ) == "NONE_ALL_PROGRAMME_GATES_CLOSED"
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
js_yaml = firebase_cli_packages.get("node_modules/js-yaml", {})
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
    and firebase_cli_package.get("overrides", {}).get("js-yaml") == "4.3.1"
    and firebase_cli_package.get("dependencies", {}).get("brace-expansion") == "file:../brace-expansion-compat"
    and firebase_cli_package.get("overrides", {}).get("brace-expansion") == "$brace-expansion"
    and firebase_cli_package.get("overrides", {}).get("tar") == "7.5.21"
    and firebase_cli_package.get("overrides", {}).get("re2") == "1.26.1"
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
    and js_yaml.get("version") == "4.3.1"
    and js_yaml.get("resolved") == "https://registry.npmjs.org/js-yaml/-/js-yaml-4.3.1.tgz"
    and js_yaml.get("integrity") == "sha512-CY6crGq313MX8GkwvB7tzgp99vjQxY1++5y10/BKN/GUfHqWaOGQMNZkBvqSzsZKWk/ijwHlWzzkLulsGHhjWQ=="
    and brace_expansion.get("version") == "5.0.9"
    and brace_expansion.get("resolved") == "file:../brace-expansion-compat"
    and brace_expansion_upstream.get("name") == "brace-expansion"
    and brace_expansion_upstream.get("version") == "5.0.9"
    and brace_expansion_upstream.get("resolved") == "https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.9.tgz"
    and brace_expansion_upstream.get("integrity") == "sha512-ScQ4IuvIEF1TMlP7Zt+vjJ//9zlPb2SDcxWxM3bk8s6t6GGdJ7KO1dCcTidOPJKePW30LE/2cT7wCyPho9/Wxg=="
    and tar.get("version") == "7.5.21"
    and tar.get("resolved") == "https://registry.npmjs.org/tar/-/tar-7.5.21.tgz"
    and tar.get("integrity") == "sha512-XdhtCvlMywwxpCW8YEq3lOXBJpUPTR2OHHcwLPO3HwsJqOHa2Ok/oJ7ruGzp+JrKoRPVCzJwAdEjqLW/vNRPHA=="
    and re2.get("version") == "1.26.1"
    and re2.get("resolved") == "https://registry.npmjs.org/re2/-/re2-1.26.1.tgz"
    and re2.get("integrity") == "sha512-oi79a4h6EO3PAwNsDMWgeCcsRGQEUa52DIgOiFTZGDEZocEXG9h+oXy0qZqndo47huUeJuVWSoOJIEhOupqOcg=="
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
    "Release gate audits all three npm dependency domains",
    "npm audit --audit-level=low" in release_gate_source
    and "npm --prefix functions audit --audit-level=low" in release_gate_source
    and "npm --prefix tooling/firebase-cli audit --audit-level=low"
        in release_gate_source,
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
        "4.3.1",
        "5.0.9",
        "1.26.1",
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
identity_repair = text(
    "lib/core/services/governed_asset_identity_local_repair.dart"
)
startup = text("lib/main.dart")
workflow_panel = text("lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart")
compliance_dialog = text("lib/features/maintenance_workflow/presentation/widgets/raise_compliance_dialog.dart")
module_provider = "\n".join(
    text(path)
    for path in (
        "lib/features/planned_maintenance/providers/job_module_provider.dart",
        "lib/features/planned_maintenance/providers/job_module_provider.local.dart",
        "lib/features/planned_maintenance/providers/job_module_provider.remote.dart",
    )
)
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
    and "currentSchemaVersion = 7" in isar_migration
    and "v4SchemaFingerprint" in isar_migration
    and "v5SchemaFingerprint" in isar_migration
    and "6: _addOperationalEventIssueLinkProjection" in isar_migration
    and "7: _addMaintenanceReopenEvidenceFields" in isar_migration
    and "existing-store-unmarked" in isar_migration
    and "legacy-marker-incomplete" in isar_migration
    and "_validateMarkerSource(" in isar_migration
    and "fromVersion < 5" in identity_repair
    and "toVersion >= 5" in identity_repair
    and "toVersion == 5" not in identity_repair
    and "repairGovernedAssetIdentityForSchemaUpgrade(" in startup
    and "repairLegacyGovernedAssetIdentityProjections(" in identity_repair
    and "resetGovernedAssetIdentityProjectionPullCursors()" in identity_repair
    and "commitAfterSuccessfulOpen()" in startup
    and startup.index("ensureIsarSchemaBeforeOpen(")
    < startup.index("Isar.open(")
    < startup.index("repairPlannedJobLocalLinks(")
    < startup.index("repairLegacyOperationalAssuranceRequests(")
    < startup.index("repairGovernedAssetIdentityForSchemaUpgrade(")
    < startup.index("commitAfterSuccessfulOpen()")
    and identity_repair.index("repairLegacyGovernedAssetIdentityProjections(")
    < identity_repair.index("resetGovernedAssetIdentityProjectionPullCursors()")
    and "readIsarSchemaProvenanceSnapshotJson()" in startup
    and '"schemaProvenanceSnapshot": $provenanceSnapshot' in startup
    and ".isar.lock" not in isar_guard,
)

isar_inventory = text("lib/core/services/isar_installed_store_provenance.dart")
local_diagnostics = text(
    "lib/features/admin/presentation/local_diagnostics_screen.dart"
)
local_diagnostics_adapter = text(
    "lib/features/admin/services/local_diagnostics_read_adapter.dart"
)
isar_fixture_test = text("test/70k_isar_populated_migration_fixture_test.dart")
isar_inventory_test = text("test/isar_installed_store_provenance_test.dart")
recovery_source_tranche = text(
    "docs/v4_2_r1/70K_LOCAL_DATABASE_RECOVERY_SOURCE_TRANCHE.md"
)
check(
    "70K inventory and populated recovery fixtures are privacy-safe and exact",
    all(marker in isar_inventory for marker in (
        "EXISTING_STORE_UNMARKED_BLOCKED",
        "EXISTING_STORE_LEGACY_PARTIAL_BLOCKED",
        "CANONICAL_MARKER_MALFORMED_BLOCKED",
        "EXISTING_STORE_PREPARED_RESTART_REQUIRED",
        "EXISTING_STORE_CANONICAL_CURRENT",
        "STORE_ABSENT_GENERATION_ROTATION_REQUIRED",
        "rawMarkerValuesIncluded': false",
        ".convert(utf8.encode(canonicalMarker.databaseGenerationId))",
    ))
    and "readPrivacySafeIsarProvenanceInventory" in isar_guard
    and "preferences.set" not in isar_guard
    and "canonicalSourceFingerprintRecognized" in isar_inventory
    and "stored-schema-fingerprint-unrecognized" in isar_inventory
    and "preserveStartupPreOpenIsarProvenanceInventory" in startup
    and '"installedStoreProvenance": $installedStoreProvenance' in startup
    and "readStartupPreOpenIsarProvenanceInventory()"
        in local_diagnostics_adapter
    and "readPrivacySafeIsarProvenanceInventory()"
        in local_diagnostics_adapter
    and "writeTxn(" not in local_diagnostics_adapter
    and local_diagnostics.index(
        "await ref.watch(currentAppUserProvider.future)"
    ) < local_diagnostics.index("LocalDiagnosticsReadAdapter().read()")
    and "'localDatabaseProvenance': provenanceInventory.toMap()"
        in local_diagnostics
    and "633c58bb0d936011e391b42627f8b8f02c510e95" in isar_fixture_test
    and "repository-proven populated v1 migrates to v7" in isar_fixture_test
    and "populated v3 compliance request migrates through v7"
        in isar_fixture_test
    and "populated v6 maintenance ticket migrates to v7"
        in isar_fixture_test
    and "stored-schema-fingerprint-unrecognized" in isar_fixture_test
    and "blocks a current target with unsupported migration ancestry"
        in isar_inventory_test
    and "preserves the startup pre-open inventory for later reporting"
        in isar_inventory_test
    and "durable restart rehearsal preserves generation" in isar_fixture_test
    and "backup restores populated rows" in isar_fixture_test
    and "isNot(contains(_generationId))" in isar_inventory_test
    and "does not add a production v2 fingerprint" in recovery_source_tranche
    and "does not by itself\nauthorize pilot handout or close `70K-RECOVERY`"
        in recovery_source_tranche,
)

local_recovery_closure_path = (
    ROOT / "release/evidence/70k-local-database-recovery-closure.json"
)
local_recovery_closure = data(
    "release/evidence/70k-local-database-recovery-closure.json"
)
f6_readiness_path = (
    ROOT / "release/evidence/stage2d-f6-build11-pilot-readiness.json"
)
f6_readiness = data(
    "release/evidence/stage2d-f6-build11-pilot-readiness.json"
)
recovery_ledger = data("governance/programme-ledger.json")
recovery_gate = next(
    (
        record
        for record in recovery_ledger.get("programmeGates", [])
        if record.get("gateId") == "70K-RECOVERY"
    ),
    {},
)
f6_gate = next(
    (
        record
        for record in recovery_ledger.get("programmeGates", [])
        if record.get("gateId") == "STAGE2D-F6"
    ),
    {},
)
p06_finding = next(
    (
        record
        for record in recovery_ledger.get("technicalFindings", [])
        if record.get("findingId") == "P-06"
    ),
    {},
)
check(
    "P-06 and 70K close on exact Build 11 evidence while F6 stays blocked",
    sha(local_recovery_closure_path)
        == "D67264FA6A93CFC07BD4A6955435D605B9062BD0F83CD53BE6BF97E12857FEF0"
    and local_recovery_closure.get("decision")
        == "PASS_70K_RECOVERY_AND_P06_CLOSURE"
    and local_recovery_closure.get("sourceAuthority", {}).get(
        "p06PostMergeRunId"
    ) == 31512254539
    and local_recovery_closure.get("installedTargets", {}).get("targetCount")
        == 2
    and local_recovery_closure.get("installedTargets", {}).get(
        "packageUidPreservedOnEveryTarget"
    ) is True
    and local_recovery_closure.get("installedTargets", {}).get(
        "appDataClearPerformed"
    ) is False
    and local_recovery_closure.get("nativeStoreCampaign", {}).get("passed")
        == 21
    and local_recovery_closure.get("nativeStoreCampaign", {}).get("failed")
        == 0
    and local_recovery_closure.get("closureBoundary", {}).get(
        "p06ClosureAuthorized"
    ) is True
    and local_recovery_closure.get("closureBoundary", {}).get(
        "stage2dF6ClosureAuthorized"
    ) is False
    and recovery_gate.get("currentStatus") == "CLOSED"
    and [entry.get("status") for entry in recovery_gate.get("statusHistory", [])]
        == ["OPEN", "DEVICE_PROVED", "CLOSED"]
    and p06_finding.get("currentStatus") == "CLOSED"
    and [entry.get("status") for entry in p06_finding.get("statusHistory", [])]
        == [
            "OPEN",
            "SOURCE_IMPLEMENTED",
            "MERGED",
            "DEPLOYED",
            "DEVICE_PROVED",
            "CLOSED",
        ]
    and sha(f6_readiness_path)
        == "7C5DF86E1DDB16C3CD36BFF476798C4790E314CFF707BE3BC8FDCE85BDC8CF1A"
    and f6_readiness.get("decision") == "READY_AWAITING_LR07_CONTAINMENT"
    and f6_readiness.get("authorizationBoundary", {}).get(
        "allSevenF6EvidenceCategoriesAuthored"
    ) is True
    and f6_readiness.get("authorizationBoundary", {}).get(
        "pilotHandoutAuthorized"
    ) is False
    and f6_gate.get("currentStatus") == "CLOSED"
    and recovery_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
)

app_database_source = text("lib/core/persistence/app_database.dart")
main_source = text("lib/main.dart")
dart_import_cycle_test = text("test/dart_import_cycle_test.dart")
dart_import_cycle_decision = text("docs/DART_IMPORT_CYCLE_CLOSURE.md")
a01_evidence_path = ROOT / "release/evidence/a01-dart-import-cycle-source-and-ci-closure.json"
a01_evidence = data("release/evidence/a01-dart-import-cycle-source-and-ci-closure.json")
a01_finding = next(
    item
    for item in recovery_ledger.get("technicalFindings", [])
    if item.get("findingId") == "A-01"
)
a01_expected_jobs = {
    "Flutter host analysis + tests + no-loss contracts",
    "Cloud Functions host build + non-emulator tests",
    "Firestore Rules + governed callable emulator",
    "Android release package + cold-start proof (non-production)",
    "Android emulator app-shell integration (not physical-device evidence)",
}
a01_pull_request_ci = a01_evidence.get("pullRequestCi", {})
a01_post_merge_ci = a01_evidence.get("postMergeCi", {})
a01_boundaries = a01_evidence.get("boundaries", {})
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
    and len(app_database_consumers) == 11
    and "lib has no internal Dart import cycles" in dart_import_cycle_test
    and "final lowLinks = <String, int>{};" in dart_import_cycle_test
    and "component.length > 1 || graph[node]!.contains(node)"
        in dart_import_cycle_test
    and "cycles,\n      isEmpty" in dart_import_cycle_test
    and "Largest component:      72 files" in dart_import_cycle_decision
    and "Cyclic components:      0" in dart_import_cycle_decision
    and "Isar schemas,\ndatabase naming, open order" in dart_import_cycle_decision
    and "Status: CLOSED" in dart_import_cycle_decision
    and a01_finding.get("currentStatus") == "CLOSED"
    and [
        entry.get("status")
        for entry in a01_finding.get("statusHistory", [])
    ] == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(a01_finding.get("evidence", [])) == 1
    and a01_finding["evidence"][0].get("evidenceFile")
        == "release/evidence/a01-dart-import-cycle-source-and-ci-closure.json"
    and a01_finding["evidence"][0].get("evidenceSha256")
        == sha(a01_evidence_path)
    and a01_finding["evidence"][0].get("decision")
        == "PASS_A01_DART_IMPORT_CYCLE_SOURCE_AND_CI_CLOSURE"
    and a01_evidence.get("decision")
        == "PASS_A01_DART_IMPORT_CYCLE_SOURCE_AND_CI_CLOSURE"
    and a01_evidence.get("sourceAuthority", {}).get("headCommit")
        == "2a5a2751ae5bb2d17cb4148799ac58ed0ae78cf6"
    and a01_evidence.get("sourceAuthority", {}).get("sourceTree")
        == "99deeb6966cc1b694f861a6154d9a4ddef3c7af0"
    and a01_evidence.get("sourceAuthority", {}).get("mergeCommit")
        == "dad9ec6d27177699a1656b0a33ca23739ffb41ea"
    and a01_evidence.get("sourceAuthority", {}).get("mergeTree")
        == "99deeb6966cc1b694f861a6154d9a4ddef3c7af0"
    and a01_evidence.get("importGraphProof", {}).get("mainDartImporterCount") == 0
    and a01_evidence.get("importGraphProof", {}).get(
        "stronglyConnectedComponentCount"
    ) == 0
    and a01_evidence.get("importGraphProof", {}).get("selfImportCycleCount") == 0
    and a01_pull_request_ci.get("workflowRun") == 31863973925
    and a01_pull_request_ci.get("headCommit")
        == "2a5a2751ae5bb2d17cb4148799ac58ed0ae78cf6"
    and a01_pull_request_ci.get("conclusion") == "success"
    and len(a01_pull_request_ci.get("jobs", [])) == 5
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a01_pull_request_ci.get("jobs", [])
    } == {(name, "success") for name in a01_expected_jobs}
    and a01_post_merge_ci.get("workflowRun") == 31864544804
    and a01_post_merge_ci.get("headCommit")
        == "dad9ec6d27177699a1656b0a33ca23739ffb41ea"
    and a01_post_merge_ci.get("conclusion") == "success"
    and len(a01_post_merge_ci.get("jobs", [])) == 5
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a01_post_merge_ci.get("jobs", [])
    } == {(name, "success") for name in a01_expected_jobs}
    and a01_boundaries == {
        "productionDeploymentPerformed": False,
        "productionDataMutationPerformed": False,
        "deviceEvidenceClaimed": False,
        "pilotAuthorizationChanged": False,
        "distributionAuthorityChanged": False,
    }
    and len(a01_finding.get("requiredExitEvidence", [])) == 5
    and len(a01_finding.get("reArmTriggers", [])) == 3,
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
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
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
build9_approval_path = (
    ROOT / "release/approvals/build-number-9-rollover-approval.json"
)
build9_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-9.json"
)
build9_approval = data(
    "release/approvals/build-number-9-rollover-approval.json"
)
build9_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-9.json"
)
build10_approval_path = (
    ROOT / "release/approvals/build-number-10-rollover-approval.json"
)
build10_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-10.json"
)
build10_approval = data(
    "release/approvals/build-number-10-rollover-approval.json"
)
build10_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-10.json"
)
build11_approval_path = (
    ROOT / "release/approvals/build-number-11-rollover-approval.json"
)
build11_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-11.json"
)
build11_approval = data(
    "release/approvals/build-number-11-rollover-approval.json"
)
build11_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-11.json"
)
build12_approval_path = (
    ROOT / "release/approvals/build-number-12-successor-approval.json"
)
build12_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-12.json"
)
build12_approval = data(
    "release/approvals/build-number-12-successor-approval.json"
)
build12_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-12.json"
)
build13_approval_path = (
    ROOT / "release/approvals/build-number-13-successor-approval.json"
)
build13_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-13.json"
)
build13_approval = data(
    "release/approvals/build-number-13-successor-approval.json"
)
build13_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-13.json"
)
build14_approval_path = (
    ROOT / "release/approvals/build-number-14-successor-approval.json"
)
build14_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-14.json"
)
build14_approval = data(
    "release/approvals/build-number-14-successor-approval.json"
)
build14_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-14.json"
)
build15_approval_path = (
    ROOT / "release/approvals/build-number-15-successor-approval.json"
)
build15_environment_approval_path = (
    ROOT
    / "release/approvals/"
    / "public-repository-environment-reviewer-approval-build-15.json"
)
build15_approval = data(
    "release/approvals/build-number-15-successor-approval.json"
)
build15_environment_approval = data(
    "release/approvals/"
    "public-repository-environment-reviewer-approval-build-15.json"
)
build10_finalization_block_path = (
    ROOT / "release/evidence/build-10-finalization-block.json"
)
build10_finalization_block = data(
    "release/evidence/build-10-finalization-block.json"
)
build8_completion_path = (
    ROOT / "release/evidence/build-8-finalization-closure.json"
)
build8_completion = data(
    "release/evidence/build-8-finalization-closure.json"
)
build9_completion_path = (
    ROOT / "release/evidence/build-9-finalization-closure.json"
)
build9_completion = data(
    "release/evidence/build-9-finalization-closure.json"
)
build11_completion_path = (
    ROOT / "release/evidence/build-11-finalization-closure.json"
)
build11_completion = data(
    "release/evidence/build-11-finalization-closure.json"
)
build12_completion_path = (
    ROOT / "release/evidence/build-12-finalization-closure.json"
)
build12_completion = data(
    "release/evidence/build-12-finalization-closure.json"
)
build13_completion_path = (
    ROOT / "release/evidence/build-13-finalization-closure.json"
)
build13_completion = data(
    "release/evidence/build-13-finalization-closure.json"
)
build14_completion_path = (
    ROOT / "release/evidence/build-14-finalization-closure.json"
)
build14_completion = data(
    "release/evidence/build-14-finalization-closure.json"
)
pr265_backend_deployment_path = (
    ROOT / "release/evidence/pr265-backend-deployment-closure.json"
)
pr265_backend_deployment = data(
    "release/evidence/pr265-backend-deployment-closure.json"
)
build14_firestore_readback_path = (
    ROOT
    / "release/evidence/"
    / "build14-firestore-rules-indexes-live-readback.json"
)
build14_firestore_readback = data(
    "release/evidence/build14-firestore-rules-indexes-live-readback.json"
)
pr290_backend_deployment_path = (
    ROOT / "release/evidence/pr290-backend-deployment-closure.json"
)
pr290_backend_deployment = data(
    "release/evidence/pr290-backend-deployment-closure.json"
)
build15_firestore_readback_path = (
    ROOT
    / "release/evidence/"
    / "build15-firestore-rules-indexes-live-readback.json"
)
build15_firestore_readback = data(
    "release/evidence/build15-firestore-rules-indexes-live-readback.json"
)
build12_custody_reconciliation_path = (
    ROOT
    / "release/evidence/build-12-closure-custody-reconciliation.json"
)
build12_custody_reconciliation = data(
    "release/evidence/build-12-closure-custody-reconciliation.json"
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
build8_intermittent_promotion_path = (
    ROOT
    / "release/approvals/"
    / "build-8-f4-intermittent-connectivity-promotion.json"
)
build8_intermittent_promotion = data(
    "release/approvals/"
    "build-8-f4-intermittent-connectivity-promotion.json"
)
build8_intermittent_harness_path = (
    ROOT / "tools/release/Invoke-Build8F4IntermittentConnectivity.ps1"
)
build8_intermittent_harness = build8_intermittent_harness_path.read_text(
    encoding="utf-8"
)
build8_intermittent_doc_path = (
    ROOT
    / "docs/v4_2_r1/"
    / "BUILD8_F4_INTERMITTENT_CONNECTIVITY_PROMOTION.md"
)
build8_intermittent_doc = build8_intermittent_doc_path.read_text(
    encoding="utf-8"
)
build8_intermittent_result_path = (
    ROOT
    / "release/evidence/"
    / "build-8-f4-intermittent-connectivity-adjudication.json"
)
build8_intermittent_result = data(
    "release/evidence/"
    "build-8-f4-intermittent-connectivity-adjudication.json"
)
build8_intermittent_result_doc_path = (
    ROOT
    / "docs/v4_2_r1/"
    / "BUILD8_F4_INTERMITTENT_CONNECTIVITY_RESULT.md"
)
build8_intermittent_result_doc = build8_intermittent_result_doc_path.read_text(
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
build9_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 9
]
build9_entry = build9_entries[0] if len(build9_entries) == 1 else {}
build10_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 10
]
build10_entry = build10_entries[0] if len(build10_entries) == 1 else {}
build11_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 11
]
build11_entry = build11_entries[0] if len(build11_entries) == 1 else {}
build12_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 12
]
build12_entry = build12_entries[0] if len(build12_entries) == 1 else {}
build13_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 13
]
build13_entry = build13_entries[0] if len(build13_entries) == 1 else {}
build14_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 14
]
build14_entry = build14_entries[0] if len(build14_entries) == 1 else {}
build15_entries = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber") == 15
]
build15_entry = build15_entries[0] if len(build15_entries) == 1 else {}
check(
    "Builds 6-14 are preserved and Build 15 is source-authorized",
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
    and version_policy_approval.get("reference") == "BAF-REF-003-C14"
    and version_policy_approval.get("buildNumber") == 15
    and version_policy_approval.get("versionName") == "1.0.0-rc.5"
    and combined_policy.get("release", {}).get("buildNumber") == 15
    and combined_policy.get("release", {}).get("versionName") == "1.0.0-rc.5"
    and combined_policy.get("finalization", {}).get("status")
        == "pending-source-authorized"
    and sha(build14_completion_path)
        == combined_policy.get("finalization", {}).get(
            "priorCompletedBuild", {}
        ).get(
            "completionReceiptSha256"
        )
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("buildNumber") == 14
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("status") == "completed-non-distributable"
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("sourceCommit")
        == "f0d51819bfa4c81ad73b5d7f83675fa8b6a07b11"
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("githubRunId")
        == 32572743604
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("governedPackageSha256")
        == "496D990749A0658D73AEE4D908451424B185137F04EDFCA8B1C932195D994F2F"
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("dualCustodyCompleted")
        is True
    and combined_policy.get("finalization", {}).get(
        "priorCompletedBuild", {}
    ).get("runtimeValidationPassed")
        is False
    and combined_policy.get("finalization", {}).get("dualCustodyCompleted")
        is False
    and all(
        field not in combined_policy.get("finalization", {})
        for field in (
            "completionReceiptFile",
            "completionReceiptSha256",
            "sourceCommit",
            "githubRunId",
            "governedPackageSha256",
        )
    )
    and build12_completion.get("status") == "passed-non-distributable"
    and build12_completion.get("sourceAuthority", {}).get("commit")
        == "8ba5b237cef151b001d9bea41e16e68015091e43"
    and build12_completion.get("workflow", {}).get("runId") == 32088466492
    and build12_completion.get("governedPackage", {}).get("sha256")
        == "8BBDB5C6F6CB72243F426AB795C1ADA96F78C7C904512784332048C8A9B901CB"
    and build12_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    ) == "b705e33b68a1deaed0d2b71f88d024b8e8db1515"
    and build12_completion.get("dualCustody", {}).get("distinctVolumes")
        is True
    and build12_completion.get("runtimeAdjudication", {}).get(
        "liveAssetWorkflowValidationCompleted"
    ) is False
    and build12_completion.get("releaseBoundary", {}).get(
        "controlledPilotApproved"
    ) is False
    and build13_completion.get("status") == "passed-non-distributable"
    and build13_completion.get("sourceAuthority", {}).get("commit")
        == "59358123a7f1d9edf7a579b18d3e2407d8a1e48e"
    and build13_completion.get("workflow", {}).get("runId") == 32545733716
    and build13_completion.get("governedPackage", {}).get("sha256")
        == "C5BACE9A71F9490EDA41AD7BDFF7DF3FD223A8BA54A58AC00A3C0ECEF8DD0AE8"
    and build13_completion.get("runtimeAdjudication", {}).get("status")
        == "not-adjudicated-for-exact-build13"
    and build13_completion.get("runtimeAdjudication", {}).get(
        "runtimeValidationPassed"
    ) is False
    and build14_completion.get("status") == "passed-non-distributable"
    and build14_completion.get("sourceAuthority", {}).get("commit")
        == "f0d51819bfa4c81ad73b5d7f83675fa8b6a07b11"
    and build14_completion.get("sourceAuthority", {}).get("tree")
        == "627a8260231e834978c6f4b7445d76160b45964c"
    and build14_completion.get("sourceAuthority", {}).get(
        "pullRequestNumber"
    ) == 267
    and build14_completion.get("workflow", {}).get("runId") == 32572743604
    and build14_completion.get("githubArtifact", {}).get("id") == 9475994815
    and build14_completion.get("governedPackage", {}).get("sha256")
        == "496D990749A0658D73AEE4D908451424B185137F04EDFCA8B1C932195D994F2F"
    and build14_completion.get("governedPackage", {}).get(
        "independentVerificationCompleted"
    ) is True
    and build14_completion.get("remoteAuthority", {}).get(
        "reservationTagObjectSha"
    ) == "a9287d5f75cde41b44dffb5ee7e00aa0e54a680e"
    and build14_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    ) == "99fdbadd63c59c28906669fa10fac56cc98a6ee5"
    and build14_completion.get("dualCustody", {}).get("distinctVolumes")
        is True
    and build14_completion.get("recoveryIncident", {}).get("occurred")
        is False
    and build14_completion.get("runtimeAdjudication", {}).get(
        "runtimeValidationPassed"
    ) is False
    and build14_completion.get("releaseBoundary", {}).get(
        "controlledPilotApproved"
    ) is False
    and build12_custody_reconciliation.get("status") == "passed"
    and build12_custody_reconciliation.get("closureArchive", {}).get(
        "sha256"
    ) == "6E4F4512A5B90F2B58FED8AC0AEDAC4882E51960F74A66073DFCE0F6F78EF6D0"
    and len(combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", []
    )) == 1
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("buildNumber")
        == 10
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("status")
        == "blocked-non-distributable"
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("evidenceSha256")
        == sha(build10_finalization_block_path)
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("sourceCommit")
        == "e6bfa327466ffa99da9519846db7f83401c86c7b"
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("githubRunId")
        == 31545500587
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("dualCustodyCompleted")
        is False
    and combined_policy.get("finalization", {}).get(
        "historicalFailedAttempts", [{}]
    )[0].get("distributionPerformed")
        is False
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
    and combined_policy.get("distribution", {}).get("approved") is True
    and combined_policy.get("distribution", {}).get(
        "preservedHistoricalAuthority"
    ) is True
    and combined_policy.get("distribution", {}).get(
        "appliesToCurrentCandidate"
    ) is False
    and combined_policy.get("distribution", {}).get("approvedBuildNumber")
        == 11
    and combined_policy.get("distribution", {}).get("authority")
        == "exact-build11-sealed-small-group-pilot"
    and combined_policy.get("distribution", {}).get("approvedBuildNumber") == 11
    and combined_policy.get("distribution", {}).get("pilotHandoutPerformed")
        is False
    and combined_policy.get("distribution", {}).get(
        "unrestrictedPlantReleaseApproved"
    )
        is False
    and build9_completion.get("status") == "passed-non-distributable"
    and build9_completion.get("sourceAuthority", {}).get("commit")
        == "f51749c3f0200a5a03b065f0644d7759c747de7f"
    and build9_completion.get("sourceAuthority", {}).get(
        "pullRequestNumber"
    )
        == 196
    and build9_completion.get("workflow", {}).get("runId")
        == 31528293704
    and build9_completion.get("workflow", {}).get("actorId")
        == 213690022
    and build9_completion.get("governedPackage", {}).get("sha256")
        == "4D1EA1781FBAB0E047A1605644E329712E717B66A594147D55095DF21DF9960E"
    and build9_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    )
        == "e478de7b186112b864199a5bf0184d3c3d9ea584"
    and build9_completion.get("dualCustody", {}).get("distinctVolumes")
        is True
    and build9_completion.get("dualCustody", {}).get(
        "allFileHashesMatched"
    )
        is True
    and build9_completion.get("runtimeAdjudication", {}).get("status")
        == "failed-startup-non-distributable"
    and build9_completion.get("runtimeAdjudication", {}).get(
        "remediationPullRequest"
    )
        == 197
    and build9_completion.get("runtimeAdjudication", {}).get(
        "deviceDataPreserved"
    )
        is True
    and build9_completion.get("releaseBoundary", {}).get(
        "runtimeValidationPassed"
    )
        is False
    and build9_completion.get("releaseBoundary", {}).get(
        "distributionPerformed"
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
    and build8_entry.get("distributionPerformed") is False
    and sha(build9_approval_path)
        == "1AF2210730052C99F8AAA2A1A1D5E8C1D38646F0F7AF07A3444A0094778E3AE9"
    and build9_approval.get("approvalReference") == "BAF-REF-003-C8"
    and build9_approval.get("consumedBuild", {}).get("buildNumber") == 8
    and build9_approval.get("nextBuild", {}).get("buildNumber") == 9
    and build9_approval.get("requiredSource", {}).get(
        "integratedSuccessorPullRequest"
    ) == 193
    and build9_approval.get("requiredSource", {}).get(
        "integratedSuccessorMergeCommit"
    ) == "28cb22064511c1abcb76759cbb302a303427f46f"
    and build9_approval.get("requiredSource", {}).get(
        "postMergeGithubRunId"
    ) == 31512254539
    and build9_approval.get("controls", {}).get("inPlaceUpgradeRequired")
        is True
    and build9_approval.get("controls", {}).get("deviceDataClearProhibited")
        is True
    and build9_approval.get("distributionApproved") is False
    and sha(build9_environment_approval_path)
        == "D4E1CC724C44B95C19FF3A533A45D739AD095FAE86A60F86013DEFB623433926"
    and build9_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-005"
    and build9_environment_approval.get("scope", {}).get("buildNumber") == 9
    and build9_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and build9_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build9_entry.get("baselineCommit")
        == "28cb22064511c1abcb76759cbb302a303427f46f"
    and build9_entry.get("versionApprovalReference") == "BAF-REF-003-C8"
    and build9_entry.get("versionApprovalDocumentSha256")
        == sha(build9_approval_path)
    and build9_entry.get("remoteReservationTag")
        == "crm3-build-reserved/9"
    and build9_entry.get("remoteBuiltTag") == "crm3-build-built/9"
    and build9_entry.get("githubRunId") == 31528293704
    and build9_entry.get("remoteReservationTagObject")
        == "feef8824b6d1587789c1f51dc4446b6a4d7c1221"
    and build9_entry.get("remoteBuiltTagObject")
        == "e478de7b186112b864199a5bf0184d3c3d9ea584"
    and build9_entry.get("governedPackageSha256")
        == "4D1EA1781FBAB0E047A1605644E329712E717B66A594147D55095DF21DF9960E"
    and build9_entry.get("completionReceiptSha256")
        == sha(build9_completion_path)
    and build9_entry.get("closureFinalizationCompleted") is True
    and build9_entry.get("dualCustodyCompleted") is True
    and build9_entry.get("runtimeValidationPassed") is False
    and build9_entry.get("runtimeFailure")
        == "missing-crashlytics-gradle-build-identifier"
    and build9_entry.get("startupRemediationPullRequest") == 197
    and build9_entry.get("distributionPerformed") is False
    and sha(build10_approval_path)
        == "5086CFB2CBAE2E8A178B565FA93D9F8D9030620BDE608EB93D85BB48ED8231B0"
    and build10_approval.get("approvalReference") == "BAF-REF-003-C9"
    and build10_approval.get("consumedBuild", {}).get("buildNumber") == 9
    and build10_approval.get("nextBuild", {}).get("buildNumber") == 10
    and build10_approval.get("requiredSource", {}).get(
        "startupRemediationPullRequest"
    ) == 197
    and build10_approval.get("requiredSource", {}).get(
        "startupRemediationMergeCommit"
    ) == "1772fe1cf34c649c6a29d375c77b75e985b6c2f0"
    and build10_approval.get("requiredSource", {}).get(
        "postMergeGithubRunId"
    ) == 31538989781
    and build10_approval.get("controls", {}).get(
        "crashlyticsGradlePluginRequired"
    ) is True
    and build10_approval.get("controls", {}).get(
        "compiledCrashlyticsMappingIdRequired"
    ) is True
    and build10_approval.get("controls", {}).get(
        "exactReleaseApkColdStartCiRequired"
    ) is True
    and build10_approval.get("controls", {}).get("lr07Build9RearmRequired")
        is True
    and build10_approval.get("controls", {}).get("inPlaceUpgradeRequired")
        is True
    and build10_approval.get("controls", {}).get("deviceDataClearProhibited")
        is True
    and build10_approval.get("distributionApproved") is False
    and sha(build10_environment_approval_path)
        == "2463002F3FBA1A6F48E4A6CE45A0458A9DCF53C1ECCD7B655A4133709A408828"
    and build10_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-006"
    and build10_environment_approval.get("scope", {}).get("buildNumber")
        == 10
    and build10_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and build10_entry.get("status")
        == "remote-consumed-artifact-built-finalization-blocked-non-distributable"
    and build10_entry.get("baselineCommit")
        == "1772fe1cf34c649c6a29d375c77b75e985b6c2f0"
    and build10_entry.get("versionApprovalReference") == "BAF-REF-003-C9"
    and build10_entry.get("versionApprovalDocumentSha256")
        == sha(build10_approval_path)
    and build10_entry.get("remoteReservationTag")
        == "crm3-build-reserved/10"
    and build10_entry.get("remoteBuiltTag") == "crm3-build-built/10"
    and build10_entry.get("githubRunId") == 31545500587
    and build10_entry.get("remoteReservationTagObject")
        == "fd74fb34eef59f9ad47dc6cef7b2cd2b8beba7b2"
    and build10_entry.get("remoteReservationCommit")
        == "e6bfa327466ffa99da9519846db7f83401c86c7b"
    and build10_entry.get("githubArtifactId") == 9122790773
    and build10_entry.get("githubArtifactDigest")
        == "sha256:6c0a1012a432bb9bad80b81b192ce3ec0a55a3e019dada66b0c873c6787c31a6"
    and build10_entry.get("governedPackageSha256")
        == "F2FE9E997285C2BB544E3610EE1E89F52BC48E34BD3A982117D562C54A17E6DE"
    and build10_entry.get("independentPackageVerificationCompleted") is True
    and build10_entry.get("closureFinalizationCompleted") is False
    and build10_entry.get("dualCustodyCompleted") is False
    and build10_entry.get("remoteBuiltTagCreated") is False
    and build10_entry.get("finalizationEvidenceSha256")
        == sha(build10_finalization_block_path)
    and build10_entry.get("distributionPerformed") is False
    and build10_finalization_block.get("decision")
        == "BUILD10_CONSUMED_FINALIZATION_BLOCKED_NON_DISTRIBUTABLE"
    and build10_finalization_block.get("finalization", {}).get("status")
        == "blocked-non-distributable"
    and build10_finalization_block.get("finalization", {}).get(
        "dualCustodyCompleted"
    ) is False
    and build10_finalization_block.get("finalization", {}).get(
        "builtTagCreated"
    ) is False
    and build10_finalization_block.get("finalization", {}).get(
        "distributionPerformed"
    ) is False
    and sha(build11_approval_path)
        == "9AC12BEF69FB8DB48ED974F557CB25A93B35010487782DBBA627F34D2E397DEE"
    and build11_approval.get("approvalReference") == "BAF-REF-003-C10"
    and build11_approval.get("consumedBuild", {}).get("buildNumber") == 10
    and build11_approval.get("nextBuild", {}).get("buildNumber") == 11
    and build11_approval.get("requiredSource", {}).get(
        "environmentAuthorityPullRequest"
    ) == 198
    and build11_approval.get("requiredSource", {}).get(
        "environmentAuthorityMergeCommit"
    ) == "e6bfa327466ffa99da9519846db7f83401c86c7b"
    and build11_approval.get("requiredSource", {}).get(
        "build10FinalizationEvidenceSha256"
    ) == sha(build10_finalization_block_path)
    and build11_approval.get("controls", {}).get(
        "environmentAuthorityRequired"
    ) is True
    and build11_approval.get("controls", {}).get("lr07Build10RearmRequired")
        is True
    and build11_approval.get("distributionApproved") is False
    and sha(build11_environment_approval_path)
        == "47C598A3F15F5D84676A1CC645BE39636AA39A713B1B0B6B9E03F9EB81019BC6"
    and build11_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-007"
    and build11_environment_approval.get("scope", {}).get("buildNumber")
        == 11
    and build11_environment_approval.get("controls", {}).get(
        "requiredIntegratedMergeCommit"
    ) == build11_approval.get("requiredSource", {}).get(
        "environmentAuthorityMergeCommit"
    )
    and build11_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and build11_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build11_entry.get("baselineCommit")
        == "e6bfa327466ffa99da9519846db7f83401c86c7b"
    and build11_entry.get("versionApprovalReference") == "BAF-REF-003-C10"
    and build11_entry.get("versionApprovalDocumentSha256")
        == sha(build11_approval_path)
    and build11_entry.get("remoteReservationTag")
        == "crm3-build-reserved/11"
    and build11_entry.get("remoteBuiltTag") == "crm3-build-built/11"
    and build11_entry.get("githubRunId") == 31552161470
    and build11_entry.get("githubArtifactId") == 9125100777
    and build11_entry.get("remoteReservationTagObject")
        == "2c39c96650fbe3b7b7f0d4c95a63736e736fed67"
    and build11_entry.get("remoteBuiltTagObject")
        == "ed33b3f48d9bd10b23c88025eaa567ae235d970c"
    and build11_entry.get("governedPackageSha256")
        == "104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970"
    and build11_entry.get("closureFinalizationCompleted") is True
    and build11_entry.get("dualCustodyCompleted") is True
    and build11_entry.get("runtimeValidationPassed") is True
    and build11_entry.get("distributionPerformed") is False
    and build11_completion.get("sourceAuthority", {}).get("commit")
        == "ca65d3deead23cccdf07ca24255bc073221d84db"
    and build11_completion.get("workflow", {}).get("runId") == 31552161470
    and build11_completion.get("remoteAuthority", {}).get(
        "builtTagObjectSha"
    ) == "ed33b3f48d9bd10b23c88025eaa567ae235d970c"
    and build11_completion.get("runtimeAdjudication", {}).get("status")
        == "passed-two-target-in-place"
    and build11_completion.get("releaseBoundary", {}).get(
        "distributionPerformed"
    ) is False
    and sha(build12_approval_path)
        == "E7E0F289A99B062F8EECDFCDE944B9C4266F58F00542C34AF49FBB7834469985"
    and sha(build15_approval_path)
        == combined_policy.get("versionPolicy", {}).get(
            "sourceDocumentSha256"
        )
    and build12_approval.get("approvalReference") == "BAF-REF-003-C11"
    and build12_approval.get("consumedBuild", {}).get("buildNumber") == 11
    and build12_approval.get("nextBuild", {}).get("buildNumber") == 12
    and build12_approval.get("nextBuild", {}).get("versionName")
        == "1.0.0-rc.2"
    and build12_approval.get("requiredSource", {}).get(
        "successorFreezeBaselineCommit"
    ) == "b020dc639cd0b69bf09808de9f6a750cde38259c"
    and build12_approval.get("requiredSource", {}).get(
        "successorFreezeBaselineTree"
    ) == "a65ff08db541bea2aa72c6930ead60b430028eea"
    and build12_approval.get("requiredSource", {}).get(
        "successorFreezePostMergeGithubRunId"
    ) == 32062710341
    and build12_approval.get("controls", {}).get("successorFreezeRequired")
        is True
    and build12_approval.get("controls", {}).get(
        "build11AuthorityPreserved"
    ) is True
    and build12_approval.get("controls", {}).get("inPlaceUpgradeRequired")
        is True
    and build12_approval.get("controls", {}).get("deviceDataClearProhibited")
        is True
    and build12_approval.get("distributionApproved") is False
    and sha(build12_environment_approval_path)
        == "552C8A34CEED2A4AFCD71B3521BF8547807761E59537CBA6D87257747638E1DB"
    and sha(build15_environment_approval_path)
        == combined_policy.get("github", {})
        .get("environmentReviewControl", {})
        .get("approvalReceiptSha256")
    and build12_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-008"
    and build12_environment_approval.get("scope", {}).get("buildNumber")
        == 12
    and build12_environment_approval.get("controls", {}).get(
        "requiredSuccessorFreezeCommit"
    ) == build12_approval.get("requiredSource", {}).get(
        "successorFreezeBaselineCommit"
    )
    and build12_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and build12_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build12_entry.get("baselineCommit")
        == "b020dc639cd0b69bf09808de9f6a750cde38259c"
    and build12_entry.get("versionApprovalReference") == "BAF-REF-003-C11"
    and build12_entry.get("versionApprovalDocumentSha256")
        == sha(build12_approval_path)
    and build12_entry.get("remoteReservationTag")
        == "crm3-build-reserved/12"
    and build12_entry.get("remoteBuiltTag") == "crm3-build-built/12"
    and build12_entry.get("githubRunId") == 32088466492
    and build12_entry.get("githubArtifactId") == 9307950694
    and build12_entry.get("remoteReservationTagObject")
        == "db8e0c347ad7278ef1ac83d4880f29ae5832274a"
    and build12_entry.get("remoteBuiltTagObject")
        == "b705e33b68a1deaed0d2b71f88d024b8e8db1515"
    and build12_entry.get("governedPackageSha256")
        == "8BBDB5C6F6CB72243F426AB795C1ADA96F78C7C904512784332048C8A9B901CB"
    and build12_entry.get("completionReceiptSha256")
        == sha(build12_completion_path)
    and build12_entry.get("dualCustodyCompleted") is True
    and build12_entry.get("runtimeValidationPassed") is True
    and build12_entry.get("fullBusinessFlowValidationCompleted") is False
    and build12_entry.get("controlledPilotApproved") is False
    and build12_entry.get("distributionPerformed") is False
    and sha(build13_approval_path)
        == "77C9B4168A9149E1C31205703B0346249C2D415C3DEB9B072DAA627337D62E2C"
    and sha(build13_environment_approval_path)
        == "8F72AE608238339DE5743A234FF69820C0F176D6416BD18C71E52C6493953FF1"
    and build13_approval.get("approvalReference") == "BAF-REF-003-C12"
    and build13_approval.get("sourceBaseline", {}).get("commit")
        == "5f4391b26b540524076eebd4488eb0685952e535"
    and build13_approval.get("sourceBaseline", {}).get("tree")
        == "c440a82470bfaf22677f6a2305e8ea8bd5ce0796"
    and build13_approval.get("consumedBuild", {}).get("buildNumber") == 12
    and build13_approval.get("nextBuild", {}).get("buildNumber") == 13
    and build13_approval.get("controls", {}).get(
        "deviceDataClearProhibited"
    ) is True
    and build13_approval.get("distributionApproved") is False
    and build13_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-009"
    and build13_environment_approval.get("scope", {}).get("buildNumber")
        == 13
    and build13_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and build13_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build13_entry.get("baselineCommit")
        == "5f4391b26b540524076eebd4488eb0685952e535"
    and build13_entry.get("versionApprovalReference") == "BAF-REF-003-C12"
    and build13_entry.get("versionApprovalDocumentSha256")
        == sha(build13_approval_path)
    and build13_entry.get("remoteReservationTag")
        == "crm3-build-reserved/13"
    and build13_entry.get("remoteBuiltTag") == "crm3-build-built/13"
    and build13_entry.get("githubRunId") == 32545733716
    and build13_entry.get("githubArtifactId") == 9468702427
    and build13_entry.get("governedPackageSha256")
        == "C5BACE9A71F9490EDA41AD7BDFF7DF3FD223A8BA54A58AC00A3C0ECEF8DD0AE8"
    and build13_entry.get("completionReceiptSha256")
        == sha(build13_completion_path)
    and build13_entry.get("dualCustodyCompleted") is True
    and build13_entry.get("runtimeValidationPassed") is False
    and build13_entry.get("distributionPerformed") is False
    and sha(build14_approval_path)
        == "3F1972E1A911D86055C6350917128A34CE25239A9E63924B98EC217F7F76FF4E"
    and sha(build14_environment_approval_path)
        == "C0D1FBF081A7EDF7F6BE982317589B8D51F64963F57ABB12BDDFE43A8EFA50F3"
    and build14_approval.get("approvalReference") == "BAF-REF-003-C13"
    and build14_approval.get("sourceBaseline", {}).get("commit")
        == "e565c4d4fccf9556c90b72bda396786875c3ddd9"
    and build14_approval.get("sourceBaseline", {}).get("tree")
        == "f63358c926c0538177c770995f963f52e3628c77"
    and build14_approval.get("consumedBuild", {}).get("buildNumber") == 13
    and build14_approval.get("nextBuild", {}).get("buildNumber") == 14
    and build14_approval.get("controls", {}).get("deviceDataClearProhibited")
        is True
    and build14_approval.get("controls", {}).get(
        "exactFunctionFleetDeploymentVerified"
    ) is True
    and build14_approval.get("controls", {}).get(
        "exactFirestoreRulesIndexesDeploymentReadbackRequired"
    ) is True
    and sha(pr290_backend_deployment_path)
        == combined_policy.get("finalization", {}).get(
            "exactFunctionFleetDeploymentReceiptSha256"
        )
    and sha(pr265_backend_deployment_path)
        == build14_approval.get("requiredSource", {}).get(
            "exactFunctionFleetDeploymentReceiptSha256"
        )
    and pr265_backend_deployment.get("decision")
        == "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK"
    and pr265_backend_deployment.get("sourceAuthority", {}).get("commit")
        == "e565c4d4fccf9556c90b72bda396786875c3ddd9"
    and pr265_backend_deployment.get("deployment", {}).get("functionCount")
        == 15
    and pr265_backend_deployment.get("deployment", {}).get(
        "allFunctionsExactSourceVerified"
    ) is True
    and pr265_backend_deployment.get("controlBoundary", {}).get(
        "productionBusinessDataMutated"
    ) is False
    and build14_approval.get("distributionApproved") is False
    and build14_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-010"
    and build14_environment_approval.get("scope", {}).get("buildNumber")
        == 14
    and build14_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and build14_entry.get("status")
        == "remote-consumed-artifact-built-finalized-non-distributable"
    and build14_entry.get("baselineCommit")
        == "e565c4d4fccf9556c90b72bda396786875c3ddd9"
    and build14_entry.get("versionApprovalReference") == "BAF-REF-003-C13"
    and build14_entry.get("versionApprovalDocumentSha256")
        == sha(build14_approval_path)
    and build14_entry.get("remoteReservationTag")
        == "crm3-build-reserved/14"
    and build14_entry.get("remoteBuiltTag") == "crm3-build-built/14"
    and build14_entry.get("remoteReservationTagObject")
        == "a9287d5f75cde41b44dffb5ee7e00aa0e54a680e"
    and build14_entry.get("remoteBuiltTagObject")
        == "99fdbadd63c59c28906669fa10fac56cc98a6ee5"
    and build14_entry.get("remoteBuiltCommit")
        == "f0d51819bfa4c81ad73b5d7f83675fa8b6a07b11"
    and build14_entry.get("githubRunId") == 32572743604
    and build14_entry.get("githubArtifactId") == 9475994815
    and build14_entry.get("governedPackageSha256")
        == "496D990749A0658D73AEE4D908451424B185137F04EDFCA8B1C932195D994F2F"
    and build14_entry.get("completionReceiptSha256")
        == sha(build14_completion_path)
    and build14_entry.get("dualCustodyCompleted") is True
    and build14_entry.get("runtimeValidationPassed") is False
    and build14_entry.get("controlledPilotApproved") is False
    and build14_entry.get("distributionPerformed") is False
    and sha(build15_approval_path)
        == "B778676C5F7B3D815D054C1B11B2BBBFCFAE3DF5A75EF255075A278CF11596C1"
    and sha(build15_environment_approval_path)
        == "E2F54E234B88C02EDE7938E40B3E9694A183633D763B8833232C199378BED7C2"
    and build15_approval.get("approved") is True
    and build15_approval.get("approvalReference") == "BAF-REF-003-C14"
    and build15_approval.get("sourceBaseline", {}).get("commit")
        == "2c979435c3b977f040efb2cab05c3021cfe7cfb5"
    and build15_approval.get("consumedBuild", {}).get("buildNumber") == 14
    and build15_approval.get("nextBuild", {}).get("buildNumber") == 15
    and build15_approval.get("nextBuild", {}).get("versionName")
        == "1.0.0-rc.5"
    and build15_approval.get("controls", {}).get("deviceDataClearProhibited")
        is True
    and build15_approval.get("controls", {}).get("build14AuthorityPreserved")
        is True
    and build15_approval.get("controls", {}).get("build11PilotAuthorityPreserved")
        is True
    and build15_approval.get("distributionApproved") is False
    and build15_environment_approval.get("approvalReference")
        == "BAF-GH-ENV-011"
    and build15_environment_approval.get("scope", {}).get("buildNumber")
        == 15
    and build15_environment_approval.get("liveStateEvidence", {}).get(
        "canAdminsBypass"
    ) is False
    and sha(pr290_backend_deployment_path)
        == build15_approval.get("requiredSource", {}).get(
            "exactFunctionFleetDeploymentReceiptSha256"
        )
    and pr290_backend_deployment.get("decision")
        == "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK"
    and pr290_backend_deployment.get("sourceAuthority", {}).get("commit")
        == "2c979435c3b977f040efb2cab05c3021cfe7cfb5"
    and pr290_backend_deployment.get("deployment", {}).get("functionCount")
        == 15
    and pr290_backend_deployment.get("deployment", {}).get(
        "allFunctionsExactSourceVerified"
    ) is True
    and pr290_backend_deployment.get("controlBoundary", {}).get(
        "productionBusinessDataMutated"
    ) is False
    and len(build15_entries) == 1
    and build15_entry.get("status")
        == "source-reserved-awaiting-remote-consumption"
    and build15_entry.get("baselineCommit")
        == "2c979435c3b977f040efb2cab05c3021cfe7cfb5"
    and build15_entry.get("versionApprovalReference") == "BAF-REF-003-C14"
    and build15_entry.get("versionApprovalDocumentSha256")
        == sha(build15_approval_path)
    and build15_entry.get("remoteReservationTag")
        == "crm3-build-reserved/15"
    and build15_entry.get("remoteBuiltTag") == "crm3-build-built/15"
    and all(
        field not in build15_entry
        for field in (
            "remoteReservationTagObject",
            "remoteBuiltTagObject",
            "remoteBuiltCommit",
            "githubRunId",
            "githubArtifactId",
            "governedPackageSha256",
            "completionReceiptFile",
        )
    ),
)
build15_firestore_authority = combined_policy.get("finalization", {}).get(
    "exactFirestoreRulesIndexesLiveReadback", {}
)
check(
    "Build 15 Firestore Rules and indexes are exact on merged production main",
    build15_firestore_authority.get("verified") is True
    and sha(build14_firestore_readback_path)
        == "7E1D7ACC72ED094A03691D1AEB5D59AC9E576D3DFE6B6CE595B355DD71595B8D"
    and canonical_receipt_sha(build14_firestore_readback)
        == build14_firestore_readback.get("receiptSha256")
    and sha(build15_firestore_readback_path)
        == build15_firestore_authority.get("receiptFileSha256")
    and build15_firestore_readback.get("receiptSha256")
        == build15_firestore_authority.get("receiptCanonicalSha256")
    and canonical_receipt_sha(build15_firestore_readback)
        == build15_firestore_readback.get("receiptSha256")
    and build15_firestore_readback.get("evidenceType")
        == "firestore-rules-indexes-live-readback"
    and build15_firestore_readback.get("mode") == "STRICT"
    and build15_firestore_readback.get("projectId")
        == "crm3-baf-ops-b8638"
    and build15_firestore_readback.get("decision")
        == "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK"
    and build15_firestore_readback.get("failedChecks") == []
    and all(
        value is True
        for value in build15_firestore_readback.get("checks", {}).values()
    )
    and build15_firestore_readback.get("source", {}).get("before", {}).get(
        "branch"
    )
        == "main"
    and build15_firestore_readback.get("source", {}).get("before", {}).get(
        "commit"
    )
        == build15_firestore_authority.get("sourceCommit")
    and build15_firestore_readback.get("source", {}).get("before", {}).get(
        "tree"
    )
        == build15_firestore_authority.get("sourceTree")
    and build15_firestore_readback.get("source", {}).get("before", {}).get(
        "originMain"
    )
        == build15_firestore_authority.get("sourceCommit")
    and build15_firestore_readback.get("source", {}).get("after", {}).get(
        "commit"
    )
        == build15_firestore_authority.get("sourceCommit")
    and build15_firestore_readback.get("outputs", {}).get("rules", {}).get(
        "sourceSha256"
    )
        == build15_firestore_authority.get("rulesSha256")
        == build15_approval.get("requiredSource", {}).get(
            "exactFirestoreRulesSha256"
        )
        == sha(ROOT / "firestore.rules")
    and build15_firestore_readback.get("outputs", {}).get("rules", {}).get(
        "activeSha256"
    )
        == build15_firestore_authority.get("rulesSha256")
    and build15_firestore_readback.get("outputs", {}).get("rules", {}).get(
        "byteExact"
    )
        is True
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "sourceCount"
    )
        == build15_firestore_authority.get("indexCount")
        == build15_approval.get("requiredSource", {}).get(
            "exactFirestoreIndexCount"
        )
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "cliCount"
    )
        == build15_firestore_authority.get("indexCount")
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "apiCount"
    )
        == build15_firestore_authority.get("indexCount")
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "apiReadyCount"
    )
        == build15_firestore_authority.get("indexCount")
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "sourceSetSha256"
    )
        == build15_firestore_authority.get("indexSetSha256")
        == build15_approval.get("requiredSource", {}).get(
            "exactFirestoreIndexSetSha256"
        )
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "cliSetSha256"
    )
        == build15_firestore_authority.get("indexSetSha256")
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "apiSetSha256"
    )
        == build15_firestore_authority.get("indexSetSha256")
    and build15_firestore_readback.get("outputs", {}).get("indexes", {}).get(
        "allApiIndexesReady"
    )
        is True
    and build15_firestore_authority.get("allIndexesReady") is True
    and build15_firestore_authority.get("redundantDeploymentPerformed")
        is False
    and all(
        value is False
        for value in build15_firestore_readback.get(
            "mutationBoundary", {}
        ).values()
    )
    and combined_policy.get("knownOpenGates")
        == [
            "BUILD15_PRODUCTION_SIGNED_FINALIZATION",
            "BUILD15_SIGNED_DEVICE_MIGRATION_AND_BUSINESS_FLOW_VALIDATION",
            "BUILD15_EXPLICIT_PILOT_PROMOTION",
        ],
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
        == "73295B13B7DC7C476A7F094B779A58DF5B3491B32DB4E349A2CDD5C695BC7096"
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
    and build8_f4_gate_records[0].get("currentStatus") == "CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
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
    and build8_f4_gate_records[0].get("currentStatus") == "CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
)
check(
    "Build 8 intermittent-connectivity source is exact, bounded and non-closing",
    sha(build8_intermittent_promotion_path)
        == "D840BA1D4BB290C21F002D70333D77DB35E641CA007EA0D2B7190877498EAA14"
    and sha(build8_intermittent_harness_path)
        == "EFC2DBF0232804C6C3E5754BD2D38AA22E5770E2410EAA2322866F171648880A"
    and sha(build8_intermittent_doc_path)
        == "5C25B3B1226EFD17B7AAEC7041D39D4E4872EF4CD5B43B5DAEA132B8592F4B98"
    and build8_intermittent_promotion.get("approved") is True
    and build8_intermittent_promotion.get("approvalClass")
        == "CONTROLLED_EXACT_TARGET_BUILD8_INTERMITTENT_CONNECTIVITY"
    and build8_intermittent_promotion.get("approvalAuthority", {}).get(
        "baselineCommit"
    )
        == "de76c8e67e7e3693d12b6965f1d0589a9b1a7a50"
    and build8_intermittent_promotion.get("approvalAuthority", {}).get(
        "baselineTree"
    )
        == "80fa29d2bf165f918b0adee0fcc8d2d8bbe2964d"
    and "five-job"
        in build8_intermittent_promotion.get("effectiveCondition", "")
    and build8_intermittent_promotion.get("offlineAuthority", {}).get(
        "adjudicationSha256"
    )
        == sha(build8_offline_result_path)
    and build8_intermittent_promotion.get("offlineAuthority", {}).get(
        "externalReceiptSha256"
    )
        == build8_offline_result.get("externalReceipt", {}).get("sha256")
    and build8_intermittent_promotion.get("offlineAuthority", {}).get(
        "externalReceiptBytes"
    )
        == build8_offline_result.get("externalReceipt", {}).get("bytes")
    and build8_intermittent_promotion.get("artifactAuthority", {})
        .get("apk", {})
        .get("versionCode")
        == 8
    and build8_intermittent_promotion.get("intermittentProfile", {}).get(
        "cycleCount"
    )
        == 3
    and build8_intermittent_promotion.get("intermittentProfile", {}).get(
        "minimumDisconnectedHoldSecondsPerCycle"
    )
        == 5
    and build8_intermittent_promotion.get("intermittentProfile", {}).get(
        "minimumRestoredHoldSecondsPerCycle"
    )
        == 10
    and build8_intermittent_promotion.get("intermittentProfile", {}).get(
        "maximumProfileSeconds"
    )
        == 300
    and build8_intermittent_promotion.get(
        "durationBoundControlledStopAmendment", {}
    ).get("priorPromotionSha256")
        == "2EFA140B00BBC1D0FD6901026A4781FC2862C3C8C1DB9C19BB5EADE23520DB23"
    and build8_intermittent_promotion.get(
        "durationBoundControlledStopAmendment", {}
    ).get("externalFailureReceipt", {}).get("sha256")
        == "C2104E26DA8C827DC4743CCCF5586F036B26FAB79041F00AFE31B0F6DA9F0435"
    and build8_intermittent_promotion.get(
        "durationBoundControlledStopAmendment", {}
    ).get("externalFailureReceipt", {}).get("bytes")
        == 820
    and build8_intermittent_promotion.get(
        "durationBoundControlledStopAmendment", {}
    ).get("observedResult", {}).get("completedCycles")
        == 3
    and build8_intermittent_promotion.get(
        "durationBoundControlledStopAmendment", {}
    ).get("observedResult", {}).get("profileDurationSeconds")
        == 233.35
    and build8_intermittent_promotion.get(
        "durationBoundControlledStopAmendment", {}
    ).get("observedResult", {}).get("exactTransportStateRestored")
        is True
    and all(
        value is False
        for value in build8_intermittent_promotion.get(
            "durationBoundControlledStopAmendment", {}
        ).get("authorityExpansion", {}).values()
    )
    and build8_intermittent_promotion.get("intermittentProfile", {}).get(
        "restoreAndReadBackAfterEveryCycle"
    )
        is True
    and build8_intermittent_promotion.get("authorizedMutations", {}).get(
        "wifiAndMobileData"
    )
        == "THREE_TEMPORARY_DISABLE_AND_EXACT_RESTORE_CYCLES"
    and build8_intermittent_promotion.get("authorizedMutations", {}).get(
        "preflightOnly"
    )
        == "READ_ONLY_NO_TRANSPORT_MUTATION"
    and build8_intermittent_promotion.get("authorizedMutations", {}).get(
        "bandwidthLatencyPacketLossInjection"
    )
        == "PROHIBITED_NOT_THIS_METHOD"
    and build8_intermittent_promotion.get("authorizedMutations", {}).get(
        "userApprovalRevocationOrRoleMutation"
    )
        == "PROHIBITED"
    and build8_intermittent_promotion.get("programmeBoundary", {}).get(
        "intermittentConnectivityAuthorized"
    )
        is True
    and build8_intermittent_promotion.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build8_intermittent_promotion.get("programmeBoundary", {}).get(
        "revocationAuthorized"
    )
        is False
    and build8_intermittent_promotion.get("programmeBoundary", {}).get(
        "wrongRoleExecutionAuthorized"
    )
        is False
    and all(
        marker in build8_intermittent_harness
        for marker in [
            "Post-merge release-gate must contain exactly five successful jobs.",
            "Android emulator app-shell integration (not physical-device evidence)",
            "External offline receipt SHA-256",
            "External controlled-stop receipt SHA-256",
            "Controlled-stop observed profile duration",
            "PASS_BUILD8_F4_INTERMITTENT_CONNECTIVITY_PREFLIGHT_READ_ONLY",
            "FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED",
            "TRANSPORT_RESTORATION_FAILED",
            "INTERMITTENT_PROFILE_DURATION_EXCEEDED",
            "FAIL_BUILD8_INTERMITTENT_CONNECTIVITY_REQUIRES_ADJUDICATION",
            "PASS_BUILD8_F4_BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY_RECOVERY",
            "stage2dF4Status = 'OPEN'",
            "stage2dF4ClosureAuthorized = $false",
            "bandwidthThrottleClaimAuthorized = $false",
            "priorFailureReceiptSha256 = Get-Sha256 $priorFailureReceiptFile",
            "cycleDurationSeconds = $cycleDurationSeconds",
            "rawUiRetained = $false",
        ]
    )
    and build8_intermittent_harness.count("Set-TransportState") >= 3
    and all(
        marker not in build8_intermittent_harness.lower()
        for marker in [
            "'pm', 'clear'",
            "'uninstall'",
            "firebase deploy",
            "appdistribution:distribute",
            "'svc', 'airplane'",
            " tc qdisc ",
        ]
    )
    and "Status: SOURCE AUTHORIZED; PHYSICAL EXECUTION PENDING"
        in build8_intermittent_doc
    and "does not claim low bandwidth" in build8_intermittent_doc
    and "233.35-second profile exceeded" in build8_intermittent_doc
    and "raises only the total ceiling to 300 seconds"
        in build8_intermittent_doc
    and "Revocation and wrong-role evidence remain separate"
        in build8_intermittent_doc
    and len(build8_f4_gate_records) == 1
    and build8_f4_gate_records[0].get("currentStatus") == "CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
)
check(
    "Build 8 intermittent connectivity is evidence-proved without throttle overclaim",
    sha(build8_intermittent_result_path)
        == "45B90B3F0C3D711FEA82B3514669B0C25FEDD2EF320AF4872EC8B102535678F6"
    and sha(build8_intermittent_result_doc_path)
        == "6C34809BAC4CE025D19CCBF9A52AC4B519E3CC977ABA81E34110B467FCF417B6"
    and build8_intermittent_result.get("decision")
        == "PASS_BUILD8_F4_INTERMITTENT_CONNECTIVITY_ADJUDICATED"
    and build8_intermittent_result.get("externalReceipt", {}).get("sha256")
        == "4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC"
    and build8_intermittent_result.get("externalReceipt", {}).get("bytes")
        == 8119
    and build8_intermittent_result.get("externalReceipt", {}).get(
        "promotionSha256"
    )
        == sha(build8_intermittent_promotion_path)
    and build8_intermittent_result.get("externalReceipt", {}).get(
        "sourceCommit"
    )
        == build8_intermittent_result.get("externalReceipt", {}).get(
            "sourceOriginMain"
        )
    and build8_intermittent_result.get("externalReceipt", {}).get(
        "postMergeRunId"
    )
        == 31030200224
    and build8_intermittent_result.get("externalReceipt", {}).get("decision")
        == "PASS_BUILD8_F4_BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY_RECOVERY"
    and build8_intermittent_result.get("prerequisiteLineage", {}).get(
        "offlineAdjudicationSha256"
    )
        == sha(build8_offline_result_path)
    and build8_intermittent_result.get("prerequisiteLineage", {}).get(
        "controlledStopFailureReceiptSha256"
    )
        == "C2104E26DA8C827DC4743CCCF5586F036B26FAB79041F00AFE31B0F6DA9F0435"
    and build8_intermittent_result.get("prerequisiteLineage", {}).get(
        "controlledStopFailureReceiptRelabelled"
    )
        is False
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "fiveJobPostMergeReleaseGatePassed"
    )
        is True
    and build8_intermittent_result.get("verifiedFacts", {}).get("cycleCount")
        == 3
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "requiredCycleCount"
    )
        == 3
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "profileDurationSeconds"
    )
        == 234.083
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "maximumProfileSeconds"
    )
        == 300
    and [
        cycle.get("cycle")
        for cycle in build8_intermittent_result.get("verifiedFacts", {}).get(
            "cycles", []
        )
    ]
        == [1, 2, 3]
    and all(
        cycle.get("allTransportsDisabled") is True
        and cycle.get("disconnectedManualSyncOutcome")
        == "TIMEOUT_WITHOUT_SUCCESS_MARKER"
        and cycle.get("falseSuccessObserved") is False
        and cycle.get("exactTransportStateRestored") is True
        and cycle.get("restoredWifiOn") == 1
        and cycle.get("restoredMobileDataOn") == 0
        and cycle.get("restoredAirplaneModeOn") == 0
        and cycle.get("reconnectSyncOutcome") == "SUCCESS"
        and cycle.get("pendingLocalBusinessWritesAfter") == 0
        and cycle.get("unresolvedLocalRejectionsAfter") == 0
        for cycle in build8_intermittent_result.get("verifiedFacts", {}).get(
            "cycles", []
        )
    )
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "everyCycleRestoredExactly"
    )
        is True
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "everyCycleRecoveredSync"
    )
        is True
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "falseSuccessObserved"
    )
        is False
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "pendingLocalBusinessWritesAfter"
    )
        == 0
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "unresolvedLocalRejectionsAfter"
    )
        == 0
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "failureReceiptPresent"
    )
        is False
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "retainedReceiptCount"
    )
        == 1
    and build8_intermittent_result.get("verifiedFacts", {}).get(
        "temporaryArtifactCountAfterExecution"
    )
        == 0
    and build8_intermittent_result.get("executionBoundary", {}).get(
        "networkStateTemporarilyChanged"
    )
        is True
    and build8_intermittent_result.get("executionBoundary", {}).get(
        "exactNetworkStateRestored"
    )
        is True
    and all(
        value is False
        for key, value in build8_intermittent_result.get(
            "executionBoundary", {}
        ).items()
        if key
        not in {
            "networkStateTemporarilyChanged",
            "exactNetworkStateRestored",
        }
    )
    and all(
        value is False
        for value in build8_intermittent_result.get(
            "privacyBoundary", {}
        ).values()
    )
    and build8_intermittent_result.get("methodQualification", {}).get(
        "acceptedGateMethod"
    )
        == "BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY"
    and build8_intermittent_result.get("methodQualification", {}).get(
        "weakNetworkCriterionClaim"
    )
        == "PROVED_BY_ACCEPTED_INTERMITTENT_METHOD"
    and build8_intermittent_result.get("methodQualification", {}).get(
        "measuredLowBandwidth"
    )
        is False
    and build8_intermittent_result.get("methodQualification", {}).get(
        "addedLatency"
    )
        is False
    and build8_intermittent_result.get("methodQualification", {}).get(
        "injectedPacketLoss"
    )
        is False
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "stage2dF4Status"
    )
        == "OPEN"
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "weakNetworkCriterionProved"
    )
        is True
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "revocationCriterionProved"
    )
        is False
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "wrongRoleCriterionProved"
    )
        is False
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    )
        is False
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "p07ClosureAuthorized"
    )
        is False
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    )
        is False
    and build8_intermittent_result.get("programmeBoundary", {}).get(
        "distributionAuthorized"
    )
        is False
    and "Status: INTERMITTENT CONNECTIVITY PROVED; F4 REMAINS OPEN"
        in build8_intermittent_result_doc
    and "does not claim measured low bandwidth"
        in build8_intermittent_result_doc
    and "bandwidth-throttling result."
        in build8_intermittent_result_doc
    and "Revocation next-operation denial and"
        in build8_intermittent_result_doc
    and len(build8_f4_gate_records) == 1
    and build8_f4_gate_records[0].get("currentStatus") == "CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
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
    and build7_f4_gate.get("currentStatus") == "CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED",
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
    and f4_rehearsal_gate.get("currentStatus") == "CLOSED"
    and any(
        entry.get("sha256")
            == "9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461"
        for entry in f4_rehearsal_gate.get("evidence", [])
    )
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
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
    and f4_rehearsal_gate.get("currentStatus") == "CLOSED"
    and any(
        entry.get("sha256")
            == "9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461"
        for entry in f4_rehearsal_gate.get("evidence", [])
    )
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
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
    len(exported_callable_occurrences) == len(exported_callable_names) == 9
    and set(exported_callable_names) == set(callable_classification)
    and len(callable_names) == 7
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
    ) == 6
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
    and "const REQUIRED_ABNORMALITY_FIELDS = [...ABNORMALITY_FIELDS].filter("
        in s07_source
    and '(field) => field !== "_globalPullServerUpdatedAt"'
        in s07_source
    and "!validServerTimestamp(data._globalPullServerUpdatedAt)"
        in s07_source
    and "const after: UserAuthorityJsonMap = {...existing};"
        in s07_source
    and "reannealed-charge-matches-source" in s07_source
    and "charge-quality-ra-not-required" in s07_source
    and "Admin RA completion requires a prior required decision"
        in s07_unit_test
    and 'transaction.set(abnormalityRef, after);' in s07_source
    and 'transaction.set(auditRef, {' in s07_source
    and 'transaction.set(receiptRef, {' in s07_source
    and 'callableName: "mutateChargeAbnormality"'
        in callable_index_source
    and "isQualityMutationOperation(request.data?.operation) ?"
        in callable_index_source
    and "userCanMutateQuality(userData, request.data.operation)"
        in callable_index_source
    and "userCanMutateChargeAbnormality(userData)"
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
ui_main_source = text("lib/main.dart")
ui_home_source = text("lib/home_screen.dart")
ui_user_source = text("lib/features/auth/data/user_model.dart")
ui_equipment_source = text(
    "lib/features/maintenance_workflow/presentation/screens/"
    "equipment_status_board.dart"
)
ui_workflow_provider_source = text(
    "lib/features/maintenance_workflow/providers/workflow_providers.dart"
)
ui_workflow_read_repository_source = text(
    "lib/features/maintenance_workflow/repositories/"
    "firestore_workflow_read_repository.dart"
)
ui_burner_report_source = text(
    "lib/features/reports/presentation/burner_reliability_screen.dart"
)
ui_burner_round_provider_source = text(
    "lib/features/assets/providers/burner_condition_round_provider.dart"
)
ui_operations_report_provider_source = text(
    "lib/features/reports/providers/operations_report_provider.dart"
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
workflow_entry_authority_test = text(
    "test/workflow_entry_authority_gate_test.dart"
)
diagnostics_guard = ui_diagnostics_source.find(
    "!actor.canViewMaintenanceWorkflowDiagnostics"
)
diagnostics_error = ui_diagnostics_source.find("if (actorAsync.hasError)")
diagnostics_read = ui_diagnostics_source.find("_ensureLoadedFor(actor)")
check(
    "Cross-app UI authority and workflow semantics remain policy-aligned",
    "Status: SOURCE_IMPLEMENTED" in ui_alignment_decision
    and "Merge and exact-head CI evidence: PENDING" in ui_alignment_decision
    and "message.data['complianceId']" in ui_home_source
    and "ComplianceNotificationScreen(" in ui_home_source
    and "module: BafModules.charges" not in ui_home_source
    and "canDeployMaintenanceEquipment" in ui_user_source
    and "row.stateKey == 'available' && canDeploy" in ui_equipment_source
    and "typedef WorkflowComplianceRecordScope" in ui_workflow_provider_source
    and "workflowCompliancePointReaderProvider" in ui_workflow_provider_source
    and "ActorSessionComplianceCache" in ui_workflow_provider_source
    and "_isOfflineCompliancePointRead" in ui_workflow_provider_source
    and "fetchComplianceById" in ui_workflow_read_repository_source
    and "GetOptions(source: Source.server)"
        in ui_workflow_read_repository_source
    and "ref.watch(operationsReportAuthorityLifecycleProvider);"
        in ui_main_source
    and "final operationsReportAuthorityLifecycleProvider = Provider<void>"
        in ui_operations_report_provider_source
    and "ref.invalidate(burnerConditionRoundsProvider)"
        in ui_operations_report_provider_source
    and "StreamProvider.autoDispose.family"
        in ui_burner_round_provider_source
    and "String actorUid" in ui_burner_round_provider_source
    and "admitActorSessionSnapshots("
        in ui_burner_round_provider_source
    and "includeMetadataChanges: true"
        in ui_burner_round_provider_source
    and "snapshot.metadata.isFromCache"
        in ui_burner_round_provider_source
    and "if (actorAsync.isLoading)" in ui_burner_report_source
    and "if (actorAsync.hasError)" in ui_burner_report_source
    and "key: ValueKey(actor.uid)" in ui_burner_report_source
    and "actorUid: widget.actor.uid" in ui_burner_report_source
    and "return _BurnerReliabilityBody(" in ui_burner_report_source
    and "final showBottomActions =" in ui_planned_detail_source
    and "if (!execution.isGovernedTemplateAssignment)" in ui_planned_detail_source
    and "if (!widget.execution.isGovernedTemplateAssignment"
        in ui_completion_source
    and "canManageTypes: canManageTypes" in ui_abnormality_source
    and "!actor.canReviewSyncConflicts" in ui_audit_source
    and diagnostics_guard >= 0
    and diagnostics_error >= 0
    and diagnostics_read > diagnostics_guard
    and "diagnostics rejects before reading privileged local data"
        in ui_alignment_test
    and "diagnostics reload for a new actor and hide on authority error"
        in workflow_entry_authority_test
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
operational_ux_control = text(
    "lib/features/operational_events/presentation/"
    "operational_control_screen.dart"
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
    and "label: 'Control'" in operational_ux_home
    and "label: 'More'" in operational_ux_home
    and "'Start here'" in operational_ux_home
    and "title: 'Work and coordination'" in operational_ux_home
    and "title: 'Assets and lifecycle'" in operational_ux_home
    and "title: 'Performance and assurance'" in operational_ux_home
    and "title: 'Standards and governance'" in operational_ux_home
    and "title: 'Administration and support'" in operational_ux_home
    and "title: 'Plant condition'" in operational_ux_home
    and "title: 'Operations intelligence'" in operational_ux_home
    and "hintText: 'Find a screen or function'" in operational_ux_home
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
    and "class OperationalControlScreen" in operational_ux_control
    and "title: 'Workflow obligations'" in operational_ux_control
    and "title: 'Quality warnings'" in operational_ux_control
    and "title: 'Cycle abnormalities'" in operational_ux_control
    and "static const large = 8.0" in operational_ux_theme
    and "static const xLarge = 8.0" in operational_ux_theme
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
    "LR-04 Firestore recoverability readback preserves its exact historical adverse posture",
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
    and lr04_policy.get("postureSemantics", {}).get(
        "isolatedImportMustMatchSourceExportOutput"
    ) is True
    and lr04_policy.get("isolatedRestore", {}).get(
        "inputUriPrefixSha256"
    )
        == lr04_policy.get("isolatedRestore", {}).get(
            "sourceExport", {}
        ).get("outputUriPrefixSha256")
    and lr04_policy.get("isolatedRestore", {}).get(
        "sourceExport", {}
    ).get("operationNameSha256")
        == "EF6A0FF2E809EA2D0C209B92380D1752E301D6C504D04BBA81D83168883C7F74"
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
    and "isolated import must derive from the exact successful source export"
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
    and p05_record.get("currentStatus") == "CLOSED"
    and p05_record.get("title")
        == "Production Firestore recovery posture lacks PITR, delete protection, native backups and restore proof"
    and len(p05_record.get("evidence", [])) == 6
    and [
        entry.get("status")
        for entry in p05_record.get("statusHistory", [])
    ] == ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"]
    and len(p05_record.get("requiredExitEvidence", [])) == 6
    and len(p05_record.get("reArmTriggers", [])) == 7
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
)

p05_receipt_path = (
    ROOT / "release/evidence/p05-firestore-recoverability-final-live-readback.json"
)
p05_receipt = data(
    "release/evidence/p05-firestore-recoverability-final-live-readback.json"
)
p05_receipt_body = dict(p05_receipt)
p05_receipt_body.pop("receiptSha256", None)
p05_receipt_canonical_sha = hashlib.sha256(
    json.dumps(
        p05_receipt_body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
p05_closure_path = (
    ROOT / "release/evidence/p05-firestore-recoverability-closure.json"
)
p05_closure = data(
    "release/evidence/p05-firestore-recoverability-closure.json"
)
p05_authority_receipt_path = (
    ROOT
    / "release/evidence/p05-firestore-recoverability-authority-repair-live-readback.json"
)
p05_authority_receipt = data(
    "release/evidence/p05-firestore-recoverability-authority-repair-live-readback.json"
)
p05_authority_receipt_body = dict(p05_authority_receipt)
p05_authority_receipt_body.pop("receiptSha256", None)
p05_authority_receipt_canonical_sha = hashlib.sha256(
    json.dumps(
        p05_authority_receipt_body,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
p05_authority_repair_path = (
    ROOT
    / "release/evidence/p05-firestore-recoverability-authority-repair.json"
)
p05_authority_repair = data(
    "release/evidence/p05-firestore-recoverability-authority-repair.json"
)
p05_contract = text("test/p05_programme_ledger_closure_contract_test.dart")
p05_authority_contract = text("test/p05_authority_repair_contract_test.dart")
check(
    "P-05 Firestore recoverability is closed by exact live controls, READY backup and isolated restore proof",
    sha(p05_receipt_path)
        == "4DDA4B23DA7F12AC958B92B7196513A7DA301D19505A489A9D88626A20BD9FCA"
    and p05_receipt_path.stat().st_size == 7492
    and p05_receipt.get("receiptSha256") == p05_receipt_canonical_sha
    and p05_receipt.get("receiptSha256")
        == "38faf40444959fb208295a9cdfa752519bd0da5afd8ce77d0f2c9930c198fb79"
    and p05_receipt.get("decision")
        == "PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK"
    and p05_receipt.get("posture", {}).get("decision")
        == "PASS_FIRESTORE_RECOVERABILITY_POSTURE"
    and p05_receipt.get("posture", {}).get("holds") == []
    and p05_receipt.get("failedChecks") == []
    and all(value is True for value in p05_receipt.get("checks", {}).values())
    and p05_receipt.get("source", {}).get("before")
        == p05_receipt.get("source", {}).get("after")
    and p05_receipt.get("source", {}).get("before", {}).get("commit")
        == "1e9803109844eaede717337317e82865c74bbd6f"
    and p05_receipt.get("source", {}).get("before", {}).get("tree")
        == "bfec7cbbea7599887d7c7a1e8ae0b530f2d4861d"
    and p05_receipt.get("outputs", {}).get("database", {}).get(
        "pointInTimeRecoveryEnablement"
    ) == "POINT_IN_TIME_RECOVERY_ENABLED"
    and p05_receipt.get("outputs", {}).get("database", {}).get(
        "deleteProtectionState"
    ) == "DELETE_PROTECTION_ENABLED"
    and p05_receipt.get("outputs", {}).get("schedules", {}).get("count") == 2
    and p05_receipt.get("outputs", {}).get("schedules", {}).get(
        "recurrenceTypeCounts"
    ) == {"DAILY": 1, "WEEKLY": 1}
    and p05_receipt.get("outputs", {}).get("backups", {}).get("count") == 5
    and p05_receipt.get("outputs", {}).get("backups", {}).get("stateCounts")
        == {"READY": 5}
    and p05_receipt.get("outputs", {}).get("operations", {}).get(
        "successfulImportOperationCount"
    ) == 0
    and p05_receipt.get("outputs", {}).get("isolatedRestore", {}).get(
        "database", {}
    ).get("databaseId") == "p05-restore-20260806"
    and p05_receipt.get("outputs", {}).get("isolatedRestore", {}).get(
        "database", {}
    ).get("deleteProtectionState") == "DELETE_PROTECTION_ENABLED"
    and p05_receipt.get("outputs", {}).get("isolatedRestore", {}).get(
        "operation", {}
    ).get("operationState") == "SUCCESSFUL"
    and p05_receipt.get("outputs", {}).get("isolatedRestore", {}).get(
        "operation", {}
    ).get("completedDocuments") == 81
    and p05_receipt.get("outputs", {}).get("isolatedRestore", {}).get(
        "operation", {}
    ).get("estimatedDocuments") == 81
    and p05_receipt.get("outputs", {}).get("isolatedRestore", {}).get(
        "exactSuccessfulImportAndValidation"
    ) is True
    and all(
        value is False
        for value in p05_receipt.get("mutationBoundary", {}).values()
    )
    and sha(p05_closure_path)
        == "176A143BACD196701A782F8959B96B69FC11CE401DB6D122E4F16DE2C1B4EE79"
    and p05_closure_path.stat().st_size == 3878
    and p05_closure.get("decision")
        == "PASS_P05_FIRESTORE_RECOVERABILITY_CLOSED"
    and p05_closure.get("recordTransition")
        == "OPEN_TO_LIVE_READBACK_PROVED_TO_CLOSED"
    and p05_closure.get("liveReceipt", {}).get("fileSha256")
        == sha(p05_receipt_path)
    and p05_closure.get("liveReceipt", {}).get("receiptSha256")
        == p05_receipt.get("receiptSha256")
    and p05_closure.get("collectorAuthority", {}).get("remoteCi", {}).get(
        "status"
    ) == "CREATED_AND_CANCELLED_NO_SUCCESS_AUTHORITY"
    and p05_closure.get("collectorAuthority", {}).get("remoteCi", {}).get(
        "pullRequestRun", {}
    ) == {
        "runId": 31124450098,
        "event": "pull_request",
        "headSha": "954c307490d6e87979a5ba96d19888e35f55e7f6",
        "conclusion": "cancelled",
    }
    and p05_closure.get("collectorAuthority", {}).get("remoteCi", {}).get(
        "postMergeRun", {}
    ) == {
        "runId": 31124445219,
        "event": "push",
        "headSha": "1e9803109844eaede717337317e82865c74bbd6f",
        "conclusion": "cancelled",
    }
    and p05_closure.get("closureCiAuthority", {}).get("pullRequest") == 173
    and p05_closure.get("closureCiAuthority", {}).get("pullRequestRun", {}).get(
        "runId"
    ) == 31394196080
    and p05_closure.get("closureCiAuthority", {}).get("pullRequestRun", {}).get(
        "conclusion"
    ) == "success"
    and p05_closure.get("closureCiAuthority", {}).get("postMergeRun", {}).get(
        "runId"
    ) == 31395073297
    and p05_closure.get("closureCiAuthority", {}).get("postMergeRun", {}).get(
        "conclusion"
    ) == "success"
    and all(
        value is False
        for value in p05_closure.get("closureBoundary", {}).values()
    )
    and p05_closure.get("historicalBoundary", {}).get(
        "adverse20260804ReceiptPreserved"
    ) is True
    and p05_closure.get("historicalBoundary", {}).get(
        "adverse20260804ClosurePreserved"
    ) is True
    and p05_closure.get("historicalBoundary", {}).get(
        "priorAdversePostureRewritten"
    ) is False
    and sha(p05_authority_receipt_path)
        == "80875E8284D6AB24C8B20E18E795CA24B5D37C9A4CD9BC2C308287167E35597D"
    and p05_authority_receipt_path.stat().st_size == 8364
    and p05_authority_receipt.get("receiptSha256")
        == p05_authority_receipt_canonical_sha
    and p05_authority_receipt.get("receiptSha256")
        == "46db50312e005f60e22117a14bcf03845d489296e277eb65cf1ff6de3e3f57b0"
    and p05_authority_receipt.get("failedChecks") == []
    and all(
        value is True
        for value in p05_authority_receipt.get("checks", {}).values()
    )
    and p05_authority_receipt.get("source", {}).get("before")
        == p05_authority_receipt.get("source", {}).get("after")
    and p05_authority_receipt.get("source", {}).get("before", {}).get(
        "commit"
    ) == "e1e1126f0d5d86f68d9fb1cf017271014c1396e9"
    and p05_authority_receipt.get("outputs", {}).get("operations", {}).get(
        "isolatedRestoreSourceExport", {}
    ).get("outputUriPrefixSha256")
        == p05_authority_receipt.get("outputs", {}).get(
            "isolatedRestore", {}
        ).get("operation", {}).get("inputUriPrefixSha256")
    and p05_authority_receipt.get("checks", {}).get(
        "isolatedRestoreSourceExportExact"
    ) is True
    and p05_authority_receipt.get("checks", {}).get(
        "isolatedRestoreDerivationExact"
    ) is True
    and sha(p05_authority_repair_path)
        == "EC7B4A3C7BB58BC67B4E8E55C2EBB9700BF793E126D0871350585F8EB97D2AAF"
    and p05_authority_repair_path.stat().st_size == 5606
    and p05_authority_repair.get("decision")
        == "PASS_P05_AUTHORITY_GAPS_REPAIRED"
    and p05_authority_repair.get("historicalEvidenceBoundary", {}).get(
        "historicalClosureRewritten"
    ) is False
    and p05_authority_repair.get("historicalEvidenceBoundary", {}).get(
        "repairIsAdditive"
    ) is True
    and p05_authority_repair.get("collectorSourceAuthority", {}).get(
        "pullRequest"
    ) == 253
    and p05_authority_repair.get("collectorSourceAuthority", {}).get(
        "pullRequestRun", {}
    ).get("runId") == 32503561030
    and p05_authority_repair.get("collectorSourceAuthority", {}).get(
        "postMergeRun", {}
    ).get("runId") == 32504753533
    and p05_authority_repair.get("correctedClosureRevisionAuthority", {}).get(
        "pullRequest"
    ) == 174
    and p05_authority_repair.get("correctedClosureRevisionAuthority", {}).get(
        "pullRequestRun", {}
    ).get("runId") == 31396537688
    and p05_authority_repair.get("correctedClosureRevisionAuthority", {}).get(
        "postMergeRun", {}
    ).get("runId") == 31397464741
    and all(
        run.get("conclusion") == "success"
        and run.get("requiredJobCount") == 5
        and run.get("allRequiredJobsSuccessful") is True
        for run in (
            p05_authority_repair.get("collectorSourceAuthority", {}).get(
                "pullRequestRun", {}
            ),
            p05_authority_repair.get("collectorSourceAuthority", {}).get(
                "postMergeRun", {}
            ),
            p05_authority_repair.get(
                "correctedClosureRevisionAuthority", {}
            ).get("pullRequestRun", {}),
            p05_authority_repair.get(
                "correctedClosureRevisionAuthority", {}
            ).get("postMergeRun", {}),
        )
    )
    and p05_authority_repair.get("ownerRatification", {}).get(
        "authorizationMode"
    ) == "POST_IMPLEMENTATION_OWNER_RATIFICATION"
    and p05_authority_repair.get("ownerRatification", {}).get(
        "ownerApprovalAcknowledged"
    ) is True
    and p05_authority_repair.get("ownerRatification", {}).get(
        "rawApprovalPhrasesRetained"
    ) is False
    and {
        entry.get("approvalPhraseSha256")
        for entry in p05_authority_repair.get("ownerRatification", {}).get(
            "approvalEvidence", []
        )
    } == {
        "328A62A785E21AA2F67FC5D3DB631DD0DBD80CA149D0346E85B5002C6E225C95",
        "8CAF93C7EB3D05A3A07452B144AB769D04A33791CAAC8F4BCC105034EEC4D446",
    }
    and all(
        value is False
        for value in p05_authority_repair.get(
            "mutationBoundary", {}
        ).values()
    )
    and "P-05 closes only on exact clean-main recovery proof" in p05_contract
    and "P-05 authority repair is additive, exact and privacy safe"
        in p05_authority_contract
    and p05_record.get("currentStatus") == "CLOSED"
    and {
        entry.get("sha256") for entry in p05_record.get("evidence", [])
    } == {
        "E339FC49400BA1817084270E4E8503C12797A00A9095FE937A30EE48D8A0F18D",
        "E760C24874C3905A675C213E1997E6BFFEE9C403683CE0F86B07CABD05A36302",
        "4DDA4B23DA7F12AC958B92B7196513A7DA301D19505A489A9D88626A20BD9FCA",
        "176A143BACD196701A782F8959B96B69FC11CE401DB6D122E4F16DE2C1B4EE79",
        "80875E8284D6AB24C8B20E18E795CA24B5D37C9A4CD9BC2C308287167E35597D",
        "EC7B4A3C7BB58BC67B4E8E55C2EBB9700BF793E126D0871350585F8EB97D2AAF",
    }
    and [
        entry.get("status")
        for entry in p05_record.get("statusHistory", [])
    ] == ["OPEN", "LIVE_READBACK_PROVED", "CLOSED"]
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER"
    and "These facts satisfy all six P-05 exit-evidence requirements"
        in lr04_decision,
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
a05_maintenance_provider = "\n".join(
    text(path)
    for path in (
        "lib/features/maintenance/providers/maintenance_provider.dart",
        "lib/features/maintenance/providers/maintenance_provider.local.dart",
        "lib/features/maintenance/providers/maintenance_provider.remote.dart",
    )
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
a05_remote_maintenance_reader = text(
    "lib/features/maintenance/data/remote_maintenance_reader.dart"
)
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
a05_tombstone_provider_paths = (
    "lib/features/abnormalities/providers/abnormality_provider.dart",
    "lib/features/directives/providers/operational_directive_provider.dart",
    "lib/features/maintenance/providers/maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/job_diary_provider.dart",
    "lib/features/planned_maintenance/providers/job_module_provider.dart",
    "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/template_governance_provider.dart",
)
a05_tombstone_provider_sources = {
    path: "\n".join(
        text(part_path)
        for part_path in (
            path,
            path.removesuffix(".dart") + ".local.dart",
            path.removesuffix(".dart") + ".remote.dart",
        )
    )
    for path in a05_tombstone_provider_paths
}
a05_tombstone_providers = "\n".join(a05_tombstone_provider_sources.values())
a05_tombstone_models = "\n".join(
    text(path)
    for path in (
        "lib/core/services/live_remote_sync_service.dart",
        "lib/features/abnormalities/data/abnormality_model.dart",
        "lib/features/planned_maintenance/data/job_diary_model.dart",
        "lib/features/planned_maintenance/data/job_module_model.dart",
        "lib/features/planned_maintenance/data/job_template_model.dart",
        "lib/features/planned_maintenance/data/template_governance_model.dart",
        "lib/features/planned_maintenance/data/remote_template_governance_reader.dart",
    )
)
a05_tombstone_models = f"{a05_tombstone_models}\n{a05_tombstone_providers}"
a05_tombstone_test = text("test/a05_remote_tombstone_integrity_test.dart")
a05_tombstone_conflict_test = text(
    "test/issue_1_tombstone_conflict_regression_test.dart"
)
a05_decision_5 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_5.md"
)
a05_timeline_template_model = text(
    "lib/features/planned_maintenance/data/remote_template_governance_reader.dart"
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
a05_user_model = text("lib/features/auth/data/user_model.dart")
a05_auth_gate = text("lib/main.dart")
a05_planned_work_screen = text(
    "lib/features/planned_maintenance/presentation/templates_screen.dart"
)
a05_planned_work_test = text("test/operational_ux_restructure_test.dart")
a05_planned_work_downgrade_test = text(
    "test/planned_work_open_job_visibility_test.dart"
)
a05_composer_live_test = text("test/module_composer_live_authority_test.dart")
a05_decision_7 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_7.md"
)
a05_maintenance_timestamps = text(
    "lib/features/maintenance/data/remote_maintenance_timestamps.dart"
)
a05_global_pull_maintenance = text(
    "lib/core/services/global_pull_service.maintenance.dart"
)
a05_sync_status_indicator = text("lib/core/widgets/sync_status_indicator.dart")
a05_timestamp_test = text("test/a05_maintenance_timestamp_integrity_test.dart")
a05_decision_8 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_8.md"
)
a05_timestamp_inventory_manifest = data(
    "governance/a05-persisted-timestamp-surface-v2.json"
)
a05_direct_timestamp_candidate_manifest = data(
    "governance/a05-direct-timestamp-candidate-classification-v1.json"
)
a05_timestamp_inventory_tool = text(
    "tools/v4/a05_persisted_timestamp_inventory.py"
)
a05_operational_timestamp_test = text(
    "test/a05_operational_timestamp_integrity_test.dart"
)
a05_decision_9 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_9.md"
)
a05_baf_reader = text(
    "lib/features/planned_maintenance/data/remote_baf_knowledge_reader.dart"
)
a05_baf_model = text(
    "lib/features/planned_maintenance/data/baf_knowledge_model.dart"
)
a05_baf_repository = text(
    "lib/features/planned_maintenance/domain/baf_knowledge_repository.dart"
)
a05_baf_provider = text(
    "lib/features/planned_maintenance/providers/knowledge_governance_provider.dart"
)
a05_workflow_pull = text(
    "lib/features/maintenance_workflow/services/workflow_pull_service.dart"
)
a05_baf_test = text("test/a05_baf_knowledge_integrity_test.dart")
a05_decision_10 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_10.md"
)
a05_directive_reader = text(
    "lib/features/directives/data/remote_operational_directive_reader.dart"
)
a05_directive_provider = "\n".join(
    text(path)
    for path in (
        "lib/features/directives/data/operational_directive_model.dart",
        "lib/features/directives/providers/operational_directive_provider.dart",
        "lib/features/directives/providers/operational_directive_provider.local.dart",
        "lib/features/directives/providers/operational_directive_provider.remote.dart",
    )
)
a05_directive_test = text(
    "test/a05_operational_directive_integrity_test.dart"
)
a05_decision_11 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_11.md"
)
a05_abnormality_model = text(
    "lib/features/abnormalities/data/abnormality_model.dart"
)
a05_abnormality_reader = text(
    "lib/features/abnormalities/data/remote_abnormality_reader.dart"
)
a05_abnormality_provider = "\n".join(
    text(path)
    for path in (
        "lib/features/abnormalities/providers/abnormality_provider.dart",
        "lib/features/abnormalities/providers/abnormality_provider.local.dart",
        "lib/features/abnormalities/providers/abnormality_provider.remote.dart",
    )
)
a05_abnormality_test = text("test/a05_abnormality_integrity_test.dart")
a05_decision_12 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_12.md"
)
a05_template_governance_model = text(
    "lib/features/planned_maintenance/data/template_governance_model.dart"
)
a05_template_governance_reader = text(
    "lib/features/planned_maintenance/data/remote_template_governance_reader.dart"
)
a05_template_governance_test = text(
    "test/a05_template_governance_integrity_test.dart"
)
a05_decision_13 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_13.md"
)
a05_module_registry_reader = text(
    "lib/features/planned_maintenance/data/remote_module_registry_reader.dart"
)
a05_module_registry_model = text(
    "lib/features/planned_maintenance/data/module_registry_model.dart"
)
a05_module_registry_provider = text(
    "lib/features/planned_maintenance/providers/module_registry_provider.dart"
)
a05_module_registry_test = text("test/a05_module_registry_integrity_test.dart")
a05_decision_14 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_14.md"
)
a05_assignment_backend = text("functions/src/publishedTemplateAssignment.ts")
a05_assignment_backend_test = text(
    "functions/test/publishedTemplateAssignment.test.js"
)
a05_assignment_response = text(
    "lib/features/planned_maintenance/services/"
    "published_template_assignment_server_service.dart"
)
a05_assignment_response_test = text(
    "test/published_template_assignment_server_contract_test.dart"
)
a05_authority_response = text(
    "lib/features/admin/services/user_authority_command_service.dart"
)
a05_authority_response_test = text("test/user_authority_command_service_test.dart")
a05_abnormality_response = text(
    "lib/features/abnormalities/services/charge_abnormality_command_service.dart"
)
a05_abnormality_response_test = text(
    "test/charge_abnormality_atomic_mutation_contract_test.dart"
)
a05_decision_15 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_15.md"
)
a05_workflow_pull_test = text("test/workflow_pull_service_watermark_test.dart")
a05_decision_16 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_16.md"
)
a05_backend_release_identity = text(
    "lib/core/release/backend_release_identity_service.dart"
)
a05_backend_release_identity_test = text(
    "test/backend_release_identity_service_test.dart"
)
a05_template_snapshot_contract = text(
    "lib/features/planned_maintenance/domain/template_version_snapshot_contract.dart"
)
a05_template_snapshot_test = text(
    "test/template_version_snapshot_contract_test.dart"
)
a05_template_lifecycle_sync = text(
    "lib/core/services/sync_service.template_governance.dart"
)
a05_template_lifecycle_test = text(
    "test/template_governance_lifecycle_replay_contract_test.dart"
)
a05_decision_17 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_17.md"
)
a05_decoder_inventory_manifest = data(
    "governance/a05-persisted-decoder-surface-v1.json"
)
a05_decoder_inventory_tool = text(
    "tools/v4/a05_persisted_decoder_inventory.py"
)
a05_production_sweep = text(
    "tools/v4/a05_production_persisted_integrity_sweep.mjs"
)
a05_production_sweep_test = text(
    "tools/v4/a05_production_persisted_integrity_sweep.test.mjs"
)
a05_reconciliation_bridge = text(
    "tools/v4/a05_persisted_reconciliation_bridge.dart"
)
a05_reconciliation_harness = text(
    "test/tools/a05_persisted_reconciliation_bridge_test.dart"
)
a05_decision_18 = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_TRANCHE_18.md"
)
a05_closure_path = (
    ROOT / "release/evidence/a05-persisted-state-integrity-closure.json"
)
a05_closure = data(
    "release/evidence/a05-persisted-state-integrity-closure.json"
)
a05_closure_decision = text(
    "docs/v4_2_r1/A05_PERSISTED_STATE_INTEGRITY_CLOSURE.md"
)
a05_timestamp_inventory_process = subprocess.run(
    [sys.executable, str(ROOT / "tools/v4/a05_persisted_timestamp_inventory.py")],
    cwd=ROOT,
    capture_output=True,
    text=True,
)
try:
    a05_timestamp_inventory_report = json.loads(
        a05_timestamp_inventory_process.stdout
    )
except json.JSONDecodeError:
    a05_timestamp_inventory_report = {}
a05_decoder_inventory_process = subprocess.run(
    [sys.executable, str(ROOT / "tools/v4/a05_persisted_decoder_inventory.py")],
    cwd=ROOT,
    capture_output=True,
    text=True,
)
try:
    a05_decoder_inventory_report = json.loads(
        a05_decoder_inventory_process.stdout
    )
except json.JSONDecodeError:
    a05_decoder_inventory_report = {}
a02_inventory_process = subprocess.run(
    [sys.executable, str(ROOT / "tools/v4/a02_architecture_inventory.py")],
    cwd=ROOT,
    capture_output=True,
    text=True,
)
try:
    a02_inventory_report = json.loads(a02_inventory_process.stdout)
except json.JSONDecodeError:
    a02_inventory_report = {}
a02_closure_path = (
    ROOT
    / "release/evidence/a02-architecture-responsibility-source-and-ci-closure.json"
)
a02_closure = data(
    "release/evidence/a02-architecture-responsibility-source-and-ci-closure.json"
)
a02_manifest = data("governance/a02-architecture-boundaries-v1.json")
a02_expected_jobs = {
    "Android emulator app-shell integration (not physical-device evidence)",
    "Android release package + cold-start proof (non-production)",
    "Cloud Functions host build + non-emulator tests",
    "Firestore Rules + governed callable emulator",
    "Flutter host analysis + tests + no-loss contracts",
}
a02_a05_exit_decision = text(
    "docs/v4_2_r1/A02_A05_ARCHITECTURE_EXIT_CRITERIA.md"
)
a02_a05_ids = {"A-02", "A-03", "A-04", "A-05"}
a02_a05_records = {
    record.get("findingId"): record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") in a02_a05_ids
}
a02_record = a02_a05_records.get("A-02", {})
a03_record = a02_a05_records.get("A-03", {})
a03_history = [
    entry.get("status")
    for entry in a03_record.get("statusHistory", [])
]
a03_manifest = data("governance/a03-persistence-boundaries-v1.json")
a03_profiles = a03_manifest.get("profiles", {})
a03_surfaces = a03_manifest.get("surfaces", [])
a03_remediation = text(
    "docs/v4_2_r1/A03_PERSISTENCE_BOUNDARY_REMEDIATION.md"
)
a03_closure_path = (
    ROOT
    / "release/evidence/a03-persistence-boundary-source-and-ci-closure.json"
)
a03_closure = data(
    "release/evidence/a03-persistence-boundary-source-and-ci-closure.json"
)
a03_evidence = a03_record.get("evidence", [])
a03_pr_ci = a03_closure.get("pullRequestCi", {})
a03_postmerge_ci = a03_closure.get("postMergeCi", {})
a03_inventory_proof = a03_closure.get("inventoryProof", {})
a03_boundaries = a03_closure.get("boundaries", {})
a04_record = a02_a05_records.get("A-04", {})
a04_history = [
    entry.get("status")
    for entry in a04_record.get("statusHistory", [])
]
a04_manifest = data("governance/a04-persisted-schema-v1.json")
a04_fields = a04_manifest.get("fields", [])
a04_inherited_decoders = a04_manifest.get("inheritedDecoderSurfaces", [])
a04_extension_policy = a04_manifest.get("extensionPolicy", {})
a04_remediation = text("docs/v4_2_r1/A04_PERSISTED_SCHEMA_REMEDIATION.md")
a04_closure_path = (
    ROOT
    / "release/evidence/a04-persisted-schema-source-ci-and-reconciliation-closure.json"
)
a04_closure = data(
    "release/evidence/a04-persisted-schema-source-ci-and-reconciliation-closure.json"
)
a04_evidence = a04_record.get("evidence", [])
a04_pr_ci = a04_closure.get("pullRequestCi", {})
a04_postmerge_ci = a04_closure.get("postMergeCi", {})
a04_inventory_proof = a04_closure.get("inventoryProof", {})
a04_production_reconciliation = a04_closure.get(
    "productionReconciliation", {}
)
a04_local_generation = a04_closure.get(
    "supportedLocalGenerationAuthority", {}
)
a04_closure_boundary = a04_closure.get("closureBoundary", {})
dart_executable = shutil.which("dart")
if sys.platform == "win32" and dart_executable:
    located_dart = Path(dart_executable)
    sdk_dart = located_dart.parent / "cache" / "dart-sdk" / "bin" / "dart.exe"
    if sdk_dart.is_file():
        dart_executable = str(sdk_dart)
    elif located_dart.suffix.lower() in {".bat", ".cmd", ""}:
        dart_executable = None
    elif located_dart.suffix == ".EXE":
        # Dart native-asset hooks compare the executable suffix
        # case-sensitively before appending ".exe" on Windows.
        dart_executable = str(located_dart.with_suffix(".exe"))
if dart_executable:
    a04_inventory_process = subprocess.run(
        [
            dart_executable,
            "run",
            str(ROOT / "tools/v4/a04_persisted_schema_inventory.dart"),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        env={**os.environ, "DART_SUPPRESS_ANALYTICS": "true"},
    )
else:
    a04_inventory_process = subprocess.CompletedProcess(
        args=["dart", "run", "tools/v4/a04_persisted_schema_inventory.dart"],
        returncode=127,
        stdout="",
        stderr="Dart SDK executable was not found.",
    )
try:
    a04_json_start = a04_inventory_process.stdout.index("{")
    a04_inventory_report = json.loads(
        a04_inventory_process.stdout[a04_json_start:]
    )
except (ValueError, json.JSONDecodeError):
    a04_inventory_report = {}
a03_presentation_persistence = []
for a03_path in (ROOT / "lib").rglob("*.dart"):
    a03_relative = a03_path.relative_to(ROOT).as_posix()
    if "/presentation/" not in a03_relative and "/widgets/" not in a03_relative:
        continue
    a03_source = a03_path.read_text(encoding="utf-8")
    if any(
        marker in a03_source
        for marker in (
            "FirebaseFirestore.instance",
            "Isar.getInstance()",
            ".writeTxn(",
        )
    ):
        a03_presentation_persistence.append(a03_relative)
a02_evidence = a02_record.get("evidence", [])
a02_history = [
    entry.get("status")
    for entry in a02_record.get("statusHistory", [])
]
a02_pr_ci = a02_closure.get("pullRequestCi", {})
a02_postmerge_ci = a02_closure.get("postMergeCi", {})
a02_inventory_proof = a02_closure.get("inventoryProof", {})
a02_boundaries = a02_closure.get("boundaries", {})
a05_records = [
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "A-05"
]
a05_record = a05_records[0] if len(a05_records) == 1 else {}
a05_evidence = a05_record.get("evidence", [])
a05_history = [
    entry.get("status")
    for entry in a05_record.get("statusHistory", [])
]
a05_pr_ci = a05_closure.get("pullRequestCi", {})
a05_postmerge_ci = a05_closure.get("postMergeCi", {})
a05_production_reconciliation = a05_closure.get(
    "productionReconciliation", {}
)
a05_local_generation = a05_closure.get(
    "supportedLocalGenerationAuthority", {}
)
a05_current_source_revalidation = a05_local_generation.get(
    "currentSourceRevalidation", {}
)
a05_closure_boundary = a05_closure.get("closureBoundary", {})
a05_expected_jobs = {
    "Android emulator app-shell integration (not physical-device evidence)",
    "Android release package + cold-start proof (non-production)",
    "Cloud Functions host build + non-emulator tests",
    "Firestore Rules + governed callable emulator",
    "Flutter host analysis + tests + no-loss contracts",
}
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
    "lib/features/planned_maintenance/data/baf_knowledge_model.dart",
    "lib/features/planned_maintenance/data/module_registry_model.dart",
    "lib/features/planned_maintenance/data/template_governance_model.dart",
    "lib/features/planned_maintenance/domain/planned_job_closure_attestation.dart",
    "lib/features/planned_maintenance/domain/planned_job_closure_guard.dart",
    "lib/features/planned_maintenance/domain/module_composer_models.dart",
    "lib/features/planned_maintenance/domain/baf_knowledge_repository.dart",
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
    "lib/features/planned_maintenance/providers/knowledge_governance_provider.dart",
    "lib/features/planned_maintenance/providers/planned_maintenance_provider.dart",
    "lib/features/planned_maintenance/providers/template_governance_provider.dart",
    "test/firestore.rules.test.js",
    "test/complete_job_screen_server_gate_test.dart",
    "test/module_registry_authoring_screen_test.dart",
    "test/planned_job_closure_guard_test.dart",
}
check(
    "A-02 to A-05 carry explicit architecture exit and re-arm constraints",
    set(a02_a05_records) == a02_a05_ids
    and a04_record.get("currentStatus") == "CLOSED"
    and len(a04_record.get("evidence", [])) == 1
    and len(a04_record.get("requiredExitEvidence", [])) == 5
    and len(a04_record.get("reArmTriggers", [])) == 3
    and a04_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and a03_record.get("currentStatus") == "CLOSED"
    and len(a03_record.get("evidence", [])) == 1
    and len(a03_record.get("requiredExitEvidence", [])) == 5
    and len(a03_record.get("reArmTriggers", [])) == 3
    and a03_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and a02_record.get("currentStatus") == "CLOSED"
    and len(a02_record.get("requiredExitEvidence", [])) == 5
    and len(a02_record.get("reArmTriggers", [])) == 3
    and a02_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and a05_record.get("currentStatus") == "CLOSED"
    and len(a05_record.get("requiredExitEvidence", [])) == 5
    and len(a05_record.get("reArmTriggers", [])) == 3
    and a05_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and "Inventories must be machine-generated" in a02_a05_exit_decision
    and "Broad exemptions for `metadataJson`" in a02_a05_exit_decision
    and "registered, authority-gated, read-only diagnostic adapters"
        in a02_a05_exit_decision
    and "governed read-only inventory" in a02_a05_exit_decision
    and "All four findings are now evidence-closed" in a02_a05_exit_decision
    and "The recorded closures" in a02_a05_exit_decision,
)
check(
    "A-03 persistence boundaries are completely classified and presentation-clean",
    a03_manifest.get("schemaVersion") == 1
    and a03_manifest.get("findingId") == "A-03"
    and a03_manifest.get("inventoryDigest")
        == "00B91C2AAA8D25B0DE669A6B02BE6DAB15DB4FAF765825A10D2264C225248A77"
    and len(a03_surfaces) == 49
    and len({surface.get("path") for surface in a03_surfaces}) == 49
    and a03_presentation_persistence == []
    and all(
        surface.get("profile") in a03_profiles
        and surface.get("allowedStores")
        and surface.get("allowedModes")
        and "test/a03_persistence_boundary_contract_test.dart"
            in surface.get("regressionTests", [])
        for surface in a03_surfaces
    )
    and all(
        surface.get("profile")
            in {"service", "repository", "repository-adapter", "auth-provider"}
        for surface in a03_surfaces
        if "mutating" in surface.get("allowedModes", [])
    )
    and all(
        surface.get("profile") in {"service", "repository"}
        for surface in a03_surfaces
        if len(surface.get("allowedStores", [])) > 1
    )
    and "Status: CLOSED" in a03_remediation
    and "509 operations" in a03_remediation
    and "No file under a presentation or widget directory" in a03_remediation,
)
check(
    "A-04 persisted schemas are completely classified and source-enforced",
    a04_inventory_process.returncode == 0
    and a04_inventory_report.get("result") == "PASS"
    and a04_inventory_report.get("findingId") == "A-04"
    and a04_inventory_report.get("fieldCount") == 53
    and a04_inventory_report.get("jsonStringFieldCount") == 47
    and a04_inventory_report.get("dynamicValueFieldCount") == 6
    and a04_inventory_report.get("extensionBagCount") == 3
    and a04_inventory_report.get("registeredExtensionFieldCount") == 0
    and a04_inventory_report.get("inheritedDecoderSurfaceCount") == 71
    and a04_inventory_report.get("inventoryDigest")
    == "6A29B8F556294169B2FE8A123993FD15BF5A7B6D5A9EBC249F5274CE5D498F33"
    and a04_inventory_report.get("failures") == []
    and a04_manifest.get("schemaVersion") == 1
    and a04_manifest.get("findingId") == "A-04"
    and len(a04_fields) == 53
    and len({field.get("id") for field in a04_fields}) == 53
    and len(a04_inherited_decoders) == 71
    and len({surface.get("id") for surface in a04_inherited_decoders}) == 71
    and all(
        field.get("classification")
            in {"SCHEMA_BEARING_PAYLOAD", "BOUNDED_REGISTERED_EXTENSION_BAG"}
        and field.get("policy")
        and field.get("decoderContract")
        and field.get("malformedPresentDisposition")
            == "FAIL_CLOSED_PENDING_REPAIR"
        and field.get("compatibility")
        and field.get("regression")
        for field in a04_fields
    )
    and a04_extension_policy.get("authorityOrBusinessInvariantFieldsAllowed")
        is False
    and a04_extension_policy.get("registeredFields") == {}
    and "Status: CLOSED" in a04_remediation
    and "classifies 53" in a04_remediation
    and "current extension registry contains zero fields" in a04_remediation
    and "supported-local-generation reconciliation" in a04_remediation,
    (
        f"returncode={a04_inventory_process.returncode} "
        f"result={a04_inventory_report.get('result')} "
        f"fields={a04_inventory_report.get('fieldCount')} "
        f"decoders={a04_inventory_report.get('inheritedDecoderSurfaceCount')} "
        f"digest={a04_inventory_report.get('inventoryDigest')} "
        f"stderr={a04_inventory_process.stderr.strip()}"
    ),
)
check(
    "A-03 closes on exact persistence inventory and admitted CI authority",
    a03_record.get("currentStatus") == "CLOSED"
    and a03_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(a03_evidence) == 1
    and a03_evidence[0].get("evidenceFile")
        == "release/evidence/a03-persistence-boundary-source-and-ci-closure.json"
    and a03_evidence[0].get("evidenceSha256") == sha(a03_closure_path)
    and a03_evidence[0].get("pullRequest") == 234
    and a03_evidence[0].get("headCommit")
        == "af14218f5281cb210bda5382fbedc5eaa2ca27e8"
    and a03_evidence[0].get("sourceTree")
        == "0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff"
    and a03_evidence[0].get("mergeCommit")
        == "829c87ee07de43846f1d6b5e6d0b1879a3801d93"
    and a03_evidence[0].get("mergeTree")
        == "0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff"
    and a03_evidence[0].get("pullRequestWorkflowRun") == 32042648071
    and a03_evidence[0].get("postMergeWorkflowRun") == 32043979797
    and a03_evidence[0].get("decision")
        == "PASS_A03_PERSISTENCE_BOUNDARY_SOURCE_AND_CI_CLOSURE"
    and a03_closure.get("decision")
        == "PASS_A03_PERSISTENCE_BOUNDARY_SOURCE_AND_CI_CLOSURE"
    and a03_closure.get("sourceAuthority", {}).get("pullRequest") == 234
    and a03_closure.get("sourceAuthority", {}).get("headCommit")
        == "af14218f5281cb210bda5382fbedc5eaa2ca27e8"
    and a03_closure.get("sourceAuthority", {}).get("sourceTree")
        == "0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff"
    and a03_closure.get("sourceAuthority", {}).get("mergeCommit")
        == "829c87ee07de43846f1d6b5e6d0b1879a3801d93"
    and a03_closure.get("sourceAuthority", {}).get("mergeTree")
        == "0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff"
    and a03_inventory_proof.get("operationCount") == 484
    and a03_inventory_proof.get("siteCount") == 1548
    and a03_inventory_proof.get("surfaceCount") == 44
    and a03_inventory_proof.get("presentationPersistenceCount") == 0
    and a03_inventory_proof.get("inventoryDigest")
        == "7923E15F9D3DBCD24C84FEBFD053A9056843E64D0BDDA2A484CDFBD826E3B92A"
    and a03_pr_ci.get("workflowRun") == 32042648071
    and a03_pr_ci.get("headCommit")
        == "af14218f5281cb210bda5382fbedc5eaa2ca27e8"
    and a03_pr_ci.get("conclusion") == "success"
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a03_pr_ci.get("jobs", [])
    } == {(name, "success") for name in a02_expected_jobs}
    and a03_postmerge_ci.get("workflowRun") == 32043979797
    and a03_postmerge_ci.get("headCommit")
        == "829c87ee07de43846f1d6b5e6d0b1879a3801d93"
    and a03_postmerge_ci.get("conclusion") == "success"
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a03_postmerge_ci.get("jobs", [])
    } == {(name, "success") for name in a02_expected_jobs}
    and a03_boundaries.get("presentationPersistenceRemoved") is True
    and a03_boundaries.get("productionDeploymentPerformed") is False
    and a03_boundaries.get("productionDataReadPerformed") is False
    and a03_boundaries.get("productionDataMutationPerformed") is False
    and a03_boundaries.get("deviceEvidenceClaimed") is False
    and a03_boundaries.get("pilotAuthorizationChanged") is False
    and a03_boundaries.get("distributionAuthorityChanged") is False,
)
check(
    "A-04 closes on exact schema, CI and reconciliation authority",
    a04_record.get("currentStatus") == "CLOSED"
    and a04_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(a04_evidence) == 1
    and a04_evidence[0].get("evidenceFile")
        == "release/evidence/a04-persisted-schema-source-ci-and-reconciliation-closure.json"
    and a04_evidence[0].get("evidenceSha256") == sha(a04_closure_path)
    and a04_evidence[0].get("pullRequest") == 235
    and a04_evidence[0].get("headCommit")
        == "1c4192c4b833919b5a045741866e9c7d6e17b79c"
    and a04_evidence[0].get("sourceTree")
        == "55c73664ce7cc2f8f60142d92e8920a4686a385f"
    and a04_evidence[0].get("mergeCommit")
        == "f54f88c4e1e526e1493712824c1b281d17c70b2e"
    and a04_evidence[0].get("mergeTree")
        == "55c73664ce7cc2f8f60142d92e8920a4686a385f"
    and a04_evidence[0].get("pullRequestWorkflowRun") == 32050533628
    and a04_evidence[0].get("postMergeWorkflowRun") == 32051729235
    and a04_evidence[0].get("productionReconciliationEvidenceSha256")
        == "8581F54892ED2973CE0D4B94C61277970DA4056BC3F4269979E4DE1C21BE2FFE"
    and a04_evidence[0].get("decision")
        == "PASS_A04_PERSISTED_SCHEMA_SOURCE_CI_AND_RECONCILIATION_CLOSURE"
    and a04_closure.get("decision")
        == "PASS_A04_PERSISTED_SCHEMA_SOURCE_CI_AND_RECONCILIATION_CLOSURE"
    and a04_closure.get("sourceAuthority", {}).get("pullRequest") == 235
    and a04_closure.get("sourceAuthority", {}).get("headCommit")
        == "1c4192c4b833919b5a045741866e9c7d6e17b79c"
    and a04_closure.get("sourceAuthority", {}).get("sourceTree")
        == "55c73664ce7cc2f8f60142d92e8920a4686a385f"
    and a04_closure.get("sourceAuthority", {}).get("mergeCommit")
        == "f54f88c4e1e526e1493712824c1b281d17c70b2e"
    and a04_closure.get("sourceAuthority", {}).get("mergeTree")
        == "55c73664ce7cc2f8f60142d92e8920a4686a385f"
    and a04_inventory_proof.get("fieldCount") == 53
    and a04_inventory_proof.get("jsonStringFieldCount") == 47
    and a04_inventory_proof.get("dynamicValueFieldCount") == 6
    and a04_inventory_proof.get("extensionBagCount") == 3
    and a04_inventory_proof.get("registeredExtensionFieldCount") == 0
    and a04_inventory_proof.get("inheritedDecoderSurfaceCount") == 54
    and a04_inventory_proof.get("inventoryDigest")
        == "27863AC2C3E366BD34BFAC9D092EA86AF269756BAD56C05C1974D78F843697C9"
    and a04_pr_ci.get("workflowRun") == 32050533628
    and a04_pr_ci.get("headCommit")
        == "1c4192c4b833919b5a045741866e9c7d6e17b79c"
    and a04_pr_ci.get("conclusion") == "success"
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a04_pr_ci.get("jobs", [])
    } == {(name, "success") for name in a02_expected_jobs}
    and a04_postmerge_ci.get("workflowRun") == 32051729235
    and a04_postmerge_ci.get("headCommit")
        == "f54f88c4e1e526e1493712824c1b281d17c70b2e"
    and a04_postmerge_ci.get("conclusion") == "success"
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a04_postmerge_ci.get("jobs", [])
    } == {(name, "success") for name in a02_expected_jobs}
    and a04_production_reconciliation.get("decision")
        == "PASS_A05_READ_ONLY_PRODUCTION_RECONCILIATION"
    and a04_production_reconciliation.get("sourceCommit")
        == "f54f88c4e1e526e1493712824c1b281d17c70b2e"
    and a04_production_reconciliation.get("sourceTree")
        == "55c73664ce7cc2f8f60142d92e8920a4686a385f"
    and a04_production_reconciliation.get("cleanFetchedMain") is True
    and a04_production_reconciliation.get("readOnly") is True
    and a04_production_reconciliation.get("cloudMutationCapability") == "NONE"
    and a04_production_reconciliation.get("rawIdentifiersEmitted") is False
    and a04_production_reconciliation.get("rawDocumentDataPersisted") is False
    and a04_production_reconciliation.get("registeredRootCollectionCount") == 67
    and a04_production_reconciliation.get("enumeratedRootCollectionCount") == 8
    and a04_production_reconciliation.get("unregisteredRootCollectionCount") == 0
    and a04_production_reconciliation.get("blockingFindingCount") == 0
    and a04_production_reconciliation.get("warningCount") == 0
    and a04_production_reconciliation.get("strictReaderAttemptedCount") == 9
    and a04_production_reconciliation.get("strictReaderPassedCount") == 9
    and a04_production_reconciliation.get("strictReaderFailedCount") == 0
    and a04_local_generation.get("sourceCommit")
        == "f54f88c4e1e526e1493712824c1b281d17c70b2e"
    and a04_local_generation.get("sourceTree")
        == "55c73664ce7cc2f8f60142d92e8920a4686a385f"
    and a04_local_generation.get("sameCheckout") is True
    and len(a04_local_generation.get("testFiles", [])) == 4
    and a04_local_generation.get("passedCount") == 27
    and a04_local_generation.get("failedCount") == 0
    and len(a04_local_generation.get("dispositions", [])) == 5
    and a04_local_generation.get("repairDisposition")
        == "PRESERVE_AND_BLOCK_PENDING_REPAIR"
    and a04_local_generation.get("silentRewritePerformed") is False
    and a04_closure_boundary.get("a04ClosureAuthorized") is True
    and a04_closure_boundary.get("productionDeploymentPerformed") is False
    and a04_closure_boundary.get("productionDataMutationPerformed") is False
    and a04_closure_boundary.get("firebaseDeploymentPerformed") is False
    and a04_closure_boundary.get("deviceEvidenceClaimed") is False
    and a04_closure_boundary.get("pilotAuthorizationChanged") is False
    and a04_closure_boundary.get("distributionAuthorityChanged") is False
    and a04_closure_boundary.get("cutoverAuthorized") is False,
)
check(
    "A-02 responsibility hotspots are completely classified and source-enforced",
    a02_inventory_process.returncode == 0
    and a02_inventory_report.get("result") == "PASS"
    and a02_inventory_report.get("findingId") == "A-02"
    and a02_inventory_report.get("hotspotCount", 0) > 0
    and a02_inventory_report.get("failures") == []
    and "three explicit units"
        in text("docs/v4_2_r1/A02_ARCHITECTURE_RESPONSIBILITY_REMEDIATION.md")
    and "Status: CLOSED"
        in text("docs/v4_2_r1/A02_ARCHITECTURE_RESPONSIBILITY_REMEDIATION.md"),
)
check(
    "A-02 closes on exact source inventory and admitted CI authority",
    a02_record.get("currentStatus") == "CLOSED"
    and a02_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(a02_evidence) == 1
    and a02_evidence[0].get("evidenceFile")
        == "release/evidence/a02-architecture-responsibility-source-and-ci-closure.json"
    and a02_evidence[0].get("evidenceSha256") == sha(a02_closure_path)
    and a02_evidence[0].get("pullRequest") == 232
    and a02_evidence[0].get("headCommit")
        == "8874c1d4d7b6ad0d07ec7924769c6aa97c76af06"
    and a02_evidence[0].get("sourceTree")
        == "a6ffe16758711d587a213a85f95bea3f6f1730ad"
    and a02_evidence[0].get("mergeCommit")
        == "0c0ddb7219c1043fe3924cd164acf06147d01e34"
    and a02_evidence[0].get("mergeTree")
        == "a6ffe16758711d587a213a85f95bea3f6f1730ad"
    and a02_evidence[0].get("pullRequestWorkflowRun") == 32036713473
    and a02_evidence[0].get("postMergeWorkflowRun") == 32037634060
    and a02_evidence[0].get("decision")
        == "PASS_A02_ARCHITECTURE_RESPONSIBILITY_SOURCE_AND_CI_CLOSURE"
    and a02_closure.get("decision")
        == "PASS_A02_ARCHITECTURE_RESPONSIBILITY_SOURCE_AND_CI_CLOSURE"
    and a02_closure.get("sourceAuthority", {}).get("headCommit")
        == "8874c1d4d7b6ad0d07ec7924769c6aa97c76af06"
    and a02_closure.get("sourceAuthority", {}).get("sourceTree")
        == "a6ffe16758711d587a213a85f95bea3f6f1730ad"
    and a02_closure.get("sourceAuthority", {}).get("mergeCommit")
        == "0c0ddb7219c1043fe3924cd164acf06147d01e34"
    and a02_closure.get("sourceAuthority", {}).get("mergeTree")
        == "a6ffe16758711d587a213a85f95bea3f6f1730ad"
    and a02_inventory_proof.get("hotspotCount") == 40
    and a02_inventory_proof.get("decomposedSurfaceCount") == 16
    and a02_inventory_proof.get("boundedExceptionCount") == 24
    and a02_inventory_proof.get("a03PresentationPersistenceCarryoverCount")
        == 3
    and a02_inventory_proof.get("inventoryDigest")
        == "617D22F40961FF828A96F84328E5209085656C22C48077535B8B70BDC07ECCAA"
    and len(a02_manifest.get("surfaces", []))
        == a02_inventory_report.get("hotspotCount")
    and a02_pr_ci.get("workflowRun") == 32036713473
    and a02_pr_ci.get("headCommit")
        == "8874c1d4d7b6ad0d07ec7924769c6aa97c76af06"
    and a02_pr_ci.get("conclusion") == "success"
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a02_pr_ci.get("jobs", [])
    } == {(name, "success") for name in a02_expected_jobs}
    and a02_postmerge_ci.get("workflowRun") == 32037634060
    and a02_postmerge_ci.get("headCommit")
        == "0c0ddb7219c1043fe3924cd164acf06147d01e34"
    and a02_postmerge_ci.get("conclusion") == "success"
    and {
        (job.get("name"), job.get("conclusion"))
        for job in a02_postmerge_ci.get("jobs", [])
    } == {(name, "success") for name in a02_expected_jobs}
    and a02_boundaries.get("a03CarryoversClosed") is False
    and a02_boundaries.get("a04PersistedSchemaClosed") is False
    and a02_boundaries.get("productionDeploymentPerformed") is False
    and a02_boundaries.get("productionDataMutationPerformed") is False
    and a02_boundaries.get("deviceEvidenceClaimed") is False
    and a02_boundaries.get("pilotAuthorizationChanged") is False
    and a02_boundaries.get("distributionAuthorityChanged") is False,
)
check(
    "A-05 strict persisted timestamp-reader inventory is exact and source-enforced",
    a05_timestamp_inventory_process.returncode == 0
    and a05_timestamp_inventory_report.get("result") == "PASS"
    and a05_timestamp_inventory_report.get("readerCount") == 69
    and a05_timestamp_inventory_report.get("directCallCount") == 165
    and a05_timestamp_inventory_report.get("requiredFieldCount") == 97
    and a05_timestamp_inventory_report.get("optionalFieldCount") == 66
    and a05_timestamp_inventory_report.get("unclassifiedReaderSites") == []
    and a05_timestamp_inventory_report.get("duplicateReaderSites") == []
    and a05_timestamp_inventory_report.get("directParserCandidateCount") == 28
    and a05_timestamp_inventory_report.get(
        "directParserClassificationGroupCount"
    ) == 6
    and a05_timestamp_inventory_report.get(
        "unclassifiedDirectParserCandidates"
    ) == []
    and a05_timestamp_inventory_report.get(
        "staleDirectParserClassifications"
    ) == []
    and a05_timestamp_inventory_manifest.get("schemaVersion") == 2
    and len(a05_timestamp_inventory_manifest.get("readers", [])) == 69
    and a05_direct_timestamp_candidate_manifest.get("schemaVersion") == 1
    and len(
        a05_direct_timestamp_candidate_manifest.get("classifications", [])
    ) == 6
    and "sourceCommit" in a05_timestamp_inventory_tool
    and "readerSha256" in a05_timestamp_inventory_tool
    and "unclassifiedReaderSites" in a05_timestamp_inventory_tool
    and "duplicateReaderSites" in a05_timestamp_inventory_tool
    and "directParserCandidates" in a05_timestamp_inventory_tool
    and "unclassifiedDirectParserCandidates" in a05_timestamp_inventory_tool
    and "staleDirectParserClassifications" in a05_timestamp_inventory_tool
    and "workflow receipts require their persisted application time"
        in a05_operational_timestamp_test
    and "malformed present optional timestamps fail closed"
        in a05_operational_timestamp_test
    and "`WorkflowCommandReceipt.fromMap`" in a05_decision_9
    and "`A-05` remains open" in a05_decision_9
    and "does not inspect or mutate production documents" in a05_decision_9,
    a05_timestamp_inventory_process.stderr.strip(),
)
check(
    "A-05 complete persisted decoder and catch inventory is exact and source-enforced",
    a05_decoder_inventory_process.returncode == 0
    and a05_decoder_inventory_report.get("result") == "PASS"
    and a05_decoder_inventory_report.get("surfaceCount") == 71
    and a05_decoder_inventory_report.get("decoderCatchSiteCount") == 45
    and a05_decoder_inventory_report.get("strictReaderConsumerFileCount") == 48
    and a05_decoder_inventory_report.get("rawJsonConsumerFileCount") == 35
    and a05_decoder_inventory_report.get("riskCandidateCount") == 373
    and a05_decoder_inventory_report.get("timestampInventoryResult") == "PASS"
    and a05_decoder_inventory_report.get("unclassifiedFiles") == []
    and a05_decoder_inventory_report.get("unclassifiedDecoderCatchSites") == []
    and a05_decoder_inventory_report.get("staleDecoderCatchPolicies") == []
    and len(a05_decoder_inventory_manifest.get("surfaces", [])) == 71
    and len(a05_decoder_inventory_manifest.get("catchSites", [])) == 45
    and "def _decoder_catch_sites" in a05_decoder_inventory_tool
    and "unclassified persisted decoder files" in a05_decoder_inventory_tool
    and "stale decoder catch policies" in a05_decoder_inventory_tool
    and "A05_COLLECTION_REGISTRY" in a05_production_sweep
    and "cloudMutationCapability: 'NONE'" in a05_production_sweep
    and "DART_RECONCILIATION_REQUIRED" in a05_production_sweep
    and "unregistered-root-collection" in a05_production_sweep
    and "Rules root and nested collection names are all registered"
        in a05_production_sweep_test
    and "app and Functions source collection references are all registered"
        in a05_production_sweep_test
    and "assertRegistryCoversSource" in a05_production_sweep
    and "sourceDefinedCollections" in a05_production_sweep
    and "any supported operational record requires Dart reconciliation"
        in a05_production_sweep_test
    and "AUTHENTICATED_LOOPBACK_MEMORY_ONLY" in a05_production_sweep
    and "flutterToolsSnapshotCandidates" in a05_production_sweep
    and "rawProductionDataPersisted: false" in a05_production_sweep
    and "reconcileA05Envelope" in a05_reconciliation_bridge
    and "decodePersistedAuditEvent(data, documentId: documentId)"
        in a05_reconciliation_bridge
    and "readRemoteMaintenanceRecord(data, documentId: documentId)"
        in a05_reconciliation_bridge
    and "A05_BRIDGE_TOKEN" in a05_reconciliation_harness
    and "reconciles an in-memory production envelope through app readers"
        in a05_reconciliation_harness
    and "actual Dart readers reconcile valid audit and maintenance records in memory"
        in a05_production_sweep_test
    and "unsupported nonempty app collections remain fail closed"
        in a05_production_sweep_test
    and "Flutter bridge locates both wrapper and cached Dart SDK layouts"
        in a05_production_sweep_test
    and release_gate_source.count(
        "- name: A-05 read-only production sweep contracts"
    ) == 1
    and release_gate_source.index(
        "- name: A-05 read-only production sweep contracts"
    ) < release_gate_source.index("  android-package:")
    and "Set up Node 22 for A-05 reconciliation contracts"
        in release_gate_source
    and "Status: OPEN - SOURCE CLOSURE AWAITING OPERATIONAL EVIDENCE"
        in a05_decision_18
    and "unsupported or uninspected nonempty collection"
        in a05_decision_18
    and "is never treated as clean" in a05_decision_18,
    a05_decoder_inventory_process.stderr.strip(),
)
check(
    "A-05 BAF knowledge and alternate factory decoders fail closed",
    "readRemoteBafKnowledgeRow(map, docId)" in a05_baf_model
    and "readRemoteBafKnowledgeMeta(map)" in a05_baf_model
    and "readBafKnowledgeRawJson(" in a05_baf_model
    and "class RemoteBafKnowledgeRowData" in a05_baf_reader
    and "rowCode != documentId" in a05_baf_reader
    and "unsupported schema version" in a05_baf_reader
    and "cannot precede createdAt" in a05_baf_reader
    and "non-finite numbers are not supported" in a05_baf_reader
    and "unsupported persisted value" in a05_baf_reader
    and a05_baf_repository.count("on FirebaseException") == 2
    and ".catchError((_) => null)" not in a05_baf_repository
    and "await Future.wait<void>(<Future<void>>[" in a05_baf_repository
    and "baseQuery.get().then((value) => firstPage = value)"
        in a05_baf_repository
    and "_firestore.doc(metaPath).get().then((value) => metaDoc = value)"
        in a05_baf_repository
    and a05_baf_repository.index("await Future.wait<void>(<Future<void>>[")
        < a05_baf_repository.index(
            "while (true) {"
        )
    and "BafKnowledgeRow.fromCloudMap(doc.data(), doc.id).toEntry(i)"
        in a05_baf_repository
    and a05_baf_repository.index("final remotes = [")
        < a05_baf_repository.index("await _isar.writeTxn(() async {")
    and a05_baf_repository.index("final metaStore =")
        < a05_baf_repository.index("await _isar.writeTxn(() async {")
    and a05_baf_provider.count("BafKnowledgeRow.fromCloudMap(") == 2
    and "int _cloudVersionFrom(" not in a05_baf_provider
    and "DateTime.fromMillisecondsSinceEpoch(0" not in a05_workflow_pull
    and "readRequiredPersistedDateTime(" in a05_workflow_pull
    and "cursor.toIso8601String() != rawCursor" in global_pull_cursor
    and "every authority-critical field is required" in a05_baf_test
    and "workflow quarantine requires identity" in a05_baf_test
    and "repository and governance paths decode before mutation"
        in a05_baf_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_10
    and "13 classified decoder surfaces" in a05_decision_10
    and "durable counted quarantine and operator repair" in a05_decision_10
    and "does not inspect or mutate production documents" in a05_decision_10,
)
check(
    "A-05 operational directives retain exact persisted authority",
    "OperationalDirective readRemoteOperationalDirective(" in a05_directive_reader
    and "must match the document ID" in a05_directive_reader
    and "must match createdByUid" in a05_directive_reader
    and "readRequiredPersistedEnum(" in a05_directive_reader
    and a05_directive_reader.count("readRequiredPersistedBool(") == 3
    and "readRequiredPersistedInt(" in a05_directive_reader
    and "assetType and assetNumber must be present together"
        in a05_directive_reader
    and "acknowledgement actor and timestamp must be present together"
        in a05_directive_reader
    and "closure actor and timestamp must be present together"
        in a05_directive_reader
    and "must be present exactly when isDeleted is true"
        in a05_directive_reader
    and "readOptionalJsonObject(" in a05_directive_reader
    and "deleted directives require deletion actor authority"
        in a05_directive_reader
    and "readRemoteOperationalDirective(" in a05_directive_provider
    and "'firestoreId': firestoreId" in a05_directive_provider
    and "return d.toMap();" in a05_directive_provider
    and "_normalizeDirectiveFromRemote" not in a05_directive_provider
    and "_enumByNameOr" not in a05_directive_provider
    and "_directiveIntOrNull" not in a05_directive_provider
    and "every authority-bearing field is required" in a05_directive_test
    and "unknown enums and scalar coercions fail closed" in a05_directive_test
    and "malformed optional lists fail instead of disappearing"
        in a05_directive_test
    and "malformed present metadata JSON fails closed" in a05_directive_test
    and "incomplete or contradictory lifecycle state fails closed"
        in a05_directive_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_11
    and "writer now includes the" in a05_decision_11
    and "exact `firestoreId`" in a05_decision_11
    and "durable counted quarantine and operator repair" in a05_decision_11
    and "does not inspect or mutate production documents" in a05_decision_11,
)
check(
    "A-05 abnormalities retain exact persisted and local-save authority",
    "readRemoteAbnormalityType(map, documentId: documentId)"
        in a05_abnormality_model
    and "readRemoteChargeAbnormality(map, documentId: documentId)"
        in a05_abnormality_model
    and "_safeString" not in a05_abnormality_model
    and "_safeInt" not in a05_abnormality_model
    and "_safeBool" not in a05_abnormality_model
    and "_enumByNameOr" not in a05_abnormality_model
    and "AbnormalityType readRemoteAbnormalityType(" in a05_abnormality_reader
    and "ChargeAbnormality readRemoteChargeAbnormality("
        in a05_abnormality_reader
    and "must match the document ID" in a05_abnormality_reader
    and "required asset-type array without duplicates"
        in a05_abnormality_reader
    and "must not contain duplicate asset" in a05_abnormality_reader
    and "cannot precede createdAt" in a05_abnormality_reader
    and "cannot precede loggedAt" in a05_abnormality_reader
    and "completed status and target charge must be present together"
        in a05_abnormality_reader
    and "deleted abnormality types require deletion authority"
        in a05_abnormality_reader
    and "deleted abnormalities require a reason" in a05_abnormality_reader
    and "_validateTypeForSave(type)" in a05_abnormality_provider
    and "_validateAbnormalityForSave(abnormality)"
        in a05_abnormality_provider
    and "_ensureTypeDefaults" not in a05_abnormality_provider
    and "_ensureAbnormalityDefaults" not in a05_abnormality_provider
    and "Untitled Abnormality" not in a05_abnormality_provider
    and "Unknown Abnormality" not in a05_abnormality_provider
    and "No reason recorded" not in a05_abnormality_provider
    and "every authority-bearing type field is required"
        in a05_abnormality_test
    and "every authority-bearing charge field is required"
        in a05_abnormality_test
    and "malformed, aliased, duplicate, or oversized assets fail closed"
        in a05_abnormality_test
    and "malformed local asset JSON is not rewritten as empty state"
        in a05_abnormality_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_12
    and "durable counted quarantine and operator repair" in a05_decision_12
    and "does not inspect or mutate production documents" in a05_decision_12,
)
check(
    "A-05 template governance retains exact persisted and closure authority",
    "readRemoteTemplatePackage(map, documentId: documentId)"
        in a05_template_governance_model
    and "readRemoteTemplateVersion(map, documentId: documentId)"
        in a05_template_governance_model
    and "readRemoteTemplatePublishAudit(map, documentId: documentId)"
        in a05_template_governance_model
    and "TemplatePackage readRemoteTemplatePackage("
        in a05_template_governance_reader
    and "TemplateVersion readRemoteTemplateVersion("
        in a05_template_governance_reader
    and "TemplatePublishAudit readRemoteTemplatePublishAudit("
        in a05_template_governance_reader
    and "must match the document ID" in a05_template_governance_reader
    and "readRequiredJsonObject(" in a05_template_governance_reader
    and "readRequiredJsonObjectList(" in a05_template_governance_reader
    and "the five closure-review projection fields must exist together"
        in a05_template_governance_reader
    and "top-level closure review must match the frozen snapshot"
        in a05_template_governance_reader
    and "published closure-critical content requires review authority"
        in a05_template_governance_reader
    and "active packages cannot carry deletion state"
        in a05_template_governance_reader
    and "active versions cannot carry deletion state"
        in a05_template_governance_reader
    and "all four snapshot JSON fields are structurally strict"
        in a05_template_governance_test
    and "closure projection is complete, exact, and snapshot-bound"
        in a05_template_governance_test
    and "whole legacy closure projection may be derived, partial may not"
        in a05_template_governance_test
    and "factories and every Firestore page use the strict readers"
        in a05_template_governance_test
    and "arrow_offset" in a05_timestamp_inventory_tool
    and "unterminated expression-bodied reader"
        in a05_timestamp_inventory_tool
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_13
    and "durable counted quarantine and operator repair" in a05_decision_13
    and "does not inspect or mutate production documents" in a05_decision_13,
)
check(
    "A-05 module registry remote state is exact, hash-bound, and contained",
    "readRemoteModuleRegistryFamily(map, documentId: docId)"
        in a05_module_registry_model
    and "readRemoteModuleRegistryRevision(" in a05_module_registry_model
    and "ModuleRegistryFamily readRemoteModuleRegistryFamily("
        in a05_module_registry_reader
    and "ModuleRegistryRevision readRemoteModuleRegistryRevision("
        in a05_module_registry_reader
    and "must match the parent registry document ID"
        in a05_module_registry_reader
    and "stableModuleRegistryContentHashStrict("
        in a05_module_registry_reader
    and "does not match the canonical registry payload"
        in a05_module_registry_reader
    and "_enumByNameOr" not in a05_module_registry_model
    and "_cleanRequiredText" not in a05_module_registry_model
    and "_decodeJsonObject(" not in a05_module_registry_model
    and a05_module_registry_provider.count("ModuleRegistryRevision.fromMap(")
        == 10
    and "rejects manufactured identity, enum, list, bool, and counters"
        in a05_module_registry_test
    and "rejects malformed JSON roots, references, lineage, and hash"
        in a05_module_registry_test
    and "source contains no top-level registry manufacturing defaults"
        in a05_module_registry_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_14
    and "25 classified readers" in a05_decision_14
    and "35 direct `DateTime` parser and epoch-sentinel" in a05_decision_14
    and "`A-05` remains open" in a05_decision_14
    and "does not inspect or mutate production documents" in a05_decision_14,
)
check(
    "A-05 command responses and assignment replay chronology fail closed",
    "new Date(0).toISOString()" not in a05_assignment_backend
    and "assertReplayAssignedAt(" in a05_assignment_backend
    and "request-assigned-at-missing" in a05_assignment_backend
    and "request-assigned-at-invalid" in a05_assignment_backend
    and "request-assigned-at-mismatch" in a05_assignment_backend
    and "replay fails closed when assignment timestamp evidence is absent or corrupt"
        in a05_assignment_backend_test
    and "readRequiredPersistedDateTime(" in a05_assignment_response
    and "map['idempotentReplay'] is! bool" in a05_assignment_response
    and "mismatched JobExecution identities" in a05_assignment_response
    and "duplicate module identity" in a05_assignment_response
    and "requires exact callable response evidence fields"
        in a05_assignment_response_test
    and "requires assignment chronology to match the execution"
        in a05_assignment_response_test
    and "readRequiredPersistedDateTime(" in a05_authority_response
    and "non-string or non-canonical committedAt evidence fails closed"
        in a05_authority_response_test
    and "readRequiredPersistedDateTime(" in a05_abnormality_response
    and "non-string or non-canonical committedAt evidence fails closed"
        in a05_abnormality_response_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_15
    and "28 classified readers" in a05_decision_15
    and "32 direct `DateTime` parser and epoch-sentinel" in a05_decision_15
    and "does not inspect or mutate production documents" in a05_decision_15,
)
check(
    "A-05 workflow quarantine is durable before cursor advancement",
    "workflow-pull-cursor-invalid" in a05_workflow_pull
    and "workflow-pull-quarantine-invalid" in a05_workflow_pull
    and "workflow-pull-quarantine-write-failed" in a05_workflow_pull
    and "workflow-pull-cursor-write-failed" in a05_workflow_pull
    and "readRequiredPersistedDateTime(" in a05_workflow_pull
    and "await _appendQuarantine(prefs, collectionRecords);"
        in a05_workflow_pull
    and a05_workflow_pull.find(
        "await _appendQuarantine(prefs, collectionRecords);"
    ) < a05_workflow_pull.find("await _advance(prefs, key, observed);")
    and "_readStoredQuarantine(prefs, _preferenceReader);"
        in a05_workflow_pull
    and "!written || _preferenceReader(prefs, key) != value"
        in a05_workflow_pull
    and "_restorePreferenceAfterFailedWrite(" in a05_workflow_pull
    and "whereType<Map>()" not in a05_workflow_pull
    and "malformed local cursor blocks fetch" in a05_workflow_pull_test
    and "corrupt quarantine prevents cursor advance"
        in a05_workflow_pull_test
    and "corrupt quarantine is visible until explicitly cleared"
        in a05_workflow_pull_test
    and "failed quarantine write prevents cursor advance"
        in a05_workflow_pull_test
    and "readback mismatch prevents cursor advance"
        in a05_workflow_pull_test
    and "existing corrupt quarantine blocks valid-only cursor advance"
        in a05_workflow_pull_test
    and "Workflow diagnostics need repair" in ui_diagnostics_source
    and "Clear local log" in ui_diagnostics_source
    and "admin can repair only a corrupt workflow quarantine log"
        in ui_alignment_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_16
    and "29 classified readers" in a05_decision_16
    and "31 direct `DateTime` parser and epoch-sentinel" in a05_decision_16
    and "does not inspect or mutate production documents" in a05_decision_16,
)
check(
    "A-05 direct timestamp candidates are classified and weak decoders fail closed",
    a05_timestamp_inventory_report.get("result") == "PASS"
    and a05_timestamp_inventory_report.get("directParserCandidateCount") == 28
    and a05_timestamp_inventory_report.get(
        "unclassifiedDirectParserCandidates"
    ) == []
    and a05_timestamp_inventory_report.get(
        "staleDirectParserClassifications"
    ) == []
    and {
        entry.get("classification")
        for entry in a05_direct_timestamp_candidate_manifest.get(
            "classifications", []
        )
    }
    == {
        "STRICT_READER_IMPLEMENTATION",
        "FAIL_CLOSED_AUTHORITY_PARSER",
        "NON_PERSISTED_RUNTIME_SENTINEL",
        "TYPED_LOCAL_STORAGE_INITIALIZER",
        "SORT_ONLY_NULL_ORDERING_SENTINEL",
        "DISPLAY_ONLY_BEST_EFFORT",
    }
    and sum(
        len(entry.get("sites", []))
        for entry in a05_direct_timestamp_candidate_manifest.get(
            "classifications", []
        )
    ) == 28
    and "Timestamp(seconds, nanoseconds).toDate().toUtc()" in a05_reader
    and "on ArgumentError" in a05_reader
    and "'seconds': -62135596801" in a05_test
    and "'seconds': 253402300800" in a05_test
    and "allowSerializedTimestampMap: true" in a05_backend_release_identity
    and "DateTime? _parseDateTime(" not in a05_backend_release_identity
    and "malformed present deployment timestamps fail closed"
        in a05_backend_release_identity_test
    and "readOptionalPersistedDateTime(" in a05_template_snapshot_contract
    and "TemplateVersionSnapshotException(error.message)"
        in a05_template_snapshot_contract
    and "malformed present closure review timestamp fails closed"
        in a05_template_snapshot_test
    and "readRequiredPersistedDateTime(" in a05_template_lifecycle_sync
    and "DateTime.tryParse(" not in a05_template_lifecycle_sync
    and "snapshotMatcher, contains('readRequiredPersistedDateTime(')"
        in a05_template_lifecycle_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_17
    and "28 direct parser and epoch-sentinel sites" in a05_decision_17
    and "zero unclassified, duplicate, or stale sites" in a05_decision_17
    and "`A-05` remains open" in a05_decision_17
    and "does not inspect or mutate production documents" in a05_decision_17,
)
check(
    "A-05 historical persisted-state tranches retain their bounded authority",
    len(a05_records) == 1
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
    and "readRemoteMaintenanceRecord(" in a05_live_sync
    and "ComponentAction.readEncodedPayload(" in a05_remote_maintenance_reader
    and "readEncodedResolutionHistoryPayload("
        in a05_remote_maintenance_reader
    and "d['actionsJson']?.toString()" not in a05_live_sync
    and "_maintenanceEvidenceIntegrityError(record)" in a05_ticket_sync
    and "Saved evidence needs repair before correction" in a05_admin_browser
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
    and "canonicalizes aliases and writes payload schema version 1"
        in a05_response_test
    and "unregistered response extensions fail closed"
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
    and "TemplateVersionSnapshotBundle.fromRawJson(" in a05_composer_model
    and "TemplateComposerDraft.fromAuthoringPayloads" in a05_composer_model
    and "_decodeObject(" not in a05_composer_model
    and "Saved composer payload needs repair" in a05_composer_screen
    and a05_composer_actions.index(
        "selectedDraft = TemplateComposerDraft.fromAuthoringPayloads"
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
        "requireRemoteTombstoneDeletedAt(" in source
        for source in a05_tombstone_provider_sources.values()
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
    and "readRequiredPersistedDateTime(" in a05_module_registry_reader
    and "DateTime? _parseTimestamp" not in a05_timeline_registry_model
    and "_rejectUnsupportedRegistryTombstone"
        in a05_timeline_registry_model
    and "function validTemplateVersionTimeline()" in rules_source
    and "function validModuleRegistryRevisionTimeline()" in rules_source
    and "isPersistedTimestamp(" in rules_source
    and "Governance timeline needs repair" in a05_registry_authoring_screen
    and "_canMutate => _liveGovernanceActor != null && _error == null"
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
    and "readRequiredPersistedString(" in a05_user_model
    and "readRequiredPersistedDateTime(" in a05_user_model
    and "DateTime _parseDateTime" not in a05_user_model
    and "Profile needs repair" in a05_auth_gate
    and "canSeeTemplates" in a05_planned_work_screen
    and "const AsyncData<List<JobTemplate>>" in a05_planned_work_screen
    and "_hasLiveComposerAuthority" in a05_composer_support
    and "_liveGovernanceActor" in a05_registry_authoring_screen
    and "widget.actor" not in a05_registry_authoring_screen
    and "operations Work is task-first and hides governance templates"
        in a05_planned_work_test
    and "live role downgrade leaves the hidden template view immediately"
        in a05_planned_work_downgrade_test
    and "non-governor cannot load composer knowledge data"
        in a05_composer_live_test
    and "live role downgrade closes an initialized composer"
        in a05_composer_live_test
    and "live role downgrade closes loaded registry data"
        in a05_registry_screen_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_7
    and "`A-05` remains open" in a05_decision_7
    and "does not inspect or mutate production documents" in a05_decision_7
    and "class RemoteMaintenanceTimestamps" in a05_maintenance_timestamps
    and a05_maintenance_timestamps.count("readRequiredPersistedDateTime(") == 3
    and a05_maintenance_timestamps.count("readOptionalPersistedDateTime(") == 8
    and "readRemoteMaintenanceRecord(" in a05_maintenance_provider
    and "readRemoteMaintenanceRecord(" in a05_live_sync
    and "readRemoteMaintenanceTimestamps(" in a05_remote_maintenance_reader
    and "DateTime? _parseTimestamp" not in a05_maintenance_provider
    and "DateTime? _parseTimestamp" not in a05_live_sync
    and "final int sourceDocumentCount;" in a05_maintenance_provider
    and "final int decodeErrorCount;" in a05_maintenance_provider
    and "Every maintenance source document must be accounted for"
        in a05_maintenance_provider
    and "A non-empty maintenance source page must retain its Firestore cursor"
        in a05_maintenance_provider
    and "sourceDocumentCount: snap.docs.length" in a05_maintenance_provider
    and "decodeErrorCount: decodeErrorCount" in a05_maintenance_provider
    and "lastSkipped += result.decodeErrorCount" in a05_global_pull_maintenance
    and "_hadRecordProcessingError = true" in a05_global_pull_maintenance
    and "result.sourceDocumentCount == 0" in a05_global_pull_maintenance
    and "result.sourceDocumentCount < GlobalPullService._pageSize"
        in a05_global_pull_maintenance
    and "Last live error" in a05_sync_status_indicator
    and "missing or malformed required timestamps fail closed"
        in a05_timestamp_test
    and "malformed present optional timestamps fail closed"
        in a05_timestamp_test
    and "page accounting rejects inconsistent counts and cursors"
        in a05_timestamp_test
    and "source paths share strict decoding and contain bad pull pages"
        in a05_timestamp_test
    and "Status: OPEN - PARTIAL SOURCE REMEDIATION" in a05_decision_8
    and "cannot advance past a quarantined document" in a05_decision_8
    and "`A-05` remains open" in a05_decision_8
    and "does not inspect or mutate production documents" in a05_decision_8
    and recon.get("counts", {}).get("BYTE_IDENTICAL") == 172
    and recon.get("counts", {}).get("SUCCESSOR_MODIFIED") == 238
    and all(
        row_map.get(path, {}).get("disposition") == "SUCCESSOR_MODIFIED"
        for path in a05_reconciliation_corrections
    )
    and all(
        row_map.get(path, {}).get("disposition") == "SUCCESSOR_MODIFIED"
        for path in a05_source_delta_paths
    ),
)
check(
    "A-05 closes on exact source, CI, production and local-generation authority",
    a05_record.get("currentStatus") == "CLOSED"
    and a05_history == ["OPEN", "SOURCE_IMPLEMENTED", "MERGED", "CLOSED"]
    and len(a05_evidence) == 1
    and a05_evidence[0].get("evidenceFile")
        == "release/evidence/a05-persisted-state-integrity-closure.json"
    and a05_evidence[0].get("evidenceSha256") == sha(a05_closure_path)
    and a05_evidence[0].get("inventoryAndDecoderPullRequest") == 204
    and a05_evidence[0].get("reconciliationPullRequest") == 205
    and a05_evidence[0].get("reconciliationHeadCommit")
        == "dc9f0c94a6f4dbed0b18f3345cac8d2560deb8e1"
    and a05_evidence[0].get("reconciliationSourceTree")
        == "7f003322ed68856c0b941ba276fd6a31aedb986c"
    and a05_evidence[0].get("reconciliationMergeCommit")
        == "3b517d7d72efb629ace4b7348e6839a60e7f40d0"
    and a05_evidence[0].get("pullRequestWorkflowRun") == 31622397485
    and a05_evidence[0].get("postMergeWorkflowRun") == 31623568710
    and a05_evidence[0].get("localGenerationRevalidationPullRequest") == 206
    and a05_evidence[0].get("localGenerationRevalidationHeadCommit")
        == "ed8b8fb0655d2fb5396f10daecb3e6ab49966342"
    and a05_evidence[0].get("localGenerationRevalidationSourceTree")
        == "98af51decc0c4b2fe9257d66dcb4de4766aa1cfd"
    and a05_evidence[0].get("localGenerationRevalidationWorkflowRun")
        == 31628102225
    and a05_evidence[0].get("localGenerationRevalidationWorkflowJob")
        == 94219670718
    and a05_evidence[0].get("remediatedA05RegressionPassedCount") == 137
    and a05_evidence[0].get("supportedLocalGenerationFixturePassedCount") == 4
    and a05_evidence[0].get("productionBlockingFindingCount") == 0
    and a05_evidence[0].get("productionWarningCount") == 0
    and a05_evidence[0].get("decision")
        == "PASS_A05_PERSISTED_STATE_INTEGRITY_CLOSURE"
    and a05_closure.get("schemaVersion") == 1
    and a05_closure.get("findingIds") == ["A-05"]
    and a05_closure.get("authorityType") == "SOURCE_AND_CI"
    and a05_closure.get("decision")
        == "PASS_A05_PERSISTED_STATE_INTEGRITY_CLOSURE"
    and a05_closure.get("machineInventory", {}).get("decoderSurfaceCount")
        == 39
    and a05_closure.get("machineInventory", {}).get("decoderCatchSiteCount")
        == 36
    and a05_closure.get("machineInventory", {}).get("timestampReaderCount")
        == 32
    and a05_closure.get("machineInventory", {}).get(
        "directTimestampCandidateCount"
    ) == 28
    and a05_closure.get("machineInventory", {}).get("riskCandidateCount")
        == 234
    and a05_closure.get("machineInventory", {}).get("unclassifiedCount") == 0
    and a05_closure.get("machineInventory", {}).get("stalePolicyCount") == 0
    and a05_production_reconciliation.get("decision")
        == "PASS_A05_READ_ONLY_PRODUCTION_RECONCILIATION"
    and a05_production_reconciliation.get("sourceCommit")
        == "3b517d7d72efb629ace4b7348e6839a60e7f40d0"
    and a05_production_reconciliation.get("sourceTree")
        == "7f003322ed68856c0b941ba276fd6a31aedb986c"
    and a05_production_reconciliation.get("cleanFetchedMain") is True
    and a05_production_reconciliation.get("readOnly") is True
    and a05_production_reconciliation.get("cloudMutationCapability") == "NONE"
    and a05_production_reconciliation.get("rawIdentifiersEmitted") is False
    and a05_production_reconciliation.get("rawDocumentDataPersisted") is False
    and a05_production_reconciliation.get("unregisteredRootCollectionCount")
        == 0
    and a05_production_reconciliation.get("blockingFindingCount") == 0
    and a05_production_reconciliation.get("warningCount") == 0
    and a05_production_reconciliation.get("strictReaderAttemptedCount") == 9
    and a05_production_reconciliation.get("strictReaderPassedCount") == 9
    and a05_production_reconciliation.get("strictReaderFailedCount") == 0
    and a05_local_generation.get("evidenceSha256")
        == sha(local_recovery_closure_path)
    and a05_local_generation.get("decision")
        == "PASS_70K_RECOVERY_AND_P06_CLOSURE"
    and a05_local_generation.get("installedTargetCount") == 2
    and a05_local_generation.get("nativeStoreTestsPassed") == 21
    and a05_local_generation.get("nativeStoreTestsFailed") == 0
    and a05_local_generation.get("cloudReconciliationPassedOnEveryTarget")
        is True
    and a05_current_source_revalidation.get("repository")
        == "abhishekvatsa/crm3_baf_ops"
    and a05_current_source_revalidation.get("pullRequest") == 206
    and a05_current_source_revalidation.get("sourceCommit")
        == "ed8b8fb0655d2fb5396f10daecb3e6ab49966342"
    and a05_current_source_revalidation.get("sourceTree")
        == "98af51decc0c4b2fe9257d66dcb4de4766aa1cfd"
    and a05_current_source_revalidation.get("workflowRun") == 31628102225
    and a05_current_source_revalidation.get("workflowJob") == 94219670718
    and a05_current_source_revalidation.get("workflowJobName")
        == "Flutter host analysis + tests + no-loss contracts"
    and a05_current_source_revalidation.get("conclusion") == "success"
    and a05_current_source_revalidation.get("sameCheckout") is True
    and a05_current_source_revalidation.get(
        "remediatedA05RegressionFileCount"
    ) == 18
    and a05_current_source_revalidation.get(
        "remediatedA05RegressionPassedCount"
    ) == 137
    and a05_current_source_revalidation.get(
        "supportedLocalGenerationFixturePassedCount"
    ) == 4
    and a05_current_source_revalidation.get(
        "supportedLocalGenerationFixtureFailedCount"
    ) == 0
    and a05_current_source_revalidation.get("fixtureFile")
        == "test/70k_isar_populated_migration_fixture_test.dart"
    and len(a05_current_source_revalidation.get("fixtureDispositions", [])) == 4
    and a05_current_source_revalidation.get(
        "integratedRepairDisposition", {}
    ).get("disposition") == "PRESERVE_AND_BLOCK_PENDING_REPAIR"
    and a05_current_source_revalidation.get(
        "integratedRepairDisposition", {}
    ).get("malformedField") == "asset"
    and a05_current_source_revalidation.get(
        "integratedRepairDisposition", {}
    ).get("rawPayloadPreserved") is True
    and a05_current_source_revalidation.get(
        "integratedRepairDisposition", {}
    ).get("repairStateExposed") is True
    and a05_current_source_revalidation.get(
        "integratedRepairDisposition", {}
    ).get("authoritativeReadRejected") is True
    and a05_current_source_revalidation.get(
        "integratedRepairDisposition", {}
    ).get("silentRewritePerformed") is False
    and "rather than being reinterpreted as Firestore documents"
        in a05_current_source_revalidation.get("authorityBoundary", "")
    and a05_pr_ci.get("runId") == 31622397485
    and a05_pr_ci.get("headSha")
        == "dc9f0c94a6f4dbed0b18f3345cac8d2560deb8e1"
    and a05_pr_ci.get("conclusion") == "success"
    and a05_postmerge_ci.get("runId") == 31623568710
    and a05_postmerge_ci.get("headSha")
        == "3b517d7d72efb629ace4b7348e6839a60e7f40d0"
    and a05_postmerge_ci.get("conclusion") == "success"
    and all(
        {
            job.get("name")
            for job in section.get("jobs", [])
            if isinstance(job, dict)
        } == a05_expected_jobs
        and all(
            job.get("conclusion") == "success"
            for job in section.get("jobs", [])
            if isinstance(job, dict)
        )
        for section in (a05_pr_ci, a05_postmerge_ci)
    )
    and a05_closure_boundary.get("a05ClosureAuthorized") is True
    and all(
        value is False
        for key, value in a05_closure_boundary.items()
        if key != "a05ClosureAuthorized"
    )
    and "Status: CLOSED" in a05_closure_decision
    and "PASS_A05_PERSISTED_STATE_INTEGRITY_CLOSURE"
        in a05_closure_decision
    and "Current-source local-generation authority" in a05_closure_decision
    and "137 A-05" in a05_closure_decision
    and "all four governed local-generation fixtures"
        in a05_closure_decision
    and "PRESERVE_AND_BLOCK_PENDING_REPAIR" in a05_closure_decision
    and "not re-created or\nreinterpreted as current-source proof"
        in a05_closure_decision
    and "closes only A-05" in a05_closure_decision,
)

lr07_policy = data(
    "release/lr07-distribution-installation-readback-policy.json"
)
lr07_collector = text(
    "tools/release/collectDistributionInstallationReadback.js"
)
lr07_containment = text(
    "tools/release/containGitHubProductionArtifacts.js"
)
lr07_collector_test = text(
    "tools/release/collectDistributionInstallationReadback.test.mjs"
)
lr07_containment_test = text(
    "tools/release/containGitHubProductionArtifacts.test.mjs"
)
lr07_contract = text(
    "test/lr07_distribution_installation_readback_source_contract_test.dart"
)
lr07_decision = text(
    "docs/v4_2_r1/LR07_DISTRIBUTION_INSTALLATION_READBACK.md"
)
lr07_workflow = text(".github/workflows/production-artifact.yml")
lr07_release_gate = text(".github/workflows/release-gate.yml")
lr07_package = data("package.json")
lr07_ledger = data("governance/programme-ledger.json")
lr07_containment_evidence_path = (
    "release/evidence/lr07-public-production-artifact-containment.json"
)
lr07_readback_evidence_path = (
    "release/evidence/lr07-distribution-installation-live-readback.json"
)
lr07_closure_evidence_path = (
    "release/evidence/lr07-distribution-installation-live-readback-closure.json"
)
lr07_build11_containment_evidence_path = (
    "release/evidence/lr07-public-production-artifact-containment-builds9-11.json"
)
lr07_build11_readback_evidence_path = (
    "release/evidence/lr07-distribution-installation-live-readback-build11.json"
)
lr07_final_promotion_evidence_path = (
    "release/evidence/stage2d-f6-build11-controlled-pilot-authorization.json"
)
lr07_containment_evidence = data(lr07_containment_evidence_path)
lr07_readback_evidence = data(lr07_readback_evidence_path)
lr07_closure_evidence = data(lr07_closure_evidence_path)
lr07_build11_containment_evidence = data(
    lr07_build11_containment_evidence_path
)
lr07_build11_readback_evidence = data(lr07_build11_readback_evidence_path)
lr07_final_promotion_evidence = data(lr07_final_promotion_evidence_path)
lr07_records = [
    record
    for record in lr07_ledger.get("programmeGates", [])
    if record.get("gateId") == "LR-07"
]
lr07_record = lr07_records[0] if len(lr07_records) == 1 else {}
lr07_stage2d_f6_record = next(
    (
        record
        for record in lr07_ledger.get("programmeGates", [])
        if record.get("gateId") == "STAGE2D-F6"
    ),
    {},
)
lr07_artifacts = lr07_policy.get("expectedArtifactsForContainment", [])
lr07_source_evidence = lr07_policy.get("sourceEvidence", [])
lr07_latest_artifact = max(
    lr07_artifacts,
    key=lambda entry: entry.get("buildNumber", -1),
    default={},
)
lr07_latest_completed_artifact = max(
    [
        entry
        for entry in lr07_artifacts
        if entry.get("dualCustodyCompleted") is True
    ],
    key=lambda entry: entry.get("buildNumber", -1),
    default={},
)
lr07_completion_authority = next(
    (
        entry
        for entry in lr07_source_evidence
        if entry.get("path")
        == (
            "release/evidence/build-"
            f"{lr07_latest_completed_artifact.get('buildNumber')}"
            "-finalization-closure.json"
        )
    ),
    {},
)
lr07_latest_authority = next(
    (
        entry
        for entry in lr07_source_evidence
        if entry.get("path")
        == lr07_latest_artifact.get(
            "authorityReceiptPath",
            (
                "release/evidence/build-"
                f"{lr07_latest_artifact.get('buildNumber')}"
                "-finalization-closure.json"
            ),
        )
    ),
    {},
)
lr07_finalization = combined_policy.get("finalization", {})
lr07_current_build = combined_policy.get("release", {}).get("buildNumber")
if (
    lr07_finalization.get("status") == "completed-non-distributable"
    and lr07_current_build == lr07_latest_completed_artifact.get("buildNumber")
):
    lr07_preserved_finalization = {
        **lr07_finalization,
        "buildNumber": lr07_current_build,
    }
elif (
    lr07_finalization.get("status") == "pending-source-authorized"
    and isinstance(lr07_current_build, int)
    and lr07_current_build > lr07_latest_completed_artifact.get(
        "buildNumber", -1
    )
):
    lr07_preserved_finalization = lr07_finalization.get(
        "priorCompletedBuild", {}
    )
else:
    lr07_preserved_finalization = {}
lr07_failed_attempt = next(
    (
        entry
        for entry in lr07_finalization.get("historicalFailedAttempts", [])
        if entry.get("buildNumber") == 10
    ),
    {},
)
lr07_failed_artifact = next(
    (
        entry
        for entry in lr07_artifacts
        if entry.get("buildNumber") == 10
    ),
    {},
)
lr07_failed_authority = next(
    (
        entry
        for entry in lr07_source_evidence
        if entry.get("path") == lr07_failed_artifact.get("authorityReceiptPath")
    ),
    {},
)
lr07_latest_ledger = next(
    (
        entry
        for entry in build_number_ledger.get("entries", [])
        if entry.get("buildNumber") == lr07_latest_artifact.get("buildNumber")
    ),
    {},
)
lr07_successor_ledger = [
    entry
    for entry in build_number_ledger.get("entries", [])
    if entry.get("buildNumber", -1)
    > lr07_latest_artifact.get("buildNumber", -1)
]
check(
    "LR-07 Builds 9 through 14 remain exact after separate closure adjudication",
    lr07_policy.get("schemaVersion") == 1
    and lr07_policy.get("policyId")
        == "LR07-DISTRIBUTION-INSTALLATION-READBACK-POLICY-V1"
    and lr07_policy.get("repository") == "abhishekvatsa/crm3_baf_ops"
    and lr07_policy.get("productionProjectId") == "crm3-baf-ops-b8638"
    and lr07_policy.get("expectedRepositoryVisibility") == "PUBLIC"
    and lr07_policy.get("workflow", {}).get(
        "requiredArtifactRetentionDays"
    ) == 1
    and len(lr07_artifacts) == 11
    and [entry.get("buildNumber") for entry in lr07_artifacts]
        == [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
    and {entry.get("id") for entry in lr07_artifacts}
        == {
            8711253816,
            8730747624,
            8771948980,
            8836687771,
            8866525607,
            9116320474,
            9122790773,
            9125100777,
            9307950694,
            9468702427,
            9475994815,
        }
    and sum(entry.get("sizeBytes", 0) for entry in lr07_artifacts)
        == 1653392550
    and sum(
        1
        for entry in lr07_artifacts
        if entry.get("dualCustodyCompleted") is True
    ) == 9
    and lr07_policy.get("installationReceipt", {}).get("bytes") == 8119
    and lr07_policy.get("installationReceipt", {}).get("sha256")
        == "4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC"
    and lr07_policy.get("strictReadback", {}).get(
        "requiredGitHubReleaseCount"
    ) == 0
    and lr07_policy.get("strictReadback", {}).get(
        "requiredLiveProductionArtifactCount"
    ) == 0
    and lr07_policy.get("executionAuthority", {}).get(
        "artifactDeletionRequiresExplicitOwnerApproval"
    ) is True
    and lr07_policy.get("executionAuthority", {}).get(
        "requiredOwnerApprovalPhrase"
    )
        == "APPROVE-LR07-DELETE-EXACT-ARTIFACTS-9475994815"
    and lr07_policy.get("executionAuthority", {}).get(
        "requiredPresentArtifactIds"
    ) == [9475994815]
    and lr07_policy.get("executionAuthority", {}).get(
        "deleteOnlyExactArtifactIds"
    ) is True
    and any(
        entry.get("path") == ".github/workflows/production-artifact.yml"
        for entry in lr07_source_evidence
    )
    and all(
        (ROOT / entry.get("path", "")).is_file()
        and (ROOT / entry["path"]).stat().st_size == entry.get("bytes")
        and sha(ROOT / entry["path"]) == entry.get("sha256")
        for entry in lr07_source_evidence
        if entry.get("path") not in {
            "release/production-release-policy.json",
            "release/build-number-ledger.json",
        }
    )
    and any(
        entry.get("path") == "release/production-release-policy.json"
        and entry.get("bytes") == 12767
        and entry.get("sha256")
            == "7CA3B2EB15764B049FB8E6072842527F46A0912A7F144BBDFFD82961B23AB97F"
        for entry in lr07_source_evidence
    )
    and any(
        entry.get("path") == "release/build-number-ledger.json"
        and entry.get("bytes") == 39295
        and entry.get("sha256")
            == "BAB08693B3182A28D3CC5EF840A96C4D2FE124418FD213876818A8CAD00F4E46"
        for entry in lr07_source_evidence
    )
    and lr07_preserved_finalization.get("buildNumber")
        == lr07_latest_completed_artifact.get("buildNumber") == 14
    and lr07_preserved_finalization.get("status")
        == "completed-non-distributable"
    and lr07_preserved_finalization.get("completionReceiptFile")
        == lr07_completion_authority.get("path")
    and lr07_preserved_finalization.get("completionReceiptSha256")
        == lr07_completion_authority.get("sha256")
    and lr07_preserved_finalization.get("sourceCommit")
        == lr07_latest_completed_artifact.get("headSha")
    and lr07_preserved_finalization.get("githubRunId")
        == lr07_latest_completed_artifact.get("workflowRunId")
    and lr07_preserved_finalization.get("governedPackageSha256")
        == lr07_latest_completed_artifact.get("governedPackageSha256")
    and lr07_preserved_finalization.get("dualCustodyCompleted") is True
    and lr07_failed_attempt.get("buildNumber")
        == lr07_failed_artifact.get("buildNumber") == 10
    and lr07_failed_attempt.get("status") == "blocked-non-distributable"
    and lr07_failed_attempt.get("evidenceFile")
        == lr07_failed_authority.get("path")
    and lr07_failed_attempt.get("evidenceSha256")
        == lr07_failed_authority.get("sha256")
    and lr07_failed_attempt.get("sourceCommit")
        == lr07_failed_artifact.get("headSha")
    and lr07_failed_attempt.get("githubRunId")
        == lr07_failed_artifact.get("workflowRunId")
    and lr07_failed_attempt.get("githubArtifactId")
        == lr07_failed_artifact.get("id")
    and lr07_failed_attempt.get("githubArtifactDigest")
        == lr07_failed_artifact.get("digest")
    and lr07_failed_attempt.get("governedPackageSha256")
        == lr07_failed_artifact.get("governedPackageSha256")
    and lr07_failed_attempt.get("independentVerificationCompleted") is True
    and lr07_failed_attempt.get("dualCustodyCompleted") is False
    and lr07_failed_attempt.get("distributionPerformed") is False
    and lr07_latest_ledger.get("githubArtifactId")
        == lr07_latest_artifact.get("id")
    and lr07_latest_ledger.get("githubArtifactName")
        == lr07_latest_artifact.get("name")
    and lr07_latest_ledger.get("githubArtifactSizeBytes")
        == lr07_latest_artifact.get("sizeBytes")
    and lr07_latest_ledger.get("githubArtifactDigest")
        == lr07_latest_artifact.get("digest")
    and lr07_latest_ledger.get("githubRunId")
        == lr07_latest_artifact.get("workflowRunId")
    and lr07_latest_ledger.get("remoteReservationCommit")
        == lr07_latest_artifact.get("headSha")
    and lr07_latest_ledger.get("disposition")
        == lr07_latest_artifact.get("ledgerDisposition")
    and lr07_latest_ledger.get("dualCustodyCompleted") is True
    and lr07_latest_ledger.get("distributionPerformed") is False
    and lr07_current_build == 15
    and len(lr07_successor_ledger) == 1
    and lr07_successor_ledger[0].get("buildNumber") == 15
    and lr07_successor_ledger[0].get("status")
        == "source-reserved-awaiting-remote-consumption"
    and all(
        field not in lr07_successor_ledger[0]
        for field in (
            "remoteReservationTagObject",
            "remoteBuiltTagObject",
            "githubRunId",
            "githubArtifactId",
            "governedPackageSha256",
        )
    )
    and combined_policy.get("distribution", {}).get("authority")
        == "exact-build11-sealed-small-group-pilot"
    and combined_policy.get("distribution", {}).get("approved") is True
    and combined_policy.get("distribution", {}).get("approvedBuildNumber") == 11
    and combined_policy.get("distribution", {}).get("approvedPackageSha256")
        == "104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970"
    and combined_policy.get("distribution", {}).get("pilotHandoutPerformed")
        is False
    and combined_policy.get("distribution", {}).get(
        "unrestrictedPlantReleaseApproved"
    ) is False
    and combined_policy.get("distribution", {}).get(
        "postBuildPromotionRequiredForAnyDistribution"
    ) is True
    and combined_policy.get("postBuildPromotion", {}).get("status")
        == "completed-controlled-pilot-only"
    and combined_policy.get("postBuildPromotion", {}).get(
        "promotionReceiptSha256"
    ) == "878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400"
    and combined_policy.get("artifactConstructionBoundary", {}).get("authority")
        == "production-signed-pre-release-candidate"
    and combined_policy.get("artifactConstructionBoundary", {}).get(
        "distributionApproved"
    ) is False
    and combined_policy.get("artifactConstructionBoundary", {}).get(
        "controlledPilotApproved"
    ) is False
    and combined_policy.get("artifactConstructionBoundary", {}).get(
        "postBuildPromotionRequiredForAnyDistribution"
    ) is True
    and "artifactConstructionBoundary" in lr07_workflow
    and "artifactConstructionBoundary" in text(
        "tools/release/New-ProductionArtifact.ps1"
    )
    and "artifactConstructionBoundary" in text(
        "tools/release/Test-ProductionReleaseManifest.ps1"
    )
    and "promotedReceiptBuild" in lr07_collector
    and "retention-days: 1" in lr07_workflow
    and "retention-days: 90" not in lr07_workflow
    and "npm run test:distribution-readback-custody" in lr07_release_gate
    and "collectDistributionInstallationReadback.test.mjs"
        in lr07_package.get("scripts", {}).get(
            "test:distribution-readback-custody", ""
        )
    and "containGitHubProductionArtifacts.test.mjs"
        in lr07_package.get("scripts", {}).get(
            "test:distribution-readback-custody", ""
        )
    and "liveProductionArtifactInventoryEmpty" in lr07_collector
    and "githubReleaseInventoryEmpty" in lr07_collector
    and "externalInstallationReceiptExact" in lr07_collector
    and "selectProductionArtifacts" in lr07_collector
    and "productionWorkflowRuns" in lr07_collector
    and "collectorAuthorizesClosure: false" in lr07_collector
    and 'flag: "wx"' in lr07_collector
    and "artifactDeletionRequiresExplicitOwnerApproval" in lr07_containment
    and "--owner-approval" in lr07_containment
    and "actions/artifacts/${artifact.id}" in lr07_containment
    and "inventoryAfter.length !== 0" in lr07_containment
    and "actions/runs/${artifact.id}" not in lr07_containment
    and "strict readback passes only" in lr07_collector_test
    and "preserved latest authority admits only a source-reserved successor"
        in lr07_collector_test
    and "completed successor still requires every retained failed-attempt receipt"
        in lr07_collector_test
    and "historicalFailedAttemptsExact" in lr07_collector
    and "summarizeMutableSourceAuthority" in lr07_collector
    and "discovered by workflow run instead of filename"
        in lr07_collector_test
    and "sealed exact preflight" in lr07_containment_test
    and "requiredPresentArtifactIds" in lr07_containment
    and "strict readback remains non-closing" in lr07_contract
    and "collector itself does not close `LR-07`" in lr07_decision
    and "Status: CLOSED - EXACT BUILD 11 SEALED PILOT AUTHORIZED"
        in lr07_decision
    and lr07_containment_evidence.get("decision")
        == "PASS_LR07_PUBLIC_PRODUCTION_ARTIFACTS_CONTAINED"
    and lr07_containment_evidence.get("source", {}).get("commit")
        == "02731af8a79f0da4a731ff9f28eb96df10458eef"
    and lr07_containment_evidence.get("source", {}).get("tree")
        == "44f657df6ffe54b885f5c994d8a604c7255089c4"
    and lr07_containment_evidence.get("inventoryBefore", {}).get("count")
        == 5
    and lr07_containment_evidence.get("inventoryBefore", {}).get(
        "totalBytes"
    ) == 765143034
    and lr07_containment_evidence.get("result", {}).get("deletedNow")
        == [8711253816, 8730747624, 8771948980, 8836687771, 8866525607]
    and lr07_containment_evidence.get("result", {}).get(
        "remainingProductionArtifactCount"
    ) == 0
    and lr07_containment_evidence.get("result", {}).get(
        "ownerApprovalAcknowledged"
    ) is True
    and lr07_containment_evidence.get("result", {}).get(
        "workflowRunsPreserved"
    ) is True
    and lr07_containment_evidence.get("externalReceipts", {}).get(
        "preflight", {}
    ).get("fileSha256")
        == "374DE3E58E368545F4806B069F5D0DBEF109D51786AD0E1466C1464EF8585820"
    and lr07_containment_evidence.get("externalReceipts", {}).get(
        "containment", {}
    ).get("fileSha256")
        == "07EA164C0B2D7E281DAAFFD3BCB7B3E1921702D7E3769AEBAD8192AD3E2A55CD"
    and lr07_readback_evidence.get("decision")
        == "PASS_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK"
    and lr07_readback_evidence.get("mode") == "STRICT"
    and lr07_readback_evidence.get("externalReceipt", {}).get("fileSha256")
        == "1EEE0A26D02E73BB4F26090E18CDFC4709C37FF6BB7ABF4F53C8D43181AA3AB2"
    and lr07_readback_evidence.get("source", {}).get("before")
        == lr07_readback_evidence.get("source", {}).get("after")
    and lr07_readback_evidence.get("outputs", {}).get("live", {}).get(
        "productionWorkflowRunCount"
    ) == 9
    and lr07_readback_evidence.get("outputs", {}).get("live", {}).get(
        "productionArtifactCount"
    ) == 0
    and lr07_readback_evidence.get("outputs", {}).get("live", {}).get(
        "githubReleaseCount"
    ) == 0
    and lr07_readback_evidence.get("outputs", {}).get("installation", {}).get(
        "fileSha256"
    ) == "4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC"
    and lr07_readback_evidence.get("outputs", {}).get("installation", {}).get(
        "physicalDevice"
    ) is True
    and all(lr07_readback_evidence.get("checks", {}).values())
    and lr07_readback_evidence.get("failedChecks") == []
    and lr07_readback_evidence.get("closureScope", {}).get(
        "collectorAuthorizesClosure"
    ) is False
    and lr07_readback_evidence.get("closureScope", {}).get(
        "separateAdjudicationRequired"
    ) is True
    and lr07_closure_evidence.get("decision")
        == "PASS_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK_CLOSURE"
    and lr07_closure_evidence.get("collectorAuthority", {}).get(
        "pullRequest"
    ) == 169
    and lr07_closure_evidence.get("collectorAuthority", {}).get(
        "sourceTree"
    ) == lr07_closure_evidence.get("collectorAuthority", {}).get("mergeTree")
    and lr07_closure_evidence.get("collectorAuthority", {}).get(
        "pullRequestCi", {}
    ).get("runId") == 31087258758
    and lr07_closure_evidence.get("collectorAuthority", {}).get(
        "postMergeCi", {}
    ).get("runId") == 31088013593
    and sha(ROOT / lr07_containment_evidence_path)
        == "B4124F0EF65CD07D6F3F4093FA0EF7672A69421724E11A3A4CD1CEF734DD27FD"
    and sha(ROOT / lr07_readback_evidence_path)
        == "27D77748B060959D0508209911A700E5267A5218F776347543F215B837850854"
    and sha(ROOT / lr07_closure_evidence_path)
        == "7E440D6DCB826607FED4D7F4FF5332A816302571F294D3F6620206EFC5AD4089"
    and all(
        value is False
        for value in lr07_closure_evidence.get("closureBoundary", {}).values()
    )
    and len(lr07_records) == 1
    and lr07_record.get("currentStatus") == "CLOSED"
    and lr07_record.get("authorization") == "CLOSED_PASS"
    and len(lr07_record.get("evidence", [])) == 6
    and {
        entry.get("sha256") for entry in lr07_record.get("evidence", [])
    } == {
        "B4124F0EF65CD07D6F3F4093FA0EF7672A69421724E11A3A4CD1CEF734DD27FD",
        "27D77748B060959D0508209911A700E5267A5218F776347543F215B837850854",
        "7E440D6DCB826607FED4D7F4FF5332A816302571F294D3F6620206EFC5AD4089",
        "D873651F251923D75DE34687600051C36C99E6B17E0662C023D2E7D2B04F9258",
        "A1BB0DD539B68A782BFDA3C2D9DBA3D003C65333EA5FF5FD4054EFC192667517",
        "878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400",
    }
    and len(lr07_record.get("requiredExitEvidence", [])) == 6
    and len(lr07_record.get("reArmTriggers", [])) == 7
    and len(lr07_record.get("notes", [])) == 10
    and [entry.get("status") for entry in lr07_record.get("statusHistory", [])]
        == [
            "OPEN",
            "LIVE_READBACK_PROVED",
            "CLOSED",
            "OPEN",
            "LIVE_READBACK_PROVED",
            "CLOSED",
        ]
    and lr07_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and lr07_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
)

check(
    "LR-07 Builds 9-11 containment and readback remain historically non-closing by themselves",
    sha(ROOT / lr07_build11_containment_evidence_path)
        == "D873651F251923D75DE34687600051C36C99E6B17E0662C023D2E7D2B04F9258"
    and lr07_build11_containment_evidence.get("decision")
        == "PASS_LR07_BUILDS_9_10_11_PUBLIC_PRODUCTION_ARTIFACTS_CONTAINED"
    and lr07_build11_containment_evidence.get("source", {}).get("commit")
        == "1fdc68e4fdb6caf301cde0946505d071e5bed0ed"
    and lr07_build11_containment_evidence.get("source", {}).get("originMain")
        == "1fdc68e4fdb6caf301cde0946505d071e5bed0ed"
    and lr07_build11_containment_evidence.get("source", {}).get(
        "governedWorktreeClean"
    ) is True
    and lr07_build11_containment_evidence.get("inventoryBefore", {}).get(
        "count"
    ) == 3
    and lr07_build11_containment_evidence.get("inventoryBefore", {}).get(
        "totalBytes"
    ) == 431389958
    and lr07_build11_containment_evidence.get("inventoryBefore", {}).get(
        "artifactIds"
    ) == [9116320474, 9122790773, 9125100777]
    and lr07_build11_containment_evidence.get("result", {}).get("deletedNow")
        == [9116320474, 9122790773, 9125100777]
    and lr07_build11_containment_evidence.get("result", {}).get(
        "remainingProductionArtifactCount"
    ) == 0
    and lr07_build11_containment_evidence.get("result", {}).get(
        "workflowRunsPreserved"
    ) is True
    and lr07_build11_containment_evidence.get("externalReceipts", {}).get(
        "preflight", {}
    ).get("receiptSha256")
        == "f51be14f8d7ac8ff2046c82b2b9ac90951e08992132e0006b3adc52199208a43"
    and lr07_build11_containment_evidence.get("externalReceipts", {}).get(
        "containment", {}
    ).get("receiptSha256")
        == "bb94e2240df836699fd6a95baa508c6f6513d8584ab6cff2483a812f651aef36"
    and lr07_build11_containment_evidence.get("mutationBoundary", {}).get(
        "githubArtifactsDeleted"
    ) is True
    and lr07_build11_containment_evidence.get("mutationBoundary", {}).get(
        "githubArtifactDeleteCount"
    ) == 3
    and all(
        value is False
        for key, value in lr07_build11_containment_evidence.get(
            "mutationBoundary", {}
        ).items()
        if key not in {"githubArtifactsDeleted", "githubArtifactDeleteCount"}
    )
    and all(
        value is False
        for value in lr07_build11_containment_evidence.get(
            "privacyBoundary", {}
        ).values()
    )
    and sha(ROOT / lr07_build11_readback_evidence_path)
        == "A1BB0DD539B68A782BFDA3C2D9DBA3D003C65333EA5FF5FD4054EFC192667517"
    and lr07_build11_readback_evidence.get("decision")
        == "PASS_LR07_BUILD11_DISTRIBUTION_INSTALLATION_LIVE_READBACK"
    and lr07_build11_readback_evidence.get("mode") == "STRICT"
    and lr07_build11_readback_evidence.get("externalReceipt", {}).get(
        "receiptSha256"
    ) == "3b31de7d69c7ad232a1a51652ddc95e86c3e7f22890f8054b745164d8e4f2e59"
    and lr07_build11_readback_evidence.get("source", {}).get("before")
        == lr07_build11_readback_evidence.get("source", {}).get("after")
    and lr07_build11_readback_evidence.get("source", {}).get(
        "validatedSourceEvidenceCount"
    ) == 10
    and lr07_build11_readback_evidence.get("source", {}).get(
        "semanticMutableAuthorityValidated"
    ) is True
    and lr07_build11_readback_evidence.get("source", {}).get(
        "build10HistoricalFailureAuthorityPreserved"
    ) is True
    and lr07_build11_readback_evidence.get("outputs", {}).get("live", {}).get(
        "productionWorkflowRunCount"
    ) == 14
    and lr07_build11_readback_evidence.get("outputs", {}).get("live", {}).get(
        "productionArtifactCount"
    ) == 0
    and lr07_build11_readback_evidence.get("outputs", {}).get("live", {}).get(
        "productionArtifactTotalBytes"
    ) == 0
    and lr07_build11_readback_evidence.get("outputs", {}).get("live", {}).get(
        "githubReleaseCount"
    ) == 0
    and lr07_build11_readback_evidence.get("outputs", {}).get("live", {}).get(
        "build11WorkflowRun", {}
    ).get("id") == 31552161470
    and all(lr07_build11_readback_evidence.get("checks", {}).values())
    and lr07_build11_readback_evidence.get("failedChecks") == []
    and lr07_build11_readback_evidence.get("closureScope", {}).get(
        "lr07LiveReadbackProved"
    ) is True
    and lr07_build11_readback_evidence.get("closureScope", {}).get(
        "lr07Closed"
    ) is False
    and lr07_build11_readback_evidence.get("closureScope", {}).get(
        "stage2dF6Closed"
    ) is False
    and lr07_build11_readback_evidence.get("closureScope", {}).get(
        "pilotHandoutAuthorized"
    ) is False
    and "431,389,958 bytes" in lr07_decision
    and "later promotion authorizes only conditional handout of exact"
        in lr07_decision,
)

check(
    "LR-07 and F6 close only through the exact Build 11 sealed-pilot promotion",
    sha(ROOT / lr07_final_promotion_evidence_path)
        == "878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400"
    and lr07_final_promotion_evidence.get("decision")
        == "PASS_LR07_CLOSED_AND_STAGE2D_F6_CONTROLLED_PILOT_AUTHORIZED"
    and lr07_final_promotion_evidence.get("sourceAuthority", {}).get(
        "adjudicatedPullRequest"
    ) == 201
    and lr07_final_promotion_evidence.get("sourceAuthority", {}).get(
        "adjudicatedMergeCommit"
    ) == "38654b9385cd91cdf4dab743ca007f07d0430f76"
    and lr07_final_promotion_evidence.get("sourceAuthority", {}).get(
        "pullRequestCi", {}
    ).get("runId") == 31578415848
    and lr07_final_promotion_evidence.get("sourceAuthority", {}).get(
        "postMergeCi", {}
    ).get("runId") == 31579340418
    and all(
        job.get("conclusion") == "success"
        for phase in ["pullRequestCi", "postMergeCi"]
        for job in lr07_final_promotion_evidence.get("sourceAuthority", {})
            .get(phase, {})
            .get("jobs", [])
    )
    and len(
        lr07_final_promotion_evidence.get("sourceAuthority", {})
            .get("pullRequestCi", {})
            .get("jobs", [])
    ) == 5
    and len(
        lr07_final_promotion_evidence.get("sourceAuthority", {})
            .get("postMergeCi", {})
            .get("jobs", [])
    ) == 5
    and lr07_final_promotion_evidence.get("promotion", {}).get(
        "authorizedBuildNumber"
    ) == 11
    and lr07_final_promotion_evidence.get("promotion", {}).get(
        "authorizedPackageSha256"
    ) == "104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970"
    and lr07_final_promotion_evidence.get("promotion", {}).get(
        "pilotHandoutAuthorized"
    ) is True
    and lr07_final_promotion_evidence.get("promotion", {}).get(
        "pilotHandoutPerformedByThisRecord"
    ) is False
    and all(
        lr07_final_promotion_evidence.get("promotion", {}).get(key) is False
        for key in [
            "publicArtifactAuthorized",
            "githubReleaseAuthorized",
            "firebaseAppDistributionAuthorized",
            "playConsoleAuthorized",
            "playStoreAuthorized",
            "webDistributionAuthorized",
            "unrestrictedDistributionAuthorized",
            "appCheckActivationAuthorized",
        ]
    )
    and [
        transition.get("to")
        for transition in lr07_final_promotion_evidence.get(
            "gateTransitions", []
        )
    ] == ["CLOSED", "PILOT_AUTHORIZED", "CLOSED"]
    and lr07_record.get("currentStatus") == "CLOSED"
    and lr07_stage2d_f6_record.get("currentStatus") == "CLOSED"
    and [
        entry.get("status")
        for entry in lr07_stage2d_f6_record.get("statusHistory", [])
    ] == ["OPEN", "PILOT_AUTHORIZED", "CLOSED"]
    and programme_ledger.get("programmeDecision", {}).get(
        "internalControlledPilot"
    ) == "GO"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get(
        "unrestrictedDistribution"
    ) == "NO_GO"
    and all(
        gate.get("currentStatus") == "CLOSED"
        for gate in programme_ledger.get("programmeGates", [])
    ),
)

build8_f4_authority_promotion = data(
    "release/approvals/build-8-f4-authority-negative-promotion.json"
)
build8_f4_authority_collector = text(
    "tools/release/Invoke-Build8F4AuthorityNegativeCampaign.ps1"
)
build8_f4_authority_doc = text(
    "docs/v4_2_r1/BUILD8_F4_AUTHORITY_NEGATIVE_PROMOTION.md"
)
build8_f4_authority_test = text(
    "test/build8_f4_authority_negative_promotion_contract_test.dart"
)
build8_f4_authority_adjudication = data(
    "release/evidence/build-8-f4-authority-negative-adjudication.json"
)
build8_f4_authority_result = text(
    "docs/v4_2_r1/BUILD8_F4_AUTHORITY_NEGATIVE_RESULT.md"
)
build8_f4_authority_adjudication_test = text(
    "test/build8_f4_authority_negative_adjudication_contract_test.dart"
)
stage2d_f5_closure = data(
    "release/evidence/stage2d-f5-live-authority-matrix-closure.json"
)
stage2d_f5_rules_readback = data(
    "release/evidence/stage2d-f5-firestore-live-readback.json"
)
stage2d_f5_authority_inventory = data(
    "release/evidence/stage2d-f5-authority-inventory.json"
)
stage2d_f5_result = text(
    "docs/v4_2_r1/STAGE2D_F5_LIVE_AUTHORITY_MATRIX_CLOSURE.md"
)
stage2d_f5_contract_test = text(
    "test/stage2d_f5_live_authority_matrix_closure_contract_test.dart"
)
build8_f4_gate = next(
    record
    for record in programme_ledger.get("programmeGates", [])
    if record.get("gateId") == "STAGE2D-F4"
)
build8_f5_gate = next(
    record
    for record in programme_ledger.get("programmeGates", [])
    if record.get("gateId") == "STAGE2D-F5"
)
stage2d_f6_gate = next(
    record
    for record in programme_ledger.get("programmeGates", [])
    if record.get("gateId") == "STAGE2D-F6"
)
build8_p07_finding = next(
    record
    for record in programme_ledger.get("technicalFindings", [])
    if record.get("findingId") == "P-07"
)
check(
    "Build 8 F4 authority-negative campaign is two-session, restorative and non-closing by itself",
    build8_f4_authority_promotion.get("approvalClass")
        == "CONTROLLED_BUILD8_F4_AUTHORITY_NEGATIVE_EVIDENCE"
    and build8_f4_authority_promotion.get(
        "adjudicatedPrerequisites", {}
    ).get("remainingCriteria")
        == ["revocation next-operation denial", "wrong-role denials"]
    and build8_f4_authority_promotion.get("artifactAuthority", {}).get(
        "versionCode"
    ) == 8
    and build8_f4_authority_promotion.get("artifactAuthority", {}).get(
        "apkSha256"
    ) == "7F6CD741431230689193A0DD9505918B2E865C0A500649B7F242EA4747303CCD"
    and build8_f4_authority_promotion.get("runtimeTopology", {}).get(
        "subject", {}
    ).get("kind") == "PHYSICAL_ANDROID_DEVICE"
    and build8_f4_authority_promotion.get("runtimeTopology", {}).get(
        "operator", {}
    ).get("kind") == "ANDROID_VIRTUAL_DEVICE"
    and build8_f4_authority_promotion.get("backendAuthority", {}).get(
        "fleetFinalizedAtUtc"
    ) == "2026-08-04T15:03:41.351Z"
    and build8_f4_authority_promotion.get(
        "wrongRoleCompositeEvidencePolicy", {}
    ).get("mayClaimLivePhysicalMutationDenial") is False
    and build8_f4_authority_promotion.get(
        "wrongRoleCompositeEvidencePolicy", {}
    ).get("mayClaimWrongRoleCriterionReadyForAdjudication") is True
    and build8_f4_authority_promotion.get("programmeBoundary", {}).get(
        "stage2dF4ClosureAuthorized"
    ) is False
    and build8_f4_authority_promotion.get("programmeBoundary", {}).get(
        "p07ClosureAuthorized"
    ) is False
    and build8_f4_authority_promotion.get("programmeBoundary", {}).get(
        "pilotHandoutAuthorized"
    ) is False
    and all(
        phase in build8_f4_authority_collector
        for phase in [
            "'Preflight'",
            "'CaptureRevoked'",
            "'CaptureRevocationRestored'",
            "'CaptureWrongRole'",
            "'CaptureFinalRestoration'",
        ]
    )
    and "Same physical application process" in build8_f4_authority_collector
    and "PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL"
        in build8_f4_authority_collector
    and "Authority functions do not share one admitted deployed source."
        in build8_f4_authority_collector
    and "Authority-function deployment changed after the admitted fleet finalization."
        in build8_f4_authority_collector
    and "$ConfirmOperationsOnlyRoleSet" in build8_f4_authority_collector
    and "restorationRequiredBeforeContinuation = $true"
        in build8_f4_authority_collector
    and "restorationRequiredBeforeFinalPass = $true"
        in build8_f4_authority_collector
    and "livePhysicalMutationDenialClaimed = $false"
        in build8_f4_authority_collector
    and "syntheticProductionMutationAttempted = $false"
        in build8_f4_authority_collector
    and "physicalCapabilityProfile = 'OPERATIONS_ONLY_SURFACES'"
        in build8_f4_authority_collector
    and "operatorConfirmedRoleProfile = @('operations')"
        in build8_f4_authority_collector
    and "stage2dF4Closed = $false" in build8_f4_authority_collector
    and "pilotHandoutAuthorized = $false" in build8_f4_authority_collector
    and "firebase deploy" not in build8_f4_authority_collector.lower()
    and "gcloud " not in build8_f4_authority_collector.lower()
    and "Why the wrong-role proof is composite" in build8_f4_authority_doc
    and "authority-negative collector is byte-bound"
        in build8_f4_authority_test
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER",
)
check(
    "Build 8 six-criterion adjudication closes only F4 and P-07 and advances to F5",
    sha(ROOT / "release/evidence/build-8-f4-authority-negative-adjudication.json")
        == "9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461"
    and build8_f4_authority_adjudication.get("decision")
        == "PASS_BUILD8_F4_AND_P07_DEVICE_EVIDENCE_CLOSURE"
    and len(build8_f4_authority_adjudication.get(
        "priorCriterionAdjudications", []
    )) == 3
    and build8_f4_authority_adjudication.get("successfulCampaign", {}).get(
        "receiptCount"
    ) == 5
    and [
        receipt.get("sha256")
        for receipt in build8_f4_authority_adjudication.get(
            "successfulCampaign", {}
        ).get("receipts", [])
    ] == [
        "EB1CB909ADC2FA9700D76F377FC73FF5C14D204FB8F130C3E6ACAEF05248141F",
        "53C986827A331B29E95AD8C120AB88EE6951D694011696652F728D051F2D33DA",
        "E389AF6C6A2364151A2079A279A320560205D606C939E7F06824089D167D0D27",
        "6C676003484A2BF0F13A4C1FB62C29864D3BBA83776C274F27130DE6BF3D0B5A",
        "14DBA5CDE999B16DDD2491D56ABA646D6264FA0CB18047403A60C325601B53A1",
    ]
    and build8_f4_authority_adjudication.get("failedClosedLineage", {}).get(
        "receiptCount"
    ) == 8
    and build8_f4_authority_adjudication.get("failedClosedLineage", {}).get(
        "failedAttemptsRelabelledPass"
    ) is False
    and all(
        criterion.get("status") == "PROVED"
        for criterion in build8_f4_authority_adjudication.get(
            "criterionAdjudication", []
        )
    )
    and len(build8_f4_authority_adjudication.get(
        "criterionAdjudication", []
    )) == 6
    and build8_f4_authority_adjudication.get(
        "authorityTransitionAdjudication", {}
    ).get("revocationDeniedNextOperation") is True
    and build8_f4_authority_adjudication.get(
        "authorityTransitionAdjudication", {}
    ).get("sameProcessAcrossEntireCampaign") is True
    and build8_f4_authority_adjudication.get(
        "authorityTransitionAdjudication", {}
    ).get("syntheticProductionMutationAttempted") is False
    and build8_f4_authority_adjudication.get(
        "authorityTransitionAdjudication", {}
    ).get("finalRoleProfile") == ["si"]
    and build8_f4_gate.get("currentStatus") == "CLOSED"
    and build8_f4_gate.get("authorization") == "CLOSED_PASS"
    and len(build8_f4_gate.get("evidence", [])) == 4
    and {
        evidence.get("sha256") for evidence in build8_f4_gate.get("evidence", [])
    } == {
        "A165DFD44ED2B2BE9DDC27F20D4D982585EA7C0DC5749915BEE1C545DFAB5F5C",
        "95A5B0C0524B98104E47A69EDA1EFC7D827D9A5E8125042F83C20A742D7A0394",
        "45B90B3F0C3D711FEA82B3514669B0C25FEDD2EF320AF4872EC8B102535678F6",
        "9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461",
    }
    and len(build8_f4_gate.get("reArmTriggers", [])) == 6
    and [entry.get("status") for entry in build8_f4_gate.get(
        "statusHistory", []
    )] == ["OPEN", "CLOSED"]
    and build8_p07_finding.get("currentStatus") == "CLOSED"
    and build8_p07_finding.get("title")
        == "Physical-device signed-in sync, revocation and role-negative matrix is closed"
    and len(build8_p07_finding.get("evidence", [])) == 1
    and build8_p07_finding.get("evidence", [])[0].get("sha256")
        == "9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461"
    and len(build8_p07_finding.get("requiredExitEvidence", [])) == 6
    and len(build8_p07_finding.get("reArmTriggers", [])) == 6
    and [entry.get("status") for entry in build8_p07_finding.get(
        "statusHistory", []
    )] == ["OPEN", "CLOSED"]
    and build8_f4_authority_adjudication.get("programmeTransition", {}).get(
        "stage2dF5Status"
    ) == "OPEN"
    and build8_f4_authority_adjudication.get("programmeTransition", {}).get(
        "nextMutation"
    ) == "STAGE2D-F5"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER"
    and "F4 AND P-07 DEVICE EVIDENCE CLOSED" in build8_f4_authority_result
    and "all eight failed-closed receipts" in build8_f4_authority_result
    and "authority-negative adjudication binds the complete receipt lineage"
        in build8_f4_authority_adjudication_test,
)
check(
    "Stage 2D-F5 exact live authority matrix closes only F5 and advances to F6",
    sha(ROOT / "release/evidence/stage2d-f5-live-authority-matrix-closure.json")
        == "DD8A8BB0E155786BF54DA468E6E15005FC303EB1057E42F01CA763C9A7F9ED7B"
    and stage2d_f5_closure.get("decision")
        == "PASS_STAGE2D_F5_LIVE_AUTHORITY_MATRIX_CLOSURE"
    and stage2d_f5_closure.get("sourceAuthority", {}).get("commit")
        == "e86efddf17a8c5c0284ac1f9596a85d773e5b566"
    and stage2d_f5_closure.get("sourceAuthority", {}).get(
        "postMergeReleaseGate", {}
    ).get("firestoreRulesTestsPassed") == 160
    and stage2d_f5_closure.get("sourceAuthority", {}).get(
        "postMergeReleaseGate", {}
    ).get("governedCallableTestsPassed") == 63
    and stage2d_f5_closure.get("deploymentLineage", {}).get(
        "mutationScope"
    ) == "FIRESTORE_RULES_ONLY"
    and stage2d_f5_closure.get("deploymentLineage", {}).get(
        "attempts", []
    )[0].get("result") == "FAILED_CLOSED"
    and stage2d_f5_closure.get("deploymentLineage", {}).get(
        "attempts", []
    )[1].get("cliResponseRelabelledSuccess") is False
    and stage2d_f5_closure.get("deploymentLineage", {}).get(
        "after", {}
    ).get("rulesByteExact") is True
    and stage2d_f5_closure.get("deploymentLineage", {}).get(
        "after", {}
    ).get("sourceIndexCount") == 51
    and stage2d_f5_closure.get("deploymentLineage", {}).get(
        "after", {}
    ).get("liveReadyIndexCount") == 51
    and stage2d_f5_rules_readback.get("decision")
        == "PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK"
    and stage2d_f5_rules_readback.get("outputs", {}).get("rules", {}).get(
        "byteExact"
    ) is True
    and stage2d_f5_rules_readback.get("outputs", {}).get("indexes", {}).get(
        "allApiIndexesReady"
    ) is True
    and stage2d_f5_authority_inventory.get("decision")
        == "PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY"
    and stage2d_f5_authority_inventory.get("coverage", {}).get(
        "joinedSubjectCount"
    ) == 3
    and stage2d_f5_authority_inventory.get("summary", {}).get(
        "blockingSubjectCount"
    ) == 0
    and len(stage2d_f5_closure.get("criterionAdjudication", [])) == 4
    and all(
        criterion.get("status") == "PROVED"
        for criterion in stage2d_f5_closure.get("criterionAdjudication", [])
    )
    and stage2d_f5_closure.get("liveAuthorityEvidence", {}).get(
        "liveClientSurface", {}
    ).get("adminEmulator", {}).get("productionAuditReadSucceeded") is True
    and stage2d_f5_closure.get("liveAuthorityEvidence", {}).get(
        "liveClientSurface", {}
    ).get("siOnlyPhysicalDevice", {}).get("auditNavigationPresent") is False
    and build8_f5_gate.get("currentStatus") == "CLOSED"
    and build8_f5_gate.get("authorization") == "CLOSED_PASS"
    and len(build8_f5_gate.get("evidence", [])) == 3
    and len(build8_f5_gate.get("reArmTriggers", [])) == 6
    and [entry.get("status") for entry in build8_f5_gate.get(
        "statusHistory", []
    )] == ["OPEN", "CLOSED"]
    and stage2d_f6_gate.get("currentStatus") == "CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("nextMutation")
        == "NONE_ALL_PROGRAMME_GATES_CLOSED"
    and programme_ledger.get("programmeDecision", {}).get("pilotHandout")
        == "AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER"
    and "`STAGE2D-F5` is closed" in stage2d_f5_result
    and "F5 closure preserves failed deployment lineage and exact live state"
        in stage2d_f5_contract_test,
)

print(f"SUMMARY | pass={len(PASS)} fail={len(FAIL)} total={len(PASS)+len(FAIL)}")
if FAIL:
    for name, detail in FAIL:
        print(f"FAILED | {name}" + (f" | {detail}" if detail else ""), file=sys.stderr)
raise SystemExit(1 if FAIL else 0)
