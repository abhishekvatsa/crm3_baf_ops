[CmdletBinding()]
param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load only the actual pin assignment and guards. Never execute lab setup,
# package installation, build steps or device operations in this regression.
$labPath = Join-Path $RepositoryRoot 'tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($labPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "Laboratory syntax errors: $parseErrors" }
$assignment = $ast.Find({param($node)
  $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$expected'
}, $false)
if ($null -eq $assignment) { throw 'Missing laboratory pin assignment' }
. ([scriptblock]::Create($assignment.Extent.Text))
foreach ($name in @('Get-JsonPropertyValue', 'Assert-FirebaseCliLockPolicy', 'Assert-FirebaseCliInstalledVersions')) {
  $definition = $ast.Find({param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
  }, $false)
  if ($null -eq $definition) { throw "Missing laboratory guard: $name" }
  . ([scriptblock]::Create($definition.Extent.Text))
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('crm3-lab-pin-contract-' + [guid]::NewGuid().ToString('N'))
$fixtureCli = Join-Path $fixtureRoot 'tooling/firebase-cli'
$evidenceDir = Join-Path $fixtureRoot 'evidence'
New-Item -ItemType Directory -Path $fixtureCli, $evidenceDir | Out-Null
$packageJson = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'tooling/firebase-cli/package.json') -Raw
$lockJson = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'tooling/firebase-cli/package-lock.json') -Raw
$packagePath = Join-Path $fixtureCli 'package.json'
$lockPath = Join-Path $fixtureCli 'package-lock.json'
Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'tooling/firebase-cli/.npmrc') -Destination $fixtureCli
$script:passedCases = 0

function Restore-LockFixture {
  [IO.File]::WriteAllText($packagePath, $packageJson)
  [IO.File]::WriteAllText($lockPath, $lockJson)
}
function Assert-Rejected {
  param([string]$Case, [scriptblock]$Action, [string]$ExpectedMessage)
  $caught = $null
  try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
  if ($null -eq $caught -or $caught -notmatch $ExpectedMessage) {
    throw "Expected guard rejection for $Case; got: $caught"
  }
  $script:passedCases++
}

# The positive case reads the real committed manifests, not expected fixtures.
$workspace = $RepositoryRoot
Assert-FirebaseCliLockPolicy | Out-Null
$script:passedCases++
$workspace = $fixtureRoot
Restore-LockFixture
$packages = @('basic-ftp', '@grpc/grpc-js', '@modelcontextprotocol/sdk', 'fast-uri', 'hono', 'ip-address', 'js-yaml', 'morgan', 'undici')
foreach ($packageName in $packages) {
  foreach ($field in @('version', 'resolved', 'integrity', 'missing', 'override')) {
    Restore-LockFixture
    $lock = $lockJson | ConvertFrom-Json -AsHashtable
    $package = $packageJson | ConvertFrom-Json -AsHashtable
    $key = "node_modules/$packageName"
    if ($field -eq 'missing') {
      $lock.packages.Remove($key)
    } elseif ($field -eq 'override') {
      $package.overrides[$packageName] = '0.0.0-regression'
    } else {
      $lock.packages[$key][$field] = 'tampered-regression'
    }
    $lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
    $package | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $packagePath -Encoding utf8
    Assert-Rejected -Case "$packageName $field" -Action { Assert-FirebaseCliLockPolicy } -ExpectedMessage '^Firebase CLI lock policy failed:'
  }
}

# A patched top-level copy must not conceal another unsafe nested copy.
foreach ($field in @('version', 'resolved', 'integrity')) {
  Restore-LockFixture
  $lock = $lockJson | ConvertFrom-Json -AsHashtable
  $copy = $lock.packages['node_modules/basic-ftp'].Clone()
  $copy[$field] = 'tampered-regression'
  $lock.packages['node_modules/fixture/node_modules/basic-ftp'] = $copy
  $lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
  Assert-Rejected -Case "nested basic-ftp $field" -Action { Assert-FirebaseCliLockPolicy } -ExpectedMessage '^Firebase CLI lock policy failed:'
}

foreach ($field in @('version', 'resolved', 'integrity')) {
  Restore-LockFixture
  $lock = $lockJson | ConvertFrom-Json -AsHashtable
  $copy = $lock.packages['node_modules/@grpc/grpc-js'].Clone()
  $copy[$field] = 'tampered-regression'
  $lock.packages['node_modules/fixture/node_modules/@grpc/grpc-js'] = $copy
  $lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
  Assert-Rejected -Case "nested @grpc/grpc-js $field" -Action { Assert-FirebaseCliLockPolicy } -ExpectedMessage '^Firebase CLI lock policy failed:'
}

# The former SDK and unsafe nested copies must fail the real laboratory guard.
Restore-LockFixture
$lock = $lockJson | ConvertFrom-Json -AsHashtable
$lock.packages['node_modules/@modelcontextprotocol/sdk'].version = '1.29.0'
$lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
Assert-Rejected -Case 'old MCP SDK' -Action { Assert-FirebaseCliLockPolicy } -ExpectedMessage '^Firebase CLI lock policy failed:'
foreach ($field in @('version', 'resolved', 'integrity')) {
  Restore-LockFixture
  $lock = $lockJson | ConvertFrom-Json -AsHashtable
  $copy = $lock.packages['node_modules/@modelcontextprotocol/sdk'].Clone()
  $copy[$field] = if ($field -eq 'version') { '1.29.0' } else { 'unbound-nested-bytes' }
  $lock.packages['node_modules/fixture/node_modules/@modelcontextprotocol/sdk'] = $copy
  $lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
  Assert-Rejected -Case "nested MCP SDK $field" -Action { Assert-FirebaseCliLockPolicy } -ExpectedMessage '^Firebase CLI lock policy failed:'
}
Restore-LockFixture
$lock = $lockJson | ConvertFrom-Json -AsHashtable
$lock.packages['node_modules/fixture/node_modules/@modelcontextprotocol/sdk'] = $lock.packages['node_modules/@modelcontextprotocol/sdk'].Clone()
$lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
Assert-FirebaseCliLockPolicy | Out-Null
$script:passedCases++

# The shared adapter and aliased upstream have different identities/resolution
# rules from registry overrides; exercise each actual lock guard independently.
foreach ($packageName in @('brace-expansion', 'brace-expansion-modern')) {
  $fields = @('version', 'resolved', 'missing')
  if ($packageName -eq 'brace-expansion-modern') { $fields += @('name', 'integrity') }
  else { $fields += @('dependency', 'declared', 'override') }
  foreach ($field in $fields) {
    Restore-LockFixture
    $lock = $lockJson | ConvertFrom-Json -AsHashtable
    $package = $packageJson | ConvertFrom-Json -AsHashtable
    $key = "node_modules/$packageName"
    if ($field -eq 'missing') { $lock.packages.Remove($key) }
    elseif ($field -eq 'dependency') { $lock.packages[$key].dependencies['brace-expansion-modern'] = 'npm:brace-expansion@0.0.0-regression' }
    elseif ($field -eq 'declared') { $package.dependencies['brace-expansion'] = '0.0.0-regression' }
    elseif ($field -eq 'override') { $package.overrides['brace-expansion'] = '0.0.0-regression' }
    else { $lock.packages[$key][$field] = 'tampered-regression' }
    $lock | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $lockPath -Encoding utf8
    $package | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $packagePath -Encoding utf8
    Assert-Rejected -Case "$packageName $field" -Action { Assert-FirebaseCliLockPolicy } -ExpectedMessage '^Firebase CLI lock policy failed:'
  }
}

# Synthetic installation manifests exercise the actual installed-version guard
# without requiring npm installation or claiming a package runtime test.
Restore-LockFixture
$lock = $lockJson | ConvertFrom-Json -AsHashtable
foreach ($key in $lock.packages.Keys) {
  if ($key.StartsWith('node_modules/') -and $lock.packages[$key].ContainsKey('version')) {
    $target = Join-Path $fixtureCli "$key/package.json"
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    @{version=$lock.packages[$key].version} | ConvertTo-Json | Set-Content -LiteralPath $target -Encoding utf8
  }
}
Assert-FirebaseCliInstalledVersions | Out-Null
$script:passedCases++
foreach ($packageName in ($packages + @('brace-expansion', 'brace-expansion-modern'))) {
  $target = Join-Path $fixtureCli "node_modules/$packageName/package.json"
  $original = Get-Content -LiteralPath $target -Raw
  try {
    '{"version":"0.0.0-regression"}' | Set-Content -LiteralPath $target -Encoding utf8
    Assert-Rejected -Case "$packageName installed version" -Action { Assert-FirebaseCliInstalledVersions } -ExpectedMessage '^Installed Firebase CLI dependency version mismatch:'
  } finally {
    [IO.File]::WriteAllText($target, $original)
  }
}
# An unrecorded installed nested SDK must be checked too. These are synthetic
# package metadata only; no npm install or SDK code execution occurs.
$nestedSdk = Join-Path $fixtureCli 'node_modules/fixture/node_modules/@modelcontextprotocol/sdk'
New-Item -ItemType Directory -Path $nestedSdk -Force | Out-Null
Assert-Rejected -Case 'nested SDK missing package metadata' -Action { Assert-FirebaseCliInstalledVersions } -ExpectedMessage '^Installed Firebase CLI dependency package.json missing:'
$nestedMetadata = Join-Path $nestedSdk 'package.json'
'{"version":"1.29.0"}' | Set-Content -LiteralPath $nestedMetadata -Encoding utf8
Assert-Rejected -Case 'nested SDK installed old version' -Action { Assert-FirebaseCliInstalledVersions } -ExpectedMessage '^Installed Firebase CLI dependency version mismatch:'
@{version=$expected.mcpSdk} | ConvertTo-Json | Set-Content -LiteralPath $nestedMetadata -Encoding utf8
Assert-FirebaseCliInstalledVersions | Out-Null
$script:passedCases++
Write-Output "PASS_FIREBASE_CLI_LAB_PIN_CONTRACTS: $script:passedCases cases"
