# Local validation status only; this module never runs a build or release action.
Set-StrictMode -Version Latest

function New-LocalGateReport {
  param([string[]]$Names)
  $steps = [ordered]@{}
  foreach ($name in $Names) {
    if ($steps.Contains($name)) { throw "Duplicate local gate: $name" }
    $steps[$name] = [ordered]@{ status = 'untested'; detail = '' }
  }
  return [ordered]@{
    schemaVersion = 1
    evidenceKind = 'local-validation-attempt'
    steps = $steps
    notEstablished = @('current-head CI success', 'DEV runtime acceptance', 'production signing', 'distribution', 'release authorization')
  }
}

function Set-LocalGateResult {
  param($Report, [string]$Name,
    [ValidateSet('passed', 'failed', 'skipped', 'warning')][string]$Status,
    [string]$Detail = '')
  if (-not $Report.steps.Contains($Name)) { throw "Unknown local gate: $Name" }
  if ($Report.steps[$Name].status -ne 'untested') { throw "Local gate result already recorded: $Name" }
  $Report.steps[$Name] = [ordered]@{ status = $Status; detail = $Detail }
}

function Write-LocalGateReport {
  param($Report, [string]$Path)
  $counts = [ordered]@{}
  foreach ($status in @('passed', 'failed', 'skipped', 'untested', 'warning')) {
    $counts[$status] = @($Report.steps.Values | Where-Object { $_.status -eq $status }).Count
  }
  $Report['counts'] = $counts
  $summary = if ($counts.failed -gt 0) { 'LOCAL VALIDATION FAILED' }
    elseif ($counts.skipped -gt 0 -or $counts.untested -gt 0) { 'LOCAL VALIDATION PARTIAL' }
    elseif ($counts.warning -gt 0) { 'LOCAL REQUIRED CHECKS PASSED WITH WARNINGS' }
    else { 'ALL AUTOMATED LOCAL GATES GREEN' }
  $Report['summary'] = $summary
  $Report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
  Write-Host $summary
  Write-Host ("Passed: {0}; failed: {1}; skipped: {2}; untested: {3}; warnings: {4}" -f $counts.passed, $counts.failed, $counts.skipped, $counts.untested, $counts.warning)
  foreach ($name in $Report.steps.Keys) {
    Write-Host ("{0}: {1} {2}" -f $Report.steps[$name].status.ToUpperInvariant(), $name, $Report.steps[$name].detail)
  }
  Write-Host 'This attempt does not establish CI success, DEV runtime acceptance, production signing, distribution or release authorization.'
}
