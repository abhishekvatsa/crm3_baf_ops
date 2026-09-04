# Raise Issue draft and Back review

Date: 2026-09-04. Scope: uncommitted client changes on
`codex/governed-charge-abnormality-form`. No APK construction, installation,
production write, deployment or push was performed for this fix.

## Findings and corrections

- Tapping the selected quality answer previously allowed an empty selection and
  cleared its classification and note. Initial selection remains mandatory, but
  an answered question can no longer be deselected accidentally. Changing the
  answer retains the draft details; a negative answer still excludes them from
  the submitted quality intent.
- Choosing the asset class after the quality classification erased that
  classification, even when it remained applicable. Valid choices now survive.
  Unavailable or inapplicable classifications remain blocked, with an explanation;
  notes are retained and a returning valid classification is restored.
- Selecting the same asset/class/component unnecessarily reset frequent-issue
  choices. Identity-preserving selections now retain them.
- The form had no route-level draft protection, and its default app-bar Back
  bypassed keyboard-first handling. Form-level and app-bar Back now dismiss an
  active editor/keyboard first, then require confirmation before discarding a
  populated issue. Leaving while submission is active is blocked.
- Quality validation also checks retained state rather than depending only on
  mounted FormFields in the scrolling list.
- The critical-issue checkbox now paints on Material, fixing a background/ink
  assertion exposed by rendering the full form. The frequent-issue picker checks
  that its context still exists before delivering a delayed selection.

## Verification

73 targeted Flutter tests passed, including 13 new actual-form tests, existing
keyboard/predictive Back tests, command payloads, input validation, governed asset
selection, async lifecycle safety, architecture boundaries and operational UI
contracts. Final log:
`output/quality-abnormality-review-2026-09-04/maintenance-draft-verified.log`.

Keyboard tests cover zero and nonzero reported keyboard insets, the app-bar
arrow, cancellation/discard, and system/predictive Back with the form inside the
actual app navigation shell. These are automated local checks, not physical-phone
acceptance. Draft retention here does not promise survival after process death.

This scoped fix does not close the separate backend/release findings in
`QUALITY_ABNORMALITY_SELF_REVIEW_2026-09-04.md`.
