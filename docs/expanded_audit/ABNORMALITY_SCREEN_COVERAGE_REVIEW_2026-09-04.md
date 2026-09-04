# Abnormality Screen Coverage Review

## Why This Was Missed

Earlier functional and authority checks were not sufficient visual acceptance. The abnormality master and charge-specific page have separate header implementations. A correction to one did not automatically correct the other.

The current local charge header already had responsive width handling, but the header was still a fixed child above an independently scrolling list. Existing tests checked permissions, the presence of actions and access to the RA form; they did not assert that the summary scrolled away, that records retained sufficient text width, or that the page remained compact at large text sizes. A legal Flutter layout can still be unpleasant or impractical without throwing an overflow exception.

The earlier broad reassurance about screens was therefore not justified by the evidence. A local fix also does not prove that an installed APK contains it.

## Corrected in This Pass

- Charge summary, command and records now share one scroll view. The header scrolls away with the records.
- Log Abnormality is an ordinary in-flow command, rather than a floating control covering evidence. It remains available while records load or fail to load, subject to existing authority.
- Edit/delete controls are below record evidence, instead of permanently consuming a side column of text width.
- Repeated instructional header copy is removed from the normal charge-opening route. Charge identity and counts remain; callers can still supply a meaningful optional subtitle.
- Bottom system safe area is respected. No server command, permission, lifecycle transition or database schema was changed for this layout correction.

## Verified Coverage

| Surface | Evidence in this pass | Boundary |
| --- | --- | --- |
| Charge Abnormalities | Four rendered and visually inspected sizes, actual scrolling assertion, available text width, compact header height, populated records, loading/error action visibility, normal navigation back button | Synthetic local records; not an installed-phone test |
| Abnormalities Home | New populated layout/scroll test at 320 logical pixels and 2x text | Not every action or data state |
| Abnormality Types | New populated layout/scroll test at 320 pixels and 2x text; existing responsive/action tests rerun | Not every possible master-data entry |
| Abnormality Reports | New populated layout/scroll test at 320 pixels and 2x text | Not every filter combination or report size |
| Asset hierarchy / administration mobile surfaces | Existing `admin_mobile_usability_test.dart` rerun | Existing cases only; no new whole-module visual certification |
| Module composer | Existing responsive widget test rerun | Existing cases only |
| Shared theme and contrast | Existing design-system and contrast tests rerun | Does not establish correct composition of every screen |
| Other business screens | Existing authority and operational UI tests rerun | Functional/source checks are not complete visual inspection |

Charge screenshot configurations: 320x640 at 1x text, 390x844 at 1.6x, 320x720 at 2x, and 800x720 at 1x. Rendering used repository Roboto fonts and Material icons, with test-theme font names supplied where Flutter otherwise uses its block-shaped test font. These are widget renderings, not screenshots from a pilot phone. System insets are simulated; the global draggable alarm overlay is not mounted in this fixture.

## Test Results

- Original scrolling defect reproduced in four viewport cases before the layout change.
- New abnormality layout suite: 8 passed.
- Existing mobile, theme, authority, operational UI and A02/A03 regression suite: 74 passed.
- Flutter analyzer: no issues found.
- Diff whitespace check: passed.

Logs: `output/quality-abnormality-review-2026-09-04/charge-layout-repro.log`, `charge-layout-fixed.log`, `charge-layout-regression.log`, `charge-layout-analyze.log`.

Rendered evidence: `output/charge-screen-review-2026-09-04/charge-320-1.0.png`, `charge-390-1.6.png`, `charge-320-2.0.png`, `charge-800-1.0.png`.

The test harness itself was corrected during this pass: an initial loading-sliver composition required unsupported intrinsic measurements and was replaced before acceptance; asynchronous screenshot capture and real-font assertions were also corrected. The final passing result is not a claim that the first edit was sufficient.

## Remaining Coverage

Source discovery found 57 files under `lib/features` named `*_screen.dart`: abnormalities 4, administration 4, assets 5, audit 1, authentication 2, critical alarm 1, directives 2, inspections 1, maintenance issues 4, maintenance workflow 6, morning review 1, operational events 3, planned maintenance 18, quality 1, and reports 4.

This is a filename inventory, not a complete route inventory: dialogs, boards, forms, nested tabs and differently named pages add further surfaces. It does not establish that the other 53 files are visually correct.

Remaining visual acceptance should use a route/state register, with each entry explicitly marked source-reviewed, layout-tested, screenshot-inspected or device-verified. Include populated and empty states, errors, long evidence text, role-specific controls, keyboard opening/back behavior, system navigation insets, global alarm-overlay placement, small screens and enlarged text. Record the exact candidate build when doing device acceptance.

No build, push, deployment, phone change or production-data change was performed for this pass.
