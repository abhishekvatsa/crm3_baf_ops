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
    "Successor reconciliation refresh is exact through the S-06 source merge",
    successor_refresh.get("throughMainCommit") == "d48ad31985d98f9415923b36bc5acb8133de7068"
    and successor_refresh.get("throughMainTree") == "374878e3fe72b4c86e4a5dcab4110ec52549c192"
    and successor_refresh.get("adjudicatedPullRequests") == [40, 41, 42, 43, 44, 45]
    and successor_refresh.get("preExistingDriftPathCount") == 14
    and successor_refresh.get("crossPlatformRepresentationPathCount") == 19
    and successor_refresh.get("refreshTranche") == "S06_ATOMIC_CLOSURE_AUTHORITY_LEDGER_CLOSURE"
    and successor_refresh.get("refreshTrancheTrackedPaths") == [
        "docs/v4_2_r1/S06_ATOMIC_CLOSURE_AUTHORITY.md",
        "governance/programme-ledger.json",
        "tools/v4/v4_2_r1_canonical_audit.py",
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
    and counts.get("BYTE_IDENTICAL") == 327
    and counts.get("SUCCESSOR_MODIFIED") == 83
    and counts.get("MISSING", 0) == 0,
    str(counts),
)

critical_exact = {
    ".github/workflows/production-artifact.yml",
    ".github/workflows/verification-artifact.yml",
    "android/app/build.gradle.kts",
    "android/settings.gradle.kts",
    "release/stage2d-f-internal-controlled-deployment-scope.json",
    "test/stage2d_f2_programme_ledger_closure_contract_test.dart",
}
row_map = {row["path"]: row for row in rows}
check(
    "Stage 2D-F2, Android and immutable workflow/release authorities remain byte-identical",
    all(row_map.get(path, {}).get("disposition") == "BYTE_IDENTICAL" for path in critical_exact),
)
check(
    "Mutable release-gate, programme-ledger and ledger-contract evolution is explicitly classified",
    all(
        row_map.get(path, {}).get("disposition") == "SUCCESSOR_MODIFIED"
        for path in (
            ".github/workflows/release-gate.yml",
            "governance/programme-ledger.json",
            "test/programme_ledger_contract_test.dart",
        )
    ),
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
    all(item in harness for item in ("22.15.0", "10.9.2", "21.0.11", "3.44.0", "3.12.0"))
    and "Assert-LockfilesStable" in harness
    and "HOLD_LOCKFILE_DRIFT" in harness,
)
check(
    "Functions compiler is an early no-emit gate immediately after dependency installation",
    "08_functions_typecheck" in harness
    and "HOLD_FUNCTIONS_TYPECHECK" in harness
    and "npm run build -- --noEmit --pretty false" in harness
    and harness.index("07_functions_npm_ci") < harness.index("08_functions_typecheck") < harness.index("11_firebase_cli_npm_ci"),
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
firebase_tools = firebase_cli_packages.get("node_modules/firebase-tools", {})
mcp_sdk = firebase_cli_packages.get("node_modules/@modelcontextprotocol/sdk", {})
check(
    "Firebase CLI tooling pins only the bounded patched dependency versions",
    firebase_cli_package.get("dependencies", {}).get("firebase-tools") == "15.22.4"
    and firebase_cli_package.get("overrides", {}).get("@hono/node-server") == "2.0.10"
    and firebase_cli_package.get("overrides", {}).get("fast-uri") == "3.1.4"
    and firebase_tools.get("version") == "15.22.4"
    and hono.get("version") == "2.0.10"
    and hono.get("resolved") == "https://registry.npmjs.org/@hono/node-server/-/node-server-2.0.10.tgz"
    and hono.get("integrity") == "sha512-ZcnNVhKTmyDJeg0UlnZjvM73JBsTAuhrH/J4fjwGOw59PwOW51r4J+p6CsKZWXdKSme4MFqU62CZMOsdDrU4CA=="
    and fast_uri.get("version") == "3.1.4"
    and fast_uri.get("resolved") == "https://registry.npmjs.org/fast-uri/-/fast-uri-3.1.4.tgz"
    and fast_uri.get("integrity") == "sha512-8JnbkQ4juDyvYs4mgFGQqg4yCYtFDtUtmp2QIQq11ZZe5CFQ5wcqm1rqDgAh/QdMySuBnPzMUiJUNZG5N/AiQw=="
    and mcp_sdk.get("dependencies", {}).get("@hono/node-server") == "^1.19.9",
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
    )),
)
check(
    "Firebase CLI major override is load-smoked before its advisory verdict",
    "HOLD_FIREBASE_CLI_RUNTIME" in harness
    and "PASS_FIREBASE_CLI_LOAD_SMOKE" in harness
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
    and "allow update: if validMaintenanceUpdate();" in rules
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
    and "contains('allow update: if validMaintenanceUpdate();')" in maintenance_replay_guard
    and r"RegExp(r'allow\s+update\s*:')" in maintenance_replay_guard
    and "Maintenance updates are intentionally split into small branch rules"
        not in maintenance_replay_guard
    and "isNot(contains('allow update: if validMaintenanceUpdate();'))"
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
check(
    "S-09 and R-06 ledger findings are exact source-implemented records",
    len(s09_records) == 1
    and len(r06_records) == 1
    and s09_record.get("currentStatus") == "SOURCE_IMPLEMENTED"
    and r06_record.get("currentStatus") == "SOURCE_IMPLEMENTED"
    and s09_record.get("evidence", [{}])[0].get("sourceCommit")
        == source_commit
    and r06_record.get("evidence", [{}])[0].get("sourceCommit")
        == source_commit
    and s09_record.get("statusHistory", [])[-1].get("status")
        == "SOURCE_IMPLEMENTED"
    and r06_record.get("statusHistory", [])[-1].get("status")
        == "SOURCE_IMPLEMENTED"
    and len(s09_record.get("requiredExitEvidence", [])) >= 7
    and len(r06_record.get("requiredExitEvidence", [])) >= 7
    and len(s09_record.get("reArmTriggers", [])) >= 5
    and len(r06_record.get("reArmTriggers", [])) >= 5,
)

print(f"SUMMARY | pass={len(PASS)} fail={len(FAIL)} total={len(PASS)+len(FAIL)}")
if FAIL:
    for name, detail in FAIL:
        print(f"FAILED | {name}" + (f" | {detail}" if detail else ""), file=sys.stderr)
raise SystemExit(1 if FAIL else 0)
