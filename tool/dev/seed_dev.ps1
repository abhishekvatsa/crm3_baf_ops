# Seeds the running emulator suite with the identity the development app needs.
#
# Setup is administrative on purpose. The action under test must still go
# through normal application permissions, the real Firestore Rules and the
# actual callable transport - otherwise the test bypasses the path being
# investigated. Nothing here grants the app any privilege it would not have in
# production; it only creates the account an identity provider would have
# created.
#
# Why this is needed: the real provider is Google Sign-In, whose token always
# carries email_verified = true. Email/password sign-up in the Auth emulator
# sets it false, and firestore.rules requires a verified token email before a
# pending user profile may be created. Seeding the account with the verified
# flag makes the stand-in faithful to the provider it replaces, rather than
# weakening the rule.
#
# Requires tool/dev/emulators.ps1 to be running.

$ErrorActionPreference = 'Stop'

$projectId = $env:CRM_DEMO_PROJECT_ID
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = 'demo-crm3-baf-ops' }
if (-not $projectId.StartsWith('demo-')) {
  throw "CRM_DEMO_PROJECT_ID must start with 'demo-'. Received: $projectId"
}

$authHost = '127.0.0.1:9099'
$email    = if ($env:CRM_DEV_EMAIL) { $env:CRM_DEV_EMAIL } else { 'dev.operations@example.invalid' }
$secret   = if ($env:CRM_DEV_SECRET) { $env:CRM_DEV_SECRET } else { 'emulator-local-only' }
$display  = if ($env:CRM_DEV_DISPLAY_NAME) { $env:CRM_DEV_DISPLAY_NAME } else { 'Dev Operations' }

$headers = @{ Authorization = 'Bearer owner'; 'Content-Type' = 'application/json' }
$base    = "http://$authHost/identitytoolkit.googleapis.com/v1"

try {
  Invoke-RestMethod -Method Get -Uri "http://$authHost/" -TimeoutSec 5 | Out-Null
} catch {
  throw "Auth emulator is not reachable at $authHost. Start tool/dev/emulators.ps1 first."
}

# Find an existing account so the script is idempotent.
$existing = Invoke-RestMethod -Method Post -Headers $headers `
  -Uri "$base/projects/$projectId/accounts:query" -Body '{}'
$account = $existing.userInfo | Where-Object { $_.email -eq $email } | Select-Object -First 1

if ($null -eq $account) {
  $signUp = @{ email = $email; password = $secret; displayName = $display } | ConvertTo-Json
  $created = Invoke-RestMethod -Method Post -Headers $headers `
    -Uri "$base/accounts:signUp?key=emulator" -Body $signUp
  $localId = $created.localId
  Write-Host "Created $email" -ForegroundColor Green
} else {
  $localId = $account.localId
  Write-Host "Reusing $email" -ForegroundColor DarkGray
}

# The verified flag is the whole point: firestore.rules refuses a pending user
# profile without it, and only an administrative write can set it.
$update = @{
  localId       = $localId
  emailVerified = $true
  displayName   = $display
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Headers $headers `
  -Uri "$base/accounts:update" -Body $update | Out-Null

$check = Invoke-RestMethod -Method Post -Headers $headers `
  -Uri "$base/projects/$projectId/accounts:query" -Body '{}'
$seeded = $check.userInfo | Where-Object { $_.email -eq $email } | Select-Object -First 1
Write-Host ("Seeded {0} | uid={1} | emailVerified={2} | displayName={3}" -f `
  $seeded.email, $seeded.localId, $seeded.emailVerified, $seeded.displayName) -ForegroundColor Green

if (-not $seeded.emailVerified) {
  throw 'Seeding did not set emailVerified; the Rules will refuse the pending profile.'
}

# ---------------------------------------------------------------------------
# Approve the account.
#
# In production an administrator approves a pending user. There is no
# administrator in a local sandbox, so the approval is written administratively
# here. This is setup, not the action under test: everything the app then does
# with that approved identity still goes through normal permissions, the real
# Rules and the actual callable transport.
# ---------------------------------------------------------------------------

$firestoreHost = '127.0.0.1:8080'
$docUri = "http://$firestoreHost/v1/projects/$projectId/databases/(default)/documents/users/$localId" +
          "?updateMask.fieldPaths=isApproved&updateMask.fieldPaths=accessDisposition"

$patch = @{
  fields = @{
    isApproved        = @{ booleanValue = $true }
    accessDisposition = @{ stringValue = 'approved' }
  }
} | ConvertTo-Json -Depth 6

# Only ever approve a profile the app has already created. Writing this
# document before first sign-in would create a malformed record holding just
# these two fields, and the app's own create would then collide with it and be
# refused by the Rules. Approval is a second step, after first sign-in.
$profileUri = "http://$firestoreHost/v1/projects/$projectId/databases/(default)/documents/users/$localId"
$profileExists = $true
try {
  Invoke-RestMethod -Method Get -Headers $headers -Uri $profileUri | Out-Null
} catch {
  $profileExists = $false
}

if (-not $profileExists) {
  Write-Host ""
  Write-Host "No profile yet for $email." -ForegroundColor Yellow
  Write-Host "Sign in once in the app to create the pending profile, then run this script again to approve it." -ForegroundColor Yellow
} else {
  Invoke-RestMethod -Method Patch -Headers $headers -Uri $docUri -Body $patch | Out-Null
  Write-Host "Approved $email (isApproved=true, accessDisposition=approved)" -ForegroundColor Green
}
