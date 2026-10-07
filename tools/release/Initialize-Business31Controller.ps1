#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepositoryRoot,
  [Parameter(Mandatory)][string]$ConfigJson,
  [Parameter(Mandatory)][string]$ConfigSha256,
  [string]$PolicyRequestJson,
  [switch]$ExportGitHubEnvironment
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Workflow callers pin this script's bytes from the independently enrolled
# configuration before invoking it. No candidate-selected trust or private
# input is read. This provisions public verifier bytes; it grants no authority.
function Get-RegularBusinessBootstrapPath([string]$Value, [bool]$Directory = $false) {
  if ([string]::IsNullOrWhiteSpace($Value) -or -not [IO.Path]::IsPathFullyQualified($Value)) { throw 'Controller path must be absolute.' }
  $item = Get-Item -LiteralPath $Value -Force
  if (($item -is [IO.DirectoryInfo]) -ne $Directory) { throw 'Controller path has the wrong type.' }
  $current = $item
  while ($null -ne $current) {
    if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Controller bootstrap paths cannot redirect.' }
    $current = if ($current -is [IO.DirectoryInfo]) { $current.Parent } else { $current.Directory }
  }
  $item.FullName
}
function Invoke-BusinessBootstrapGit([string[]]$Arguments) {
  $start = [Diagnostics.ProcessStartInfo]::new($script:gitPath)
  $start.UseShellExecute = $false; $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
  $start.Environment.Clear()
  $start.Environment['PATH'] = Split-Path -Parent $script:gitPath
  foreach ($name in @('SystemRoot', 'WINDIR')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($IsWindows -and $value) { $start.Environment[$name] = $value }
  }
  $start.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
  $start.Environment['GIT_CONFIG_GLOBAL'] = $(if ($IsWindows) { 'NUL' } else { '/dev/null' })
  $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
  $start.Environment['GIT_NO_LAZY_FETCH'] = '1'
  foreach ($arg in @('--no-replace-objects', '--no-pager', '--no-optional-locks', '-c', 'core.longpaths=true',
      '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=', '-c', 'protocol.allow=never',
      '-c', 'credential.helper=', '-C', $script:repo) + $Arguments) { [void]$start.ArgumentList.Add($arg) }
  $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
  try {
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) { $process.Kill($true); [void]$process.WaitForExit(10000); throw 'Verifier source read timed out.' }
    $text = $stdout.GetAwaiter().GetResult(); $errors = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0 -or $text.Length -gt 65536 -or $errors.Length -gt 65536) { throw 'Verifier source read failed.' }
    $text.Trim()
  } finally { $process.Dispose() }
}

$raw = [Text.UTF8Encoding]::new($false).GetBytes($ConfigJson)
if ($raw.Length -eq 0 -or $raw.Length -gt 2097152 -or $ConfigSha256 -cnotmatch '^[A-F0-9]{64}$' -or
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($raw)) -cne $ConfigSha256) { throw 'Controller enrollment bytes differ.' }
$config = $ConfigJson | ConvertFrom-Json -AsHashtable -Depth 100
if ($config.schemaVersion -cne 1 -or $config.profile -cne 'build31-business-prerequisite-controller-v1') { throw 'Controller enrollment is unsupported.' }
$selfName = 'tools/release/Initialize-Business31Controller.ps1'
if ($config.controller.files[$selfName] -cnotmatch '^[A-F0-9]{64}$' -or
    (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash -cne $config.controller.files[$selfName]) { throw 'Bootstrap source differs from enrolled verifier.' }
$script:repo = Get-RegularBusinessBootstrapPath $RepositoryRoot $true
$dot = Get-RegularBusinessBootstrapPath (Join-Path $repo '.git') $true
foreach ($entry in @('commondir', 'gitdir', 'shallow', 'objects/info/alternates', 'info/grafts')) {
  if (Test-Path -LiteralPath (Join-Path $dot $entry)) { throw 'Verifier source requires complete self-contained Git custody.' }
}
$gitConfig = Join-Path $dot 'config'
if ((Test-Path -LiteralPath $gitConfig) -and ([IO.File]::ReadAllText($gitConfig) -match '(?im)^\s*\[\s*(?:include(?:If)?|filter|diff)\b|^\s*(?:worktree|promisor|partialclone|partialclonefilter)\s*=')) {
  throw 'External or executable Git configuration is not admitted.'
}
$packRoot = Join-Path $dot 'objects/pack'
if ((Test-Path -LiteralPath $packRoot) -and @(Get-ChildItem -LiteralPath $packRoot -Filter '*.promisor' -File -Force).Count -ne 0) {
  throw 'Partial Git object populations are not admitted.'
}
$nodeCommand = @(Get-Command node -CommandType Application -ErrorAction Stop)[0]
$gitCommand = @(Get-Command git -CommandType Application -ErrorAction Stop)[0]
$nodePath = Get-RegularBusinessBootstrapPath $nodeCommand.Source
$script:gitPath = Get-RegularBusinessBootstrapPath $gitCommand.Source
foreach ($runtime in @(@($nodePath, $config.controller.nodeSha256), @($gitPath, $config.controller.gitSha256))) {
  if ($runtime[1] -cnotmatch '^[A-F0-9]{64}$' -or (Get-FileHash -LiteralPath $runtime[0] -Algorithm SHA256).Hash -cne $runtime[1]) {
    throw 'Controller runtime differs from independent enrollment.'
  }
}
$commit = $config.replayTrust.verifier.commit; $tree = $config.replayTrust.verifier.tree
if ($commit -cnotmatch '^[a-f0-9]{40}$' -or $tree -cnotmatch '^[a-f0-9]{40}$' -or
    (Invoke-BusinessBootstrapGit @('rev-parse', '--verify', "$commit^{tree}")) -cne $tree) { throw 'Verifier Git identity differs.' }
$parent = Get-RegularBusinessBootstrapPath ([IO.Path]::GetTempPath()) $true
$work = Join-Path $parent ('business31-controller-' + [Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $work) { throw 'Controller bootstrap directory exists.' }
[void][IO.Directory]::CreateDirectory($work)
$archive = Join-Path $work 'verifier.zip'; $verifierRoot = Join-Path $work 'verifier'
[void](Invoke-BusinessBootstrapGit @('archive', '--format=zip', "--output=$archive", $commit))
# Extract only the independently selected file population. Git archive export
# attributes cannot silently omit, duplicate or replace a selected member.
[void][IO.Directory]::CreateDirectory($verifierRoot)
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
  if ($config.controller.files.Count -eq 0 -or $config.controller.files.Count -gt 256) { throw 'Verifier file population is invalid.' }
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($entry in $config.controller.files.GetEnumerator()) {
    $name = $entry.Key
    if ($name -cnotmatch '^[A-Za-z0-9._/-]+$' -or $name.StartsWith('/') -or $name.Contains('//') -or
        $name.Split('/') -contains '..' -or $name.Split('/') -contains '.' -or -not $seen.Add($name) -or
        $entry.Value -cnotmatch '^[A-F0-9]{64}$') { throw 'Verifier file selector is invalid.' }
    $matches = @($zip.Entries | Where-Object FullName -CEQ $name)
    if ($matches.Count -ne 1 -or $matches[0].Length -gt 2097152 -or $matches[0].Length -eq 0 -or
        (($matches[0].ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Verifier source member is absent or invalid.' }
    $destination = Join-Path $verifierRoot $name
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
    [IO.Compression.ZipFileExtensions]::ExtractToFile($matches[0], $destination, $false)
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -cne $entry.Value) { throw 'Verifier source member bytes differ.' }
  }
} finally { $zip.Dispose() }
$configPath = Join-Path $work 'controller-config.json'
[IO.File]::WriteAllBytes($configPath, $raw)
$selection = [ordered]@{BUSINESS31_CONTROLLER_CONFIG=$configPath; BUSINESS31_CONTROLLER_CONFIG_SHA256=$ConfigSha256;
  BUSINESS31_VERIFIER_ROOT=$verifierRoot; BUSINESS31_CONTROLLER_NODE=$nodePath; BUSINESS31_CONTROLLER_GIT=$gitPath}
if (-not [string]::IsNullOrWhiteSpace($PolicyRequestJson)) {
  $requestBytes = [Text.UTF8Encoding]::new($false).GetBytes($PolicyRequestJson)
  if ($requestBytes.Length -gt 131072) { throw 'Policy result locator exceeds its bound.' }
  $request = $PolicyRequestJson | ConvertFrom-Json -AsHashtable -Depth 50
  if ($request.schemaVersion -cne 2) { throw 'A challenged policy result locator is required.' }
  $requestPath = Join-Path $work 'policy-request.json'; [IO.File]::WriteAllBytes($requestPath, $requestBytes)
  $selection['BUSINESS31_POLICY_REQUEST'] = $requestPath
}
if ($ExportGitHubEnvironment) {
  if ($env:GITHUB_ACTIONS -cne 'true') { throw 'GitHub environment export requires Actions.' }
  $environmentFile = Get-RegularBusinessBootstrapPath $env:GITHUB_ENV
  foreach ($entry in $selection.GetEnumerator()) {
    if ($entry.Value -match '[\r\n]') { throw 'Controller export contains a newline.' }
    [IO.File]::AppendAllText($environmentFile, "$($entry.Key)=$($entry.Value)`n", [Text.UTF8Encoding]::new($false))
  }
}
[pscustomobject]$selection
