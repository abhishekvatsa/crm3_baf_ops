import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

// Execute the production classifiers against real Git trees without running
// the complete release gate or changing the application's repository.
test("source authority follows shipped inputs and backend parity, not governance commits", () => {
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-source-authority-"));
  const git = (...args) => execFileSync("git", args, {
    cwd: fixtureRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
  const write = (relative, content) => {
    const target = path.join(fixtureRoot, relative);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.writeFileSync(target, content);
  };
  const commit = () => {
    git("add", ".");
    git("-c", "user.name=Source authority fixture", "-c", "user.email=fixture@example.invalid",
      "commit", "--no-gpg-sign", "-m", "fixture");
    return git("rev-parse", "HEAD");
  };
  try {
    git("init", "--quiet");
    const applicationInputs = [
      "android/app/build.gradle.kts", "assets/fixture.txt", "lib/main.dart",
      "pubspec.yaml", "pubspec.lock",
    ];
    for (const input of applicationInputs) write(input, "baseline\n");
    const initial = commit();
    const cases = [{label: "same source", promoted: initial, current: initial, expected: true}];
    for (const input of ["docs/notes.md", "governance/fixture.json", "test/fixture_test.dart",
      "tools/release/fixture.ps1", ".github/workflows/production-artifact.yml"]) {
      write(input, "governance only\n");
    }
    let previous = commit();
    cases.push({label: "governance-only commit", promoted: initial, current: previous, expected: true});
    for (const input of applicationInputs) {
      write(input, "changed\n");
      const changed = commit();
      cases.push({label: input, promoted: previous, current: changed, expected: false});
      previous = changed;
    }
    fs.unlinkSync(path.join(fixtureRoot, "pubspec.lock"));
    const missing = commit();
    cases.push({label: "missing input on both sides", promoted: missing, current: missing, expected: false});
    write("cases.json", JSON.stringify(cases));

    const powershell = String.raw`
param([string]$ProductionSource, [string]$CasesPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ast = [Management.Automation.Language.Parser]::ParseFile($ProductionSource, [ref]$null, [ref]$null)
$assignment = $ast.Find({param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
  $node.Left.Extent.Text -eq '$PromotedApplicationSourcePaths'
}, $false)
Invoke-Expression $assignment.Extent.Text
foreach ($name in @('Get-GitTreeObjectId', 'Test-PromotedApplicationSourceMatches', 'Get-CurrentSourceRuntimeAuthority')) {
  $definition = $ast.Find({param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
  }, $false)
  Invoke-Expression $definition.Extent.Text
}
$rows = foreach ($case in (Get-Content -LiteralPath $CasesPath -Raw | ConvertFrom-Json)) {
  $matches = Test-PromotedApplicationSourceMatches -PromotedCommit $case.promoted -CurrentCommit $case.current
  [ordered]@{
    label = $case.label
    matches = $matches
    approved = Get-CurrentSourceRuntimeAuthority -ArtifactPilotApproved $true -BackendMatchesDeployed $true -ApplicationMatchesPromotedArtifact $matches
    backendDrift = Get-CurrentSourceRuntimeAuthority -ArtifactPilotApproved $true -BackendMatchesDeployed $false -ApplicationMatchesPromotedArtifact $matches
    unapproved = Get-CurrentSourceRuntimeAuthority -ArtifactPilotApproved $false -BackendMatchesDeployed $true -ApplicationMatchesPromotedArtifact $matches
  }
}
$rows | ConvertTo-Json -Depth 4 -Compress
`;
    const python = String.raw`
import ast, json, pathlib, re, subprocess, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
names = {"git_tree_object_id", "promoted_application_source_matches", "current_source_runtime_authority"}
nodes = [node for node in ast.parse(source).body if
    isinstance(node, ast.FunctionDef) and node.name in names or
    isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "PROMOTED_APPLICATION_SOURCE_PATHS" for target in node.targets)]
scope = {"subprocess": subprocess, "re": re, "ROOT": pathlib.Path.cwd()}
exec(compile(ast.Module(body=nodes, type_ignores=[]), sys.argv[1], "exec"), scope)
rows = []
for case in json.loads(pathlib.Path(sys.argv[2]).read_text()):
    matches = scope["promoted_application_source_matches"](case["promoted"], case["current"])
    authority = scope["current_source_runtime_authority"]
    rows.append(dict(label=case["label"], matches=matches, approved=authority(True, True, matches), backendDrift=authority(True, False, matches), unapproved=authority(False, True, matches)))
print(json.dumps(rows))
`;
    write("check.ps1", powershell);
    write("check.py", python);
    const expected = cases.map(({label, expected: matches}) => ({
      label, matches, approved: matches, backendDrift: false, unapproved: false,
    }));
    for (const [executable, args] of [
      ["pwsh", ["-NoProfile", "-File", path.join(fixtureRoot, "check.ps1"),
        path.join(repositoryRoot, "tools/release/Test-ProductionReleasePolicy.ps1"), path.join(fixtureRoot, "cases.json")]],
      [process.platform === "win32" ? "python" : "python3", [path.join(fixtureRoot, "check.py"),
        path.join(repositoryRoot, "tools/v4/v4_2_r1_canonical_audit.py"), path.join(fixtureRoot, "cases.json")]],
    ]) {
      const result = execFileSync(executable, args, {cwd: fixtureRoot, encoding: "utf8"});
      assert.deepEqual(JSON.parse(result), expected, executable);
    }
  } finally {
    const parent = path.resolve(os.tmpdir());
    assert.equal(path.dirname(path.resolve(fixtureRoot)), parent);
    assert.ok(path.basename(fixtureRoot).startsWith("crm3-source-authority-"));
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});
