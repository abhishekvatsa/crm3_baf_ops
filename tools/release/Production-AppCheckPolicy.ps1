#requires -Version 7.0
# Pure validation shared by construction and the archive-bound package verifier.
# This records a compiler choice, never a token, Console configuration or proof
# that a Play-delivered installation has successfully attested.
function Get-ProductionAppCheckBuildEvidence {
  param(
    [Parameter(Mandatory)][object]$Policy,
    [AllowNull()][object]$Approval,
    [AllowNull()][object]$BackendReceipt,
    [AllowEmptyString()][string]$ApprovalSha256 = '',
    [AllowEmptyString()][string]$BackendReceiptSha256 = '',
    [AllowNull()][object]$Runtime31Proof,
    [AllowNull()][object]$Business31Proof
  )

  $build = $Policy.release.buildNumber
  if ($build -isnot [int] -and $build -isnot [long]) {
    throw 'App Check build number must be an integer.'
  }
  if ($build -ge 1 -and $build -le 29) { return $null }
  if ($build -notin @(30, 31)) { throw 'No App Check construction protocol is admitted for this build.' }
  if ($null -eq $Policy.PSObject.Properties['appCheckBuild']) {
    throw 'Build30 requires an explicit governed App Check client choice.'
  }
  $choice = $Policy.appCheckBuild
  $approvalFile = "release/approvals/build$build-app-check-client-approval.json"
  if ($choice.clientEnabled -isnot [bool] -or
      $choice.androidProvider -cne $(if ($choice.clientEnabled) { 'playIntegrity' } else { 'disabled' }) -or
      $choice.approvalFile -cne $approvalFile -or
      $choice.approvalSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
      $ApprovalSha256 -cne $choice.approvalSha256.ToUpperInvariant()) {
    throw 'App Check choice, Android provider or exact approval bytes differ.'
  }
  if ($null -eq $Approval -or $null -eq $BackendReceipt -or
      $Approval.schemaVersion -ne 1 -or
      $Approval.documentType -cne 'governed-app-check-client-build-approval' -or
      $Approval.approved -isnot [bool] -or $Approval.approved -ne $true -or
      ($Approval.intendedBuildNumber -isnot [int] -and $Approval.intendedBuildNumber -isnot [long]) -or
      $Approval.intendedBuildNumber -cne $build -or
      $Approval.releaseId -cne $Policy.release.releaseId -or
      $Approval.reservationId -cne $Policy.versionPolicy.reservationId -or
      $Approval.firebaseProjectId -cne 'crm3-baf-ops-b8638' -or
      $Approval.applicationId -cne 'in.co.sail.bsl.crm3.bafops' -or
      $Approval.clientEnabled -isnot [bool] -or $Approval.clientEnabled -ne $choice.clientEnabled -or
      $Approval.androidProvider -cne $choice.androidProvider -or
      $Approval.enforcementChangeAuthorized -isnot [bool] -or $Approval.enforcementChangeAuthorized -ne $false) {
    throw 'App Check client choice lacks exact candidate-specific approval; no enforcement change is authorized.'
  }
  foreach ($identity in @($Approval.approverName, $Approval.approvalReference)) {
    if ($identity -isnot [string] -or [string]::IsNullOrWhiteSpace($identity) -or $identity.Length -gt 4000) {
      throw 'App Check approval identity must be accountable non-placeholder text.'
    }
    # Compare NFKD text without Unicode 16 Default_Ignorable_Code_Point ranges
    # (DerivedCoreProperties.txt), then trim. .NET regex uses UTF-16 pairs for
    # the three supplementary ranges. Never rewrite hash-bound original text.
    $invisibleIdentityPattern = '[\u00AD\u034F\u061C\u115F-\u1160\u17B4-\u17B5\u180B-\u180F\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0\uFFF0-\uFFF8]|\uD82F[\uDCA0-\uDCA3]|\uD834[\uDD73-\uDD7A]|[\uDB40-\uDB43][\uDC00-\uDFFF]'
    $normalizedIdentity = [regex]::Replace($identity.Normalize([Text.NormalizationForm]::FormKD), $invisibleIdentityPattern, '').Trim()
    # Compare presentation punctuation, symbols and whitespace as spaces,
    # including supplementary Unicode symbols. Retain word boundaries rather
    # than concatenating arbitrary names; never alter the approval's raw text.
    $identityComparison = [Text.StringBuilder]::new()
    for ($offset = 0; $offset -lt $normalizedIdentity.Length;) {
      $width = 1
      if ([char]::IsHighSurrogate($normalizedIdentity[$offset]) -and
          $offset + 1 -lt $normalizedIdentity.Length -and
          [char]::IsLowSurrogate($normalizedIdentity[$offset + 1])) { $width = 2 }
      $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($normalizedIdentity, $offset)
      # Combining decoration is comparison-only. Decomposition also makes
      # canonically equivalent composed/decomposed decorated markers agree.
      # Genuine names and the hash-bound original evidence remain untouched.
      if ($category.ToString() -match 'Mark$') {
        $offset += $width
        continue
      }
      if ([char]::IsWhiteSpace($normalizedIdentity, $offset) -or
          $category.ToString() -match '(Punctuation|Symbol)$') {
        [void]$identityComparison.Append(' ')
      } else {
        [void]$identityComparison.Append($normalizedIdentity.Substring($offset, $width))
      }
      $offset += $width
    }
    $normalizedIdentity = $identityComparison.ToString().Trim()
    # Apply the same suffix handling to every known placeholder stem. Complete
    # template markers precede bare stems so split APPROVER/REFERENCE forms are
    # compacted too. Genuine prefixes such as To-dor/To-doist remain distinct.
    $placeholderStems = @('TODO', 'FIXTURE', 'REPLACE')
    $placeholderMarkers = @(foreach ($stem in $placeholderStems) {
      "${stem}APPROVER"
      "${stem}REFERENCE"
    }) + $placeholderStems
    foreach ($marker in $placeholderMarkers) {
      $markerPattern = '^' + (($marker.ToCharArray() | ForEach-Object {
        [regex]::Escape([string]$_)
      }) -join '\s*')
      $normalizedIdentity = [regex]::Replace($normalizedIdentity, $markerPattern, $marker,
        ([Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant))
    }
    # A known full template marker remains unfinished when more text follows.
    # Bare stems require a boundary or numeric suffix, preserving genuine words
    # such as Todor, Todoist and Replacement.
    if ([string]::IsNullOrWhiteSpace($normalizedIdentity) -or
        $normalizedIdentity -match '^(TODO|FIXTURE|REPLACE)($|[^\p{L}\p{N}]|\d|APPROVER|REFERENCE)') {
      throw 'App Check approval identity must be accountable non-placeholder text.'
    }
  }
  $approvedAt = [DateTimeOffset]::MinValue
  # ConvertFrom-Json in newer PowerShell materializes explicit UTC ISO strings
  # as DateTime; older supported versions retain strings. Never treat a local
  # or unspecified wall clock as approval UTC.
  $approvedWire = $Approval.approvedAtUtc
  if ($approvedWire -is [DateTime] -and $approvedWire.Kind -eq [DateTimeKind]::Utc) {
    $approvedWire = $approvedWire.ToString('o')
  }
  if ($approvedWire -isnot [string] -or $approvedWire -notmatch 'Z$' -or
      -not [DateTimeOffset]::TryParse($approvedWire, [ref]$approvedAt) -or
      $approvedAt -gt [DateTimeOffset]::UtcNow) {
    throw 'App Check approval chronology is invalid.'
  }
  $runtime31 = $null -ne $Policy.PSObject.Properties['runtimeBackendPrivateReplay'] -or
    ($null -ne $Policy.PSObject.Properties['clientBackendCompatibility'] -and
      $Policy.clientBackendCompatibility.file -ceq 'release/approvals/build31-runtime-client-compatibility-approval.json')
  $business31 = Test-ProductionAppCheckBusiness31Selected $Policy
  if ($business31) {
    if ($runtime31 -or $build -ne 31) { throw 'App Check business31 cannot select a mixed or different build route.' }
    Assert-ProductionAppCheckBusiness31Binding -Policy $Policy -Proof $Business31Proof -BackendReceipt $BackendReceipt
    $backendSourceCommit = $Business31Proof.businessBackend31.source.commit
    $businessMeasurement = Get-ProductionAppCheckBusiness31Measurement $Business31Proof
    $serverDefaultEnforcement = $businessMeasurement.client.policy.appCheck.serverEnforcementAtBuild
  } elseif ($runtime31) {
    if ($null -eq $Runtime31Proof -or $build -ne 31) { throw 'App Check runtime31 choice requires complete private replay.' }
    Assert-ProductionRuntime31PublicBinding -Policy $Policy -Proof $Runtime31Proof
    if ($BackendReceipt.schemaVersion -ne 2 -or
        $BackendReceipt.documentType -cne 'build31-runtime-private-record-custody' -or
        $BackendReceipt.recordKind -cne 'closure' -or
        $BackendReceipt.source.commit -cne $Runtime31Proof.runtimeBackend31.source.commit) {
      throw 'App Check runtime31 public closure differs from private replay.'
    }
    $backendSourceCommit = $Runtime31Proof.runtimeBackend31.source.commit
    $serverDefaultEnforcement = $false # Independently replayed preserved boundary, not a new grant.
  } else {
    $backendSourceCommit = $BackendReceipt.sourceAuthority.commit
    $serverDefaultEnforcement = $BackendReceipt.deployment.appCheckEnforcement
  }
  if ($BackendReceiptSha256 -notmatch '^[0-9A-F]{64}$' -or
      $BackendReceiptSha256 -cne $Policy.finalization.exactFunctionFleetDeploymentReceiptSha256.ToUpperInvariant() -or
      $Approval.backendReceiptSha256 -cne $BackendReceiptSha256 -or
      $Approval.backendSourceCommit -cne $backendSourceCommit -or
      $serverDefaultEnforcement -isnot [bool] -or
      $Approval.serverEnforcementAtBuild -isnot [bool] -or
      $Approval.serverEnforcementAtBuild -ne $serverDefaultEnforcement -or
      ($serverDefaultEnforcement -and -not $choice.clientEnabled)) {
    throw 'App Check client choice and pinned backend enforcement evidence disagree.'
  }
  $scopes = $null
  if ($build -eq 31) {
    # The historical deployment receipt's appCheckEnforcement describes the
    # default/mutating boundary, not the independently enforced identity gate.
    # This bounded client-only successor preserves that exact deployed source.
    $expectedScopes = [ordered]@{
      defaultMutatingEnforced = $false
      identityCallable = 'getBackendReleaseIdentity'
      identityCallableEnforced = $true
      identitySourceFile = 'functions/src/stage2dSecurityConfig.ts'
      identitySourceSha256 = '1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F'
    }
    if (-not $choice.clientEnabled -or $choice.androidProvider -cne 'playIntegrity' -or
        (-not $runtime31 -and -not $business31 -and ($BackendReceipt.sourceAuthority.commit -cne '2aa30de56cfdb960da3eeefd8956d8cbbae57b46' -or
        $BackendReceiptSha256 -cne '3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45' -or
        $Policy.finalization.exactFunctionFleetDeploymentReceiptFile -cne 'release/evidence/build30-current-source-backend-deployment-closure.json')) -or
        $null -eq $Approval.PSObject.Properties['serverEnforcementScopesAtBuild']) {
      throw 'Build31 requires Play Integrity and explicit unchanged default/identity enforcement scopes.'
    }
    $scopes = $Approval.serverEnforcementScopesAtBuild
    if (@(Compare-Object @($expectedScopes.Keys | Sort-Object) @($scopes.PSObject.Properties.Name | Sort-Object)).Count -ne 0) {
      throw 'Build31 enforcement scope fields differ from the deployed source contract.'
    }
    foreach ($key in $expectedScopes.Keys) {
      if (($scopes.$key | ConvertTo-Json -Compress) -cne ($expectedScopes[$key] | ConvertTo-Json -Compress)) {
        throw "Build31 enforcement scope differs from the deployed source: $key"
      }
    }
  }
  $result = [ordered]@{
    clientEnabled = $choice.clientEnabled
    androidProvider = $choice.androidProvider
    dartDefine = $(if ($choice.clientEnabled) { 'true' } else { 'false' })
    approvalFile = $approvalFile
    approvalSha256 = $ApprovalSha256
    backendReceiptFile = $Policy.finalization.exactFunctionFleetDeploymentReceiptFile
    backendReceiptSha256 = $BackendReceiptSha256
    serverEnforcementAtBuild = $serverDefaultEnforcement
    enforcementChangedByBuild = $false
    tokenValidationEvidence = 'not-proved-by-artifact-construction'
  }
  if ($build -eq 31) { $result.serverEnforcementScopesAtBuild = $scopes }
  if ($business31) {
    Assert-ProductionAppCheckSameValue $result $businessMeasurement.client.policy.appCheck 'Business31 replayed App Check compiler choice'
  }
  $result
}

function Test-ProductionAppCheckBusiness31Selected {
  param([Parameter(Mandatory)][object]$Policy)
  if ($null -ne $Policy.PSObject.Properties['businessBackendPrivateReplay']) { return $true }
  foreach ($name in @('clientBackendCompatibility', 'runtimeBackendPrivateReplay')) {
    if ($null -ne $Policy.PSObject.Properties[$name]) {
      foreach ($field in @('profile', 'file')) {
        if ($null -ne $Policy.$name -and $null -ne $Policy.$name.PSObject.Properties[$field] -and
            $Policy.$name.$field -is [string] -and $Policy.$name.$field -match 'business') { return $true }
      }
    }
  }
  return $false
}

function Assert-ProductionAppCheckSameValue {
  param([AllowNull()][object]$Actual, [AllowNull()][object]$Expected, [string]$Label)
  # Compare closed objects independently of JSON property order; types of scalar
  # values remain significant. This only joins an already authenticated result.
  $aObject = $Actual -is [Collections.IDictionary] -or $Actual -is [pscustomobject]
  $eObject = $Expected -is [Collections.IDictionary] -or $Expected -is [pscustomobject]
  if ($aObject -or $eObject) {
    if (-not $aObject -or -not $eObject) { throw "$Label differs." }
    $aKeys = @(if ($Actual -is [Collections.IDictionary]) { $Actual.Keys } else { $Actual.PSObject.Properties.Name })
    $eKeys = @(if ($Expected -is [Collections.IDictionary]) { $Expected.Keys } else { $Expected.PSObject.Properties.Name })
    if (@(Compare-Object ($aKeys | Sort-Object) ($eKeys | Sort-Object) -CaseSensitive).Count -ne 0) { throw "$Label fields differ." }
    foreach ($key in $aKeys) { Assert-ProductionAppCheckSameValue $Actual.$key $Expected.$key "$Label/$key" }
    return
  }
  if ((ConvertTo-Json -InputObject $Actual -Compress -Depth 30) -cne (ConvertTo-Json -InputObject $Expected -Compress -Depth 30)) {
    throw "$Label differs."
  }
}

function Assert-ProductionAppCheckBusiness31Binding {
  param([Parameter(Mandatory)][object]$Policy, [AllowNull()][object]$Proof,
    [Parameter(Mandatory)][object]$BackendReceipt)
  # The repository adapter obtains this from the independently pinned V child.
  # This pure join never turns a supplied object into private replay authority.
  if ($null -eq $Proof -or $Proof.ok -isnot [bool] -or -not $Proof.ok -or
      $Proof.route -cne 'business-backend31' -or $Policy.versionPolicy.buildNumber -cne 31 -or
      $Policy.businessBackendPrivateReplay.profile -cne 'build31-exact-business-backend-v1' -or
      $Policy.clientBackendCompatibility.profile -cne 'build31-business-client-compatibility-v1') {
    throw 'App Check business31 requires the exact authenticated policy measurement.'
  }
  $business = $Proof.businessBackend31
  $result = Get-ProductionAppCheckBusiness31Measurement $Proof
  $client = $result.client
  $measured = $client.policy
  if ($client.schemaVersion -cne 2 -or $client.profile -cne 'build31-business-client-compatibility-v1' -or
      $client.appCheckSourcePolicyVerified -isnot [bool] -or -not $client.appCheckSourcePolicyVerified -or
      $measured.schemaVersion -cne 1 -or $measured.profile -cne 'build31-business-client-policy-v1' -or
      $measured.policySourceVerified -isnot [bool] -or -not $measured.policySourceVerified -or
      $measured.appCheckSourcePolicyVerified -isnot [bool] -or -not $measured.appCheckSourcePolicyVerified -or
      $BackendReceipt.schemaVersion -cne 1 -or $BackendReceipt.documentType -cne 'build31-business-private-record-custody' -or
      $BackendReceipt.recordKind -cne 'closure') { throw 'App Check business31 policy/closure measurement is incomplete.' }
  foreach ($name in @('independentlySelectedInputsAuthenticated', 'executingHostAuthenticated', 'humanIdentityAuthenticated',
      'trustedClockAuthenticated', 'credentialAccessAuthorized', 'backendDeploymentAuthorized',
      'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized')) {
    foreach ($scope in @($client, $measured)) {
      if ($scope.$name -isnot [bool] -or $scope.$name -ne $false) { throw 'App Check business31 measurement cannot grant operational authority.' }
    }
  }
  if ($client.platformIdentityAuthenticated -isnot [bool] -or $client.platformIdentityAuthenticated -ne $false -or
      $measured.platformIdentityAuthenticated -isnot [bool] -or $measured.platformIdentityAuthenticated -ne $false -or
      $measured.privateReplayVerified -isnot [bool] -or $measured.privateReplayVerified -ne $false) {
    throw 'App Check business31 source measurement cannot authenticate processes or private execution.'
  }
  Assert-ProductionAppCheckSameValue $BackendReceipt $business.currentBackend 'Business31 actual closure bytes'
  foreach ($source in @($BackendReceipt.source, $result.source, $measured.source)) {
    Assert-ProductionAppCheckSameValue $source $business.source 'Business31 source M'
  }
  foreach ($entry in @(@('businessBackendPrivateReplay', 'descriptorPointer'), @('clientBackendCompatibility', 'clientPointer'))) {
    $selected = $Policy.($entry[0]); $pointer = $business.($entry[1])
    foreach ($field in @('commit', 'file', 'sha256')) {
      if ($selected.$field -cne $pointer.$field) { throw 'App Check business31 selected pointer differs.' }
    }
  }
  Assert-ProductionAppCheckSameValue $business.descriptorPointer $result.descriptorPointer 'Business31 measured descriptor'
  Assert-ProductionAppCheckSameValue $business.clientPointer $client.decisionPointer 'Business31 measured client decision'
  Assert-ProductionAppCheckSameValue $business.closurePointer $result.closurePointer 'Business31 measured closure'
  if ($business.closurePointer.file -cne $Policy.finalization.exactFunctionFleetDeploymentReceiptFile -or
      $business.closurePointer.sha256 -cne $Policy.finalization.exactFunctionFleetDeploymentReceiptSha256 -or
      $measured.release.releaseId -cne $Policy.release.releaseId -or
      $measured.release.reservationId -cne $Policy.versionPolicy.reservationId -or
      $measured.release.buildNumber -cne 31) { throw 'App Check business31 release or closure differs.' }
}

function Assert-ProductionAppCheckManifest {
  param([Parameter(Mandatory)][object]$Manifest, [Parameter(Mandatory)][object]$Expected)
  if ($null -eq $Manifest.PSObject.Properties['appCheckBuild'] -or
      $Manifest.appIdentity.CRM3_APP_CHECK_ENABLED -cne $Expected.dartDefine) {
    throw 'Manifest omits or contradicts the actual App Check compiler choice.'
  }
  $actual = $Manifest.appCheckBuild
  $expectedKeys = @($Expected.Keys | Sort-Object)
  if (@(Compare-Object $expectedKeys @($actual.PSObject.Properties.Name | Sort-Object)).Count -ne 0) {
    throw 'Manifest App Check evidence fields differ from the governed contract.'
  }
  foreach ($key in $expectedKeys) {
    if (($actual.$key | ConvertTo-Json -Compress) -cne ($Expected[$key] | ConvertTo-Json -Compress)) {
      throw "Manifest App Check evidence differs: $key"
    }
  }
}

function Get-ProductionAppCheckBusiness31Measurement {
  param([Parameter(Mandatory)][object]$Proof)
  $business = $Proof.businessBackend31
  $hasPolicy = $null -ne $business.PSObject.Properties['policyResult']
  $hasPrerequisite = $null -ne $business.PSObject.Properties['prerequisiteResult']
  if ($hasPolicy -eq $hasPrerequisite) { throw 'App Check requires exactly one authenticated measurement route.' }
  if ($hasPolicy) {
    $result = $business.policyResult
    if ($result.schemaVersion -cne 1 -or $result.profile -cne 'build31-business-policy-result-v1' -or
        $result.purpose -cne 'policy' -or $result.policyMeasurementVerified -isnot [bool] -or -not $result.policyMeasurementVerified) {
      throw 'App Check policy measurement is incomplete.'
    }
    foreach ($name in @('independentlySelectedInputsAuthenticated', 'executingHostAuthenticated', 'humanIdentityAuthenticated',
        'trustedClockAuthenticated', 'originalProcessExecutionAuthenticated', 'credentialAccessAuthorized',
        'backendDeploymentAuthorized', 'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized')) {
      if ($result.$name -isnot [bool] -or $result.$name -ne $false) { throw 'App Check policy measurement cannot grant authority.' }
    }
  } else {
    $result = $business.prerequisiteResult
    if ($result.schemaVersion -cne 1 -or $result.profile -cne 'build31-business-prerequisite-measurement-v1' -or
        $result.purpose -cnotin @('construction', 'package-verification') -or
        $result.replayMode -cnotin @('fresh-dispatch', 'same-parent-reauthentication') -or
        ($result.purpose -ceq 'package-verification' -and $result.replayMode -cne 'fresh-dispatch') -or
        $result.freshHostedReplayVerified -isnot [bool] -or -not $result.freshHostedReplayVerified) {
      throw 'App Check operational prerequisite measurement is incomplete.'
    }
    Assert-ProductionAppCheckSameValue $result.limits ([ordered]@{deploymentAuthorized=$false; constructionAuthorized=$false;
      signingAuthorized=$false; distributionAuthorized=$false}) 'App Check prerequisite limits'
  }
  $result
}

function Get-ProductionAppCheckRepositoryEvidence {
  param([Parameter(Mandatory)][string]$RepositoryRoot, [Parameter(Mandatory)][object]$Policy)
  if ($Policy.release.buildNumber -ge 1 -and $Policy.release.buildNumber -le 29) { return $null }
  $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  $comparison = if ([IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  $backendEntry = $Policy.finalization.exactFunctionFleetDeploymentReceiptFile
  if ($backendEntry -isnot [string] -or [IO.Path]::IsPathRooted($backendEntry) -or
      $backendEntry.Contains(':') -or $backendEntry -match '(^|[\\/])\.\.([\\/]|$)') {
    throw 'App Check backend receipt must be a repository source entry.'
  }
  $backendPath = [IO.Path]::GetFullPath((Join-Path $root $backendEntry))
  if (-not $backendPath.StartsWith($root, $comparison)) { throw 'App Check backend receipt escapes source custody.' }
  if ($Policy.release.buildNumber -notin @(30, 31)) { throw 'No App Check construction protocol is admitted for this build.' }
  $approvalPath = Join-Path $root "release/approvals/build$($Policy.release.buildNumber)-app-check-client-approval.json"
  $runtimeProof = $null
  $businessProof = $null
  if (Test-ProductionAppCheckBusiness31Selected $Policy) {
    $helper = Join-Path $RepositoryRoot 'tools/release/clientBackendCompatibility31.js'
    $output = @(& node --no-global-search-paths $helper $RepositoryRoot (Join-Path $RepositoryRoot 'release/production-release-policy.json'))
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'App Check business31 protected policy measurement failed.' }
    $businessProof = [string]$output[0] | ConvertFrom-Json -Depth 100
  } elseif ($null -ne $Policy.PSObject.Properties['runtimeBackendPrivateReplay'] -or
      ($null -ne $Policy.PSObject.Properties['clientBackendCompatibility'] -and
       $Policy.clientBackendCompatibility.file -ceq 'release/approvals/build31-runtime-client-compatibility-approval.json')) {
    . (Join-Path $RepositoryRoot 'tools/release/Runtime-BackendPrivateReplay31.ps1')
    $runtimeProof = Get-ProductionRuntime31RepositoryEvidence -RepositoryRoot $RepositoryRoot -Policy $Policy
  }
  Get-ProductionAppCheckBuildEvidence -Policy $Policy `
    -Approval (Get-Content -LiteralPath $approvalPath -Raw | ConvertFrom-Json) `
    -BackendReceipt (Get-Content -LiteralPath $backendPath -Raw | ConvertFrom-Json) `
    -ApprovalSha256 ((Get-FileHash -LiteralPath $approvalPath -Algorithm SHA256).Hash) `
    -BackendReceiptSha256 ((Get-FileHash -LiteralPath $backendPath -Algorithm SHA256).Hash) `
    -Runtime31Proof $runtimeProof -Business31Proof $businessProof
}
