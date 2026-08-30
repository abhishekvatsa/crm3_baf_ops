# Maintenance-Issue Plant-Condition Projection

## Purpose

This contract defines how an open maintenance issue contributes to the current
Plant Condition view without replacing the independent plant-condition control.

## Issue effects

- A standard issue defaults to `unfit`.
- The raiser may deliberately select `unavailable` instead.
- A furnace stuck-up case uses the specialized `stuckUp` projection and is not
  counted a second time as a generic issue contribution.
- Legacy records that predate the persisted effect remain neutral. Their status
  is not guessed during local migration.

## Visible provenance

Every issue-derived condition must carry a visible comment that names its
origin and explains the fault. For example:

`Unfit due to maintenance issue MT-104: Cooling-water leakage requires repair.`

If a closure exists only locally, the contribution remains visible and the
comment adds `Closure is awaiting server confirmation.` It is removed only
after the canonical closure is accepted and read back.

## Composition

- Several open issues may contribute independently to the same asset.
- The effective condition is the most restrictive active contribution.
- Resolving one issue removes only that issue's contribution.
- A manually declared `down` or `unfit` condition remains in force until it is
  changed through the plant-condition control, even when all linked issues close.
- The issue reference and description remain available in the condition detail
  so users can distinguish issue-derived unfitness from an independent manual
  declaration.

## Authority and compatibility

The client may show a pending local contribution, but it cannot declare the
asset available on the strength of an unconfirmed local closure. The backend
stores the selected effect and applies `unfit` as the compatibility default for
older clients. Isar schema v9 adds the field additively; older local rows decode
to `none` and are reconciled from canonical remote data.

