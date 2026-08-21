# CRM-III BAF Ops Product Experience Assessment

Assessment date: 2026-08-22

Assessment scope: current source on `codex/management-intelligence-ia`, based on the repository state following the reporting, information-architecture, navigation, and feature-representation tranche. This is a source and automated-verification assessment. It is not a claim that the current production-installed Android build contains this tranche.

## Rating Method

Each dimension is marked out of 10 against the needs of a role-controlled industrial maintenance and operations product. The marks consider functional breadth, discoverability, decision usefulness, failure containment, responsive behavior, and implementation evidence. A score above 9 denotes a strong production-grade source position, not a global percentile claim.

No 99th-percentile assertion is made. That would require independent comparison, representative users, measured task completion, accessibility review, and sustained field telemetry.

## Dimension Marks

| Dimension | Mark | Evidence-led assessment |
|---|---:|---|
| Business and BAF-domain fit | 9.3 | The product covers issues, planned maintenance, governed templates, components, assets, directives, abnormalities, quality, workflow lanes, compliance, operational events, audit, and administration. Several flows are unusually specific to batch annealing operations. |
| Feature representation in the UI | 9.2 | Entitled functions now have explicit, searchable destinations. The `More` directory exposes work coordination, lifecycle, performance, governance, and administration even when live counters are zero. Role-aware `Start here` actions shorten the route to common work. |
| Information architecture and navigation | 9.1 | The primary shell remains task-oriented: Home, Issues, Work, Control, and More. Management and specialist functions are grouped by purpose, with role-aware starting routes and searchable secondary navigation. Further evidence should come from observed user wayfinding rather than more source expansion. |
| Reporting and management insight | 9.0 | Reports now unite assets, issues, maintenance, quality warnings, monitoring, abnormalities, directives, workflow lanes, compliance, and operational disruptions. Overview, Work, Control, Reliability, and Assurance views support both scanning and governed drill-through. Live comparative trends and exported scheduled packs remain future improvements. |
| Workflow and task ergonomics | 8.9 | Common work is reachable directly and queues expose accountable obligations. Cross-domain report signals route to the relevant governed screens. Multi-step field workflows still need representative-user timing and interruption testing. |
| Visual design and system consistency | 8.6 | The shared industrial design system, restrained hierarchy, stable geometry, coherent states, and compact phone layouts provide a credible professional baseline. A higher mark requires fresh device captures across the complete route inventory and independent visual review. |
| Accessibility and responsive behavior | 8.7 | Widget evidence covers narrow phones, wider layouts, enlarged text, scrolling states, and stable app-bar geometry. Formal screen-reader, contrast-tool, switch-access, and real-device accessibility audits remain outstanding. |
| Data integrity and governance | 9.6 | A-02 through A-05 are source-enforced, persisted readers fail closed where required, role checks precede report-domain reads, and the canonical audit passes all 144 assertions. |
| Security and authority alignment | 9.4 | Reporting and navigation use actual actor capabilities; actor rejection precedes report subscriptions; governed mutation and role policies remain intact. Runtime and deployment controls continue to be judged by their separate evidence gates. |
| Offline resilience and recovery | 8.8 | Existing Isar provenance, migration, replay, quarantine, and synchronization controls are extensive and independently audited. Field behavior under prolonged poor connectivity remains a runtime concern rather than a source-only claim. |
| Maintainability and architecture | 8.8 | Cross-domain aggregation is centralized, UI panels are split into bounded parts, and the new report provider has an explicit A-02 exception with regression ownership. The report screen remains close to its line ceiling and should be decomposed before substantial additional presentation logic is added. |
| Test and release discipline | 9.6 | Flutter analysis is clean; 1,147 tests pass with one intentional skip; canonical, whole-app, expanded implementation, workflow, and structural audits all pass. Current build/deployment inclusion is deliberately separate from source correctness. |

Arithmetic mean: **9.08 / 10**.

## What This Tranche Changed

1. Added role-aware `Start here` actions and renamed the secondary destination from `Explore` to the clearer `More`.
2. Added a dedicated Work and coordination group with explicit routes to Directives, Maintenance workflow, Maintenance rhythm, Resolved issues, and Closed job dossiers.
3. Expanded operational reporting from issue and maintenance summaries into a cross-domain management readout spanning quality, abnormalities, directives, workflow obligations, compliance, and plant disruptions.
4. Added a Control report view and direct drill-through from management signals to their governed operational destinations.
5. Preserved authority-first behavior by rejecting an unauthorized actor before starting any report-domain data subscription.
6. Added narrow-phone, report-mode, source-order, actor-visibility, filtering, and cross-domain ranking regressions.

## Residual Product Boundaries

- The source tranche is not present on a user's phone until it is included in a governed successor build and installed or upgraded.
- The abnormality report input is refreshed as a bounded snapshot rather than a continuous live stream.
- A global percentile position cannot be established from repository evidence alone.
- Reporting would benefit next from saved management views, comparative trend baselines, scheduled exports, and measured drill-through use.
- Information architecture should next be validated with representative Operations, Mechanical, Electrical, I&A, RED, SI, and supervisory users performing timed tasks.
- Visual design should next receive a route-complete device capture review, including empty, loading, error, dense-data, and enlarged-text states.

## Verification Record

- Flutter analyzer: PASS, no issues.
- Flutter tests: PASS, 1,147 passed and 1 intentionally skipped.
- Canonical governed audit: PASS, 144/144.
- Whole-app reconciliation audit: PASS, 23/23.
- Expanded implementation audit: PASS, 15/15.
- Maintenance workflow full-tree audit: PASS, 18/18.
- Dart structural audit: PASS across 622 Dart files.

