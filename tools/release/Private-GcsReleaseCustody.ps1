#requires -Version 7.0
# This library performs only the explicitly selected Build28 private backup.
# Its command seam is replaced by in-memory fixtures in tests, never by a CLI flag.
function Invoke-PrivateGcsCommand {
  param([string]$Command, [string[]]$ArgumentList)
  $output = @(& $Command @ArgumentList 2>&1 | ForEach-Object { "$_" })
  if ($LASTEXITCODE -ne 0) {
    throw "Private custody command failed (exit $LASTEXITCODE): $($output -join "`n")"
  }
  $output -join "`n"
}

function Assert-PrivateGcsCustodyAuthority {
  param([string]$RepositoryRoot, [string]$Prefix, [int]$BuildNumber)
  $commit = 'e1db8eaa4b34c26254d3fd2a4cfc533747e187a4'
  $file = 'release/approvals/build28-private-cloud-custody-approval.json'
  $sha256 = '3DEB2A9E26FCFDBBAC20A591256ABB3A29FA3EBEF75D3A91FDACCEA2BA64FC88'
  if ($BuildNumber -ne 28 -or $Prefix -cnotmatch '^gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-28/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
    throw 'Private cloud custody is admitted only for Build28 and its unique approved campaign prefix.'
  }
  $approvalPath = Join-Path $RepositoryRoot $file
  if ((Get-FileHash -LiteralPath $approvalPath -Algorithm SHA256).Hash -cne $sha256) {
    throw 'Private cloud approval differs from its fixed custody digest.'
  }
  $committedBlob = & git --no-replace-objects -C $RepositoryRoot rev-parse --verify "${commit}:$file"
  if ($LASTEXITCODE -ne 0) { throw 'Private cloud approval Git custody is unavailable.' }
  $localBlob = & git --no-replace-objects -C $RepositoryRoot hash-object --no-filters -- $approvalPath
  if ($LASTEXITCODE -ne 0 -or $localBlob -cne $committedBlob) {
    throw 'Private cloud approval is not the admitted Git object.'
  }
  [pscustomobject]@{ commit = $commit; file = $file; sha256 = $sha256 }
}

function Get-PrivateGcsBucketControls {
  param([string]$GcloudCommand)
  $bucket = 'crm3-baf-ops-b8638-firestore-restore'
  $metadata = Invoke-PrivateGcsCommand $GcloudCommand @(
    'storage', 'buckets', 'describe', "gs://$bucket", '--project=crm3-baf-ops-b8638', '--format=json'
  ) | ConvertFrom-Json -AsHashtable
  $iam = Invoke-PrivateGcsCommand $GcloudCommand @(
    'storage', 'buckets', 'get-iam-policy', "gs://$bucket", '--project=crm3-baf-ops-b8638', '--format=json'
  ) | ConvertFrom-Json -AsHashtable
  $public = @($iam.bindings | ForEach-Object { $_.members } | Where-Object { $_ -in @('allUsers', 'allAuthenticatedUsers') })
  if ($metadata.name -cne $bucket -or $metadata.location -cne 'ASIA-SOUTH1' -or
      $metadata.public_access_prevention -cne 'enforced' -or
      $metadata.uniform_bucket_level_access -isnot [bool] -or $metadata.uniform_bucket_level_access -ne $true -or
      $metadata.versioning_enabled -isnot [bool] -or $metadata.versioning_enabled -ne $true -or
      [string]$metadata.retention_policy.retentionPeriod -cne '7776000' -or
      [string]$metadata.soft_delete_policy.retentionDurationSeconds -cne '604800' -or
      $iam.bindings -isnot [array] -or $public.Count -ne 0) {
    throw 'Private backup bucket privacy, versioning or retention differs from the approved controls.'
  }
  [pscustomobject]@{
    bucket = $bucket; location = 'ASIA-SOUTH1'; publicAccessPrevention = 'enforced'
    uniformBucketLevelAccess = $true; versioningEnabled = $true; publicIamPrincipalsAbsent = $true
    retentionSeconds = 7776000; softDeleteSeconds = 604800
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
  }
}

function Copy-PrivateGcsCustodyFile {
  param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$Prefix,
    [Parameter(Mandatory)][int]$BuildNumber,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$ExpectedSha256,
    [Parameter(Mandatory)][ValidateSet('productionPackage','productionPackageSidecar','closurePackage','closurePackageSidecar','custodyRecord','custodyRecordSidecar')][string]$Purpose,
    [string]$GcloudCommand = 'gcloud'
  )
  $authority = Assert-PrivateGcsCustodyAuthority $RepositoryRoot $Prefix $BuildNumber
  $source = Get-Item -LiteralPath $SourcePath
  $name = $source.Name
  if ($source.PSIsContainer -or $source.Length -le 0 -or
      $name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{0,239}$' -or
      (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -cne $ExpectedSha256.ToUpperInvariant()) {
    throw 'Private backup source is not the exact independently verified file.'
  }
  $controls = Get-PrivateGcsBucketControls $GcloudCommand
  $uri = "$Prefix/$name"
  # Gcloud reports the generation created by THIS upload. Never choose whichever
  # generation happens to be current at a later metadata read.
  $created = Invoke-PrivateGcsCommand $GcloudCommand @(
    'storage', 'cp', $source.FullName, $uri, '--if-generation-match=0',
    '--print-created-message', '--project=crm3-baf-ops-b8638', '--quiet'
  )
  $pattern = '(?m)^Created: ' + [regex]::Escape($uri) + '#([1-9][0-9]*)\s*$'
  $matches = [regex]::Matches($created, $pattern)
  if ($matches.Count -ne 1) { throw 'Upload did not return one exact created object generation; preserve the uncertain copy.' }
  $generation = $matches[0].Groups[1].Value
  $generationUri = "${uri}#$generation"
  $metadata = Invoke-PrivateGcsCommand $GcloudCommand @(
    'storage', 'objects', 'describe', $generationUri, '--project=crm3-baf-ops-b8638', '--format=json'
  ) | ConvertFrom-Json -AsHashtable
  $objectName = $uri.Substring('gs://crm3-baf-ops-b8638-firestore-restore/'.Length)
  if ([string]$metadata.generation -cne $generation -or
      $metadata.bucket -cne $controls.bucket -or $metadata.name -cne $objectName -or
      [string]$metadata.size -cne [string]$source.Length) {
    throw 'Created object generation, identity or size differs from the verified source.'
  }
  $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  $downloadDirectory = Join-Path $temporaryRoot ('crm3-private-custody-' + [guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($downloadDirectory) | Out-Null
  $download = Join-Path $downloadDirectory $name
  try {
    Invoke-PrivateGcsCommand $GcloudCommand @(
      'storage', 'cp', $generationUri, $download, '--project=crm3-baf-ops-b8638', '--quiet'
    ) | Out-Null
    $downloaded = Get-Item -LiteralPath $download
    $downloadedSha256 = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash
    if ($downloaded.Length -ne $source.Length -or $downloadedSha256 -cne $ExpectedSha256.ToUpperInvariant()) {
      throw 'Generation-pinned private backup download failed independent SHA-256/size verification.'
    }
    # Source changing during the upload cannot silently produce a custody claim.
    if ((Get-Item -LiteralPath $SourcePath).Length -ne $source.Length -or
        (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -cne $ExpectedSha256.ToUpperInvariant()) {
      throw 'Verified local source changed during private backup.'
    }
    [pscustomobject]@{
      schemaVersion = 1; provider = 'gcs'; purpose = $Purpose; buildNumber = 28
      bucket = $controls.bucket; prefix = $Prefix; objectName = $objectName
      objectUri = $uri; generation = $generation; generationUri = $generationUri
      bytes = [long]$source.Length; sha256 = $ExpectedSha256.ToUpperInvariant()
      downloadedBytes = [long]$downloaded.Length; downloadedSha256 = $downloadedSha256
      createOnly = $true; generationPinnedReadback = $true; verified = $true
      verifiedAtUtc = [DateTime]::UtcNow.ToString('o'); approval = $authority; bucketControls = $controls
    }
  } finally {
    # Delete only this invocation's explicitly checked temporary download folder.
    $resolved = [IO.Path]::GetFullPath($downloadDirectory)
    if ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\','/') -cne $temporaryRoot.TrimEnd('\','/') -or
        [IO.Path]::GetFileName($resolved) -cnotmatch '^crm3-private-custody-[0-9a-f]{32}$') {
      throw 'Temporary custody download path failed containment verification.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
