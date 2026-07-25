# CRM3 v4.2 Successor-Programme Authority

v4.2 is the active **source-migration architecture** for CRM3 BAF Ops.

The governing decision is not to minimise change. The objective is to migrate the application's legitimate operational capability into the stronger v3.3/v4 authority model. Old mechanisms may be retained only when they remain the best implementation; otherwise their business, security, evidence or migration guarantee is absorbed into the new design and the conflicting mechanism is fenced or retired.

## Authority distinction

- **v4.2 is authoritative for successor development.**
- The existing application remains operationally canonical until a governed cutover.
- The old source is the no-loss, security and migration baseline; it is not an equal architectural authority.
- Direct deployment, production mutation and field distribution remain prohibited.

The machine-readable decision is `governance/v4_successor_programme_authority_v1.json`.
