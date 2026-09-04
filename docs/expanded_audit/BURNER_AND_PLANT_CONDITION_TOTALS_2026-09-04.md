# Burner and Plant Condition Totals

## Delivered Locally

- Furnace Condition Audit, reached from Burner Reliability, shows marked-position totals on Burner blocks, Draft seal, UV melted, UV missing and UV hung tabs. Lifecycle tabs show their loaded retained-event counts.
- Condition totals opens a combined summary with finding counts and distinct affected-furnace counts. Copy exports that summary with capture time and an explicit draft label when unsaved selections are included.
- Draft seal counts both red-hot and hot-air findings; the summary separates these. Two findings on one furnace are not presented as two affected furnaces.
- Totals derive from the existing displayed condition projection and current draft, scoped to the screen's active registered Furnaces 1-26. They are not date-filtered historical occurrence counts or a second persisted source of truth.
- No-prior-evidence coverage is shown. Unmarked positions are not certified healthy. Unsaved ticks do not become shared records merely because they appear in totals.
- Plant Condition lists the governed class and asset number once, rather than appending a display name that may repeat a zero-padded number or retain a copied name. No registry records were edited or removed.
- Down, Unfit and Stuck-up counts appear between each class name and its right-aligned registered count when the measured text fits; otherwise the counts wrap below. Existing independent/overlapping condition semantics are unchanged.
- Enlarged text uses fewer condition-tile columns without truncating labels. The audit matrix retains visible checkbox space and taller rows at large text sizes.

## Verification

The targeted suite passed 85 tests, covering matrix tick/untick, mutually exclusive UV categories, draft-seal totals, copying, draft labelling, newer evidence, retained unsaved selections, source failure, reporting, lifecycle projections, plant conditions, and A02/A03 boundaries. The 47-base case is tested at phone and wide sizes. No architecture limits were increased.

Logs are in `output/quality-abnormality-review-2026-09-04/condition-totals-regression.log` and `condition-totals-analyze.log`.

Rendered screenshots are in `output/condition-totals-review-2026-09-04/`. Audit matrix and summary sizes are 320x720 at 2x text, 390x844 at 1x, and 900x800 at 1x. Plant summary sizes are 320x900 at 2x, 390x900 at 1x, and 800x900 at 1x. Repository fonts and Material icons are loaded in the fixtures.

These are synthetic widget interactions and renderings, not phone acceptance or production readback. The global alarm overlay is not mounted. This pass does not certify all other screens. Test/layout iterations caught and corrected compile, dialog-intrinsic-sizing, source-size and test-fixture issues before acceptance.

## Delivery Boundary

No APK construction, push, deployment, device installation, production writes or data deletion. No new PDF export was added; the combined condition summary has a copy facility. Existing persisted condition, maintenance and sync contracts remain unchanged by this pass.
