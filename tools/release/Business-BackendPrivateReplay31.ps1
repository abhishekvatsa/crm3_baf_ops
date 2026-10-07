#requires -Version 7.0
# Fresh replay prerequisite only. The independently selected controller owns
# dispatch and authenticates the completed private replay; this bridge never
# accepts a saved result, callback or permission supplied by candidate metadata.
function Test-ProductionBusiness31Selected {
  param([Parameter(Mandatory)][object]$Policy)
  if ($Policy -is [Collections.IDictionary]) {
    if ($Policy.Contains('businessBackendPrivateReplay')) { return $true }
    foreach ($name in @('clientBackendCompatibility', 'runtimeBackendPrivateReplay')) {
      if ($Policy.Contains($name) -and $null -ne $Policy[$name]) {
        foreach ($field in @('profile', 'file')) {
          if ([string]$Policy[$name][$field] -match '(?i)business') { return $true }
        }
      }
    }
    return $false
  }
  if ($null -ne $Policy.PSObject.Properties['businessBackendPrivateReplay']) { return $true }
  foreach ($name in @('clientBackendCompatibility', 'runtimeBackendPrivateReplay')) {
    $property = $Policy.PSObject.Properties[$name]
    if ($null -ne $property -and $null -ne $property.Value) {
      foreach ($field in @('profile', 'file')) {
        $value = $property.Value.PSObject.Properties[$field]
        if ($null -ne $value -and [string]$value.Value -match '(?i)business') { return $true }
      }
    }
  }
  return $false
}

function Assert-Business31Keys {
  param([object]$Value, [string[]]$Names, [string]$Label)
  if ($Value -isnot [Collections.IDictionary]) { throw "$Label must be a JSON object." }
  $actual = @($Value.Keys | Sort-Object -CaseSensitive)
  $expected = @($Names | Sort-Object -CaseSensitive)
  if (($actual -join "`n") -cne ($expected -join "`n")) { throw "$Label fields differ." }
}

function Get-Business31RegularPath {
  param([string]$Path, [switch]$Directory)
  if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathFullyQualified($Path)) {
    throw 'Business31 requires an absolute path.'
  }
  $full = [IO.Path]::GetFullPath($Path)
  $current = [IO.Path]::GetPathRoot($full)
  foreach ($part in $full.Substring($current.Length).Split([char[]]@('/', '\'), [StringSplitOptions]::RemoveEmptyEntries)) {
    $current = Join-Path $current $part
    $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Business31 refuses redirected paths.' }
  }
  $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
  if ($Directory) {
    if (-not $item.PSIsContainer) { throw 'Business31 requires a directory.' }
  } elseif ($item.PSIsContainer) { throw 'Business31 requires a regular file.' }
  return $full
}

function Get-Business31FileHash {
  param([string]$Path, [long]$MaximumBytes = 268435456)
  $full = Get-Business31RegularPath $Path
  $before = Get-Item -LiteralPath $full -Force
  if ($before.Length -gt $MaximumBytes) { throw 'Business31 file exceeds its byte bound.' }
  $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
  [void](Get-Business31RegularPath $full)
  $after = Get-Item -LiteralPath $full -Force
  if ($before.Length -ne $after.Length -or $before.LastWriteTimeUtc -ne $after.LastWriteTimeUtc) {
    throw 'Business31 file changed during hashing.'
  }
  return $hash
}

function Read-Business31Json {
  param([string]$Path, [int]$MaximumBytes = 2097152)
  $full = Get-Business31RegularPath $Path
  if ((Get-Item -LiteralPath $full).Length -gt $MaximumBytes) { throw 'Business31 JSON exceeds its byte bound.' }
  $bytes = [IO.File]::ReadAllBytes($full)
  if ($bytes.Length -eq 0 -or $bytes.Length -gt $MaximumBytes) { throw 'Business31 JSON byte bound differs.' }
  $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
  $document = [Text.Json.JsonDocument]::Parse($text)
  try {
    function ConvertFrom-Business31JsonElement($Element, [int]$Depth) {
      if ($Depth -gt 40) { throw 'Business31 JSON depth exceeds its bound.' }
      if ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $result = [ordered]@{}
        foreach ($property in $Element.EnumerateObject()) {
          if (-not $seen.Add($property.Name)) { throw 'Business31 JSON has duplicate keys.' }
          $result[$property.Name] = ConvertFrom-Business31JsonElement $property.Value ($Depth + 1)
        }
        return $result
      } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array) {
        $items = [Collections.Generic.List[object]]::new()
        foreach ($child in $Element.EnumerateArray()) { $items.Add((ConvertFrom-Business31JsonElement $child ($Depth + 1))) }
        return ,$items.ToArray()
      } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::String) {
        return $Element.GetString()
      } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Number) {
        $integer = 0L
        if ($Element.TryGetInt64([ref]$integer)) { return $integer }
        return $Element.GetDouble()
      } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::True) {
        return $true
      } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::False) {
        return $false
      } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Null) {
        return $null
      }
      throw 'Business31 JSON value kind is unsupported.'
    }
    return ConvertFrom-Business31JsonElement $document.RootElement 0
  } finally { $document.Dispose() }
}

function ConvertTo-Business31CanonicalJson {
  param([AllowNull()][object]$Value)
  if ($Value -is [Collections.IDictionary]) {
    $parts = foreach ($key in @($Value.Keys | Sort-Object -CaseSensitive)) {
      ($key | ConvertTo-Json -Compress) + ':' + (ConvertTo-Business31CanonicalJson $Value[$key])
    }
    return '{' + ($parts -join ',') + '}'
  }
  if ($Value -is [Array]) {
    $parts = foreach ($item in $Value) { ConvertTo-Business31CanonicalJson $item }
    return '[' + ($parts -join ',') + ']'
  }
  return ConvertTo-Json -InputObject $Value -Compress -Depth 50
}

function Assert-Business31Same {
  param([AllowNull()][object]$Actual, [AllowNull()][object]$Expected, [string]$Label)
  if ((ConvertTo-Business31CanonicalJson $Actual) -cne (ConvertTo-Business31CanonicalJson $Expected)) {
    throw "$Label differs."
  }
}

function Assert-Business31Pointer {
  param([object]$Value, [string]$Profile, [string]$File)
  Assert-Business31Keys $Value @('profile', 'commit', 'file', 'sha256') 'Business31 policy pointer'
  if ($Value.profile -cne $Profile -or $Value.file -cne $File -or
      $Value.commit -isnot [string] -or $Value.commit -cnotmatch '^[a-f0-9]{40}$' -or
      $Value.sha256 -isnot [string] -or $Value.sha256 -cnotmatch '^[A-F0-9]{64}$') {
    throw 'Business31 policy pointer is malformed.'
  }
}

function Assert-Business31SelectedFiles {
  param([string]$Root, [object]$Files)
  if ($Files -isnot [Collections.IDictionary] -or $Files.Count -eq 0 -or $Files.Count -gt 256) {
    throw 'Business31 complete verifier file selection is absent.'
  }
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($name in $Files.Keys) {
    if ($name -isnot [string] -or $name -cnotmatch '^[A-Za-z0-9._/-]+$' -or
        $name.StartsWith('/') -or $name.Split('/') -contains '..' -or $name.Split('/') -contains '.' -or
        $name.Contains('//') -or -not $seen.Add($name) -or
        $Files[$name] -isnot [string] -or $Files[$name] -cnotmatch '^[A-F0-9]{64}$') {
      throw 'Business31 verifier file selection is malformed.'
    }
    if ((Get-Business31FileHash (Join-Path $Root $name) 2097152) -cne $Files[$name]) {
      throw 'Business31 selected verifier file bytes differ.'
    }
  }
  if (-not $Files.Contains('tools/release/business31Prerequisite.cjs')) { throw 'Business31 controller entry is not selected.' }
}

function Invoke-Business31OwnedController {
  param([Diagnostics.ProcessStartInfo]$Start, [string]$Directory, [int]$TimeoutSeconds)
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $Start
  $stdout = [IO.MemoryStream]::new(); $stderr = [IO.MemoryStream]::new()
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $failure = $null
  try {
    [void]$process.Start()
    $buffers = @([byte[]]::new(8192), [byte[]]::new(8192))
    $streams = @($process.StandardOutput.BaseStream, $process.StandardError.BaseStream)
    $sinks = @($stdout, $stderr)
    $tasks = @($streams[0].ReadAsync($buffers[0], 0, 8192), $streams[1].ReadAsync($buffers[1], 0, 8192))
    $eof = @($false, $false)
    while (-not ($process.HasExited -and $eof[0] -and $eof[1])) {
      if ($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) { throw 'Business31 controller timed out.' }
      for ($index = 0; $index -lt 2; $index++) {
        if (-not $eof[$index] -and $tasks[$index].IsCompleted) {
          $count = $tasks[$index].GetAwaiter().GetResult()
          if ($count -eq 0) { $eof[$index] = $true; continue }
          if ($sinks[$index].Length + $count -gt 1048576) { throw 'Business31 controller output exceeds its bound.' }
          $sinks[$index].Write($buffers[$index], 0, $count)
          $tasks[$index] = $streams[$index].ReadAsync($buffers[$index], 0, 8192)
        }
      }
      Start-Sleep -Milliseconds 20
    }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw 'Business31 protected controller failed; retained stderr is diagnostic only.' }
  } catch {
    $failure = $_
    try { if (-not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(10000) } } catch { }
  } finally {
    try {
      [IO.File]::WriteAllBytes((Join-Path $Directory 'controller-stdout.bin'), $stdout.ToArray())
      [IO.File]::WriteAllBytes((Join-Path $Directory 'controller-stderr.bin'), $stderr.ToArray())
    } finally { $stdout.Dispose(); $stderr.Dispose(); $process.Dispose() }
  }
  if ($null -ne $failure) { throw $failure }
}

function Invoke-ProductionBusiness31PrerequisiteReplay {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('Construction', 'PackageVerification')][string]$Purpose,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][object]$Policy,
    [string]$SourceArchivePath,
    [string]$ManifestPath,
    [string]$ResumeRequestPath,
    [string]$RequestOutputPath
  )
  if (-not (Test-ProductionBusiness31Selected $Policy)) { return $null }
  $policyData = ($Policy | ConvertTo-Json -Depth 50 -Compress) | ConvertFrom-Json -AsHashtable -Depth 50
  if (($policyData.release.buildNumber -isnot [int] -and $policyData.release.buildNumber -isnot [long]) -or
      ($policyData.versionPolicy.buildNumber -isnot [int] -and $policyData.versionPolicy.buildNumber -isnot [long]) -or
      $policyData.release.buildNumber -cne 31 -or $policyData.versionPolicy.buildNumber -cne 31 -or
      $policyData.Contains('runtimeBackendPrivateReplay')) { throw 'Business31 policy is partial or mixed with a legacy route.' }
  Assert-Business31Pointer $policyData.clientBackendCompatibility 'build31-business-client-compatibility-v1' 'release/approvals/build31-business-client-compatibility-approval.json'
  Assert-Business31Pointer $policyData.businessBackendPrivateReplay 'build31-exact-business-backend-v1' 'release/evidence/build31-business-private-replay.json'
  $repo = Get-Business31RegularPath $RepositoryRoot -Directory
  $policyPath = Join-Path $repo 'release/production-release-policy.json'
  Assert-Business31Same $policyData (Read-Business31Json $policyPath) 'Passed and repository policy'
  $configPath = Get-Business31RegularPath $env:BUSINESS31_CONTROLLER_CONFIG
  $configHash = $env:BUSINESS31_CONTROLLER_CONFIG_SHA256
  if ($configHash -cnotmatch '^[A-F0-9]{64}$' -or (Get-Business31FileHash $configPath 2097152) -cne $configHash) {
    throw 'Business31 independently selected configuration digest differs.'
  }
  $root = Get-Business31RegularPath $env:BUSINESS31_VERIFIER_ROOT -Directory
  $node = Get-Business31RegularPath $env:BUSINESS31_CONTROLLER_NODE
  $git = Get-Business31RegularPath $env:BUSINESS31_CONTROLLER_GIT
  $config = Read-Business31Json $configPath
  Assert-Business31Keys $config @('schemaVersion', 'profile', 'replayTrust', 'controller', 'selected', 'requester', 'maximumWaitSeconds') 'Business31 controller configuration'
  Assert-Business31Keys $config.controller @('nodeSha256', 'gitSha256', 'files') 'Business31 controller runtime'
  Assert-Business31Keys $config.selected @('candidate', 'descriptorPointer', 'clientSelectionSha256') 'Business31 independent selection'
  if ($config.schemaVersion -cne 1 -or $config.profile -cne 'build31-business-prerequisite-controller-v1' -or
      ($config.maximumWaitSeconds -isnot [int] -and $config.maximumWaitSeconds -isnot [long]) -or
      $config.maximumWaitSeconds -lt 60 -or $config.maximumWaitSeconds -gt 9000 -or
      $config.controller.nodeSha256 -cnotmatch '^[A-F0-9]{64}$' -or
      $config.controller.gitSha256 -cnotmatch '^[A-F0-9]{64}$' -or
      (Get-Business31FileHash $node) -cne $config.controller.nodeSha256 -or
      (Get-Business31FileHash $git) -cne $config.controller.gitSha256) { throw 'Business31 selected runtime/configuration differs.' }
  Assert-Business31Same $config.controller.files $config.replayTrust.verifier.files 'Controller and replay verifier selection'
  Assert-Business31SelectedFiles $root $config.controller.files
  $descriptor = [ordered]@{commit=$policyData.businessBackendPrivateReplay.commit; file=$policyData.businessBackendPrivateReplay.file; sha256=$policyData.businessBackendPrivateReplay.sha256}
  Assert-Business31Same $descriptor $config.selected.descriptorPointer 'Selected and policy descriptor'
  $kind = if ($Purpose -ceq 'Construction') { 'construction' } else { 'package-verification' }
  if (($ResumeRequestPath -or $RequestOutputPath) -and $kind -cne 'construction') {
    throw 'Only construction can retain or reauthenticate its original request.'
  }
  if ($ResumeRequestPath -and $RequestOutputPath) { throw 'A resumed request cannot overwrite or issue another locator.' }
  $resume = $null; $resumePath = $null; $requestOutput = $null
  if ($ResumeRequestPath) {
    $resumePath = Get-Business31RegularPath $ResumeRequestPath
    $resume = Read-Business31Json $resumePath 131072
    Assert-Business31Keys $resume @('schemaVersion', 'profile', 'controllerConfigSha256', 'request') 'Business31 resume locator'
    if ($resume.schemaVersion -cne 1 -or $resume.profile -cne 'build31-business-prerequisite-resume-v1' -or
        $resume.controllerConfigSha256 -cne $configHash) { throw 'Business31 resume configuration differs.' }
  }
  if ($RequestOutputPath) {
    if (-not [IO.Path]::IsPathFullyQualified($RequestOutputPath)) { throw 'Business31 locator output requires an absolute path.' }
    $requestOutput = [IO.Path]::GetFullPath($RequestOutputPath)
    [void](Get-Business31RegularPath (Split-Path -Parent $requestOutput) -Directory)
    if (Test-Path -LiteralPath $requestOutput) { throw 'Business31 locator output already exists.' }
  }
  $archive = $null; $manifest = $null; $packagePaths = @()
  if ($kind -ceq 'construction') {
    if ($SourceArchivePath -or $ManifestPath) { throw 'Construction cannot select a future package.' }
  } else {
    $archive = Get-Business31RegularPath $SourceArchivePath
    $manifest = Get-Business31RegularPath $ManifestPath
    $data = Read-Business31Json $manifest
    if ($data.source.gitCommit -cne $config.selected.candidate.commit -or
        $data.source.gitTree -cne $config.selected.candidate.tree) { throw 'Package candidate identity differs.' }
    $packageRoot = Split-Path -Parent $manifest
    foreach ($artifact in $data.artifacts) {
      if ($artifact.file -isnot [string] -or $artifact.file -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,159}\.(?:apk|aab)$') {
        throw 'Business31 package artifact name is invalid.'
      }
      $packagePaths += Get-Business31RegularPath (Join-Path $packageRoot $artifact.file)
    }
    if ($packagePaths.Count -ne 2 -or @(@($archive, $manifest) + $packagePaths | Select-Object -Unique).Count -ne 4) {
      throw 'Business31 package requires source, manifest and two distinct Android artifacts.'
    }
  }
  $packageFiles = @()
  if ($kind -ceq 'package-verification') {
    $packageFiles = @($archive, $manifest) + $packagePaths
  }
  $token = [Environment]::GetEnvironmentVariable('GH_TOKEN')
  if ([string]::IsNullOrWhiteSpace($token) -or $token -match '[\r\n]') { throw 'Business31 protected dispatch credential is absent.' }
  $parent = Get-Business31RegularPath ([IO.Path]::GetTempPath()) -Directory
  $work = Join-Path $parent ('business31-prerequisite-' + [Guid]::NewGuid().ToString('N'))
  if (Test-Path -LiteralPath $work) { throw 'Business31 invocation directory already exists.' }
  [void][IO.Directory]::CreateDirectory($work)
  foreach ($name in @('home', 'tmp', 'appdata', 'localappdata')) { [void][IO.Directory]::CreateDirectory((Join-Path $work $name)) }
  $inputPath = Join-Path $work 'input.json'; $outputPath = Join-Path $work 'result.json'
  $inputData = [ordered]@{schemaVersion=1; purpose=$kind; repositoryRoot=$repo; gitExecutable=$git; sourceArchivePath=$archive; manifestPath=$manifest; packagePaths=@($packagePaths)}
  [IO.File]::WriteAllText($inputPath, (ConvertTo-Json -InputObject $inputData -Depth 20 -Compress) + "`n", [Text.UTF8Encoding]::new($false))
  $bindings = [ordered]@{}
  foreach ($file in @($configPath, $node, $git, $policyPath, $inputPath)) { $bindings[$file] = Get-Business31FileHash $file }
  if ($resumePath) { $bindings[$resumePath] = Get-Business31FileHash $resumePath 131072 }
  $fileBindings = @()
  foreach ($file in $packageFiles) {
    $bindings[$file] = Get-Business31FileHash $file 4294967296
    $role = if ($file -ceq $archive) { 'source-archive' } elseif ($file -ceq $manifest) { 'manifest' } else { 'package' }
    $fileBindings += [ordered]@{role=$role; name=[IO.Path]::GetFileName($file); sha256=$bindings[$file]; bytes=(Get-Item -LiteralPath $file).Length}
  }
  $start = [Diagnostics.ProcessStartInfo]::new($node)
  $start.UseShellExecute=$false; $start.CreateNoWindow=$true
  $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
  $start.WorkingDirectory=$work
  $start.Environment.Clear()
  $start.Environment['PATH'] = (Split-Path -Parent $node) + [IO.Path]::PathSeparator + (Split-Path -Parent $git)
  foreach ($name in @('SystemRoot', 'WINDIR')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($IsWindows -and $value) { $start.Environment[$name] = Get-Business31RegularPath $value -Directory }
  }
  foreach ($name in @('HOME', 'USERPROFILE')) { $start.Environment[$name] = Join-Path $work 'home' }
  foreach ($name in @('TEMP', 'TMP', 'TMPDIR')) { $start.Environment[$name] = Join-Path $work 'tmp' }
  $start.Environment['APPDATA']=Join-Path $work 'appdata'; $start.Environment['LOCALAPPDATA']=Join-Path $work 'localappdata'
  $start.Environment['CI']='true'; $start.Environment['LANG']='C.UTF-8'; $start.Environment['GITHUB_TOKEN']=$token
  foreach ($name in @('GITHUB_ACTIONS', 'GITHUB_REPOSITORY', 'GITHUB_REPOSITORY_ID', 'GITHUB_REPOSITORY_OWNER_ID', 'GITHUB_RUN_ID',
      'GITHUB_RUN_ATTEMPT', 'GITHUB_SHA', 'GITHUB_REF', 'GITHUB_WORKFLOW_REF', 'GITHUB_WORKFLOW', 'GITHUB_JOB',
      'GITHUB_ACTOR_ID', 'GITHUB_ACTOR', 'GITHUB_TRIGGERING_ACTOR', 'GITHUB_EVENT_NAME')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value) { $start.Environment[$name] = $value }
  }
  foreach ($argument in @('--no-global-search-paths', (Join-Path $root 'tools/release/business31Prerequisite.cjs'),
      '--config', $configPath, '--config-sha256', $configHash, '--input', $inputPath, '--output', $outputPath)) {
    [void]$start.ArgumentList.Add($argument)
  }
  if ($resumePath) { [void]$start.ArgumentList.Add('--resume-request'); [void]$start.ArgumentList.Add($resumePath) }
  $invocationStarted = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Invoke-Business31OwnedController $start $work $config.maximumWaitSeconds
  foreach ($file in $bindings.Keys) { if ((Get-Business31FileHash $file 4294967296) -cne $bindings[$file]) { throw 'Business31 invocation input changed.' } }
  Assert-Business31SelectedFiles $root $config.controller.files
  $result = Read-Business31Json $outputPath 131072
  Assert-Business31Keys $result @('schemaVersion', 'profile', 'purpose', 'verifier', 'source', 'candidate', 'descriptorPointer',
    'closurePointer', 'commitments', 'client', 'challenge', 'runId', 'runAttempt', 'artifactId', 'resultSha256',
    'replayMode', 'freshHostedReplayVerified', 'limits') 'Business31 fresh result'
  $expectedMode = if ($resumePath) { 'same-parent-reauthentication' } else { 'fresh-dispatch' }
  if ($result.schemaVersion -cne 1 -or $result.profile -cne 'build31-business-prerequisite-measurement-v1' -or
      $result.purpose -cne $kind -or $result.replayMode -cne $expectedMode -or $result.freshHostedReplayVerified -isnot [bool] -or
      $result.freshHostedReplayVerified -cne $true) { throw 'Business31 fresh result scope differs.' }
  Assert-Business31Same $result.verifier ([ordered]@{commit=$config.replayTrust.verifier.commit; tree=$config.replayTrust.verifier.tree}) 'Result verifier V'
  Assert-Business31Same $result.source $config.replayTrust.source 'Result source M'
  Assert-Business31Same $result.candidate $config.selected.candidate 'Result candidate S'
  Assert-Business31Same $result.descriptorPointer $descriptor 'Result descriptor'
  if ($result.closurePointer.file -cne $policyData.finalization.exactFunctionFleetDeploymentReceiptFile -or
      $result.closurePointer.sha256 -cne $policyData.finalization.exactFunctionFleetDeploymentReceiptSha256) { throw 'Business31 result closure differs from policy.' }
  Assert-Business31Same $result.client.decisionPointer ([ordered]@{commit=$policyData.clientBackendCompatibility.commit; file=$policyData.clientBackendCompatibility.file; sha256=$policyData.clientBackendCompatibility.sha256}) 'Result client decision'
  if ($result.client.schemaVersion -cne 2 -or $result.client.profile -cne 'build31-business-client-compatibility-v1' -or
      $result.client.appCheckSourcePolicyVerified -isnot [bool] -or
      $result.client.appCheckSourcePolicyVerified -cne $true) { throw 'Business31 client source/policy measurement is incomplete.' }
  Assert-Business31Keys $result.limits @('deploymentAuthorized', 'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized') 'Business31 authority limits'
  foreach ($name in $result.limits.Keys) { if ($result.limits[$name] -isnot [bool] -or $result.limits[$name] -cne $false) { throw 'Business31 replay cannot grant operational authority.' } }
  foreach ($name in @('independentlySelectedInputsAuthenticated', 'executingHostAuthenticated', 'humanIdentityAuthenticated',
      'trustedClockAuthenticated', 'platformIdentityAuthenticated', 'credentialAccessAuthorized', 'backendDeploymentAuthorized',
      'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized')) {
    if ($result.client[$name] -isnot [bool] -or $result.client[$name] -cne $false) { throw 'Business31 client measurement cannot grant authority.' }
  }
  foreach ($name in @('runId', 'runAttempt', 'artifactId')) { if ($result[$name] -isnot [string] -or $result[$name] -cnotmatch '^[1-9][0-9]{0,19}$') { throw 'Business31 result platform identity is malformed.' } }
  if ($result.resultSha256 -cnotmatch '^[A-F0-9]{64}$' -or $result.challenge.purpose -cne $kind) { throw 'Business31 result challenge is malformed.' }
  Assert-Business31Keys $result.commitments @('bundleSha256', 'membersSha256', 'relocationSha256', 'sourceManifestSha256') 'Business31 commitments'
  foreach ($name in $result.commitments.Keys) { if ($result.commitments[$name] -isnot [string] -or $result.commitments[$name] -cnotmatch '^[A-F0-9]{64}$') { throw 'Business31 commitment digest is malformed.' } }
  if ($result.commitments.sourceManifestSha256 -cne $config.replayTrust.sourceManifestSha256) { throw 'Business31 source manifest differs.' }
  $challenge = $result.challenge
  Assert-Business31Keys $challenge @('schemaVersion', 'nonce', 'purpose', 'requestedAtUtc', 'expiresAtUtc', 'requester', 'clientSelectionSha256', 'fileBindings') 'Business31 challenge'
  if ($challenge.schemaVersion -cne 1 -or $challenge.nonce -isnot [string] -or $challenge.nonce -cnotmatch '^[a-f0-9]{64}$' -or
      $challenge.clientSelectionSha256 -cne $config.selected.clientSelectionSha256) { throw 'Business31 invocation challenge differs.' }
  $requested = [DateTimeOffset]::ParseExact($challenge.requestedAtUtc, "yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
  $expires = [DateTimeOffset]::ParseExact($challenge.expiresAtUtc, "yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
  if ((-not $resumePath -and $requested.ToUnixTimeMilliseconds() -lt $invocationStarted) -or
      $requested -gt [DateTimeOffset]::UtcNow -or $expires -le $requested -or
      ($expires - $requested).TotalSeconds -gt 9000 -or $expires -lt [DateTimeOffset]::UtcNow) {
    throw 'Business31 result is not from this fresh bounded invocation.'
  }
  Assert-Business31Same @($challenge.fileBindings | Sort-Object name) @($fileBindings | Sort-Object name) 'Business31 challenged package files'
  Assert-Business31Keys $challenge.requester @('kind', 'runId', 'runAttempt', 'invocationId') 'Business31 requester'
  if ($challenge.requester.invocationId -cnotmatch '^[a-f0-9]{64}$') { throw 'Business31 requester invocation is malformed.' }
  if ($kind -ceq 'construction' -and ($challenge.requester.kind -cne 'github-actions' -or
      $challenge.requester.runId -cne $env:GITHUB_RUN_ID -or $challenge.requester.runAttempt -cne $env:GITHUB_RUN_ATTEMPT)) {
    throw 'Business31 construction requester differs.'
  }
  $originalRequest = [ordered]@{schemaVersion=2; candidate=$result.candidate; descriptorPointer=$result.descriptorPointer;
    challenge=$result.challenge; runId=$result.runId; runAttempt=$result.runAttempt}
  if ($resumePath) { Assert-Business31Same $originalRequest $resume.request 'Reauthenticated original request' }
  if ($requestOutput) {
    # Locator only: a later caller must repeat the fixed remote/Git checks. This
    # JSON does not contain a result, permission, credential or cached PASS.
    [void](Get-Business31RegularPath (Split-Path -Parent $requestOutput) -Directory)
    $locator = [ordered]@{schemaVersion=1; profile='build31-business-prerequisite-resume-v1';
      controllerConfigSha256=$configHash; request=$originalRequest}
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $locator -Depth 50 -Compress) + "`n")
    $stream = [IO.File]::Open($requestOutput, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  }
  return [pscustomobject]$result
}
