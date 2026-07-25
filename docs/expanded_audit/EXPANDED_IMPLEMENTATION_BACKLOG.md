# Expanded Implementation Backlog

## P0 — Authority and runtime gates

1. Reconcile the authoritative repository, branches and unique deltas before applying this candidate.
2. Materialize this patch on a fresh governed branch from proven current main.
3. Run Isar code generation, `flutter analyze`, Flutter tests and Android build.
4. Run Firestore emulator Rules and transaction-contention suites.
5. Run device notification, lifecycle rejection/form-retention and weak-network matrix.

## P1 — Business completeness

1. **Ticket defer/reactivation:** extend `MaintenanceRecord`, Isar schema/migration, server projection and UI before exposing `confirmConditionAndReactivate` as a ticket operation.
2. **Direct compliance navigation:** notification → exact compliance detail, while preserving authority and local projection availability.
3. **Lane progress:** derive module completion/required totals per lane and explain why closure remains blocked.
4. **Equipment integration:** project workflow-derived equipment status into fleet status, asset timeline and support diagnostics.
5. **Administrative support:** outbox/receipt/compliance visibility with non-destructive investigation controls.

## P2 — Whole-app deepening beyond workflow

Use the source atlas order, beginning with:

1. `main.dart` and startup/recovery invariants;
2. authentication and user-role lifecycle;
3. planned-maintenance provider/model serialization hubs;
4. maintenance and planned-job sync push/pull/conflict paths;
5. Firestore Rules parity with all client reads/writes;
6. Android/Kotlin/application identity after repository reconciliation;
7. release identity, signing and production artifact machinery.

## Change-control rule

A reviewer concern becomes an implementation item only when it is supported by the ratified contract, executable policy/current source, or a demonstrable operational failure path. Later user decisions are not reverted merely to satisfy an older review preference.
