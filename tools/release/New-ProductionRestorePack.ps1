[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedMainCommit,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^projects/crm3-baf-ops-b8638/databases/\(default\)/operations/.+$')]
  [string]$ExportOperationName,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^gs://crm3-baf-ops-b8638-firestore-restore/pre-live/[A-Za-z0-9._-]+$')]
  [string]$ExportPrefix,

  [Parameter(Mandatory = $true)]
  [string]$Build6PackagePath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [long[]]$CiRunIds,

  [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectId = 'crm3-baf-ops-b8638'
$ProjectNumber = '894346496105'
$Region = 'asia-south1'
$ExpectedOriginUrl = 'https://github.com/abhishekvatsa/crm3_baf_ops.git'
$ExpectedBuild6Sha256 =
  'E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E'
$ExpectedCiJobNames = @(
  'Android release APK + AAB packaging proof',
  'Cloud Functions build + test',
  'Firestore rules + governed transaction emulator',
  'Flutter analyze + tests + no-loss spine'
)
$ExpectedFunctionNames = @(
  'assignPublishedTemplateVersion',
  'completePlannedJobExecution',
  'getBackendReleaseIdentity',
  'mutateRuntimeJobModulePopulation',
  'onJobAssigned',
  'onTicketCreated',
  'onTicketResolved'
)

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $RepositoryRoot 'release_output'
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$Firebase = Join-Path $RepositoryRoot 'tooling\firebase-cli\node_modules\.bin\firebase.cmd'

function Invoke-ExternalText {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$ArgumentList
  )

  $output = @(& $FilePath @ArgumentList 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed ($LASTEXITCODE): $FilePath $($ArgumentList -join ' ')`n$($output -join "`n")"
  }
  return ($output -join "`n").Trim()
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
  )

  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText(
    $Path,
    $Value,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Value
  )

  Write-Utf8NoBom -Path $Path -Value ($Value | ConvertTo-Json -Depth 100)
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-Md5Base64 {
  param([Parameter(Mandatory = $true)][string]$Path)

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
      return [Convert]::ToBase64String($md5.ComputeHash($stream))
    }
    finally {
      $md5.Dispose()
    }
  }
  finally {
    $stream.Dispose()
  }
}

function Assert-ExactSet {
  param(
    [Parameter(Mandatory = $true)][string[]]$Actual,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $actualSorted = @($Actual | Sort-Object -Unique)
  $expectedSorted = @($Expected | Sort-Object -Unique)
  if (($actualSorted -join "`n") -cne ($expectedSorted -join "`n")) {
    throw "$Label mismatch. Actual=[$($actualSorted -join ', ')] Expected=[$($expectedSorted -join ', ')]"
  }
}

if (-not (Test-Path -LiteralPath $Firebase -PathType Leaf)) {
  throw "Pinned Firebase CLI not found: $Firebase"
}
if (-not (Test-Path -LiteralPath $Build6PackagePath -PathType Leaf)) {
  throw "Governed Build 6 package not found: $Build6PackagePath"
}
$Build6PackagePath = (Resolve-Path -LiteralPath $Build6PackagePath).Path
$Build6SidecarPath = "$Build6PackagePath.sha256.txt"
if (-not (Test-Path -LiteralPath $Build6SidecarPath -PathType Leaf)) {
  throw "Governed Build 6 sidecar not found: $Build6SidecarPath"
}
if ((Get-Sha256 -Path $Build6PackagePath) -cne $ExpectedBuild6Sha256) {
  throw 'Governed Build 6 package SHA-256 mismatch.'
}
$build6SidecarText = (Get-Content -LiteralPath $Build6SidecarPath -Raw).Trim()
$build6SidecarMatch = [regex]::Match(
  $build6SidecarText,
  '^(?<sha>[0-9A-Fa-f]{64})\s+\*?(?<name>\S+)$'
)
if (
  -not $build6SidecarMatch.Success -or
  $build6SidecarMatch.Groups['sha'].Value.ToUpperInvariant() -cne
    $ExpectedBuild6Sha256 -or
  $build6SidecarMatch.Groups['name'].Value -cne
    [System.IO.Path]::GetFileName($Build6PackagePath)
) {
  throw 'Governed Build 6 sidecar does not bind the admitted package.'
}

Push-Location $RepositoryRoot
try {
  $branch = Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'branch', '--show-current'
  )
  if ($branch -cne 'main') {
    throw "Restore pack must run from main, not $branch."
  }
  $originUrl = Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'remote', 'get-url', 'origin'
  )
  if ($originUrl -cne $ExpectedOriginUrl) {
    throw "Unexpected origin repository: $originUrl"
  }
  $trackedStatus = Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'status', '--porcelain', '--untracked-files=no'
  )
  if (-not [string]::IsNullOrWhiteSpace($trackedStatus)) {
    throw "Tracked worktree is not clean:`n$trackedStatus"
  }
  Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'fetch', '--quiet', 'origin', 'main'
  ) | Out-Null
  $head = Invoke-ExternalText -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD')
  $originMain = Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'rev-parse', 'origin/main'
  )
  if ($head -cne $ExpectedMainCommit -or $originMain -cne $ExpectedMainCommit) {
    throw "Expected main/origin parity at $ExpectedMainCommit; HEAD=$head origin/main=$originMain."
  }

  $createdAtUtc = [DateTime]::UtcNow.ToString('o')
  $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
  $shortCommit = $ExpectedMainCommit.Substring(0, 8)
  $packName = "CRM3_PRODUCTION_RESTORE_PACK_${stamp}_${shortCommit}"
  $workDirectory = Join-Path $OutputRoot $packName
  $archivePath = Join-Path $OutputRoot "$packName.zip"
  $sidecarPath = "$archivePath.sha256.txt"
  New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
  if (
    (Test-Path -LiteralPath $workDirectory) -or
    (Test-Path -LiteralPath $archivePath) -or
    (Test-Path -LiteralPath $sidecarPath)
  ) {
    throw "Restore-pack output already exists for $packName."
  }

  New-Item -ItemType Directory -Path $workDirectory | Out-Null
  $sourceDirectory = New-Item -ItemType Directory -Path (
    Join-Path $workDirectory 'source'
  )
  $controlDirectory = New-Item -ItemType Directory -Path (
    Join-Path $workDirectory 'control-plane'
  )
  $functionDirectory = New-Item -ItemType Directory -Path (
    Join-Path $workDirectory 'functions'
  )
  $functionSourceDirectory = New-Item -ItemType Directory -Path (
    Join-Path $functionDirectory.FullName 'source-archives'
  )
  $exportDirectory = New-Item -ItemType Directory -Path (
    Join-Path $workDirectory 'managed-firestore-export'
  )
  $clientDirectory = New-Item -ItemType Directory -Path (
    Join-Path $workDirectory 'governed-client'
  )
  $ciDirectory = New-Item -ItemType Directory -Path (
    Join-Path $workDirectory 'ci'
  )

  Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'archive',
    '--format=zip',
    "--output=$($sourceDirectory.FullName)\current-main-source.zip",
    $ExpectedMainCommit
  ) | Out-Null
  Invoke-ExternalText -FilePath 'git' -ArgumentList @(
    'bundle',
    'create',
    "$($sourceDirectory.FullName)\current-main.bundle",
    'origin/main'
  ) | Out-Null
  Write-Utf8NoBom -Path (
    Join-Path $sourceDirectory.FullName 'current-main-commit.txt'
  ) -Value (Invoke-ExternalText -FilePath 'git' -ArgumentList @(
      'show', '--no-patch', '--format=fuller', $ExpectedMainCommit
    ))

  foreach ($runId in $CiRunIds) {
    $runJson = Invoke-ExternalText -FilePath 'gh' -ArgumentList @(
      'run', 'view', $runId.ToString(),
      '--json', 'databaseId,status,conclusion,event,headBranch,headSha,workflowName,url,jobs'
    )
    $run = $runJson | ConvertFrom-Json
    if (
      [long]$run.databaseId -ne $runId -or
      $run.status -cne 'completed' -or
      $run.conclusion -cne 'success' -or
      $run.event -cne 'push' -or
      $run.headBranch -cne 'main' -or
      $run.workflowName -cne 'release-gate' -or
      $run.headSha -cne $ExpectedMainCommit
    ) {
      throw "CI run $runId is not a successful exact-commit proof."
    }
    Assert-ExactSet -Actual @($run.jobs | ForEach-Object { $_.name }) `
      -Expected $ExpectedCiJobNames -Label "CI run $runId job inventory"
    $failedJobs = @(
      $run.jobs |
        Where-Object {
          $_.status -cne 'completed' -or $_.conclusion -cne 'success'
        }
    )
    if ($failedJobs.Count -ne 0) {
      throw "CI run $runId contains an incomplete or unsuccessful required job."
    }
    Write-Utf8NoBom -Path (
      Join-Path $ciDirectory.FullName "github-run-$runId.json"
    ) -Value $runJson
  }

  $databaseJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
    'firestore', 'databases', 'describe',
    '--database=(default)',
    "--project=$ProjectId",
    '--format=json'
  )
  Write-Utf8NoBom -Path (
    Join-Path $controlDirectory.FullName 'firestore-database.json'
  ) -Value $databaseJson

  $indexesJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
    'firestore', 'indexes', 'composite', 'list',
    '--database=(default)',
    "--project=$ProjectId",
    '--format=json'
  )
  Write-Utf8NoBom -Path (
    Join-Path $controlDirectory.FullName 'firestore-composite-indexes.json'
  ) -Value $indexesJson

  $token = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
    'auth', 'print-access-token'
  )
  $headers = @{
    Authorization = "Bearer $token"
    'X-Goog-User-Project' = $ProjectId
  }
  $rulesRelease = Invoke-RestMethod -ErrorAction Stop -Headers $headers -Uri (
    "https://firebaserules.googleapis.com/v1/projects/$ProjectId/releases/cloud.firestore"
  )
  if ([string]::IsNullOrWhiteSpace($rulesRelease.rulesetName)) {
    throw 'Active production Rules release omitted rulesetName.'
  }
  $ruleset = Invoke-RestMethod -ErrorAction Stop -Headers $headers -Uri (
    "https://firebaserules.googleapis.com/v1/$($rulesRelease.rulesetName)"
  )
  $rulesFile = $ruleset.source.files |
    Where-Object { $_.name -eq 'firestore.rules' } |
    Select-Object -First 1
  if ($null -eq $rulesFile -or $null -eq $rulesFile.content) {
    throw 'Active production Rules source omitted firestore.rules.'
  }
  Write-JsonFile -Path (
    Join-Path $controlDirectory.FullName 'firestore-rules-release.json'
  ) -Value $rulesRelease
  Write-JsonFile -Path (
    Join-Path $controlDirectory.FullName 'firestore-ruleset.json'
  ) -Value $ruleset
  Write-Utf8NoBom -Path (
    Join-Path $controlDirectory.FullName 'firestore.rules'
  ) -Value ([string]$rulesFile.content)

  $functionsEnvelopeJson = Invoke-ExternalText -FilePath $Firebase -ArgumentList @(
    'functions:list', "--project=$ProjectId", '--json'
  )
  $functionsEnvelope = $functionsEnvelopeJson | ConvertFrom-Json
  $functions = @($functionsEnvelope.result)
  Assert-ExactSet -Actual @($functions | ForEach-Object { $_.id }) `
    -Expected $ExpectedFunctionNames -Label 'Production Function inventory'
  Write-Utf8NoBom -Path (
    Join-Path $functionDirectory.FullName 'firebase-functions-list.json'
  ) -Value $functionsEnvelopeJson

  $functionReceipts = @()
  foreach ($function in ($functions | Sort-Object id)) {
    if (
      $function.region -cne $Region -or
      $function.platform -cne 'gcfv2' -or
      $function.state -cne 'ACTIVE'
    ) {
      throw "Function $($function.id) is outside the admitted rollback shape."
    }
    $descriptionJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
      'functions', 'describe', $function.id,
      '--gen2', "--region=$Region", "--project=$ProjectId", '--format=json'
    )
    Write-Utf8NoBom -Path (
      Join-Path $functionDirectory.FullName "$($function.id).json"
    ) -Value $descriptionJson

    $storageSource = $function.source.storageSource
    if (
      [string]::IsNullOrWhiteSpace($storageSource.bucket) -or
      [string]::IsNullOrWhiteSpace($storageSource.object) -or
      [string]::IsNullOrWhiteSpace([string]$storageSource.generation)
    ) {
      throw "Function $($function.id) omitted generation-pinned source custody."
    }
    $sourceUri = "gs://$($storageSource.bucket)/$($storageSource.object)#$($storageSource.generation)"
    $destination = Join-Path $functionSourceDirectory.FullName (
      "$($function.id)-generation-$($storageSource.generation).zip"
    )
    $sourceDescriptionJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
      'storage', 'objects', 'describe', $sourceUri,
      "--project=$ProjectId", '--format=json'
    )
    $sourceDescription = $sourceDescriptionJson | ConvertFrom-Json
    if (
      [string]$sourceDescription.generation -cne [string]$storageSource.generation -or
      [long]$sourceDescription.size -le 0 -or
      [string]::IsNullOrWhiteSpace($sourceDescription.md5_hash)
    ) {
      throw "Function $($function.id) source object metadata is incomplete."
    }
    Write-Utf8NoBom -Path "$destination.metadata.json" `
      -Value $sourceDescriptionJson
    Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
      'storage', 'cp', $sourceUri, $destination, "--project=$ProjectId"
    ) | Out-Null
    if (
      (Get-Item -LiteralPath $destination).Length -ne [long]$sourceDescription.size -or
      (Get-Md5Base64 -Path $destination) -cne $sourceDescription.md5_hash
    ) {
      throw "Function $($function.id) source download failed byte verification."
    }
    $functionReceipts += [ordered]@{
      name = $function.id
      deploymentHash = $function.hash
      serviceAccount = $function.serviceAccount
      sourceUri = $sourceUri
      localArchive = "functions/source-archives/$([System.IO.Path]::GetFileName($destination))"
      sourceArchiveSha256 = Get-Sha256 -Path $destination
      sourceArchiveBytes = (Get-Item -LiteralPath $destination).Length
      sourceArchiveMd5Base64 = $sourceDescription.md5_hash
    }
  }

  $operationJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
    'firestore', 'operations', 'describe', $ExportOperationName,
    "--project=$ProjectId", '--format=json'
  )
  $operation = $operationJson | ConvertFrom-Json
  $operationHasError =
    $null -ne $operation.PSObject.Properties['error'] -and
    $null -ne $operation.PSObject.Properties['error'].Value
  if (
    $operation.done -ne $true -or
    $operation.metadata.operationState -cne 'SUCCESSFUL' -or
    $operation.response.outputUriPrefix -cne $ExportPrefix -or
    $operationHasError
  ) {
    throw 'Managed Firestore export is not a successful exact-prefix operation.'
  }
  Write-Utf8NoBom -Path (
    Join-Path $exportDirectory.FullName 'operation.json'
  ) -Value $operationJson

  $bucketJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
    'storage', 'buckets', 'describe',
    'gs://crm3-baf-ops-b8638-firestore-restore',
    "--project=$ProjectId", '--format=json'
  )
  $bucket = $bucketJson | ConvertFrom-Json
  if (
    $bucket.location -cne 'ASIA-SOUTH1' -or
    $bucket.public_access_prevention -cne 'enforced' -or
    $bucket.uniform_bucket_level_access -ne $true -or
    $bucket.versioning_enabled -ne $true -or
    [long]$bucket.retention_policy.retentionPeriod -ne 7776000
  ) {
    throw 'Restore bucket safety configuration does not match the admitted shape.'
  }
  Write-Utf8NoBom -Path (
    Join-Path $exportDirectory.FullName 'bucket.json'
  ) -Value $bucketJson
  Write-Utf8NoBom -Path (
    Join-Path $exportDirectory.FullName 'bucket-iam.json'
  ) -Value (Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
      'storage', 'buckets', 'get-iam-policy',
      'gs://crm3-baf-ops-b8638-firestore-restore',
      "--project=$ProjectId", '--format=json'
    ))

  $prefixBase = ($ExportPrefix.TrimEnd('/') -split '/')[-1]
  $exportObjects = @(
    "$ExportPrefix/$prefixBase.overall_export_metadata",
    "$ExportPrefix/all_namespaces/all_kinds/all_namespaces_all_kinds.export_metadata",
    "$ExportPrefix/all_namespaces/all_kinds/output-0"
  )
  $listedExportObjects = @(
    (Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
        'storage', 'ls', "$ExportPrefix/**", "--project=$ProjectId"
      )) -split '\r?\n' |
      ForEach-Object { $_.Trim() } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  )
  Assert-ExactSet -Actual $listedExportObjects -Expected $exportObjects `
    -Label 'Managed Firestore export object inventory'
  $exportReceipts = @()
  foreach ($objectUri in $exportObjects) {
    $descriptionJson = Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
      'storage', 'objects', 'describe', $objectUri,
      "--project=$ProjectId", '--format=json'
    )
    $description = $descriptionJson | ConvertFrom-Json
    if (
      [string]::IsNullOrWhiteSpace([string]$description.generation) -or
      [long]$description.size -le 0 -or
      [string]::IsNullOrWhiteSpace($description.md5_hash) -or
      [string]::IsNullOrWhiteSpace($description.crc32c_hash)
    ) {
      throw "Export object is incomplete: $objectUri"
    }
    $relativeObject = $objectUri.Substring($ExportPrefix.Length + 1)
    $localObject = Join-Path $exportDirectory.FullName (
      Join-Path 'objects' $relativeObject.Replace('/', '\')
    )
    New-Item -ItemType Directory -Path (Split-Path -Parent $localObject) -Force |
      Out-Null
    $generationUri = "$objectUri#$($description.generation)"
    Invoke-ExternalText -FilePath 'gcloud' -ArgumentList @(
      'storage', 'cp', $generationUri, $localObject, "--project=$ProjectId"
    ) | Out-Null
    if (
      (Get-Item -LiteralPath $localObject).Length -ne [long]$description.size -or
      (Get-Md5Base64 -Path $localObject) -cne $description.md5_hash
    ) {
      throw "Export object failed byte verification: $objectUri"
    }
    $descriptionPath = "$localObject.metadata.json"
    Write-Utf8NoBom -Path $descriptionPath -Value $descriptionJson
    $exportReceipts += [ordered]@{
      objectUri = $generationUri
      bytes = [long]$description.size
      md5Base64 = $description.md5_hash
      crc32cBase64 = $description.crc32c_hash
      retentionExpiration = $description.retention_expiration
      localPath = "managed-firestore-export/objects/$($relativeObject.Replace('\', '/'))"
      localSha256 = Get-Sha256 -Path $localObject
    }
  }

  $build6Destination = Join-Path $clientDirectory.FullName (
    [System.IO.Path]::GetFileName($Build6PackagePath)
  )
  Copy-Item -LiteralPath $Build6PackagePath -Destination $build6Destination
  Copy-Item -LiteralPath $Build6SidecarPath -Destination (
    "$build6Destination.sha256.txt"
  )
  Copy-Item -LiteralPath (
    Join-Path $RepositoryRoot 'release\evidence\build-6-finalization-closure.json'
  ) -Destination $clientDirectory.FullName

  $runbook = @"
# Production Stop and Rollback Runbook

Decision owner: repository owner `abhishekvatsa` or a formally delegated incident owner.

## Stop conditions

Stop expansion immediately on authentication regressions, Rules denial for an admitted legacy path, callable not-found or integrity errors, trigger retry growth, malformed server stamps, non-zero backfill gaps, unexpected runtime identity, or any production state that differs from the sealed preflight.

## Immediate containment

1. Stop client distribution and new pilot activity.
2. Preserve logs, operation IDs, deployed revisions and the first failing request ID.
3. Do not delete additive fields, indexes or new data.
4. Do not import the managed export into production during incident triage.

## Rules rollback

Use `control-plane/firestore.rules` from this private pack in a disposable rollback workspace. Compile it, compare its SHA-256 with `MANIFEST.json`, deploy Rules only to `$ProjectId`, then read back the active ruleset and require the same digest. This action requires a separate live rollback decision.

## Functions rollback

Each active Function has a generation-pinned source archive and full deployment description under `functions/`. Restore only the affected Function from its matching archive, preserve its recorded configuration and environment, and verify the resulting revision, runtime identity, trigger and deployment hash. Never redeploy the whole fleet by default.

## Index rollback

Do not automatically delete additive indexes. Compare the live inventory with `control-plane/firestore-composite-indexes.json` and adjudicate removals separately.

## Data recovery

The managed export is `$ExportPrefix`. Verify every generation and checksum in `MANIFEST.json`. Rehearse any import in an isolated recovery project or database first. Production import, document replacement or reset requires separate explicit authority and a collision plan.

## Exit

Resume only after the rollback owner records exact post-action Rules, Functions, indexes, data reconciliation and client state. Code rollback alone is not data rollback.
"@
  Write-Utf8NoBom -Path (Join-Path $workDirectory 'STOP_AND_ROLLBACK.md') `
    -Value $runbook.Trim()

  $fileEntries = @(
    Get-ChildItem -LiteralPath $workDirectory -Recurse -File |
      Sort-Object FullName |
      ForEach-Object {
        [ordered]@{
          path = $_.FullName.Substring($workDirectory.Length + 1).Replace('\', '/')
          bytes = $_.Length
          sha256 = Get-Sha256 -Path $_.FullName
        }
      }
  )
  $manifest = [ordered]@{
    schemaVersion = 1
    evidenceType = 'production-pre-live-restore-pack-private-manifest'
    createdAtUtc = $createdAtUtc
    projectId = $ProjectId
    projectNumber = $ProjectNumber
    source = [ordered]@{
      commit = $ExpectedMainCommit
      branch = 'main'
      originParity = $true
      trackedWorktreeClean = $true
      ciRunIds = @($CiRunIds)
    }
    managedFirestoreExport = [ordered]@{
      operationName = $ExportOperationName
      outputUriPrefix = $ExportPrefix
      operationState = $operation.metadata.operationState
      startTime = $operation.metadata.startTime
      endTime = $operation.metadata.endTime
      objects = $exportReceipts
    }
    deployedFunctions = $functionReceipts
    governedClient = [ordered]@{
      file = "governed-client/$([System.IO.Path]::GetFileName($build6Destination))"
      sha256 = Get-Sha256 -Path $build6Destination
      expectedSha256 = $ExpectedBuild6Sha256
    }
    mutationBoundary = [ordered]@{
      firestoreDocumentMutationPerformed = $false
      firestoreImportPerformed = $false
      rulesMutationPerformed = $false
      indexesMutationPerformed = $false
      functionsMutationPerformed = $false
      iamMutationPerformed = $false
      clientDistributionPerformed = $false
    }
    files = $fileEntries
  }
  $manifestPath = Join-Path $workDirectory 'MANIFEST.json'
  Write-JsonFile -Path $manifestPath -Value $manifest

  Compress-Archive -Path (Join-Path $workDirectory '*') `
    -DestinationPath $archivePath -CompressionLevel Optimal
  $archiveSha256 = Get-Sha256 -Path $archivePath
  Write-Utf8NoBom -Path $sidecarPath -Value (
    "$archiveSha256  $([System.IO.Path]::GetFileName($archivePath))"
  )

  [ordered]@{
    decision = 'PASS_PRIVATE_PRODUCTION_RESTORE_PACK_SEALED'
    workDirectory = $workDirectory
    archive = $archivePath
    archiveSha256 = $archiveSha256
    sidecar = $sidecarPath
    manifestSha256 = Get-Sha256 -Path $manifestPath
    fileCount = $fileEntries.Count
    managedExportObjectCount = $exportReceipts.Count
    deployedFunctionCount = $functionReceipts.Count
  } | ConvertTo-Json -Depth 10
}
finally {
  Pop-Location
}
