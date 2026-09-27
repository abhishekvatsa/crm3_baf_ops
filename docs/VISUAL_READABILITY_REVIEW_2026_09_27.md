# Visual readability review — 27 September 2026

This is a restrained visual pass over the shared operational interface, following
the user's request to consider aesthetics alongside the business-function work.
Existing uncommitted business repairs and the 15-row list policy are preserved.
This does not claim that every screen or device configuration was exhaustively
reviewed.

## Implemented refinements

- Shared hint/secondary reading colour now provides at least 4.5:1 contrast
  against the tested light operational surfaces. Repeated dashboard cards use
  a softer shadow; routed-screen subtitles are slightly larger.
- Home's title and sync action stack when space or enlarged text requires it,
  rather than shrinking the heading. Management-pulse cards use responsive
  columns and readable, wrapping detail text.
- Issues use naturally wrapping action buttons and give status badges and
  metadata their own space. Important identifiers no longer compete with long
  badges in one narrow row.
- Directives put the list/search first and keep saved-command recovery available
  in a labelled expandable section. Heading/status/filter controls adapt to
  narrow phones and enlarged text.
- Quality filters wrap when necessary, long card headings have separate status
  space, and enlarged tab labels remain reachable. Abnormality cards lead with
  the observation; the form's observation-kind choices stack on small screens.
- Fleet and burner report content is centred within a readable width on larger
  displays. Burner metrics grow to fit labels rather than clipping at a fixed
  height. Existing horizontally scrollable report content remains available.
- Asset administration shows an explicit selected/unselected Retired filter;
  compact search/filter rows and Definition/Installed tabs handle enlarged text.
- The movable alarm shortcut is quieter only when a server-verified feed is
  empty, red when active alarms exist, and amber when live status is unverified.
  Its accessibility description states that condition. Existing access, dragging,
  modal handling, notification posting and reconciliation behavior are retained.

The app's existing brand, colour meanings, roles and business decisions remain
unchanged. Planned-work technical provenance grouping was identified as a later
design opportunity; this pass does not restructure the job's evidence or workflow.

## Validation

Confirmed focused host checks:

| Slice | Result | Log |
| --- | --- | --- |
| Issues and Directives layouts, paging and adjacent authority/usability | 31 passed | `.dart_tool/maintenance-directive-visual-tests.log` |
| Quality/abnormality layouts, paging, live menus and authority | 27 passed | `output/dev-visual-review-20260927/quality-visual-tests.log` |
| Shared header, contrast, card material and critical-alarm behavior | 25 passed | `output/dev-visual-review-20260927/shared-tests.log` |
| Home/report/admin responsive layouts and adjacent business/identity behavior | 73 passed | `.dart_tool/home-report-visual-tests.log` |
| Final alarm suite, including retained-empty refresh regression | 19 passed | `output/dev-visual-review-20260927/alarm-refresh-final-tests.log` |

The new layout checks use 320px phones and text scaling up to 1.8x, retaining
usable actions and visible labels. Relevant source/test analyzers are clean.
An initial shared test caught an incompatible tooltip in the global alarm host;
the tooltip was removed, and the complete scoped batch then passed. Failed and
final logs are retained. This is not a full release gate or production rollout.
An independent review identified the retained-data refresh case: a prior empty
snapshot must not be announced as currently verified while its provider is loading
or failed. The display now checks that condition explicitly. The regression
invalidates the real provider, verifies the retained value/loading combination,
and checks both the unverified description and the subsequent live recovery.

Large-text checks also exposed existing clipping in the admin tabs/filter row
and the burner card's identity/status row. Those layout defects were repaired;
the final affected suites passed with the original record values/actions.

## Visual inspection and delivery

The initial Home screenshot is saved at
`output/dev-visual-review-20260927/home-before.png`. The read-only DEV screen tour
in `integration_test/dev_visual_review_test.dart` passed, including teardown,
in 45 seconds of test execution. It verified `demo-crm3-baf-ops` before navigation.
Evidence: `output/dev-visual-review-20260927/phone-visual-01.log`.

Twelve screenshots were captured in the separate DEV app sandbox, copied to
`output/dev-visual-review-20260927/`, and visually inspected: Home, Home pulse,
Issues, Directives, Quality, abnormality browsing, Plant condition, Burner
reliability, Operations reports, Raise issue, Work and More. The tour did not
submit any business form. Existing synthetic records and incomplete-evidence
notices remain visible. Admin large-text behavior was verified in host widget
tests, not by a separate admin phone journey.

Visual inspection prompted a final theme correction: selected filters had white
checkmarks on pale backgrounds, so checkmarks now use the darker teal. The tour
screenshots precede that small colour correction; the restored ordinary DEV
app includes it. Android's FCM registration error is expected for this local
emulator profile and is not evidence of production push-notification readiness.
The ordinary DEV app was restored successfully and confirmed foregrounded.
An additional navigation-only screenshot, `issues-final-normal-dev.png`, was
inspected to verify the final dark checkmark on the selected Open filter.
The phone is left on the normal DEV Issues screen. Restoration log:
`output/dev-visual-review-20260927/restore-normal-dev.log`.

Two design follow-ups remain explicit: planned-job details still expose a dense
provenance section, and the existing movable alarm shortcut can overlap content
at its saved position. Its global access/drag behavior was retained in this pass;
a dedicated unobstructive placement requires a separate navigation-layout change.

All presentation changes are shared application code. Production users receive
them through a reviewed application update; this task does not deploy a backend,
alter production records, commit, push or distribute a production build.
