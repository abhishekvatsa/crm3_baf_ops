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
    and counts.get("BYTE_IDENTICAL") == 286
    and counts.get("SUCCESSOR_MODIFIED") == 124
    and counts.get("MISSING", 0) == 0,
    str(counts),
)

critical_exact = {
    "android/app/build.gradle.kts",
    "android/settings.gradle.kts",
    "release/stage2d-f-internal-controlled-deployment-scope.json",
}
row_map = {row["path"]: row for row in rows}
check(
    "Android and immutable release authorities remain byte-identical",
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
c03_package_script = text(
    "tools/release/Invoke-CIAndroidPackageProof.ps1"
)
c03_package_test = text("test/c03_android_packaging_ci_contract_test.dart")
c03_package_decision = text("docs/v4_2_r1/C03_ANDROID_PR_PACKAGING.md")
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
    and "Invoke-CIAndroidPackageProof.ps1" in c03_job_source
    and "${{ secrets." not in c03_job_source
    and "\n    environment:" not in c03_job_source
    and "upload-artifact" not in c03_job_source
    and "CI packaging proof refuses pre-existing signing input"
        in c03_package_script
    and "RandomNumberGenerator]::GetBytes(24)" in c03_package_script
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
    and len(workflow_action_refs) == 21
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
    and "authority.data.fcmToken" in text("functions/src/notifications.ts")
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
            "npm run audit:emitted-output && npm run audit:callable-inventory"
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

firebase_cli_package = data("tooling/firebase-cli/package.json")
firebase_cli_lock = data("tooling/firebase-cli/package-lock.json")
firebase_cli_packages = firebase_cli_lock.get("packages", {})
hono = firebase_cli_packages.get("node_modules/@hono/node-server", {})
fast_uri = firebase_cli_packages.get("node_modules/fast-uri", {})
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
    and firebase_cli_package.get("overrides", {}).get("fast-uri") == "3.1.4"
    and firebase_cli_package.get("dependencies", {}).get("brace-expansion") == "file:../brace-expansion-compat"
    and firebase_cli_package.get("overrides", {}).get("brace-expansion") == "$brace-expansion"
    and firebase_cli_package.get("overrides", {}).get("tar") == "7.5.21"
    and firebase_cli_package.get("overrides", {}).get("re2") == "1.25.2"
    and firebase_tools.get("version") == "15.22.4"
    and hono.get("version") == "2.0.10"
    and hono.get("resolved") == "https://registry.npmjs.org/@hono/node-server/-/node-server-2.0.10.tgz"
    and hono.get("integrity") == "sha512-ZcnNVhKTmyDJeg0UlnZjvM73JBsTAuhrH/J4fjwGOw59PwOW51r4J+p6CsKZWXdKSme4MFqU62CZMOsdDrU4CA=="
    and fast_uri.get("version") == "3.1.4"
    and fast_uri.get("resolved") == "https://registry.npmjs.org/fast-uri/-/fast-uri-3.1.4.tgz"
    and fast_uri.get("integrity") == "sha512-8JnbkQ4juDyvYs4mgFGQqg4yCYtFDtUtmp2QIQq11ZZe5CFQ5wcqm1rqDgAh/QdMySuBnPzMUiJUNZG5N/AiQw=="
    and brace_expansion.get("version") == "5.0.8"
    and brace_expansion.get("resolved") == "file:../brace-expansion-compat"
    and brace_expansion_upstream.get("name") == "brace-expansion"
    and brace_expansion_upstream.get("version") == "5.0.8"
    and brace_expansion_upstream.get("resolved") == "https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.8.tgz"
    and brace_expansion_upstream.get("integrity") == "sha512-JZyDyq3D4AUifKTPOB7DELf6XsB3WdPuNxCtob1vFXPsSXhdAiHBWJ/tJ8HAc9aH84BK+5JFZLNkJKx3G9kzQg=="
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
    and brace_adapter_package.get("version") == "5.0.8"
    and brace_adapter_package.get("dependencies", {}).get("brace-expansion-modern") == "npm:brace-expansion@5.0.8"
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
        "3.1.4",
        "5.0.8",
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
    and "allow update: if globalPullStampUnchangedOnUpdate()" in rules
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
    and "contains('allow update: if globalPullStampUnchangedOnUpdate()')"
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
check(
    "Build 6 is finalized, dual-custodied and non-distributable",
    sha(build6_approval_path)
        == combined_policy.get("versionPolicy", {}).get(
            "sourceDocumentSha256"
        )
    and sha(build6_exception_path)
        == combined_policy.get("github", {})
        .get("environmentReviewControl", {})
        .get("exceptionApprovalSha256")
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
    and version_policy_approval.get("reference") == "BAF-REF-003-C5"
    and version_policy_approval.get("buildNumber") == 6
    and combined_policy.get("release", {}).get("buildNumber") == 6
    and combined_policy.get("finalization", {}).get("status")
        == "completed-non-distributable"
    and sha(build6_completion_path)
        == combined_policy.get("finalization", {}).get(
            "completionReceiptSha256"
        )
    and combined_policy.get("finalization", {}).get(
        "dualCustodyCompleted"
    )
        is True
    and combined_policy.get("distribution", {}).get("approved") is False
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
    and build6_entry.get("distributionPerformed") is False,
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
        "...READ_ONLY_CALLABLE_SECURITY_OPTIONS"
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

print(f"SUMMARY | pass={len(PASS)} fail={len(FAIL)} total={len(PASS)+len(FAIL)}")
if FAIL:
    for name, detail in FAIL:
        print(f"FAILED | {name}" + (f" | {detail}" if detail else ""), file=sys.stderr)
raise SystemExit(1 if FAIL else 0)
