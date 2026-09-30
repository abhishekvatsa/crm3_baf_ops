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
    [AllowEmptyString()][string]$BackendReceiptSha256 = ''
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
  if ($BackendReceiptSha256 -notmatch '^[0-9A-F]{64}$' -or
      $BackendReceiptSha256 -cne $Policy.finalization.exactFunctionFleetDeploymentReceiptSha256.ToUpperInvariant() -or
      $Approval.backendReceiptSha256 -cne $BackendReceiptSha256 -or
      $Approval.backendSourceCommit -cne $BackendReceipt.sourceAuthority.commit -or
      $BackendReceipt.deployment.appCheckEnforcement -isnot [bool] -or
      $Approval.serverEnforcementAtBuild -isnot [bool] -or
      $Approval.serverEnforcementAtBuild -ne $BackendReceipt.deployment.appCheckEnforcement -or
      ($BackendReceipt.deployment.appCheckEnforcement -and -not $choice.clientEnabled)) {
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
        $BackendReceipt.sourceAuthority.commit -cne '2aa30de56cfdb960da3eeefd8956d8cbbae57b46' -or
        $BackendReceiptSha256 -cne '3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45' -or
        $Policy.finalization.exactFunctionFleetDeploymentReceiptFile -cne 'release/evidence/build30-current-source-backend-deployment-closure.json' -or
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
    serverEnforcementAtBuild = $BackendReceipt.deployment.appCheckEnforcement
    enforcementChangedByBuild = $false
    tokenValidationEvidence = 'not-proved-by-artifact-construction'
  }
  if ($build -eq 31) { $result.serverEnforcementScopesAtBuild = $scopes }
  $result
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
  Get-ProductionAppCheckBuildEvidence -Policy $Policy `
    -Approval (Get-Content -LiteralPath $approvalPath -Raw | ConvertFrom-Json) `
    -BackendReceipt (Get-Content -LiteralPath $backendPath -Raw | ConvertFrom-Json) `
    -ApprovalSha256 ((Get-FileHash -LiteralPath $approvalPath -Algorithm SHA256).Hash) `
    -BackendReceiptSha256 ((Get-FileHash -LiteralPath $backendPath -Algorithm SHA256).Hash)
}
