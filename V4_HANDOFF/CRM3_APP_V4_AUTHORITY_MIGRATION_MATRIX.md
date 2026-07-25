# CRM3 App v4 — Authority and Capability Migration Matrix

v4 preserves the v3.3 architecture and absorbs the original app's valid capabilities into one authority model.

| Capability / state | Historical authority | v4 canonical authority | Legacy treatment |
|---|---|---|---|
| Workflow lifecycle | New workflow callable | Receipt-first workflow command dispatcher | Retained and strengthened |
| Job closure | `completePlannedJobExecution` plus workflow `finalizeJob` | Workflow `finalizeJob` with canonical remote-module validation, evidence checks, attestation and audit | Original callable fenced to legacy schema jobs |
| Module completion readiness | Original module records and closure guard | Canonical remote modules validated inside workflow closure | Original guarantees absorbed, not discarded |
| Module reopen | Original module lifecycle | `reopenWorkflowModule`, atomically reopening the owning lane and writing correlated audit | Direct divergence prevented |
| Lane topology | Manually selected workflow lanes | Mandatory lanes derived from canonical module disciplines, unioned with requested lanes | Missing-lane assignments repaired transactionally |
| Shared/Safety/Admin/Others coordination | Previously unlaned or collapsed | Governed `shared` coordination lane | Module edit authority stays discipline-specific |
| EMD / Refractory | Historically collapsed in some parsers | First-class `emd` and `red` lanes and generated policy | Old parser collapse removed |
| Lane removal/replacement | Lane-only mutation | Refuse when dependent work would strand; same-lane generation replacement remaps modules atomically | Silent orphaning retired |
| Cancellation | Workflow document only | One transaction projects cancellation to execution, lanes, compliance, modules, maintenance, equipment, event and audit | Original open-job residue eliminated |
| Compliance | Workflow records with partial reference trust | Workflow-bound, terminal-guarded and reference-revalidated commands | Foreign/historical references rejected |
| Maintenance-ticket deferral | Hidden workflow fields on maintenance records | Governed bridge represented in model, sync, UI and Rules | Legacy mutation blocked while deferred |
| Equipment condition | Original maintenance/execution derivation plus workflow projection | Canonical `equipment_status` projection | Asset timeline and fleet report consume canonical projection |
| Audit | Separate workflow events and original audit logs | Workflow operational timeline plus correlated original attestation/cancellation/module audits | Histories linked, not discarded |
| Escalation | Scheduled blind updates | Paged candidates, transactionally revalidated, deterministic events and terminal-tier exit | Stale close/completion notifications prevented |
| Pull failure handling | Collection-level failure | Per-document quarantine with bounded diagnostics and watermark policy | Valid sibling documents continue syncing |
| Client/server policy | Partly hand-maintained | Generated Dart, TypeScript and Rules policy | Drift surface reduced |
| App Check | Client support without governed workflow enforcement | Deploy-time callable option, default off until signed-client readiness | Premature lockout avoided |
| Isar persistence | Missing/stale workflow bindings | Explicit schema v3 contract plus provisional deterministic bindings and release guard | Release blocked until pinned generator replaces provisional output |
