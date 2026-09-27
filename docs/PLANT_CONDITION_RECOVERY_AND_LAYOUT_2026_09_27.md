# Plant condition recovery and layout — 2026-09-27

This note records source changes and validation. It does not certify a new production client release.

## Diagnosis and recovery

A missing equipment workflow projection is missing evidence, not proof that an asset is unavailable or that availability is zero. Registered assets must remain in the physical inventory while their condition is unverified. The availability percentage remains unavailable until the required evidence is complete.

The permanent client route is **Equipment availability → Review missing equipment states**. An approved Admin or SI can review a registered physical identity and request reconciliation through the existing workflow command. It requires complete, current server evidence; cached, rejected or ambiguous evidence cannot establish absence. Existing projections are excluded from the missing-state list. The confirmation is rechecked against the actor, authority revision and registry evidence before submission. An uncertain retry retains the same immutable command.

Reconciliation derives workflow state from current records. It does not clear independent Down, Unfit or stuck-up restrictions, and it does not invent physical deployment or transition dates.

A separately reviewed repair of missing production-derived projections has completed with canonical readback and protected source evidence unchanged. Its create-only transaction also records an explicit operational notification-suppression marker; suppression was verified without claiming that notifications were delivered. The private repair guards reject existing outputs, changed source evidence and inconsistent replays. No backend deployment was required or performed for this repair: the reconciliation business logic was already deployed and unchanged.

Relevant source:

- [Missing-projection eligibility](../lib/features/maintenance_workflow/domain/missing_equipment_projection.dart)
- [Review and retry screen](../lib/features/maintenance_workflow/presentation/screens/missing_equipment_projection_screen.dart)
- [Equipment availability entry point](../lib/features/maintenance_workflow/presentation/screens/equipment_status_board.dart)

## Plant condition presentation

The six Plant condition tiles use three columns and two rows at normal phone widths, including logical widths of 360 and 393. Each tile places the number above its label. Larger text or narrower space reduces the column count rather than clipping the content. Existing metric taps and the separate Down and Unfit counts are preserved.

When evidence is incomplete, the headline states the recorded asset count and distinguishes verified availability from unverified condition. It no longer presents a bare available/total fraction that could imply a complete availability assessment.

The current source already includes the earlier physical-inventory corrections: serial Inner Cover profiles participate in inventory without counting numbered placeholders twice, known assets are retained when qualifying evidence is missing, and evidence problems on one asset do not contaminate unrelated assets. Those earlier source fixes are distinct from this projection repair and tile-layout change.

Relevant source: [Plant overview panel](../lib/features/assets/presentation/asset_condition_board.dart) and [responsive metric tiles](../lib/features/assets/presentation/asset_condition_board.filters.dart).

## Verified checks

| Scope | Result |
| --- | --- |
| Layout and counting widgets | 27 passed, including normal-width three-by-two geometry, larger-text fallback and truthful incomplete-state wording |
| Recovery and adjacent behavior | 45 unique checks passed, including authority/evidence changes during confirmation and immutable uncertain retry |
| Combined client scope above | 72 unique checks passed |
| Private operational repair guards | 24 synthetic checks passed, including create-only outputs, source drift, replay/readback integrity and notification suppression |
| Whole-client analyzer | Clean |
| Canonical governance audit | 153 passed |
| Physical phone, separate DEV app | In-place DEV update preserved the session; all six tiles were observed in three columns at exactly two row positions |

The recovery count includes the latest 20-check isolated rerun and its newly added retry regression; it is not an additional 20 checks on top of the earlier 44-check checkpoint.

Representative regressions are [plant overview layout](../test/plant_overview_panel_test.dart), [inventory counting widgets](../test/plant_inventory_counting_widget_test.dart), [missing projection recovery](../test/missing_equipment_projection_recovery_test.dart) and [registry rebinding](../test/equipment_registry_rebinding_test.dart).

## Release boundary

Repairing derived backend state does not update an installed application's inventory or layout implementation. Production Build 29 retains its older client behavior until a new production client is released. The compact layout has been inspected on the physical phone in DEV; production packaging, full candidate acceptance and Play distribution remain separate, incomplete steps.
