# Maintenance Action Time Rejection

## Finding

The user's 20:42 screenshot shows the server rejecting issue resolution with
`maintenance-ticket-action-time-invalid`: an action time falls outside the work
period. The screenshot does not expose the ticket ID, selected closure time,
or stored action payload, so it cannot establish the only cause for that exact
record. A deterministic defect capable of producing this rejection was found
and reproduced in the shared action serialization and server interpretation.

`ResolveForm` passes its selected end time to `ActionBottomSheet`. The resolution
command sends `endDate` in UTC, but `ComponentAction.toMap()` previously wrote
local `createdAt` and `updatedAt` without a timezone. An action performed at
21:15 IST could therefore arrive as `21:15`, while the closure instant correctly
arrived as `15:45Z`. A UTC server interpreted the action as 5.5 hours later.

The existing server time check is appropriate; removing or widening it would
conceal the serialization error. This is not evidence of Isar corruption or
of a required minimum length for the remarks in the screenshot.

## Repair

- New component actions serialize both timestamp fields with an explicit UTC
  suffix. This shared model covers issue work, planned-job work, module work,
  and burner attendance/replacement evidence.
- Decoded evidence preserves its original timestamp strings, including timezone
  suffix and fractional precision. Appending new work must not rewrite a saved
  history prefix or invent historical times.
- Maintenance's persisted-time reader now uses the existing
  `persistedInstantMillis` compatibility policy. That policy treats suffix-free
  legacy pilot timestamps as Indian plant time, while respecting explicit UTC
  or other offsets. No offset is inferred from whichever interpretation makes
  a request pass.
- Burner-block and UV lifecycle readers use the same policy. Correcting only
  the issue validator would leave their independent closure-time checks broken.
- Shared action cards and planned-job detail views display the resulting instant
  in device-local time. Maintenance dossiers and PDF serializers already convert
  their action timestamps to local time.
- The original history, actor rules, governed target checks, append-only guard,
  work-period bounds, and five-minute closure tolerance remain in force.

The legacy interpretation applies to the existing Indian-plant pilot contract.
A timezone-less historical record originally authored in another timezone is
ambiguous and is not automatically repaired by this change. No stored business
records were rewritten, deleted, or corrected during this investigation.

## Verification

A shared Dart/Node fixture covers IST, UTC, negative offsets, microsecond
precision, and a local calendar day different from the UTC day.

- Full Flutter suite: 1,841 passed, one conditional production-envelope test
  skipped. This is not physical-device or production proof.
- Final focused UI/serialization suite: 27 passed, including action times in
  both execution and module dossiers and local-time action-card rendering.
- Full Functions host suite under UTC: 924 passed. Its 97 emulator-only tests
  were separately executed against `demo-crm3-action-time`; all 97 passed.
- Five targeted backend suites under UTC and Asia/Kolkata: 219 passed in each
  timezone. Coverage includes issue resolution/replay, legacy planned completion,
  workflow finalization, and burner-block/UV lifecycle projections for all three
  source routes.
- Before-work and after-closure actions remain rejected, including legacy Indian
  timestamp forms. Rejection leaves the ticket unchanged.
- Existing action timestamp text survives an append and idempotent retry.
- Analyzer: no issues. Canonical audit: 149 passed. Four current-candidate source
  hashes were refreshed; original canonical hashes and release receipts remain
  unchanged.

The initial local backend run accepted a timezone-less Indian action because
the Windows host itself uses Indian time. Running explicitly under UTC exposed
the production-like difference. Future evidence for these paths must include
UTC-server execution, not only the developer machine's default timezone.

Logs are in `output/build24-release-preflight/action-time-*`.

## Release Status

This fix is local source work following `dee9d8c`. It has not been pushed,
deployed, or included in a new APK. Existing installed apps do not change merely
because these tests passed. A governed backend deployment is required for the
legacy-reader repair, and the next app build is required for new UTC writes and
display fixes.

The separate PR #345 older-client abnormality asset-count review and staged
rollout decision remain open. This screenshot was not treated as approval to
deploy, relax Firestore validation, or distribute an APK.
