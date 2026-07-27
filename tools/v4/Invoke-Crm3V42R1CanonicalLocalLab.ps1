[CmdletBinding()]
param(
  [string]$CandidatePath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
  [string]$CurrentAppRoot,
  [string]$FirebaseOptionsPath,
  [string]$GoogleServicesPath,
  [string]$EvidenceRoot = (Join-Path $HOME 'Downloads'),
  [ValidateSet('Authoritative', 'Diagnostic')][string]$Mode = 'Authoritative',
  [switch]$RunEmulators,
  [ValidateRange(1024, 65535)][int]$EmulatorPort = 8080,
  [switch]$SkipFlutterTests,
  [switch]$InstallOnCleanDevice,
  [string]$DeviceId,
  [switch]$KeepWorkspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$expected = [ordered]@{
  canonicalMainCommit = '633c58bb0d936011e391b42627f8b8f02c510e95'
  canonicalMainTree = '2f547a79e79076c70dd15ae8b85a7ad70c9fa018'
  projectId = 'crm3-baf-ops-b8638'
  packageName = 'in.co.sail.bsl.crm3.bafops'
  firebaseAppId = '1:894346496105:android:fba14febfbbee102e63af8'
  firebaseOptionsSha256 = '07912823FCC37500C785BE26741B3930087D7A47F02F5E2268F7C7FC1A6031DE'
  canonicalGoogleServicesSha256 = '2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B'
  canonicalRepositoryGoogleServicesSha256 = '6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7'
  canonicalGoogleServicesSemanticSha256 = 'A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2'
  supersededDebugOnlyGoogleServicesSha256 = 'DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D'
  supersededDebugOnlyGoogleServicesSemanticSha256 = '8BB5FFA242C09AB10323D9B8F1FF560724B045EC39D2EA565367F057EE49DC1F'
  registrationSourceGoogleServicesSha256 = '730A044FF0A698C2FBCCF3B993EE6964EE5431CA8C6435DDC02AA98A9848646A'
  debugOauthClientId = '894346496105-hmk7941e55ph206e6nr6ifvvqqqf7ee6.apps.googleusercontent.com'
  productionOauthClientId = '894346496105-oljmi6mm7o790ue6o7cgcs20cakanjkg.apps.googleusercontent.com'
  restorationReference = 'CRM3-FB-RESTORE-001-C1'
  restorationEvidenceSha256 = '24C335AF607595363F4C1D9E68B81AC9E558D37FB49263DE16EF87136D58E6CF'
  flutter = '3.44.0'
  dart = '3.12.0'
  node = '22.15.0'
  npm = '10.9.2'
  javaPrefix = '21.0.11'
  firebaseTools = '15.22.4'
  honoNodeServer = '2.0.10'
  fastUri = '3.1.4'
  braceExpansion = '5.0.8'
  tar = '7.5.21'
  isarFlutterLibs = '3.1.0+1'
  isarFlutterLibsArchiveSha256 = 'BC6768CC4B9C61AABFF77152E7F33B4B17D2FC93134F7AF1C3DD51500FE8D5E8'
}

$CandidatePath = (Resolve-Path $CandidatePath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runRoot = Join-Path $EvidenceRoot "CRM3_V42_R1_16_CANONICAL_LOCAL_LAB_$stamp"
$evidenceDir = Join-Path $runRoot 'evidence'
$workspace = Join-Path $runRoot 'workspace'
New-Item -ItemType Directory -Force -Path $evidenceDir, $workspace | Out-Null
$transcriptPath = Join-Path $evidenceDir '00_TRANSCRIPT.txt'
$transcriptActive = $false
$steps = [System.Collections.Generic.List[object]]::new()
$startedAt = (Get-Date).ToUniversalTime().ToString('o')
$failureStatus = 'FAIL_LOCAL_LAB'
$diagnosticReasons = [System.Collections.Generic.List[string]]::new()
$recordedHolds = [System.Collections.Generic.List[object]]::new()
$isarCoreCustody = $null

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Add-StepResult {
  param([string]$Name, [string]$Status, [string]$Log, [string]$Detail = '')
  $steps.Add([ordered]@{name = $Name; status = $Status; log = $Log; detail = $Detail})
}

function Assert-Command {
  param([Parameter(Mandatory)][string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    $script:failureStatus = 'HOLD_REQUIRED_TOOL_MISSING'
    throw "Required command not found: $Name"
  }
  return $cmd
}

function Invoke-CheckedStep {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action,
    [string]$WorkingDirectory = $workspace
  )
  $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
  $log = Join-Path $evidenceDir "$safeName.log"
  Write-Host "`n===== $Name =====" -ForegroundColor Cyan
  Push-Location $WorkingDirectory
  try {
    $global:LASTEXITCODE = 0
    & $Action 2>&1 | Tee-Object -FilePath $log
    $exitCode = if ($null -eq $global:LASTEXITCODE) {0} else {[int]$global:LASTEXITCODE}
    if ($exitCode -ne 0) {
      Add-StepResult -Name $Name -Status 'FAIL' -Log $log -Detail "exitCode=$exitCode"
      throw "$Name failed with exit code $exitCode"
    }
    Add-StepResult -Name $Name -Status 'PASS' -Log $log
  }
  catch {
    if (-not ($steps | Where-Object {$_.name -eq $Name -and $_.status -eq 'FAIL'})) {
      Add-StepResult -Name $Name -Status 'FAIL' -Log $log -Detail $_.Exception.Message
    }
    throw
  }
  finally {
    Pop-Location
  }
}

function Invoke-RecordedHoldStep {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action,
    [Parameter(Mandatory)][string]$HoldStatus,
    [string]$WorkingDirectory = $workspace
  )
  $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
  $log = Join-Path $evidenceDir "$safeName.log"
  Write-Host "`n===== $Name =====" -ForegroundColor Cyan
  Push-Location $WorkingDirectory
  try {
    $global:LASTEXITCODE = 0
    & $Action 2>&1 | Tee-Object -FilePath $log
    $exitCode = if ($null -eq $global:LASTEXITCODE) {0} else {[int]$global:LASTEXITCODE}
    if ($exitCode -ne 0) {
      $detail = "exitCode=$exitCode; nonBlocking=true"
      Add-StepResult -Name $Name -Status 'HOLD' -Log $log -Detail $detail
      $script:recordedHolds.Add([ordered]@{status=$HoldStatus; step=$Name; detail=$detail; log=$log})
      Write-Host ("{0} recorded; application evidence collection continues, but final PASS remains prohibited." -f $HoldStatus) -ForegroundColor Yellow
      return
    }
    Add-StepResult -Name $Name -Status 'PASS' -Log $log
  }
  catch {
    $detail = "$($_.Exception.Message); nonBlocking=true"
    if (-not ($steps | Where-Object {$_.name -eq $Name})) {
      Add-StepResult -Name $Name -Status 'HOLD' -Log $log -Detail $detail
    }
    $script:recordedHolds.Add([ordered]@{status=$HoldStatus; step=$Name; detail=$detail; log=$log})
    Write-Host ("{0} recorded; application evidence collection continues, but final PASS remains prohibited." -f $HoldStatus) -ForegroundColor Yellow
  }
  finally {
    Pop-Location
  }
}

function Copy-PristineTree {
  param([string]$Source, [string]$Destination)
  Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
  }
}

function Resolve-Python {
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python) { return [ordered]@{exe = $python.Source; prefix = @()} }
  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py) { return [ordered]@{exe = $py.Source; prefix = @('-3')} }
  $script:failureStatus = 'HOLD_REQUIRED_TOOL_MISSING'
  throw 'Python 3 is required.'
}

function Assert-ExactHash {
  param([string]$Path, [string]$ExpectedHash, [string]$Label)
  $actual = Get-Sha256 $Path
  if ($actual -ne $ExpectedHash) {
    $script:failureStatus = 'HOLD_FIREBASE_CUSTODY_MISMATCH'
    throw "$Label SHA-256 mismatch. Expected $ExpectedHash; got $actual"
  }
  return $actual
}

function Assert-AllowedHash {
  param([string]$Path, [string[]]$ExpectedHashes, [string]$Label)
  $actual = Get-Sha256 $Path
  if (-not $ExpectedHashes.Contains($actual)) {
    $script:failureStatus = 'HOLD_FIREBASE_CUSTODY_MISMATCH'
    throw "$Label SHA-256 mismatch. Expected one of $($ExpectedHashes -join ', '); got $actual"
  }
  return $actual
}

function Assert-LockfilesStable {
  param([hashtable]$Before)
  foreach ($rel in $Before.Keys) {
    $path = Join-Path $workspace $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $script:failureStatus = 'HOLD_LOCKFILE_DRIFT'
      throw "Lockfile disappeared: $rel"
    }
    $actual = Get-Sha256 $path
    if ($actual -ne $Before[$rel]) {
      $script:failureStatus = 'HOLD_LOCKFILE_DRIFT'
      throw "Lockfile changed during trial: $rel"
    }
  }
}

function Assert-PublicNpmLockfileCustody {
  param([string[]]$RelativePaths)
  $forbidden = @(
    'packages.applied-caas-gateway1.internal.api.openai.org',
    'artifactory/api/npm/npm-public'
  )
  foreach ($rel in $RelativePaths) {
    $path = Join-Path $workspace $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $script:failureStatus = 'HOLD_LOCKFILE_MISSING'
      throw "npm lockfile missing: $rel"
    }
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($pattern in $forbidden) {
      if ($text.Contains($pattern)) {
        $script:failureStatus = 'HOLD_LOCKFILE_REGISTRY_CONTAMINATION'
        throw "Private/internal npm registry URL found in ${rel}: $pattern"
      }
    }
  }
}

function Get-JsonPropertyValue {
  param(
    [AllowNull()]$Object,
    [Parameter(Mandatory)][string]$Name
  )
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Assert-FirebaseCliLockPolicy {
  $packagePath = Join-Path $workspace 'tooling/firebase-cli/package.json'
  $lockPath = Join-Path $workspace 'tooling/firebase-cli/package-lock.json'
  $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
  $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json -AsHashTable

  $firebaseToolsDeclared = [string](Get-JsonPropertyValue -Object $package.dependencies -Name 'firebase-tools')
  $braceExpansionDeclared = [string](Get-JsonPropertyValue -Object $package.dependencies -Name 'brace-expansion')
  $honoOverride = [string](Get-JsonPropertyValue -Object $package.overrides -Name '@hono/node-server')
  $fastUriOverride = [string](Get-JsonPropertyValue -Object $package.overrides -Name 'fast-uri')
  $braceExpansionOverride = [string](Get-JsonPropertyValue -Object $package.overrides -Name 'brace-expansion')
  $tarOverride = [string](Get-JsonPropertyValue -Object $package.overrides -Name 'tar')
  $lockPackages = Get-JsonPropertyValue -Object $lock -Name 'packages'
  if ($null -eq $lockPackages) {
    $script:failureStatus = 'HOLD_FIREBASE_CLI_LOCK_POLICY'
    throw 'Firebase CLI package-lock.json does not contain a packages map.'
  }
  $honoLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/@hono/node-server'
  $fastUriLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/fast-uri'
  $braceExpansionLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/brace-expansion'
  $braceExpansionUpstreamLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/brace-expansion-modern'
  $tarLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/tar'
  $firebaseToolsLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/firebase-tools'
  $mcpLock = Get-JsonPropertyValue -Object $lockPackages -Name 'node_modules/@modelcontextprotocol/sdk'
  $mcpHonoRange = if ($null -ne $mcpLock) {
    [string](Get-JsonPropertyValue -Object $mcpLock.dependencies -Name '@hono/node-server')
  } else { '' }

  $checks = [ordered]@{
    firebaseToolsDeclared = ($firebaseToolsDeclared -eq $expected.firebaseTools)
    firebaseToolsLocked = ($null -ne $firebaseToolsLock -and [string](Get-JsonPropertyValue -Object $firebaseToolsLock -Name 'version') -eq $expected.firebaseTools)
    honoOverride = ($honoOverride -eq $expected.honoNodeServer)
    honoLocked = ($null -ne $honoLock -and [string](Get-JsonPropertyValue -Object $honoLock -Name 'version') -eq $expected.honoNodeServer)
    honoResolved = ($null -ne $honoLock -and [string](Get-JsonPropertyValue -Object $honoLock -Name 'resolved') -eq 'https://registry.npmjs.org/@hono/node-server/-/node-server-2.0.10.tgz')
    honoIntegrity = ($null -ne $honoLock -and [string](Get-JsonPropertyValue -Object $honoLock -Name 'integrity') -eq 'sha512-ZcnNVhKTmyDJeg0UlnZjvM73JBsTAuhrH/J4fjwGOw59PwOW51r4J+p6CsKZWXdKSme4MFqU62CZMOsdDrU4CA==')
    honoNaturalRange = ($mcpHonoRange -eq '^1.19.9')
    fastUriOverride = ($fastUriOverride -eq $expected.fastUri)
    fastUriLocked = ($null -ne $fastUriLock -and [string](Get-JsonPropertyValue -Object $fastUriLock -Name 'version') -eq $expected.fastUri)
    fastUriResolved = ($null -ne $fastUriLock -and [string](Get-JsonPropertyValue -Object $fastUriLock -Name 'resolved') -eq 'https://registry.npmjs.org/fast-uri/-/fast-uri-3.1.4.tgz')
    fastUriIntegrity = ($null -ne $fastUriLock -and [string](Get-JsonPropertyValue -Object $fastUriLock -Name 'integrity') -eq 'sha512-8JnbkQ4juDyvYs4mgFGQqg4yCYtFDtUtmp2QIQq11ZZe5CFQ5wcqm1rqDgAh/QdMySuBnPzMUiJUNZG5N/AiQw==')
    braceExpansionDeclared = ($braceExpansionDeclared -eq 'file:../brace-expansion-compat')
    braceExpansionOverride = ($braceExpansionOverride -eq '$brace-expansion')
    braceExpansionAdapterLocked = ($null -ne $braceExpansionLock -and [string](Get-JsonPropertyValue -Object $braceExpansionLock -Name 'version') -eq $expected.braceExpansion)
    braceExpansionAdapterResolved = ($null -ne $braceExpansionLock -and [string](Get-JsonPropertyValue -Object $braceExpansionLock -Name 'resolved') -eq 'file:../brace-expansion-compat')
    braceExpansionUpstreamNamed = ($null -ne $braceExpansionUpstreamLock -and [string](Get-JsonPropertyValue -Object $braceExpansionUpstreamLock -Name 'name') -eq 'brace-expansion')
    braceExpansionUpstreamLocked = ($null -ne $braceExpansionUpstreamLock -and [string](Get-JsonPropertyValue -Object $braceExpansionUpstreamLock -Name 'version') -eq $expected.braceExpansion)
    braceExpansionUpstreamResolved = ($null -ne $braceExpansionUpstreamLock -and [string](Get-JsonPropertyValue -Object $braceExpansionUpstreamLock -Name 'resolved') -eq 'https://registry.npmjs.org/brace-expansion/-/brace-expansion-5.0.8.tgz')
    braceExpansionUpstreamIntegrity = ($null -ne $braceExpansionUpstreamLock -and [string](Get-JsonPropertyValue -Object $braceExpansionUpstreamLock -Name 'integrity') -eq 'sha512-JZyDyq3D4AUifKTPOB7DELf6XsB3WdPuNxCtob1vFXPsSXhdAiHBWJ/tJ8HAc9aH84BK+5JFZLNkJKx3G9kzQg==')
    tarOverride = ($tarOverride -eq $expected.tar)
    tarLocked = ($null -ne $tarLock -and [string](Get-JsonPropertyValue -Object $tarLock -Name 'version') -eq $expected.tar)
    tarResolved = ($null -ne $tarLock -and [string](Get-JsonPropertyValue -Object $tarLock -Name 'resolved') -eq 'https://registry.npmjs.org/tar/-/tar-7.5.21.tgz')
    tarIntegrity = ($null -ne $tarLock -and [string](Get-JsonPropertyValue -Object $tarLock -Name 'integrity') -eq 'sha512-XdhtCvlMywwxpCW8YEq3lOXBJpUPTR2OHHcwLPO3HwsJqOHa2Ok/oJ7ruGzp+JrKoRPVCzJwAdEjqLW/vNRPHA==')
    installLinksPolicy = ((Get-Content -LiteralPath (Join-Path $workspace 'tooling/firebase-cli/.npmrc') -Raw).Trim() -eq 'install-links=true')
  }
  $failed = @($checks.GetEnumerator() | Where-Object {-not $_.Value} | ForEach-Object {$_.Key})
  $report = [ordered]@{
    expected = [ordered]@{
      firebaseTools = $expected.firebaseTools
      honoNodeServer = $expected.honoNodeServer
      fastUri = $expected.fastUri
      braceExpansion = $expected.braceExpansion
      tar = $expected.tar
    }
    declared = [ordered]@{
      firebaseTools = $firebaseToolsDeclared
      braceExpansion = $braceExpansionDeclared
      braceExpansionOverride = $braceExpansionOverride
      tarOverride = $tarOverride
      honoNodeServerOverride = $honoOverride
      fastUriOverride = $fastUriOverride
      mcpHonoRange = $mcpHonoRange
    }
    locked = [ordered]@{
      firebaseTools = if ($null -ne $firebaseToolsLock) {[string](Get-JsonPropertyValue -Object $firebaseToolsLock -Name 'version')} else {$null}
      honoNodeServer = if ($null -ne $honoLock) {[string](Get-JsonPropertyValue -Object $honoLock -Name 'version')} else {$null}
      fastUri = if ($null -ne $fastUriLock) {[string](Get-JsonPropertyValue -Object $fastUriLock -Name 'version')} else {$null}
      braceExpansion = if ($null -ne $braceExpansionLock) {[string](Get-JsonPropertyValue -Object $braceExpansionLock -Name 'version')} else {$null}
      braceExpansionUpstream = if ($null -ne $braceExpansionUpstreamLock) {[string](Get-JsonPropertyValue -Object $braceExpansionUpstreamLock -Name 'version')} else {$null}
      tar = if ($null -ne $tarLock) {[string](Get-JsonPropertyValue -Object $tarLock -Name 'version')} else {$null}
    }
    checks = $checks
    failed = $failed
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'firebase-cli-lock-policy.json') -Encoding utf8
  if ($failed.Count -gt 0) {
    $script:failureStatus = 'HOLD_FIREBASE_CLI_LOCK_POLICY'
    throw "Firebase CLI lock policy failed: $($failed -join ', ')"
  }
  Write-Output "PASS_FIREBASE_CLI_LOCK_POLICY: firebase-tools=$firebaseToolsDeclared brace-expansion=$braceExpansionDeclared tar=$tarOverride @hono/node-server=$honoOverride fast-uri=$fastUriOverride"
}

function Assert-FirebaseCliInstalledVersions {
  $packagePaths = [ordered]@{
    firebaseTools = Join-Path $workspace 'tooling/firebase-cli/node_modules/firebase-tools/package.json'
    honoNodeServer = Join-Path $workspace 'tooling/firebase-cli/node_modules/@hono/node-server/package.json'
    fastUri = Join-Path $workspace 'tooling/firebase-cli/node_modules/fast-uri/package.json'
    braceExpansion = Join-Path $workspace 'tooling/firebase-cli/node_modules/brace-expansion/package.json'
    braceExpansionUpstream = Join-Path $workspace 'tooling/firebase-cli/node_modules/brace-expansion-modern/package.json'
    tar = Join-Path $workspace 'tooling/firebase-cli/node_modules/tar/package.json'
  }
  $actual = [ordered]@{}
  foreach ($key in $packagePaths.Keys) {
    $path = $packagePaths[$key]
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $script:failureStatus = 'HOLD_FIREBASE_CLI_DEPENDENCY_VERSION'
      throw "Installed Firebase CLI dependency package.json missing: $key at $path"
    }
    $actual[$key] = [string]((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).version)
  }
  $expectedVersions = [ordered]@{
    firebaseTools = $expected.firebaseTools
    honoNodeServer = $expected.honoNodeServer
    fastUri = $expected.fastUri
    braceExpansion = $expected.braceExpansion
    braceExpansionUpstream = $expected.braceExpansion
    tar = $expected.tar
  }
  $mismatches = @()
  foreach ($key in $expectedVersions.Keys) {
    if ($actual[$key] -ne $expectedVersions[$key]) {
      $mismatches += "$key expected=$($expectedVersions[$key]) actual=$($actual[$key])"
    }
  }
  [ordered]@{
    expected = $expectedVersions
    actual = $actual
    mismatches = $mismatches
  } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidenceDir 'firebase-cli-installed-versions.json') -Encoding utf8
  if ($mismatches.Count -gt 0) {
    $script:failureStatus = 'HOLD_FIREBASE_CLI_DEPENDENCY_VERSION'
    throw "Installed Firebase CLI dependency version mismatch: $($mismatches -join '; ')"
  }
  Write-Output "PASS_FIREBASE_CLI_INSTALLED_VERSIONS: firebase-tools=$($actual.firebaseTools) brace-expansion=$($actual.braceExpansion) tar=$($actual.tar) @hono/node-server=$($actual.honoNodeServer) fast-uri=$($actual.fastUri)"
}

function Invoke-NpmCiStep {
  param(
    [Parameter(Mandatory)][string]$Name,
    [string]$WorkingDirectory = $workspace
  )
  try {
    Invoke-CheckedStep -Name $Name -WorkingDirectory $WorkingDirectory -Action {
      npm ci --ignore-scripts --fetch-retries=3 --fetch-retry-mintimeout=20000 --fetch-retry-maxtimeout=120000
    }
  }
  catch {
    $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
    $log = Join-Path $evidenceDir "$safeName.log"
    $logText = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw } else { '' }
    if ($logText -match '(?i)(ETIMEDOUT|ECONNRESET|EAI_AGAIN|ENETUNREACH|network request|503 Service Unavailable|proxy)') {
      $script:failureStatus = 'HOLD_DEPENDENCY_NETWORK'
    }
    else {
      $script:failureStatus = 'HOLD_DEPENDENCY_INSTALL'
    }
    throw
  }
}

function Find-AndroidInspectionTool {
  $apkanalyzer = Get-Command apkanalyzer -ErrorAction SilentlyContinue
  if ($apkanalyzer) { return [ordered]@{kind='apkanalyzer'; path=$apkanalyzer.Source} }
  $aapt = Get-Command aapt -ErrorAction SilentlyContinue
  if ($aapt) { return [ordered]@{kind='aapt'; path=$aapt.Source} }
  foreach ($root in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $HOME 'AppData/Local/Android/Sdk'))) {
    if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) { continue }
    $candidate = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {$_.Name -in @('apkanalyzer.bat','apkanalyzer','aapt.exe','aapt')} |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($candidate) {
      $kind = if ($candidate.Name -like 'apkanalyzer*') {'apkanalyzer'} else {'aapt'}
      return [ordered]@{kind=$kind; path=$candidate.FullName}
    }
  }
  return $null
}

function Seal-Evidence {
  param([string]$Status)
  if ($script:transcriptActive) {
    try { Stop-Transcript | Out-Null } catch {}
    $script:transcriptActive = $false
  }
  $zipPath = "$runRoot.zip"
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  Compress-Archive -LiteralPath $evidenceDir -DestinationPath $zipPath -CompressionLevel Optimal
  $sha = Get-Sha256 $zipPath
  "$sha  $([IO.Path]::GetFileName($zipPath))" | Set-Content -LiteralPath "$zipPath.sha256.txt" -Encoding ascii
  Write-Host "`n$Status" -ForegroundColor $(if ($Status -like 'PASS*') {'Green'} else {'Yellow'})
  Write-Host "Evidence ZIP: $zipPath"
  Write-Host "SHA-256:      $sha"
}

try {
  Start-Transcript -Path $transcriptPath -Force | Out-Null
  $transcriptActive = $true
  Write-Host 'CRM3 v4.2_R1.16 canonical-main local laboratory' -ForegroundColor Green
  Write-Host "Pristine candidate: $CandidatePath"
  Write-Host "Disposable workspace: $workspace"
  Write-Host "Mode: $Mode"
  Write-Host 'No Git remote mutation, backend release action, production write, uninstall, or data clear is performed.'

  if ($SkipFlutterTests -and $Mode -eq 'Authoritative') {
    $failureStatus = 'HOLD_TESTS_SKIPPED'
    throw 'Authoritative mode does not permit -SkipFlutterTests.'
  }
  if ($SkipFlutterTests) { $diagnosticReasons.Add('flutter-tests-skipped') }

  $python = Resolve-Python
  $pythonExe = [string]$python.exe
  $pythonPrefix = @($python.prefix)
  foreach ($required in @(
    'V4_2_R1_HANDOFF/FILE_SHA256SUMS.txt',
    'governance/v4_successor_programme_authority_v1.json',
    'docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json',
    'docs/v4_2_r1/CANONICAL_ISAR_SCHEMA_BASELINE.json',
    'tools/v4/trial_workspace_custody.py',
    'tools/isar/verify_canonical_main_isar_continuity.py',
    'tools/isar/stage_governed_test_isar_core.py'
  )) {
    if (-not (Test-Path -LiteralPath (Join-Path $CandidatePath $required) -PathType Leaf)) {
      $failureStatus = 'HOLD_CANDIDATE_INCOMPLETE'
      throw "Candidate is incomplete: $required"
    }
  }

  Invoke-CheckedStep -Name '01_pristine_candidate_manifest' -WorkingDirectory $CandidatePath -Action {
    & $pythonExe @pythonPrefix 'tools/v4/verify_file_manifest.py' '--manifest' 'V4_2_R1_HANDOFF/FILE_SHA256SUMS.txt' '--root' '.'
  }
  Copy-PristineTree -Source $CandidatePath -Destination $workspace
  Invoke-CheckedStep -Name '02_workspace_copy_manifest' -Action {
    & $pythonExe @pythonPrefix 'tools/v4/verify_file_manifest.py' '--manifest' 'V4_2_R1_HANDOFF/FILE_SHA256SUMS.txt' '--root' '.'
  }

  $beforeManifest = Join-Path $evidenceDir 'workspace-pristine-manifest.json'
  Invoke-CheckedStep -Name '03_workspace_pristine_inventory' -Action {
    & $pythonExe @pythonPrefix 'tools/v4/trial_workspace_custody.py' 'capture' '--root' '.' '--output' $beforeManifest
  }

  foreach ($command in @('node','npm','flutter','dart','java')) { Assert-Command $command | Out-Null }

  if (-not $FirebaseOptionsPath -and $CurrentAppRoot) { $FirebaseOptionsPath = Join-Path $CurrentAppRoot 'lib/firebase_options.dart' }
  if (-not $GoogleServicesPath -and $CurrentAppRoot) { $GoogleServicesPath = Join-Path $CurrentAppRoot 'android/app/google-services.json' }
  if (-not $FirebaseOptionsPath -or -not (Test-Path -LiteralPath $FirebaseOptionsPath -PathType Leaf)) {
    $failureStatus = 'HOLD_FIREBASE_INPUT_MISSING'
    throw 'Provide -CurrentAppRoot or -FirebaseOptionsPath.'
  }
  if (-not $GoogleServicesPath -or -not (Test-Path -LiteralPath $GoogleServicesPath -PathType Leaf)) {
    $failureStatus = 'HOLD_FIREBASE_INPUT_MISSING'
    throw 'Provide -CurrentAppRoot or -GoogleServicesPath.'
  }
  $FirebaseOptionsPath = (Resolve-Path $FirebaseOptionsPath).Path
  $GoogleServicesPath = (Resolve-Path $GoogleServicesPath).Path
  $firebaseOptionsSha = Assert-ExactHash -Path $FirebaseOptionsPath -ExpectedHash $expected.firebaseOptionsSha256 -Label 'firebase_options.dart'
  $googleServicesSha = Assert-AllowedHash -Path $GoogleServicesPath -ExpectedHashes @(
    $expected.canonicalGoogleServicesSha256,
    $expected.canonicalRepositoryGoogleServicesSha256
  ) -Label 'canonical-main google-services.json'

  $firebaseOptionsText = Get-Content -LiteralPath $FirebaseOptionsPath -Raw
  if ($firebaseOptionsText -notmatch [regex]::Escape($expected.projectId) -or
      $firebaseOptionsText -notmatch [regex]::Escape($expected.firebaseAppId)) {
    $failureStatus = 'HOLD_FIREBASE_IDENTITY_MISMATCH'
    throw 'firebase_options.dart identity does not match the governed project/app.'
  }
  $googleServices = Get-Content -LiteralPath $GoogleServicesPath -Raw | ConvertFrom-Json
  $matchingClient = @($googleServices.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq $expected.packageName -and
    $_.client_info.mobilesdk_app_id -eq $expected.firebaseAppId
  })
  if ([string]$googleServices.project_info.project_id -ne $expected.projectId -or $matchingClient.Count -ne 1) {
    $failureStatus = 'HOLD_FIREBASE_IDENTITY_MISMATCH'
    throw 'google-services.json identity does not match the governed project/package/app.'
  }
  $androidOauthClients = @($matchingClient[0].oauth_client | Where-Object {
    [int]$_.client_type -eq 1 -and
    [string]$_.android_info.package_name -eq $expected.packageName
  })
  $debugOauth = @($androidOauthClients | Where-Object {
    [string]$_.client_id -eq $expected.debugOauthClientId -and
    ([string]$_.android_info.certificate_hash).Replace(':','').ToUpperInvariant() -eq '30B58F0F39E1BA3CA69FD9032D7CF6FB41EC8F31'
  })
  $productionOauth = @($androidOauthClients | Where-Object {
    [string]$_.client_id -eq $expected.productionOauthClientId -and
    ([string]$_.android_info.certificate_hash).Replace(':','').ToUpperInvariant() -eq '41C2B828C71683A50EC346D19E1D44048758438D'
  })
  if ($androidOauthClients.Count -ne 2 -or $debugOauth.Count -ne 1 -or $productionOauth.Count -ne 1) {
    $failureStatus = 'HOLD_FIREBASE_IDENTITY_MISMATCH'
    throw 'Combined google-services.json does not contain exactly the governed debug and production Android OAuth clients.'
  }
  New-Item -ItemType Directory -Force -Path (Join-Path $workspace 'lib'), (Join-Path $workspace 'android/app') | Out-Null
  Copy-Item -LiteralPath $FirebaseOptionsPath -Destination (Join-Path $workspace 'lib/firebase_options.dart') -Force
  Copy-Item -LiteralPath $GoogleServicesPath -Destination (Join-Path $workspace 'android/app/google-services.json') -Force
  [ordered]@{
    projectId = $expected.projectId
    packageName = $expected.packageName
    firebaseAppId = $expected.firebaseAppId
    firebaseOptionsSha256 = $firebaseOptionsSha
    canonicalMainGoogleServicesSha256 = $googleServicesSha
    canonicalMainGoogleServicesSemanticSha256 = $expected.canonicalGoogleServicesSemanticSha256
    supersededDebugOnlyGoogleServicesSha256 = $expected.supersededDebugOnlyGoogleServicesSha256
    supersededDebugOnlyGoogleServicesSemanticSha256 = $expected.supersededDebugOnlyGoogleServicesSemanticSha256
    registrationSourceGoogleServicesSha256 = $expected.registrationSourceGoogleServicesSha256
    debugOauthClientId = $expected.debugOauthClientId
    productionOauthClientId = $expected.productionOauthClientId
    restorationReference = $expected.restorationReference
    restorationEvidenceSha256 = $expected.restorationEvidenceSha256
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidenceDir 'firebase-custody.json') -Encoding utf8

  $nodeVersion = ((& node --version) -join '').TrimStart('v')
  $npmVersion = ((& npm --version) -join '').Trim()
  $javaText = (& java -version 2>&1) -join "`n"
  $flutterMachineText = (& flutter --version --machine 2>&1) -join "`n"
  $flutterInfo = $flutterMachineText | ConvertFrom-Json
  $flutterVersion = [string]$flutterInfo.frameworkVersion
  $dartVersion = ([string]$flutterInfo.dartSdkVersion -split '\s+')[0]
  $toolchainMismatches = [System.Collections.Generic.List[string]]::new()
  if ($nodeVersion -ne $expected.node) { $toolchainMismatches.Add("node expected=$($expected.node) actual=$nodeVersion") }
  if ($npmVersion -ne $expected.npm) { $toolchainMismatches.Add("npm expected=$($expected.npm) actual=$npmVersion") }
  if ($javaText -notmatch [regex]::Escape($expected.javaPrefix)) { $toolchainMismatches.Add("java expected-prefix=$($expected.javaPrefix)") }
  if ($flutterVersion -ne $expected.flutter) { $toolchainMismatches.Add("flutter expected=$($expected.flutter) actual=$flutterVersion") }
  if ($dartVersion -ne $expected.dart) { $toolchainMismatches.Add("dart expected=$($expected.dart) actual=$dartVersion") }
  [ordered]@{
    expected = $expected
    actual = [ordered]@{node=$nodeVersion; npm=$npmVersion; java=$javaText; flutter=$flutterVersion; dart=$dartVersion}
    mismatches = $toolchainMismatches
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'toolchain.json') -Encoding utf8
  if ($toolchainMismatches.Count -gt 0 -and $Mode -eq 'Authoritative') {
    $failureStatus = 'HOLD_TOOLCHAIN_MISMATCH'
    throw "Pinned toolchain mismatch: $($toolchainMismatches -join '; ')"
  }
  foreach ($mismatch in $toolchainMismatches) { $diagnosticReasons.Add($mismatch) }

  Assert-PublicNpmLockfileCustody -RelativePaths @(
    'package-lock.json',
    'functions/package-lock.json',
    'tooling/firebase-cli/package-lock.json'
  )

  $lockfiles = @{}
  foreach ($rel in @('pubspec.lock','package-lock.json','functions/package-lock.json','tooling/firebase-cli/package-lock.json')) {
    $lockfiles[$rel] = Get-Sha256 (Join-Path $workspace $rel)
  }
  $lockfiles | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidenceDir 'lockfiles-before.json') -Encoding utf8

  Invoke-CheckedStep -Name '04_integrity_sweep_unit_tests' -Action { node --test tools/v4/firestore_integrity_sweep.test.mjs }
  Invoke-NpmCiStep -Name '05_root_npm_ci'
  Invoke-CheckedStep -Name '06_root_npm_audit' -Action { npm audit --audit-level=low }
  Invoke-NpmCiStep -Name '07_functions_npm_ci' -WorkingDirectory (Join-Path $workspace 'functions')
  $failureStatus = 'HOLD_FUNCTIONS_TYPECHECK'
  Invoke-CheckedStep -Name '08_functions_typecheck' -WorkingDirectory (Join-Path $workspace 'functions') -Action { npm run build -- --noEmit --pretty false }
  $failureStatus = 'FAIL_LOCAL_LAB'
  Invoke-CheckedStep -Name '09_functions_npm_audit' -WorkingDirectory (Join-Path $workspace 'functions') -Action { npm audit --audit-level=low }
  $failureStatus = 'HOLD_FIREBASE_CLI_LOCK_POLICY'
  Invoke-CheckedStep -Name '10_firebase_cli_lock_policy' -WorkingDirectory (Join-Path $workspace 'tooling/firebase-cli') -Action { Assert-FirebaseCliLockPolicy }
  $failureStatus = 'FAIL_LOCAL_LAB'
  Invoke-NpmCiStep -Name '11_firebase_cli_npm_ci' -WorkingDirectory (Join-Path $workspace 'tooling/firebase-cli')
  $failureStatus = 'HOLD_FIREBASE_CLI_DEPENDENCY_VERSION'
  Invoke-CheckedStep -Name '12_firebase_cli_installed_versions' -WorkingDirectory (Join-Path $workspace 'tooling/firebase-cli') -Action { Assert-FirebaseCliInstalledVersions }
  $failureStatus = 'HOLD_FIREBASE_CLI_RUNTIME'
  Invoke-CheckedStep -Name '13_firebase_cli_load_smoke' -WorkingDirectory (Join-Path $workspace 'tooling/firebase-cli') -Action {
    $compatibilityScript = Join-Path $workspace 'tools/dependencies/verify_brace_expansion_compat.mjs'
    & node $compatibilityScript
    $firebaseCliEntry = Join-Path (Get-Location) 'node_modules/firebase-tools/lib/bin/firebase.js'
    $loadedVersion = ((& node $firebaseCliEntry --version 2>&1) -join "`n").Trim()
    if ($loadedVersion -ne $expected.firebaseTools) {
      throw "Firebase CLI load/version mismatch. Expected $($expected.firebaseTools); got $loadedVersion"
    }
    Write-Output "PASS_FIREBASE_CLI_LOAD_SMOKE: firebase-tools=$loadedVersion"
  }
  $failureStatus = 'FAIL_LOCAL_LAB'
  Invoke-RecordedHoldStep -Name '14_firebase_cli_npm_audit' -WorkingDirectory (Join-Path $workspace 'tooling/firebase-cli') -HoldStatus 'HOLD_FIREBASE_CLI_DEPENDENCY_AUDIT' -Action { npm audit --audit-level=low }
  Assert-LockfilesStable -Before $lockfiles

  Invoke-CheckedStep -Name '15_flutter_pub_get' -Action { flutter pub get }
  Assert-LockfilesStable -Before $lockfiles
  Invoke-CheckedStep -Name '16_authentic_isar_codegen' -Action { dart run build_runner build --delete-conflicting-outputs }
  Assert-LockfilesStable -Before $lockfiles

  $postCodegenManifest = Join-Path $evidenceDir 'workspace-post-codegen-manifest.json'
  $postCodegenReport = Join-Path $evidenceDir 'workspace-post-codegen-delta.json'
  Invoke-CheckedStep -Name '17_post_codegen_custody' -Action {
    & $pythonExe @pythonPrefix 'tools/v4/trial_workspace_custody.py' 'verify' '--root' '.' '--before' $beforeManifest '--report' $postCodegenReport '--after' $postCodegenManifest
  }
  Invoke-CheckedStep -Name '18_canonical_isar_semantic_continuity' -Action {
    & $pythonExe @pythonPrefix 'tools/isar/verify_canonical_main_isar_continuity.py' '--report' (Join-Path $evidenceDir 'isar-semantic-continuity.json')
  }
  Invoke-CheckedStep -Name '19_isar_release_authority' -Action {
    & $pythonExe @pythonPrefix 'tools/isar/verify_v4_isar_schema.py' '--release'
  }

  Invoke-CheckedStep -Name '20_v42_r1_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/v4_2_r1_canonical_audit.py' '--phase' 'post-codegen' }
  Invoke-CheckedStep -Name '21_v42_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/v4_2_ultimate_audit.py' }
  Invoke-CheckedStep -Name '22_v41_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/v4_1_due_diligence_audit.py' }
  Invoke-CheckedStep -Name '23_whole_app_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/whole_app_reconciliation_audit.py' }
  Invoke-CheckedStep -Name '24_inherited_full_tree_audit' -Action { & $pythonExe @pythonPrefix 'tools/maintenance_workflow/full_tree_source_audit.py' }
  Invoke-CheckedStep -Name '25_inherited_expanded_audit' -Action { & $pythonExe @pythonPrefix 'tools/expanded_audit/expanded_implementation_audit.py' }
  Invoke-CheckedStep -Name '26_dart_structural_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/dart_structural_audit.py' }
  Invoke-CheckedStep -Name '27_policy_generation_check' -Action { npm run workflow:policy:check }
  Invoke-CheckedStep -Name '28_functions_tests' -WorkingDirectory (Join-Path $workspace 'functions') -Action { npm test }
  Invoke-CheckedStep -Name '29_flutter_analyze' -Action { flutter analyze }
  if (-not $SkipFlutterTests) {
    $isarCorePath = Join-Path $workspace '.governed-native/isar.dll'
    $isarCoreEvidencePath = Join-Path $evidenceDir 'isar-test-core-custody.json'
    $failureStatus = 'HOLD_ISAR_CORE_CUSTODY'
    Invoke-CheckedStep -Name '30_isar_test_core_custody' -Action {
      & $pythonExe @pythonPrefix 'tools/isar/stage_governed_test_isar_core.py' `
        '--project-root' $workspace `
        '--output' $isarCorePath `
        '--evidence' $isarCoreEvidencePath `
        '--expected-version' $expected.isarFlutterLibs `
        '--expected-archive-sha256' $expected.isarFlutterLibsArchiveSha256
    }
    $isarCoreCustody = Get-Content -LiteralPath $isarCoreEvidencePath -Raw | ConvertFrom-Json

    $previousIsarCorePath = [Environment]::GetEnvironmentVariable('CRM_ISAR_CORE_PATH', 'Process')
    $previousIsarCoreRequired = [Environment]::GetEnvironmentVariable('CRM_ISAR_CORE_REQUIRED', 'Process')
    [Environment]::SetEnvironmentVariable('CRM_ISAR_CORE_PATH', $isarCorePath, 'Process')
    [Environment]::SetEnvironmentVariable('CRM_ISAR_CORE_REQUIRED', '1', 'Process')
    try {
      $failureStatus = 'FAIL_LOCAL_LAB'
      Invoke-CheckedStep -Name '31_flutter_tests' -Action {
        flutter test --concurrency=1
      }
    }
    finally {
      [Environment]::SetEnvironmentVariable('CRM_ISAR_CORE_PATH', $previousIsarCorePath, 'Process')
      [Environment]::SetEnvironmentVariable('CRM_ISAR_CORE_REQUIRED', $previousIsarCoreRequired, 'Process')
    }
  }
  Invoke-CheckedStep -Name '32_android_debug_apk' -Action { flutter build apk --debug }
  Assert-LockfilesStable -Before $lockfiles

  $emulatorPassed = $false
  if ($RunEmulators) {
    $emulatorConfig = Join-Path $workspace ".firebase.v42r1.$stamp.json"
    $config = Get-Content -LiteralPath (Join-Path $workspace 'firebase.json') -Raw | ConvertFrom-Json
    $config.emulators.firestore | Add-Member -NotePropertyName host -NotePropertyValue '127.0.0.1' -Force
    $config.emulators.firestore.port = $EmulatorPort
    $config.emulators.ui.enabled = $false
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $emulatorConfig -Encoding utf8
    try {
      $firebaseCli = Join-Path $workspace 'tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js'
      Invoke-CheckedStep -Name '33_rules_and_functions_emulators' -Action {
        node $firebaseCli emulators:exec --config $emulatorConfig --only firestore "npm run test:rules && npm --prefix functions run test:emulator:governed"
      }
      $emulatorPassed = $true
    }
    finally {
      Remove-Item -LiteralPath $emulatorConfig -Force -ErrorAction SilentlyContinue
    }
  }

  $apkPath = Join-Path $workspace 'build/app/outputs/flutter-apk/app-debug.apk'
  if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    $failureStatus = 'HOLD_APK_MISSING'
    throw "Debug APK not found: $apkPath"
  }
  $apkCopy = Join-Path $evidenceDir 'app-debug.apk'
  Copy-Item -LiteralPath $apkPath -Destination $apkCopy -Force
  $apkSha = Get-Sha256 $apkCopy
  $inspection = Find-AndroidInspectionTool
  if (-not $inspection -and $Mode -eq 'Authoritative') {
    $failureStatus = 'HOLD_APK_IDENTITY_TOOL_MISSING'
    throw 'apkanalyzer or aapt is required for authoritative APK identity inspection.'
  }
  $apkIdentityText = ''
  if ($inspection) {
    if ($inspection.kind -eq 'apkanalyzer') {
      $appId = ((& $inspection.path manifest application-id $apkCopy 2>&1) -join '').Trim()
      $versionName = ((& $inspection.path manifest version-name $apkCopy 2>&1) -join '').Trim()
      $versionCode = ((& $inspection.path manifest version-code $apkCopy 2>&1) -join '').Trim()
      $apkIdentityText = "applicationId=$appId`nversionName=$versionName`nversionCode=$versionCode"
      if ($appId -ne $expected.packageName) {
        $failureStatus = 'HOLD_APK_IDENTITY_MISMATCH'
        throw "APK application ID mismatch: $appId"
      }
    }
    else {
      $apkIdentityText = (& $inspection.path dump badging $apkCopy 2>&1) -join "`n"
      if ($apkIdentityText -notmatch "package: name='$([regex]::Escape($expected.packageName))'") {
        $failureStatus = 'HOLD_APK_IDENTITY_MISMATCH'
        throw 'APK package identity mismatch.'
      }
    }
    $apkIdentityText | Set-Content -LiteralPath (Join-Path $evidenceDir 'apk-identity.txt') -Encoding utf8
  }
  [ordered]@{path='app-debug.apk'; sha256=$apkSha; bytes=(Get-Item $apkCopy).Length; inspectionTool=$inspection} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidenceDir 'apk-custody.json') -Encoding utf8

  $freshInstallPassed = $false
  if ($InstallOnCleanDevice) {
    Assert-Command adb | Out-Null
    if (-not $DeviceId) {
      $devices = @(& adb devices | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '^([^\s]+)\s+device$') {$matches[1]}
      })
      if ($devices.Count -ne 1) {
        $failureStatus = 'HOLD_DEVICE_SELECTION_REQUIRED'
        throw 'Specify -DeviceId unless exactly one authorised device is connected.'
      }
      $DeviceId = $devices[0]
    }
    $existing = (& adb -s $DeviceId shell pm path $expected.packageName 2>&1) -join "`n"
    if ($existing -match '^package:') {
      $failureStatus = 'HOLD_DEVICE_NOT_CLEAN'
      throw 'Target device already contains the package. This harness proves fresh install only and will not uninstall or clear it.'
    }
    Invoke-CheckedStep -Name '34_clean_device_fresh_install' -Action { adb -s $DeviceId install -t $apkCopy }
    & adb -s $DeviceId shell dumpsys package $expected.packageName 2>&1 |
      Set-Content -LiteralPath (Join-Path $evidenceDir 'device-package-dump.txt') -Encoding utf8
    $freshInstallPassed = $true
  }

  $authoritative = $Mode -eq 'Authoritative' -and $diagnosticReasons.Count -eq 0 -and -not $SkipFlutterTests
  if ($freshInstallPassed) {
    $executionOutcome = if ($authoritative) {'PASS_AUTHORITATIVE_FRESH_INSTALL'} else {'PASS_DIAGNOSTIC_FRESH_INSTALL'}
  }
  elseif ($emulatorPassed) {
    $executionOutcome = if ($authoritative) {'PASS_AUTHORITATIVE_BUILD_AND_EMULATOR'} else {'PASS_DIAGNOSTIC_BUILD_AND_EMULATOR'}
  }
  else {
    $executionOutcome = if ($authoritative) {'PASS_AUTHORITATIVE_BUILD_ONLY'} else {'PASS_DIAGNOSTIC_BUILD_ONLY'}
  }
  if ($recordedHolds.Count -eq 0) {
    $status = $executionOutcome
  }
  elseif ($recordedHolds.Count -eq 1) {
    $status = [string]$recordedHolds[0].status
  }
  else {
    $status = 'HOLD_MULTIPLE_NONBLOCKING_GATES'
  }
  $result = [ordered]@{
    schemaVersion = 1
    status = $status
    canonicalMainCommit = $expected.canonicalMainCommit
    canonicalMainTree = $expected.canonicalMainTree
    pristineCandidate = $CandidatePath
    disposableWorkspace = $workspace
    mode = $Mode
    diagnosticReasons = $diagnosticReasons
    recordedHolds = $recordedHolds
    executionOutcome = $executionOutcome
    startedAt = $startedAt
    completedAt = (Get-Date).ToUniversalTime().ToString('o')
    remoteGitMutationPerformed = $false
    firebaseDeploymentPerformed = $false
    productionDataMutationPerformed = $false
    deviceUninstallOrClearPerformed = $false
    emulatorPassed = $emulatorPassed
    freshInstallPassed = $freshInstallPassed
    isarTestCoreCustody = $isarCoreCustody
    apkSha256 = $apkSha
    deviceId = if ($freshInstallPassed) {$DeviceId} else {$null}
    steps = $steps
  }
  $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidenceDir 'trial-result.json') -Encoding utf8
  if (-not $KeepWorkspace) { Remove-Item -LiteralPath $workspace -Recurse -Force }
  Seal-Evidence -Status $status
  if ($status -like 'HOLD*') { exit 2 }
}
catch {
  $failure = [ordered]@{
    schemaVersion = 1
    status = $failureStatus
    canonicalMainCommit = $expected.canonicalMainCommit
    canonicalMainTree = $expected.canonicalMainTree
    pristineCandidate = $CandidatePath
    disposableWorkspace = $workspace
    mode = $Mode
    diagnosticReasons = $diagnosticReasons
    recordedHolds = $recordedHolds
    startedAt = $startedAt
    failedAt = (Get-Date).ToUniversalTime().ToString('o')
    error = $_.Exception.Message
    remoteGitMutationPerformed = $false
    firebaseDeploymentPerformed = $false
    productionDataMutationPerformed = $false
    deviceUninstallOrClearPerformed = $false
    isarTestCoreCustody = $isarCoreCustody
    steps = $steps
  }
  $failure | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidenceDir 'trial-result.json') -Encoding utf8
  Write-Host ("{0}: {1}" -f $failureStatus, $_.Exception.Message) -ForegroundColor Red
  Seal-Evidence -Status $failureStatus
  exit 1
}
finally {
  if ($transcriptActive) {
    try { Stop-Transcript | Out-Null } catch {}
  }
}
