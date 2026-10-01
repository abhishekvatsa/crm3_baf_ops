#requires -Version 7.0
# One source-bound read-only route. Public fields never replace private replay.
function Invoke-Runtime31SafeGitRead {
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$Arguments)
  $dot = Join-Path $Root '.git'
  $item = Get-Item -LiteralPath $dot -Force
  if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Runtime31 requires a regular local Git directory.'
  }
  foreach ($name in @('commondir','gitdir','objects/info/alternates','info/grafts')) {
    if (Test-Path -LiteralPath (Join-Path $dot $name)) { throw 'Runtime31 Git cannot redirect to external state.' }
  }
  $config = Join-Path $dot 'config'
  if ((Test-Path -LiteralPath $config) -and
      ([IO.File]::ReadAllText($config) -match '(?im)^\s*\[\s*(?:include(?:If)?|filter|diff)\b' -or
       [IO.File]::ReadAllText($config) -match '(?im)^\s*worktree\s*=')) {
    throw 'Executable or external Git configuration is not admitted.'
  }
  $start = [Diagnostics.ProcessStartInfo]::new('git')
  $start.UseShellExecute = $false; $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
  foreach ($key in @($start.Environment.Keys)) { if ($key -match '^GIT_') { [void]$start.Environment.Remove($key) } }
  $start.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
  $start.Environment['GIT_CONFIG_GLOBAL'] = $(if ($IsWindows) { 'NUL' } else { '/dev/null' })
  $start.Environment['GIT_TERMINAL_PROMPT'] = '0'; $start.Environment['GIT_PAGER'] = 'cat'
  $start.Environment['GIT_OPTIONAL_LOCKS'] = '0'
  foreach ($argument in @('--no-replace-objects','--no-pager','--no-optional-locks',
      '-c','core.longpaths=true','-c','core.fsmonitor=false','-c',('core.hooksPath=' + (Join-Path $dot 'crm31-disabled-hooks')),
      '-c','core.untrackedCache=false','-c','core.preloadIndex=false','-c','diff.external=',
      '-c','credential.helper=','-c','protocol.allow=never','-C',$Root) + $Arguments) {
    $start.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
  try {
    [void]$process.Start()
    $outTask = $process.StandardOutput.ReadToEndAsync(); $errTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit(); $output = $outTask.GetAwaiter().GetResult(); [void]$errTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw 'Runtime31 immutable Git read failed.' }
    $output.TrimEnd("`r", "`n") -split '\r?\n'
  } finally { $process.Dispose() }
}

function Test-ProductionRuntime31Selected {
  param([Parameter(Mandatory)][object]$Policy)
  ($null -ne $Policy.PSObject.Properties['runtimeBackendPrivateReplay']) -or
    ($null -ne $Policy.PSObject.Properties['clientBackendCompatibility'] -and
      ($Policy.clientBackendCompatibility.file -ceq 'release/approvals/build31-runtime-client-compatibility-approval.json' -or
       ($null -ne $Policy.clientBackendCompatibility.PSObject.Properties['profile'] -and
        $Policy.clientBackendCompatibility.profile -ceq 'build31-exact-grpc-runtime-backend-v1')))
}

function Assert-ProductionRuntime31PublicBinding {
  param([Parameter(Mandatory)][object]$Policy, [Parameter(Mandatory)][object]$Proof,
    [AllowNull()][object]$CurrentSuccessorState)
  if (-not (Test-ProductionRuntime31Selected $Policy) -or
      $Policy.release.buildNumber -cne 31 -or $Policy.versionPolicy.buildNumber -cne 31 -or
      $Proof.ok -isnot [bool] -or -not $Proof.ok -or $Proof.route -cne 'runtime-backend31' -or
      $Proof.runtimeBackend31.privateEvidenceReplayed -isnot [bool] -or
      -not $Proof.runtimeBackend31.privateEvidenceReplayed) {
    throw 'Runtime31 requires the exact complete private replay route.'
  }
  $runtime = $Proof.runtimeBackend31
  $backend = $runtime.currentBackend
  if ($Policy.finalization.exactFunctionFleetDeploymentReceiptFile -cne $runtime.closurePointer.file -or
      $Policy.finalization.exactFunctionFleetDeploymentReceiptSha256 -cne $runtime.closurePointer.sha256 -or
      $Policy.clientBackendCompatibility.commit -cne $runtime.clientPointer.commit -or
      $Policy.clientBackendCompatibility.file -cne $runtime.clientPointer.file -or
      $Policy.clientBackendCompatibility.sha256 -cne $runtime.clientPointer.sha256 -or
      $Policy.runtimeBackendPrivateReplay.commit -cne $runtime.descriptorPointer.commit -or
      $Policy.runtimeBackendPrivateReplay.file -cne $runtime.descriptorPointer.file -or
      $Policy.runtimeBackendPrivateReplay.sha256 -cne $runtime.descriptorPointer.sha256 -or
      $backend.source.commit -cne $runtime.source.commit -or
      $backend.source.tree -cne $runtime.source.tree -or
      $backend.source.functionsTree -cne $runtime.source.functionsTree -or
      $backend.fleet.callables -cne 13 -or $backend.fleet.events -cne 5 -or
      $backend.fleet.schedulers -cne 1 -or $backend.fleet.total -cne 19 -or
      $backend.preserved.rules -cne $true -or $backend.preserved.indexes -cne $true -or
      $backend.preserved.iam -cne $true -or $backend.preserved.enforcement -cne $true -or
      $backend.preserved.businessLogic -cne $true -or
      $backend.appCheck.clientRequired -cne $true -or $backend.appCheck.androidProvider -cne 'playIntegrity' -or
      $backend.appCheck.mutatingEnforcementChanged -cne $false) {
    throw 'Runtime31 public policy does not select the independently replayed exact backend.'
  }
  if ($null -ne $CurrentSuccessorState) {
    $deployed = $CurrentSuccessorState.authorityPlanes.deployedBackend
    if ($deployed.functionFleetSourceCommit -cne $runtime.source.commit -or
        $deployed.functionFleetEvidenceFile -cne $runtime.closurePointer.file -or
        $deployed.functionFleetEvidenceSha256 -cne $runtime.closurePointer.sha256 -or
        $deployed.deploymentApprovalFile -cne $runtime.approvalPointer.file -or
        $deployed.deploymentApprovalSha256 -cne $runtime.approvalPointer.sha256 -or
        $deployed.rulesAndIndexesEvidenceFile -cne $Policy.finalization.exactFirestoreRulesIndexesLiveReadback.receiptFile -or
        $deployed.rulesAndIndexesEvidenceSha256 -cne $Policy.finalization.exactFirestoreRulesIndexesLiveReadback.receiptFileSha256) {
      throw 'Current successor state differs from replayed runtime31 and exact source Firestore readback.'
    }
  }
}

function Get-ProductionRuntime31RepositoryEvidence {
  param([Parameter(Mandatory)][string]$RepositoryRoot, [Parameter(Mandatory)][object]$Policy)
  if (-not (Test-ProductionRuntime31Selected $Policy)) { return $null }
  $helper = Join-Path $RepositoryRoot 'tools/release/clientBackendCompatibility31.js'
  $output = @(& node --no-global-search-paths $helper $RepositoryRoot (Join-Path $RepositoryRoot 'release/production-release-policy.json'))
  if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'Runtime31 full source-bound private replay failed.' }
  $proof = [string]$output[0] | ConvertFrom-Json -Depth 100
  Assert-ProductionRuntime31PublicBinding -Policy $Policy -Proof $proof
  $proof
}

function Assert-ProductionRuntime31SourceArchive {
  param([Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$SourceArchivePath,
    [Parameter(Mandatory)][string]$SourceCommit)
  # A source ZIP alone cannot prove S descends M. A genuine Git checkout is
  # mandatory for this route until independently authenticated Git transport exists.
  if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { throw 'Runtime31 package verification requires actual Git ancestry custody.' }
  $top = @(Invoke-Runtime31SafeGitRead -Root $RepositoryRoot -Arguments @('rev-parse','--show-toplevel'))
  if ($top.Count -ne 1 -or
      [IO.Path]::GetFullPath($top[0]) -cne [IO.Path]::GetFullPath($RepositoryRoot)) {
    throw 'Runtime31 package repository must be the actual Git top-level.'
  }
  $head = @(Invoke-Runtime31SafeGitRead -Root $RepositoryRoot -Arguments @('rev-parse','HEAD'))
  if ($head.Count -ne 1 -or $head[0] -cne $SourceCommit) {
    throw 'Runtime31 source archive commit differs from actual repository.'
  }
  $rows = @(Invoke-Runtime31SafeGitRead -Root $RepositoryRoot -Arguments @('-c','core.quotepath=false','ls-tree','-r',$SourceCommit))
  if ($rows.Count -eq 0) { throw 'Unable to obtain source archive Git inventory.' }
  $expected = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  foreach ($row in $rows) {
    if ($row -cnotmatch '^100(?:644|755) blob ([0-9a-f]{40})\t([^\r\n]+)$') {
      throw 'Runtime31 source inventory contains unsupported link, gitlink or encoded name.'
    }
    $expected.Add($Matches[2], $Matches[1])
  }
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $seenFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $expectedDirectories = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $seenDirectories = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($name in $expected.Keys) {
    for ($offset = $name.IndexOf('/'); $offset -ge 0; $offset = $name.IndexOf('/', $offset + 1)) {
      [void]$expectedDirectories.Add($name.Substring(0, $offset + 1))
    }
  }
  $archive = [IO.Compression.ZipFile]::OpenRead($SourceArchivePath)
  try {
    foreach ($entry in $archive.Entries) {
      $name = $entry.FullName
      if ($name -match '(^/|\\|:|(^|/)\.\.?(/|$))' -or -not $seen.Add($name) -or
          (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
        throw 'Runtime31 source archive contains duplicate, escaping or symlink entries.'
      }
      if ($name.EndsWith('/')) {
        if ($entry.Length -ne 0 -or -not $expectedDirectories.Contains($name)) {
          throw 'Source archive directory differs from the immutable Git population.'
        }
        [void]$seenDirectories.Add($name)
        continue
      }
      if (-not $expected.ContainsKey($name) -or $entry.Length -gt 128MB) { throw 'Unexpected source archive member.' }
      $stream = $entry.Open()
      try {
        $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA1)
        try {
          $hash.AppendData([Text.Encoding]::UTF8.GetBytes("blob $($entry.Length)`0"))
          $buffer = [byte[]]::new(65536)
          $length = 0L
          while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $length += $count
            if ($length -gt $entry.Length) { throw 'Source archive member exceeds its declared length.' }
            $hash.AppendData($buffer, 0, $count)
          }
          if ($length -ne $entry.Length -or [Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant() -cne $expected[$name]) {
            throw 'Source archive member differs from exact Git blob bytes.'
          }
        } finally { $hash.Dispose() }
      } finally { $stream.Dispose() }
      [void]$seenFiles.Add($name)
    }
  } finally { $archive.Dispose() }
  if ($seenFiles.Count -ne $expected.Count -or $seenDirectories.Count -ne $expectedDirectories.Count) {
    throw 'Runtime31 source archive omits an immutable Git member.'
  }
}
