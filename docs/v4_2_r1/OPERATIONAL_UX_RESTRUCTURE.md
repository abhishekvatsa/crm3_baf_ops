# Operational UX Restructure

Status: SOURCE_IMPLEMENTED

Merge and exact-head CI evidence: PENDING

## Finding

The application exposed the right underlying capabilities, but its primary
navigation did not consistently express how field users act on them:

- Home repeated the bottom navigation as large module cards and used two
  different labels for the same open-issue count;
- Work separated planned jobs from maintenance-workflow lane and compliance
  obligations;
- Issues made manual synchronization more prominent than raising an issue;
- Directives and operational lists had no immediate search control;
- More was a long numbered catalogue that mixed ordinary records, governance
  tools and privileged support surfaces;
- record visibility was coupled to unrelated mutation permissions: Operations
  could reopen a resolved issue but could not reach resolved history, while
  approved users had no universal route to closed planned-job dossiers;
- workflow overview and diagnostics were reachable only from an existing
  visible lane or a notification, leaving an empty queue without a complete
  control-plane entry point;
- entity audit evidence had no general Admin destination and could begin its
  data read before direct-entry authority was resolved;
- narrow and wide layouts used the same navigation and content width; and
- large radii, shadows, headings and repeated empty-state counts consumed
  operational screen space without adding decision value.

These were information-architecture and usability defects. No backend
authorization, workflow transition, receipt, projection or synchronization
contract is changed by this tranche.

## Source Decision

The initial five-destination restructure used Home, Issues, Work, Directives
and More. The 2026-08-22 follow-on re-audit found that this still isolated
cross-functional control work and made the last destination sound residual.
The current five destinations are Home, Issues, Work, Control and Explore:

| Surface | Decision |
| --- | --- |
| Home | Shows the primary Raise Issue action, plant state, a severity-ranked decision signal and truthful role-scoped work needing attention |
| Issues | Keeps Raise available in populated and empty states, adds search, and retains refresh as a compact secondary action |
| Work | Combines assigned jobs, authorized lane/compliance obligations and role-gated template governance in one segmented surface |
| Control | Brings directives, workflow obligations, plant disruptions, quality warnings, cycle abnormalities and inspection findings into one risk-ranked control surface |
| Explore | Provides a searchable role-scoped directory grouped as Assets and lifecycle, Performance and assurance, Standards and governance, and Administration and support |
| Wide layout | Uses a navigation rail and bounded readable content widths; phones retain the five-item bottom navigation |
| Visual system | Uses restrained radii, borders and shadows with compact operational headings and stable control dimensions |

Maintenance-workflow queue rows continue to use the generated actor policy for
lane access. Template and assignment controls continue to use existing
`AppUser` capabilities. Navigation visibility is guidance only; backend and
repository authorization remain final.

## Functionality Representation Re-audit

The follow-up role-to-functionality walk confirms that every governed workflow
command has an operational UI path. It also closes the presentation gaps found
around retained records and specialist oversight:

| Capability | UI representation |
| --- | --- |
| Approved-user asset visibility | Explore > Asset registry and Plant condition, including Operations |
| Approved-user resolved maintenance visibility | Explore > Resolved issues; reopen remains independently role-gated |
| Approved-user closed planned-job visibility | Explore > Closed job dossiers, a bounded recent index searchable across completed and cancelled jobs |
| Approved-user workflow inspection | Work > Workflow > Workflow overview, even when no lane is assigned |
| Cross-functional operational control | Control > Directives, workflow obligations, disruptions, quality, abnormalities and inspections |
| Admin audit visibility | Explore > Audit log and entity audit evidence; both authorize before reading |
| Admin/SI workflow diagnostics | Workflow overview > Workflow Diagnostics |

The operations report now adds a risk-ranked decision brief. Unavailable
assets, open critical issues and plant disruptions lead count-heavy but lower
severity queues. Every signal routes to the screen where evidence can be
reviewed and action taken. The Home management pulse uses the same severity
principle and makes its availability, action and assurance metrics actionable.

Direct entry to Assets, Resolved issues, Closed job dossiers, Workflow overview
and Audit screens now resolves the current user capsule before starting the
corresponding data surface. Ordinary workflow event history remains visible to
approved workflow users; correlated audit-log evidence remains Admin-only.

## Verification

Local source verification on 2026-07-31:

```text
Flutter analyze:                           no issues
Focused operational/representation tests: 10 passed
Phone viewport exercised:                  320 x 800
Full Flutter suite:                        572 passed
Canonical R1 audit:                        87 passed, 0 failed
```

The focused matrix covers task-first Work for an Operations actor, hidden
template-governance controls, integrated workflow access, Issues empty-state
priority, Directives search, compact widths, mobile overflow detection,
closed-dossier search, read-versus-mutation capability separation and
authority-before-read ordering for closed dossiers, workflow and audit data.

Follow-on source verification on 2026-08-22 adds phone-width coverage for the
four-command Home hierarchy, actionable management pulse, Operational Control
queue representation, severity-ranked report signals and all four report
modes. Exact-head CI and full-suite counts are recorded by the merge PR rather
than backfilled into the historical 2026-07-31 result above.

## Remaining Boundary

This source tranche does not replace or modify the immutable production-signed
Build 6, prove the F4 physical-device matrix, authorize pilot handout, move a
programme gate or claim deployed-client evidence. A future governed build must
carry these changes before device-level usability, offline/reconnect and
role-walkthrough evidence can be collected.
