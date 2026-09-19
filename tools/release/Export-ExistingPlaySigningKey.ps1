#requires -Version 5.1
<#
.SYNOPSIS
Creates a locally encrypted Google Play transfer ZIP from the existing approved
release key. Does not upload, change Play settings, or build an application.
.DESCRIPTION
Run interactively. Google PEPK requests passwords through the local console.
Use -PastePasswords for masked boxes with Ctrl+V support instead. That mode
passes char arrays directly to the pinned PEPK API within one local JVM.
For a desktop launch, use -Interactive with PowerShell -File, without -NoExit.
The helper then pauses on completion/failure instead of exposing a shell prompt.
No passwords are accepted as script arguments or written to a file. Downloaded
inputs are pinned to the files obtained from this app's Play Console on
20 September 2026. If Google supplies different inputs, review them and update
the pins deliberately; do not bypass the checks.
#>
[CmdletBinding()]
param(
  [string]$JavaPath = 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe',
  [string]$KeystorePath = 'C:\Users\abhis\CRM_III_BAF_Ops_Signing_Custody\Primary\crm3-baf-ops-production-signing.p12',
  [string]$PepkPath = 'C:\Users\abhis\Downloads\pepk.jar',
  [string]$EncryptionKeyPath = 'C:\Users\abhis\Downloads\encryption_public_key.pem',
  [string]$OutputDirectory = 'C:\Users\abhis\CRM_III_BAF_Ops_Signing_Custody\PlayTransfer',
  [switch]$ValidateOnly,
  [switch]$Interactive,
  [switch]$PastePasswords
)
$ErrorActionPreference = 'Stop'
function Wait-ForExportWindowClose {
  Write-Host 'Press Enter to close this window. No password is needed here.'
  # Discard input without echoing it or passing it to the shell/history.
  do { $closeKey = [Console]::ReadKey($true) } while ($closeKey.Key -ne [ConsoleKey]::Enter)
}
trap {
  Write-Host 'Signing export stopped. No upload or Play setting change was performed.' -ForegroundColor Red
  Write-Host $_.Exception.Message
  if ($Interactive) { try { Wait-ForExportWindowClose } catch { } }
  exit 1
}
if ($Interactive) {
  $Host.UI.RawUI.WindowTitle = 'CRM3 - Google signing-key export'
  if ($PastePasswords) { Write-Host 'Paste passwords ONLY in the masked CRM3 dialog. Nothing is uploaded.' -ForegroundColor Yellow }
  else { Write-Host 'Only enter passwords when GOOGLE PEPK explicitly asks for the store or key password.' -ForegroundColor Yellow }
}
$expectedCertificate = '6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C'
$inputPins = @(
  @{ Path = $KeystorePath; Hash = '4D5727DB14A82FB25A16DC9B063B94462E66FD36D006B97E888465E2DD730471' },
  @{ Path = $PepkPath; Hash = 'AACCC0774B240AA5304BDAD2A49865E92F229CA73209ECB6EAAFE75DC858E24E' },
  @{ Path = $EncryptionKeyPath; Hash = 'BB2FE629411F0291BA64A35B43C4135EAA3952548C760C84003FA73DFFDAD1C0' }
)
foreach ($pin in $inputPins) {
  if ((Get-FileHash -LiteralPath $pin.Path -Algorithm SHA256).Hash -ne $pin.Hash) {
    throw "Input hash mismatch: $($pin.Path). Stop and review; do not upload."
  }
}
if (-not (Test-Path -LiteralPath $JavaPath -PathType Leaf)) { throw 'Java runtime not found.' }
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\')
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if ($outputRoot.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputRoot.StartsWith($repoRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The encrypted key transfer must remain outside the repository.'
}
[void][IO.Directory]::CreateDirectory($outputRoot)
if ($ValidateOnly) { Write-Output 'Input pins and output location validated; no key export performed.'; return }
$outputZip = Join-Path $outputRoot ('crm3-original-signing-key-' + [Guid]::NewGuid().ToString('N') + '.zip')
if ($PastePasswords) {
  Write-Host 'Opening masked password boxes. Ctrl+V paste is supported; passwords are never process arguments.'
  & $JavaPath --class-path $PepkPath (Join-Path $PSScriptRoot 'PlaySigningPasswordDialog.java') $KeystorePath 'crm3-baf-ops-release' $outputZip $EncryptionKeyPath
} else {
  Write-Host 'Starting Google PEPK. Wait for its explicit Enter password for store/key prompt.'
  Write-Host 'Do not paste them into chat. This step encrypts locally; it does not upload.'
  & $JavaPath -jar $PepkPath "--keystore=$KeystorePath" '--alias=crm3-baf-ops-release' "--output=$outputZip" '--include-cert' '--rsa-aes-encryption' "--encryption-key-path=$EncryptionKeyPath"
}
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputZip -PathType Leaf)) {
  throw 'PEPK did not complete. No transfer is approved; inspect the local password/error prompt.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($outputZip)
try {
  $certEntries = @($archive.Entries | Where-Object { $_.FullName -eq 'certificate.pem' })
  if ($certEntries.Count -ne 1) { throw 'Unexpected PEPK archive: exactly one certificate.pem is required.' }
  $certStream = $certEntries[0].Open()
  $reader = New-Object IO.StreamReader($certStream)
  try { $pem = $reader.ReadToEnd() } finally { $reader.Dispose() }
  $match = [regex]::Match($pem, '(?s)-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----')
  if (-not $match.Success) { throw 'PEPK certificate is not a PEM certificate.' }
  $der = [Convert]::FromBase64String(($match.Groups[1].Value -replace '\s', ''))
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $actualCertificate = ([BitConverter]::ToString($sha.ComputeHash($der))).Replace('-', '') }
  finally { $sha.Dispose() }
  if ($actualCertificate -ne $expectedCertificate) { throw 'Exported certificate differs from the installed APK signer. Do not upload.' }
  if (@($archive.Entries | Where-Object { $_.FullName -eq 'encryptedPrivateKey' -and $_.Length -gt 0 }).Count -ne 1) {
    throw 'Expected encryptedPrivateKey entry missing. Do not upload.'
  }
} finally { $archive.Dispose() }
$receipt = [ordered]@{
  status = 'encrypted-export-verified-not-uploaded'
  appPackage = 'in.co.sail.bsl.crm3.bafops'
  certificateSha256 = $actualCertificate
  zipSha256 = (Get-FileHash -LiteralPath $outputZip -Algorithm SHA256).Hash
  outputZip = $outputZip
  createdAtUtc = [DateTime]::UtcNow.ToString('o')
}
$receipt | ConvertTo-Json | Set-Content -LiteralPath ($outputZip + '.receipt.json') -Encoding UTF8
Write-Host ('Verified encrypted transfer ZIP: ' + $outputZip)
Write-Host ('Signer SHA-256: ' + $actualCertificate)
Write-Host 'No upload or Play signing change has been made. Return to the signing task for transfer and readback.'
if ($Interactive) { Wait-ForExportWindowClose }
