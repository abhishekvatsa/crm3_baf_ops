# Governed Maintenance-Ticket Supervision

## Purpose

Maintenance issues now have an explicit receiving-authority acknowledgement and
an audited Admin correction path. These commands complete the ticket lifecycle
without duplicating the existing compliance-request workflow used for
deferment, assurance, and Operations support.

## Acknowledgement

`acknowledgeMaintenanceTicket` records that the receiving lane has accepted the
issue for triage. It does not resolve the issue, defer it, or certify that work
has started.

Authority is evaluated from the current approved user record inside the same
transaction as the mutation:

- Admin, SI, Contract Supervisor, and Shift Supervisor may acknowledge any
  route.
- Electrical, Mechanical, Instrumentation, Operations, and Refractory actors
  may acknowledge only the route represented by their current role.
- EMD and shared routes require the supervisory authority defined above.

Only a clean `open` ticket may be acknowledged. Deleted, resolved, malformed,
stale-version, workflow-deferred, and partially acknowledged records fail
closed. The transaction writes the ticket acknowledgement fields, an immutable
audit, and an owner-bound idempotency receipt atomically.

## Deferment And Support

Acknowledgement deliberately does not introduce a second deferment state
machine. Maintenance deferment, operational constraints, crane or relocation
support, condition reactivation, counterconditions, and closure continue to use
the governed compliance-request lifecycle. A workflow-deferred ticket must be
handled through its linked compliance request.

## Admin Correction

`correctMaintenanceTicket` is Admin-only and requires a clear correction
reason. It may correct only:

- description;
- receiving route;
- maintenance type and criticality;
- component, subsystem, tag, classification, other department, and remarks.

It cannot alter asset identity, reporter identity, quality intent, workflow
bridge fields, acknowledgement evidence, closure/reopen evidence, deletion
state, action history, resolution history, or lifecycle status. Those remain
owned by their dedicated governed actions.

The resulting route also preserves the issue-creation invariant: `others`
requires a named other department, while every standard route requires that
field to be empty. Existing component evidence cannot be cleared through a
correction.

The Admin screen reflects this boundary: asset identity and status are shown as
locked context, while the supported fields and mandatory reason are submitted
through the maintenance callable. The former direct client update path has been
removed, and Firestore Rules no longer authorize generic Admin ticket edits.

## Integrity Contract

Both commands use optimistic version checks and canonical command
fingerprints. Every applied command produces:

- one ticket version increment;
- one deterministic `audit_logs/server_maintenance_ticket_<commandId>` record;
- one private `maintenance_workflow_command_receipts/<commandId>` receipt.

Replay revalidates the actor's current authority, request fingerprint, receipt
ownership, and matching immutable audit. Missing or malformed audit evidence
fails closed. Client Rules reserve the deterministic audit prefix so it cannot
be occupied before the server transaction.

## Deployment Boundary

Source and tests do not prove live deployment. The callable and Firestore Rules
must be deployed together before the UI is distributed; otherwise the new
commands will either be unavailable or the old direct-write policy may remain
live. Post-deployment readback should confirm the callable source revision and
the Rules hash before device acceptance evidence is collected.
