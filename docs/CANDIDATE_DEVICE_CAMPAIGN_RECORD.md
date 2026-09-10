# Candidate device campaign — execution record

An empty form, to be filled by executing it. Nothing here is a result.

Every row below is **not demonstrated** until a run writes into it. That is the
default and it is not a criticism of the candidate: source correction and
device demonstration are different claims, and this document exists so the
second is not inferred from the first.

## Why this form and not a narrative

The corrective round that produced this candidate found four defects of the
same shape — a correct contract, and a caller that did not use its full
meaning. None was found by the test suite; all were found by reading. A
narrative report would have hidden that, because every intermediate state also
looked fine in prose.

So this asks for observed values, not assurances. Where timing could not be
established, write **not demonstrated** rather than inferring from a plausible
sequence.

## Candidate binding

Fill before any test runs. A campaign against an unbound artifact proves
nothing about what is installed.

| Field | Value |
| --- | --- |
| Source commit | |
| Exact-head CI run and conclusion | |
| APK SHA-256 (from the device, not the build host) | |
| versionName / versionCode | |
| Signing identity | |
| Backend release identity observed by the app | |
| Installed baseline **measured on the handset** | |
| Recovery copy taken, and what it actually covers | |

The baseline is measured, not assumed. The last campaign plan carried a
Build 21 reference forward while the incident handset was running Build 27.

## Questions this campaign answers

Start with the maintenance acknowledgement / lane path: it is the contract the
recovered-receipt work repaired, so a failure there is traceable to a known
command, target, actor and expected result. Do not begin with every module at
once.

| # | Question | Controlled exercise | Observed | Verdict |
| --- | --- | --- | --- | --- |
| 1 | Does the upgrade preserve existing work? | Install in place after the preservation step. No uninstall, no clear-data, no reset. | | not demonstrated |
| 2 | Does an ordinary command complete through its real caller? | A permitted user acknowledges a designated test ticket or completes an authorised test lane. | | not demonstrated |
| 3 | Does a second device see the same result? | A second authorised user reads that record. Match target identity and server revision, not screen text. | | not demonstrated |
| 4 | Does uncertainty stay honest? | Controlled response loss where server acceptance and the missing client response are independently established. | | not demonstrated |
| 5 | Does attention persist, and clear for the right reason? | A designated rejected or review-required request, two quiet runs, a restart, then resolution through the intended mechanism. | | not demonstrated |
| 6 | Does lifecycle and network recovery behave? | Background and resume under the relevant network conditions. | | not demonstrated |

For each executed row record: original command id, target identity, actor,
expected outcome, authoritative receipt or readback, and the resulting business
revision.

## What must not be done to obtain a result

- Do not corrupt the production store to force a warning. The difficult
  internal orderings — an unreadable receipt, a returned verification failure —
  are established in the automated tests. This campaign establishes that the
  packaged application preserves and presents their outcomes.
- Do not change live plant-condition declarations to exercise a test. Use
  designated test records or an isolated environment.
- Do not create a new command identity to get past an obstruction.
- Do not record a pass for a timing-dependent case whose timing was not
  established.

## Claims this campaign cannot support

State these as limits in the report rather than leaving them to be assumed.

| Not established by this campaign | Why |
| --- | --- |
| Durable unattended background submission | Not implemented. There is no background scheduler in this candidate. |
| Recovery from process death **before** a request identity was durably stored | The retry row is written in the failure path, after the gateway call. Testing a request whose uncertainty was already retained does not exercise that window. |
| Complete historical agreement between local and server | A delta pull run says nothing about records an earlier client may already have passed over. |
| Ownership safety across concurrent execution contexts | There is only one execution context in this candidate. |
| Backend identity / App Check cause | Unresolved and separately owned. A green workflow test does not close it. |
| Critical alarm delivery | Never exercised, either side. The plant's existing emergency route stays primary. |

The 2026-09-09 incident evidence established same-process foreground recovery
with **zero-item pushes**. It remains a useful background-recovery observation
and is not evidence for the nonempty command path this campaign tests.

## Report format

Return the filled table above, plus the binding block, plus the limits section
unchanged. Do not substitute a test count, a CI badge or an overall assurance
for an observed value.
