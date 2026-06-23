# 70I-B2 — Android Permanent Identity Migration and No-Loss Boundary

## Why this is a migration

Changing `com.example.crm3_baf_ops` to the permanent application ID creates a
new Android application sandbox. The new app cannot directly read the old
app's private Isar files, preferences or tokens. A clean source change can
therefore be technically correct while operationally stranding local-only
state.

## O-02 closure boundary

O-02 closes when the approved permanent Android/Firebase identity is present in
source and proven in the signed APK/AAB. It does **not** close operational
cutover. Device-by-device migration, reconciliation and retirement of the old
package remain O-10/70J.

## Required collection classification

Before branch preparation, run
`Generate_Android_Identity_Migration_Plan.ps1`. Every detected Isar collection
must be classified as exactly one of:

- fully rehydratable from Firebase;
- synchronised but requiring reconciliation;
- deliberately local-only and requiring archive;
- export/import required;
- diagnostic/rejection evidence requiring archive.

Each collection needs explicit pre-cutover evidence, post-cutover evidence,
reconciliation rule and retirement condition. Unclassified collections are a
hard stop.

## Cross-cutting procedures

The approved plan must address:

- FCM token replacement and coexistence of old/new registrations;
- authenticated-user continuity;
- old/new record-count and identity reconciliation;
- local drafts and rejected rows;
- rollback after the new app has already written remote state;
- accountable device-retirement authority.

These procedures may remain `PLANNED` during O-02 source preparation, but the
old app must not be retired and the new app must not be promoted to controlled
pilot until the named-device cutover evidence is complete.

## Device cutover minimum evidence

For every target device:

1. identify installed old package/version and user;
2. sync and inventory pending/dirty/rejected/local-only rows;
3. export or archive every collection requiring it;
4. install the new package without uninstalling or clearing the old package;
5. authenticate and rehydrate/import as approved;
6. reconcile counts, stable IDs, evidence hashes and rejection state;
7. prove one clean reconnect with no duplicate or evidence loss;
8. record new FCM token registration;
9. exercise rollback procedure where approved;
10. retire the old package only after accountable sign-off.

## Prohibitions

- Do not copy private sandbox files ad hoc.
- Do not mark dirty rows synced to make the queue appear clean.
- Do not delete rejection/audit evidence.
- Do not uninstall or clear the placeholder app before signed cutover approval.
- Do not call source identity closure a 70J field proof.
