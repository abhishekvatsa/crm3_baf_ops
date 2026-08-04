[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    'Preflight',
    'Provision',
    'DeployCallables',
    'DeployEvents',
    'DeployScheduler',
    'Finalize',
    'RestoreEditor'
  )]
  [string]$Phase,

  [Parameter(Mandatory = $true)]
  [string]$RepositoryRoot,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^crm3-baf-ops-b8638$')]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^crm3-baf-ops-b8638$')]
  [string]$ConfirmProjectId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^asia-south1$')]
  [string]$Region,

  [Parameter(Mandatory = $true)]
  [ValidateRange(1, [long]::MaxValue)]
  [long]$PostMergeRunId,

  [Parameter(Mandatory = $true)]
  [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-ExternalText {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$WorkingDirectory
  )
  $priorLocation = Get-Location
  $output = @()
  $exitCode = -1
  try {
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
      Set-Location -LiteralPath $WorkingDirectory
    }
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    Set-Location -LiteralPath $priorLocation
  }
  $text = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
  if ($exitCode -ne 0) {
    throw "External command failed ($exitCode): $FilePath $($Arguments -join ' ')`n$text"
  }
  if (-not [string]::IsNullOrWhiteSpace($text)) {
    Write-Host $text
  }
  return $text.Trim()
}

function Get-GcloudJson {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)
  $raw = Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
    -Arguments ($Arguments + '--format=json')
  return $raw | ConvertFrom-Json
}

function Get-ProjectRoles {
  param([Parameter(Mandatory = $true)][string]$Email)
  $policy = Get-GcloudJson -Arguments @(
    'projects', 'get-iam-policy', $ProjectId
  )
  return @($policy.bindings | Where-Object {
    $_.condition -eq $null -and
    @($_.members) -contains "serviceAccount:$Email"
  } | ForEach-Object { [string]$_.role } | Sort-Object -Unique)
}

function Ensure-ProjectRole {
  param(
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][string]$Role
  )
  if ((Get-ProjectRoles -Email $Email) -contains $Role) {
    Write-Host "Role already present: $Role -> $Email"
    return
  }
  Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
    -Arguments @(
      'projects', 'add-iam-policy-binding', $ProjectId,
      "--member=serviceAccount:$Email",
      "--role=$Role",
      '--condition=None',
      '--quiet'
    ) | Out-Null
}

function Remove-ProjectRole {
  param(
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][string]$Role
  )
  if ((Get-ProjectRoles -Email $Email) -notcontains $Role) {
    Write-Host "Role already absent: $Role -> $Email"
    return
  }
  Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
    -Arguments @(
      'projects', 'remove-iam-policy-binding', $ProjectId,
      "--member=serviceAccount:$Email",
      "--role=$Role",
      '--condition=None',
      '--quiet'
    ) | Out-Null
}

function Assert-Receipt {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Decision
  )
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root -Arguments @(
    'tools/release/collectFunctionFleetRuntimeIdentityReadback.js',
    '--verify-receipt', $resolved,
    '--label', $Decision
  ) | Out-Null
  $receipt = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
  if ($receipt.source.before.commit -cne $head) {
    throw 'Prior receipt is not bound to the current exact main commit.'
  }
  return $receipt
}

function Invoke-Readback {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('preflight', 'provisioned', 'callables', 'events', 'fleet', 'final')]
    [string]$ReadbackPhase,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [switch]$ProbeCallables
  )
  $arguments = @(
    'tools/release/collectFunctionFleetRuntimeIdentityReadback.js',
    '--phase', $ReadbackPhase,
    '--repository-root', $root,
    '--project-id', $ProjectId,
    '--region', $Region,
    '--output', $OutputPath,
    '--gcloud', $script:gcloud
  )
  if ($ProbeCallables) {
    $arguments += '--probe-callables'
  }
  Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root `
    -Arguments $arguments | Out-Null
}

function Get-FunctionNamesByClass {
  param([Parameter(Mandatory = $true)][string[]]$Classes)
  return @($policy.functionBindings.PSObject.Properties | Where-Object {
    $Classes -contains [string]$_.Value.workloadClass
  } | ForEach-Object { [string]$_.Name } | Sort-Object)
}

function Invoke-FunctionDeployment {
  param([Parameter(Mandatory = $true)][string[]]$FunctionNames)
  if ($FunctionNames.Count -eq 0) {
    throw 'A Function deployment cohort cannot be empty.'
  }
  Invoke-ExternalText -FilePath 'npm.cmd' -WorkingDirectory $root `
    -Arguments @('--prefix', 'functions', 'run', 'build') | Out-Null
  $parameterFile = Join-Path $root "functions/.env.$ProjectId"
  if (Test-Path -LiteralPath $parameterFile) {
    throw "Refusing to overwrite Functions environment file: $parameterFile"
  }
  try {
    [IO.File]::WriteAllText(
      $parameterFile,
      "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false`n",
      [Text.UTF8Encoding]::new($false)
    )
    $targets = ($FunctionNames | ForEach-Object { "functions:$_" }) -join ','
    Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root -Arguments @(
      $firebaseBin,
      'deploy',
      '--only', $targets,
      '--project', $ProjectId,
      '--non-interactive'
    ) | Out-Null
  } finally {
    if (Test-Path -LiteralPath $parameterFile) {
      Remove-Item -LiteralPath $parameterFile -Force
    }
  }
  $tracked = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
    -Arguments @('status', '--porcelain', '--untracked-files=no')
  if ($tracked) {
    throw 'Tracked source changed during the Function deployment.'
  }
}

function Get-RunServiceName {
  param([Parameter(Mandatory = $true)][string]$FunctionName)
  $resource = Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
    -Arguments @(
      'functions', 'describe', $FunctionName,
      '--v2',
      "--region=$Region",
      "--project=$ProjectId",
      '--format=value(serviceConfig.service)'
    )
  $service = ($resource -split '/')[-1]
  if ([string]::IsNullOrWhiteSpace($service)) {
    throw "Function $FunctionName has no Cloud Run service binding."
  }
  return $service
}

function Ensure-ServiceInvoker {
  param(
    [Parameter(Mandatory = $true)][string]$FunctionName,
    [Parameter(Mandatory = $true)][string]$Email
  )
  $service = Get-RunServiceName -FunctionName $FunctionName
  $runPolicy = Get-GcloudJson -Arguments @(
    'run', 'services', 'get-iam-policy', $service,
    "--region=$Region",
    "--project=$ProjectId"
  )
  $runBindings = if (
    $runPolicy.PSObject.Properties.Name -contains 'bindings'
  ) {
    @($runPolicy.bindings)
  } else {
    @()
  }
  $hasBinding = @($runBindings | Where-Object {
    $_.condition -eq $null -and
    $_.role -eq 'roles/run.invoker' -and
    @($_.members) -contains "serviceAccount:$Email"
  }).Count -gt 0
  if (-not $hasBinding) {
    Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
      -Arguments @(
        'run', 'services', 'add-iam-policy-binding', $service,
        "--region=$Region",
        "--project=$ProjectId",
        "--member=serviceAccount:$Email",
        '--role=roles/run.invoker',
        '--condition=None',
        '--quiet'
      ) | Out-Null
  }
}

if ($ProjectId -cne $ConfirmProjectId) {
  throw 'ConfirmProjectId must exactly match ProjectId.'
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd('\', '/')
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\', '/')
$rootPrefix = "$root$([IO.Path]::DirectorySeparatorChar)"
if (
  $evidenceRoot.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
  $evidenceRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
) {
  throw 'EvidenceDirectory must be outside the repository.'
}
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

$gcloudCommand = Get-Command 'gcloud.cmd' -ErrorAction SilentlyContinue
if ($null -eq $gcloudCommand) {
  $gcloudCommand = Get-Command 'gcloud' -ErrorAction Stop
}
$script:gcloud = $gcloudCommand.Source
$firebaseBin = Join-Path $root `
  'tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js'
$policyPath = Join-Path $root `
  'release/function-fleet-runtime-identity-policy.json'
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('fetch', '--quiet', 'origin', 'main') | Out-Null
$branch = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('branch', '--show-current')
$head = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', 'HEAD')
$originMain = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', 'origin/main')
$trackedStatus = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('status', '--porcelain', '--untracked-files=no')
if ($branch -cne 'main' -or $head -cne $originMain -or $trackedStatus) {
  throw 'Campaign phases require exact tracked-clean main equal to origin/main.'
}
$environmentFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'functions') `
  -Force -File -Filter '.env*')
if ($environmentFiles.Count -ne 0) {
  throw 'Campaign phases require no pre-existing Functions environment file.'
}

$project = Get-GcloudJson -Arguments @('projects', 'describe', $ProjectId)
$defaultCompute = "$($project.projectNumber)-compute@developer.gserviceaccount.com"
$preflightPath = Join-Path $evidenceRoot '01-preflight.json'
$provisionedPath = Join-Path $evidenceRoot '02-provisioned.json'
$callablesPath = Join-Path $evidenceRoot '03-callables.json'
$eventsPath = Join-Path $evidenceRoot '04-events.json'
$schedulerPreflightPath = Join-Path $evidenceRoot '05-scheduler-preflight.json'
$fleetPath = Join-Path $evidenceRoot '06-fleet.json'
$preFinalDependenciesPath = Join-Path $evidenceRoot '07-lr03-lr06-prefinal.json'
$finalPath = Join-Path $evidenceRoot '08-final.json'
$finalDependenciesPath = Join-Path $evidenceRoot '09-lr03-lr06-final.json'

switch ($Phase) {
  'Preflight' {
    $runRaw = Invoke-ExternalText -FilePath 'gh' -WorkingDirectory $root `
      -Arguments @(
        'run', 'view', [string]$PostMergeRunId,
        '--repo', 'abhishekvatsa/crm3_baf_ops',
        '--json', 'databaseId,headSha,conclusion,event,workflowName,jobs,url'
      )
    $run = $runRaw | ConvertFrom-Json
    if (
      $run.databaseId -ne $PostMergeRunId -or
      $run.headSha -cne $head -or
      $run.workflowName -cne 'release-gate' -or
      $run.event -cne 'push' -or
      $run.conclusion -cne 'success' -or
      @($run.jobs).Count -ne 4 -or
      @($run.jobs | Where-Object { $_.conclusion -cne 'success' }).Count -ne 0
    ) {
      throw 'Preflight requires the exact four-job successful post-merge release gate.'
    }
    Invoke-Readback -ReadbackPhase 'preflight' -OutputPath $preflightPath
  }

  'Provision' {
    Assert-Receipt -Path $preflightPath `
      -Decision 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_PREFLIGHT' | Out-Null
    if ((Get-ProjectRoles -Email $defaultCompute) -notcontains 'roles/editor') {
      throw 'Default Compute Editor must remain available as rollback authority during provisioning.'
    }

    $roles = @(Get-GcloudJson -Arguments @(
      'iam', 'roles', 'list', "--project=$ProjectId", '--show-deleted'
    ))
    $customRoleName = "projects/$ProjectId/roles/$($policy.customRoles.notificationSender.roleId)"
    $customRole = $roles | Where-Object { $_.name -eq $customRoleName }
    if ($null -eq $customRole) {
      Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
        -Arguments @(
          'iam', 'roles', 'create', $policy.customRoles.notificationSender.roleId,
          "--project=$ProjectId",
          '--title=CRM3 notification sender',
          '--description=Send FCM messages for governed CRM3 notification triggers',
          '--permissions=cloudmessaging.messages.create',
          '--stage=GA',
          '--quiet'
        ) | Out-Null
    } else {
      $customRole = Get-GcloudJson -Arguments @(
        'iam', 'roles', 'describe',
        $policy.customRoles.notificationSender.roleId,
        "--project=$ProjectId"
      )
      $isDeleted =
        $customRole.PSObject.Properties.Name -contains 'deleted' -and
        $customRole.deleted -eq $true
      if (
        $isDeleted -or
        @($customRole.includedPermissions).Count -ne 1 -or
        @($customRole.includedPermissions) -notcontains 'cloudmessaging.messages.create'
      ) {
        throw 'Existing notification custom role is deleted or has unexpected permissions.'
      }
    }

    $accounts = @(Get-GcloudJson -Arguments @(
      'iam', 'service-accounts', 'list', "--project=$ProjectId"
    ))
    foreach ($property in $policy.functionBindings.PSObject.Properties) {
      $accountId = [string]$property.Value.runtimeServiceAccountId
      $email = "$accountId@$ProjectId.iam.gserviceaccount.com"
      if (@($accounts | Where-Object { $_.email -eq $email }).Count -eq 0) {
        Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
          -Arguments @(
            'iam', 'service-accounts', 'create', $accountId,
            "--project=$ProjectId",
            "--display-name=CRM3 $($property.Name) runtime",
            '--quiet'
          ) | Out-Null
      }
      foreach ($rawRole in @($property.Value.requiredProjectRoles)) {
        $role = ([string]$rawRole).Replace('${PROJECT_ID}', $ProjectId)
        Ensure-ProjectRole -Email $email -Role $role
      }
      if ($null -ne $property.Value.requiredCloudRunServiceRoles) {
        Ensure-ProjectRole -Email $email -Role 'roles/run.invoker'
      }
    }
    Ensure-ProjectRole -Email $defaultCompute `
      -Role 'roles/cloudbuild.builds.builder'
    Invoke-Readback -ReadbackPhase 'provisioned' `
      -OutputPath $provisionedPath
  }

  'DeployCallables' {
    Assert-Receipt -Path $provisionedPath `
      -Decision 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_PROVISIONED' | Out-Null
    $callables = Get-FunctionNamesByClass -Classes @(
      'CALLABLE_FIRESTORE_MUTATION',
      'CALLABLE_FIRESTORE_READ_ONLY',
      'APP_CHECKED_CALLABLE_FIRESTORE_READ_ONLY'
    )
    Invoke-FunctionDeployment -FunctionNames $callables
    Invoke-Readback -ReadbackPhase 'callables' -OutputPath $callablesPath `
      -ProbeCallables
  }

  'DeployEvents' {
    Assert-Receipt -Path $callablesPath `
      -Decision 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_CALLABLES' | Out-Null
    $events = Get-FunctionNamesByClass -Classes @(
      'FIRESTORE_NOTIFICATION_TRIGGER',
      'FIRESTORE_PROTOCOL_TRIGGER'
    )
    Invoke-FunctionDeployment -FunctionNames $events
    foreach ($name in $events) {
      $binding = $policy.functionBindings.$name
      $email = "$($binding.runtimeServiceAccountId)@$ProjectId.iam.gserviceaccount.com"
      Ensure-ServiceInvoker -FunctionName $name -Email $email
      Remove-ProjectRole -Email $email -Role 'roles/run.invoker'
    }
    Invoke-Readback -ReadbackPhase 'events' -OutputPath $eventsPath `
      -ProbeCallables
  }

  'DeployScheduler' {
    Assert-Receipt -Path $eventsPath `
      -Decision 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_EVENTS' | Out-Null
    Invoke-Readback -ReadbackPhase 'events' `
      -OutputPath $schedulerPreflightPath -ProbeCallables
    $scheduler = Get-FunctionNamesByClass -Classes @(
      'SCHEDULED_FIRESTORE_MUTATION'
    )
    Invoke-FunctionDeployment -FunctionNames $scheduler
    $schedulerName = $scheduler[0]
    $binding = $policy.functionBindings.$schedulerName
    $email = "$($binding.runtimeServiceAccountId)@$ProjectId.iam.gserviceaccount.com"
    Ensure-ServiceInvoker -FunctionName $schedulerName -Email $email
    Remove-ProjectRole -Email $email -Role 'roles/run.invoker'
    $schedulerJob = "firebase-schedule-$schedulerName-$Region"
    Invoke-ExternalText -FilePath $script:gcloud -WorkingDirectory $root `
      -Arguments @(
        'scheduler', 'jobs', 'run', $schedulerJob,
        "--location=$Region",
        "--project=$ProjectId",
        '--quiet'
      ) | Out-Null
    Start-Sleep -Seconds 20
    Invoke-Readback -ReadbackPhase 'fleet' -OutputPath $fleetPath `
      -ProbeCallables
  }

  'Finalize' {
    Assert-Receipt -Path $fleetPath `
      -Decision 'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FLEET' | Out-Null
    Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root -Arguments @(
      'tools/release/collectFunctionsIamDependenciesReadback.js',
      '--repository-root', $root,
      '--project-id', $ProjectId,
      '--region', $Region,
      '--output', $preFinalDependenciesPath,
      '--gcloud', $script:gcloud,
      '--tar', 'tar'
    ) | Out-Null

    $reader = "crm3-global-pull-reader@$ProjectId.iam.gserviceaccount.com"
    $writer = "crm3-global-pull-writer@$ProjectId.iam.gserviceaccount.com"
    Remove-ProjectRole -Email $reader -Role 'roles/logging.logWriter'
    Remove-ProjectRole -Email $writer -Role 'roles/logging.logWriter'
    Remove-ProjectRole -Email $writer -Role 'roles/run.invoker'
    Remove-ProjectRole -Email $defaultCompute -Role 'roles/eventarc.eventReceiver'
    Remove-ProjectRole -Email $defaultCompute -Role 'roles/run.invoker'
    Remove-ProjectRole -Email $defaultCompute -Role 'roles/editor'

    try {
      Invoke-Readback -ReadbackPhase 'final' -OutputPath $finalPath `
        -ProbeCallables
    } catch {
      Ensure-ProjectRole -Email $defaultCompute -Role 'roles/editor'
      throw 'Final readback failed; Default Compute Editor was restored.'
    }
    Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root -Arguments @(
      'tools/release/collectFunctionsIamDependenciesReadback.js',
      '--repository-root', $root,
      '--project-id', $ProjectId,
      '--region', $Region,
      '--output', $finalDependenciesPath,
      '--gcloud', $script:gcloud,
      '--tar', 'tar'
    ) | Out-Null
    $dependencies = Get-Content -LiteralPath $finalDependenciesPath -Raw |
      ConvertFrom-Json
    if ($dependencies.posture.decision -cne 'PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE') {
      Ensure-ProjectRole -Email $defaultCompute -Role 'roles/editor'
      throw 'Dependency posture did not pass; Default Compute Editor was restored.'
    }
  }

  'RestoreEditor' {
    Ensure-ProjectRole -Email $defaultCompute -Role 'roles/editor'
    Write-Host 'Default Compute Editor is present. No Function was redeployed.'
  }
}
