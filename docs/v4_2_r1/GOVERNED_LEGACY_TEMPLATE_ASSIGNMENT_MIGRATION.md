# Governed Legacy-Template Assignment Migration

Status: SOURCE IMPLEMENTED

Deployment authority: none

## Purpose

The retained local `JobTemplate` library remains available for authoring,
history and completion, but it can no longer create a new planned job from a
freely typed equipment number. New assignments through `AssignJobScreen` use
the same governed physical-asset selector as published catalogue assignments.

The historical command name `createLegacyWorkflowJob` is retained so existing
workflow receipts and command routing remain intelligible. Its version-2
payload is no longer a legacy authority model.

## Client Contract

The client sends only:

- assignment schema version 2;
- generated execution identity;
- saved template identity and expected version;
- selected asset-class and physical-asset identities; and
- optional positive charge number and remarks.

It does not send template name, asset type, asset number or assigned agencies.
Those fields are server-owned. Supplying any of the former client-authoritative
fields is rejected.

The selector:

- permits only active registered physical assets;
- fails closed on absent or ambiguous legacy class mappings;
- requires an explicit hierarchy class for governed-custom templates;
- respects fixed physical-asset references; and
- routes Inner Cover work through an active Base carrying a currently linked
  Inner Cover, with the serial shown to the operator.

New whole-asset templates that choose a governed class now retain a class-level
hierarchy reference. A new governed-custom template cannot be saved without an
explicit class. Historical standard templates without a reference may use a
unique active legacy class mapping; historical custom templates without a
reference remain blocked until repaired or superseded.

## Transactional Authority

The maintenance workflow transaction re-reads and validates:

1. current actor authority;
2. the saved template, active state and expected version;
3. the compatible active class, including uniqueness for legacy mappings;
4. the selected active physical asset and registry number;
5. the complete reconciled equipment projection; and
6. for Inner Cover work, both the Base assignment and reverse installed-cover
   profile.

Only then may it create the execution, workflow, equipment transition, event
and command receipt. Template or asset changes abort with zero business writes.

## Frozen Evidence

Every new assignment carries class ID, physical asset ID and asset number in
the execution metadata and workflow. Inner Cover jobs additionally freeze the
Base, cover serial, cover ID, linkage ID and assignment version. Existing
execution readers, detail screens and reports consume this evidence even when
the job has no published `TemplateVersion` ID.

An older complete type-and-number equipment projection can be upgraded with
exact identity. A partial identity or a contradictory complete identity fails
closed. Existing counter completeness remains a prerequisite.

## Historical Compatibility

No historical template, execution, response, completion dossier or audit event
is rewritten. Old jobs without exact metadata remain readable through the
documented legacy fallback. New jobs cannot use that fallback.

The separate legacy template publisher remains an authoring and historical
surface. It is not a bypass around governed physical-asset selection.

## Deployment Sequence

This source change deliberately makes mixed old/new runtime pairs fail safe:

- a new client against the old backend omits the old client-authoritative
  fields and assignment fails;
- an old client against the new backend lacks schema version 2 and exact
  identity and assignment fails.

Deploy the verified backend first, accept the bounded assignment outage, then
distribute the matching signed client and prove one standard and one Inner
Cover assignment. Do not deploy the client first and do not describe source or
CI evidence as production availability.

## Verification

Coverage includes old-client rejection, server-owned-field rejection, stale
template rejection, active class and asset validation, projection completeness,
exact evidence persistence, Inner Cover linkage freezing, concurrent Firestore
creation, replay authority, persisted-data decoding and shared-selector source
contracts.

Removing the free-number `int.parse` path also removes its obsolete A-05
command-presentation catch classification. The mechanically discovered decoder
catch inventory therefore moves from 39 to 38 without weakening a remaining
decoder boundary.
