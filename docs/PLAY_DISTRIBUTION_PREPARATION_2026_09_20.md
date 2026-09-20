# Google Play preparation — 20 September 2026

Preparation against local HEAD `b35df6bd` plus the evolving working tree. Business-domain corrections remain in progress. This document supplies draft materials and dated observations, not a release approval or proof that current source is distributable. Continue through the existing [release plan](BUILD28_REMEDIATED_SOURCE_RELEASE_PLAN_2026_09_12.md); do not replace its custody, compatibility or release records.

## Live Console observations

Read through the authenticated Console on 20 September 2026. No release, form, key or protection setting was changed.

| Area | Observed state | Implication |
| --- | --- | --- |
| App | CRM-III BAF Ops, `in.co.sail.bsl.crm3.bafops` | Existing entry; do not create a second package. |
| Setup | 0 of 11 tasks complete | Store listing and app-content setup still needed. |
| Internal test | 0 of 3 tasks complete | Testers and first release not completed. |
| Closed test | Zero testers; Console requires at least 12 continuously opted in for 14 days | This elapsed-time requirement has not started; internal testing alone does not satisfy it. |
| Production access | Apply button disabled | Verification of the developer account did not itself unlock production. |
| Publishing overview | No unpublished changes | No pending publication shown on this page. |
| Upload certificate | Shown only after first bundle upload | No upload certificate available on the signing page. |
| App signing | In-use quantum-ready key section, previous key dated 9 September, 0% install base | Inspect the complete certificate set before deciding signing changes. |
| App Links JSON | SHA-256 `2F19F489326F92369C98203E103799419AEC7AE112CA92A81B96E361493DC396` | Does not match the independently checked legacy APK signer below. This is not an inventory of every hybrid signing certificate. |
| Protected with Play | Automatic protection 1/1 active; Play Integrity API not integrated | Assess sideload coexistence before rollout; this page does not establish Firebase App Check settings. |

Source pages: [dashboard](https://play.google.com/console/u/0/developers/5163879421610181326/app/4975375541039311970/app-dashboard), [signing](https://play.google.com/console/u/0/developers/5163879421610181326/app/4975375541039311970/keymanagement), [protection](https://play.google.com/console/u/0/developers/5163879421610181326/app/4975375541039311970/protect-with-play). These observations will age; refresh them before execution. Google's [testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465) explain the closed-test production application process; elapsed time alone is not approval.

## Signing continuity: first release dependency

**Resolved configuration mismatch — 20 September 2026:** the owner authorized transfer of the exact verified encrypted ZIP. It was uploaded to this app's original-key import form, saved, and the operation completed. The app-signing public certificate downloaded from Play afterward matches the existing APK signer in both SHA-256 and SHA-1. The Console's App Links snippet and upload certificate now also show the original signer. See the [non-secret import/readback receipt](../release/evidence/play-original-signing-key-import-20260920.json). The observations and preparation history below predate completion. No APK/AAB or app release was uploaded/published. A Play-delivered retained-data update remains to be tested on the eventual candidate.

Android SDK 36.0.0 `apksigner verify --print-certs` successfully verified the owner's existing Downloads APK `CRM_III_BAF_Ops_Build_25_1.0.0-rc.15+25_PRODUCTION_SIGNED.apk` on 20 September. Its certificate is:

- SHA-256: `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`
- SHA-1: `41C2B828C71683A50EC346D19E1D44048758438D`

This verifies that file, not every installed user's APK. Measure representative installed versions and signers before migration. No private keystore or password was read for this check.

Before upload, compare the complete Play certificate set and signing lineage with the installed fleet. If continuity is absent, use the Console's supported original-key import/setup path before rollout; do not accept a new unrelated key as an automatic replacement. Distinguish the upload certificate from the APK signing certificates. Google's [signing instructions](https://support.google.com/googleplay/android-developer/answer/9842756) describe encrypted original-key transfer and the certificates to register with API providers. Account for all applicable Android-version signing variants, including hybrid signing; the App Links snippet alone is insufficient.

After configuration, obtain APKs delivered by the actual internal testing track and verify signatures and an in-place update from a representative sideloaded installation. Do not use Internal App Sharing as the sole signing-continuity proof. Verify Google sign-in, Firebase access and notification installation registration for the Play-delivered build. Preserve supported sideloaded clients' access during the transition. Key transfer and access changes require a concrete reviewed action; no private key belongs in this preparation document or repository.

### Original-key import preparation — 20 September follow-up

The owner requested resolution of the signing mismatch. The live Console's Change key flow offers **Export and upload a key from Java keystore**. The selection form was opened; Save remains unavailable pending an encrypted ZIP. No signing change was saved. The warning concerns any existing Play internal/closed installations; the earlier observed Play install base was zero. Preserve actual sideloaded installations through the original signer and confirm the final track update separately.

The existing keystore was located in the owner's named signing-custody directory. Its SHA-256 is `4D5727DB14A82FB25A16DC9B063B94462E66FD36D006B97E888465E2DD730471`, exactly matching the approved custody record. Alias: `crm3-baf-ops-release`. The record explicitly says the password is not recorded; the release-signing environment variables are absent from this session. Do not retrieve secrets by exposing CI secrets in logs or artifacts.

Google's PEPK tool and this Console form's encryption public key were downloaded through its buttons. Observed SHA-256 values:

- `pepk.jar`: `AACCC0774B240AA5304BDAD2A49865E92F229CA73209ECB6EAAFE75DC858E24E`
- `encryption_public_key.pem`: `BB2FE629411F0291BA64A35B43C4135EAA3952548C760C84003FA73DFFDAD1C0`

[Export-ExistingPlaySigningKey.ps1](../tools/release/Export-ExistingPlaySigningKey.ps1) pins these inputs and the approved keystore, asks Google PEPK to prompt for passwords locally, keeps its output outside the repository, and checks the exported public certificate against the existing APK signer before writing a non-secret verification receipt. Syntax was checked, Google's tool help was inspected, and expected ZIP entry names were checked against the downloaded tool. The export itself is not yet verified: an interactive local console was opened for the owner to enter the existing password. No password was requested in chat.

Original planned sequence: complete local export; independently check its receipt, ZIP hash and public certificate; authorize the concrete encrypted-key transfer to this Play app; upload and save the existing-key selection; read back Play signing fingerprints; then verify the Play-delivered update on a stable release candidate. The export, authorization, import and certificate-readback steps are now complete as recorded above; the delivered-update test remains.

Local prompt follow-up: agent-launched helper windows were not visible to the owner. A password was mistakenly entered at a normal shell prompt. The owner subsequently reported that the locally masked cleanup dialog removed matching history lines; this is not an assertion that transcripts/security logs were examined or erased. Continue export only through a user-launched foreground PowerShell process with `-File` and the helper's `-Interactive` option, without `-NoExit`. The helper now pauses with non-echoed input on success/error and then exits; it does not return to `PS>`. Its pinned-input validation passed in Windows PowerShell. No encrypted export was present at the latest check.

Paste-entry follow-up: the owner has the original password available and requested copy/paste support. Use `-PastePasswords -Interactive` with the same helper. `PlaySigningPasswordDialog.java` provides masked Ctrl+V boxes and an optional separate key password. It calls the pinned PEPK public API with character arrays in the same local JVM; passwords are not subprocess arguments, shell commands or files. Fields/buffers are cleared after use; this does not promise erasure of all copies inside Swing or cryptographic libraries. No personal-information file on removable media was read by the assistant. Synthetic tests passed for PKCS12 export/certificate, wrong store/key rejection, existing-output preservation, distinct Unicode/space-containing passwords and buffer cleanup. This testing used only a disposable key. Real export and Play configuration remain pending.

## Store listing draft

These are proposed copy fields, not published claims. Recheck them against the final candidate and organizational branding authority.

**App name:** CRM-III BAF Ops

**Short description:** Maintenance, equipment history and team workflows for approved BAF personnel.

**Full description:**

CRM-III BAF Ops helps approved personnel record and coordinate maintenance work for batch annealing operations.

Use the app to follow equipment and component history, record maintenance observations, track assigned work, and coordinate reviews and responses between participating teams. Equipment records include supported Inner Cover and burner component lifecycle activities. Authorized users can view operational alarms and maintain the associated response records.

Access depends on your approved account and assigned role. Sign in with Google and follow your organization's access-approval process. Available actions depend on your responsibilities and the current status of the work.

Some records and pending submissions are retained on the device to support recovery. Actions requiring server validation need an internet connection. Notification delivery depends on connectivity, device settings and notification permission.

This app is intended for authorized workplace use. Follow your organization's operating and emergency procedures.

**Proposed category:** Business. Confirm publisher identity and branding authority before submission. Do not infer the Government apps declaration from either this category or the plant's ownership.

**Asset preparation:** Use the approved app icon and genuine screenshots of the final candidate with synthetic, explicitly approved demonstration records. Suggested sequence: maintenance overview; equipment/component history; cross-team request; alarm and response screen. Avoid real employee contacts, operational incident details and unresolved submission identifiers. Capture actual screens once the business review stabilizes; do not fabricate UI screenshots. Recheck current [Play asset specifications](https://support.google.com/googleplay/android-developer/answer/9866151) when exporting. Icon, feature graphic and screenshots remain to be supplied; existing SAIL/Manmithas assets do not establish publication rights.

## App-content preparation

The 11 Console tasks observed are privacy policy, sign-in details, ads, content rating, target audience, Data safety, Government apps, financial features, health, app category/contact details and store listing. Draft positioning is workplace maintenance, not a consumer financial or health product. Complete the actual questionnaires against the final app; neither this positioning nor a dependency search is a submitted declaration.

### Data map for the disclosure reviewer

The following facts were checked in source. They are inputs for classification, not a ready-to-submit Data safety form. Use the final dependency graph and artifact configuration, not CI package-proof builds with collection disabled.

| Data / behavior | Source evidence | Purpose and disclosure work |
| --- | --- | --- |
| Google/Firebase UID, name, email and optional profile image URL; new pending user profile | `lib/features/auth/services/auth_service.dart`, `signInWithGoogle`, `ensureUserDocument`, `_pendingUserPayload` | Authentication, account creation and access management. Classify personal information/user IDs; assess profile image handling explicitly. |
| Roles, approval and associated user profile | `lib/features/auth/data/user_model.dart`; auth provider | Role-based operation and administration. Identify the organization controlling access. |
| Equipment/workflow submissions, free text, actor attribution, histories and alarm records | Maintenance workflow and critical-alarm features; backend handlers | Workplace operations and accountability. Classify the actual personal/user-generated fields, including any contact fields; do not assume every business record is non-personal. |
| Installation UUID, FCM token, platform and update time under user notification installations | `lib/features/auth/services/notification_installation_registry.dart` | Notification routing and installation/account binding; assess device or other identifiers. |
| Crash reports, pseudonymous user identifier, role/approval custom keys and diagnostic events | `lib/core/services/app_logger.dart`, `lib/main.dart` | Reliability diagnostics. Pseudonymization does not automatically make data anonymous. Include SDK-collected diagnostics and installation identifiers. |
| Local database, cached records and durable pending command envelopes | Isar and durable-submission services | On-device continuity/recovery; distinguish local-only storage from data later transmitted to Firebase. Account removal must address local pending work deliberately. |

Firebase documents automatic and optional SDK collection in its [Android disclosure guide](https://firebase.google.com/docs/android/play-data-disclosure). Review the exact Authentication, Firestore, Functions, Messaging, App Check, Crashlytics, Installations and Sessions dependencies/configuration. The Dart dependency list has no `firebase_analytics` package; the manifest's analytics flag alone proves neither inclusion nor absence of a transitive analytics SDK. Verify the final graph. Do not declare no collection on the strength of sanitized crash logs.

Under [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469), service-provider handling may be treated differently from sharing. Confirm actual recipients and uses; do not automatically label all Firebase processing as third-party sharing or automatically claim no sharing. Internal-only distribution has a form exception, but closed/open/production distribution requires the relevant disclosures.

### Privacy policy and account deletion

No privacy-policy or account-deletion implementation was established by the focused source search. That search is not an exhaustive legal assessment. Google sign-in creates a Firebase app account and pending profile; do not answer that accounts cannot be created simply because an administrator approves workplace access later.

Prepare a public HTTPS policy naming the publisher/app, data categories and purposes above, recipients/processors, security approach, contact route and actual retention/deletion handling. Owner inputs still needed: responsible organization, monitored support/privacy address, policy hosting URL, retention rules, and who handles requests. Do not invent a retention period or promise implemented deletion that does not exist.

Assess an in-app deletion-request route and external request page before closed testing under Google's [account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111). Workplace usage alone does not establish the permanently-private or enterprise-device-management exemption. Any retained operational/audit evidence needs an explicit justified policy and user explanation. Avoid silently deleting shared maintenance history or abandoning uncertain saved commands. This needs a scoped implementation decision after the business-domain work, not a guessed destructive routine during store preparation.

### Reviewer access draft

The app uses Google sign-in followed by profile approval and role checks. Provide reviewers a working, approved access arrangement that remains usable during review, documented navigation and representative features for each necessary role. The current draft is incomplete until reviewer access is exercised end to end.

Prepare a dedicated demonstration environment/data set or a deliberately restricted approved review arrangement; preserve authentication and role controls. Do not place production credentials in the listing, this file or Git. Do not invent a username/password login the app does not implement. Resolve Google's actual reviewer sign-in requirements with the available Google sign-in flow before submitting access instructions.

Suggested instructions to complete later: sign in using the supplied review arrangement; verify the approved profile appears; open Maintenance to view the prepared demonstration job; open Equipment for component history; open Critical Alarms for the prepared response record. Supply precise final labels, role access and test records after candidate validation.

## Artifact and rollout preparation

Source already configures package `in.co.sail.bsl.crm3.bafops`, compile/target SDK 36, NDK `28.2.13676358`, production signing through the governed workflow and a release AAB build. The source version remains `1.0.0-rc.18+28`; this observation is not a reservation or permission to reuse that version. Allocate the next unused candidate through current release controls.

The production script and dispatch workflow now both cap versionCode at **2,100,000,000**, matching [Android's Play limit](https://developer.android.com/studio/publish/versioning). The CI package-proof script already used that cap. Debug verification artifact limits were not changed.

For the eventual candidate, retain exact source, backend capability/readback, AAB and APK hashes, signing certificates, consumed versionCode, supported-client matrix and recovery evidence in the existing release records. Verify the final merged manifest and permissions, release Firebase configuration, SDK dependency graph and signing identity. Re-evaluate if domain corrections change backend or persisted data.

NDK r28 is a useful starting point for [16 KB page-size support](https://developer.android.com/guide/practices/page-sizes), but does not prove prebuilt Isar/Flutter/plugin libraries or packaged APK alignment. Check every shipped native library, ZIP alignment and cold start on a 16 KB environment using the exact candidate. Preserve the current persisted-schema forward-repair contract; earlier dated schema observations in the parent release plan are historical.

Execution order once a candidate is stable:

1. Resolve signing continuity and API certificate registration; finalize required publisher/contact/privacy/access materials.
2. Build through the existing governed pipeline; verify the exact artifact and backend compatibility.
3. Release to the internal testing track. Test a Play-delivered update over a representative existing installation without uninstalling or clearing data. Check retained records, original-account pending commands/receipts, sign-in, recovery, notifications and normal business actions. Measure device connection and installed state then; this preparation did not establish current phone state.
4. Complete setup and start the closed test with at least 12 genuinely participating testers. Record actual opt-in dates, continuing participation and feedback. Do not backdate the 14-day period or count internal testers as closed testers automatically.
5. Address findings, apply for production access and use a controlled initial rollout after acceptance. Keep a higher-version compatible repair path and operator support instructions available.

Firebase remains the backend and may host a reviewed privacy/deletion page. Firebase Hosting of an APK alone does not complete the Play update route. Existing users' Play update eligibility depends on correct package/signing, higher version, account/track availability and device compatibility; prove it on the intended track before telling operators it works.

## Preparation validation

- Existing Build 25 APK signature verification passed; public certificate recorded above.
- Release workflow dispatch-input and action-reference suites: 7 tests passed.
- PowerShell syntax passed. Isolated binding of the production script's actual versionCode parameter accepted 1 and 2,100,000,000 and rejected 0 and 2,100,000,001 without executing the build script. Modified tracked files passed diff validation.
- No business source changed by this preparation. No build number reserved, APK/AAB built, private key transferred, tester invited, declaration submitted, Firebase deployment made or Play release published.
