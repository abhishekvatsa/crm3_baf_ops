# v4.1 Review Adjudication Matrix

| Review statement | Status | Basis / action |
|---|---|---|
| v4 is strongest successor candidate but not immediate replacement | Accepted | Matches existing v4 classification |
| v4 must be reconciled to exact current main before merge | Accepted as integration gate | Claimed `633c…` not independently accessible; no Git mutation performed |
| v4 should remain subordinate to current Stage 2D roadmap | Rejected | Conflicts with ratified successor-programme direction |
| Firebase files absent | Accepted build gate | Deliberate custody separation; now explicitly documented |
| Firebase Android app IDs conflict | Accepted defect | Source aligned to permanent `…fba14…` registration |
| Admin user writes lack `hasOnly` | Accepted defect | Exact seven-field whitelist added |
| Command deadlines persist as strings | Rejected | `FirebaseWorkflowStore` converts timestamp-named ISO values before writes; tests added |
| Compliance mapper drops lifecycle fields | Accepted defect | Full mapper and Flutter test source added |
| Isar bindings provisional | Accepted deliberate gate | Release verifier remains fail-closed |
| Migration proof is marker-only | Accepted runtime gap | Real v2→v4 database laboratory remains mandatory |
| Dependency posture is not clean | Accepted external gate | Controlled O-07 remediation remains open |
| Client testing is insufficient | Accepted verification gap | Mapper test added; full Flutter/widget/provider suite remains open |
| Root documentation is boilerplate | Accepted maintainability defect | Replaced with operational README and Firebase custody guide |
| Coupling to `main.dart` remains | Accepted maintainability debt | Not changed in this narrow correction tranche |
| Current app remains operationally canonical | Accepted until integration | Does not demote v4 as successor design authority |
