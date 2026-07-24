#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RepositoryRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path -LiteralPath $RepositoryRoot)

$flutter = & flutter --version --machine | ConvertFrom-Json
if ([string]$flutter.frameworkVersion -ne '3.44.0') {
  throw "Flutter 3.44.0 required; found $($flutter.frameworkVersion)."
}
if ([string]$flutter.dartSdkVersion -notmatch '^3\.12\.0(?:\b|-)') {
  throw "Dart 3.12.0 required; found $($flutter.dartSdkVersion)."
}

& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

& dart run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) { throw 'Isar build_runner generation failed.' }

& python tools/isar/verify_v4_isar_schema.py --release
if ($LASTEXITCODE -ne 0) { throw 'Generated Isar bindings failed v4 authority verification.' }

& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed after Isar generation.' }

& flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed after Isar generation.' }

Write-Host 'PASS: pinned v4 Isar codegen, Flutter analysis and Flutter tests.'
