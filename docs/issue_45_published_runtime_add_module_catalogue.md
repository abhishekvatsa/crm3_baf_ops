# Issue 45 — Published runtime-add module catalogue

## Decision

The normal governed source for active-job runtime module additions should be a published `TemplateVersion` module snapshot, not the hard-coded Emergency/manual seed catalogue.

This patch adds the pure domain layer needed for that migration:

- parse published `TemplateVersion.moduleSnapshotsJson` into runtime-add candidates;
- preserve linked `fieldDefinitionsJson` for the selected module;
- filter candidates by active job asset type;
- exclude modules that are already attached to the active job;
- build a `JobModuleInstance` whose metadata clearly identifies `published_template_version_runtime_add`.

## What this patch does not do yet

This patch intentionally does not replace the active Add Module sheet. The existing Emergency/manual seed flow remains the UI fallback until the next UI integration step is reviewed.

No schema, Firestore rules, sync policy, or authority matrix changes are introduced.

## Why staged

A direct UI replacement would need operational decisions about catalogue scope:

1. use only the same `TemplateVersion` that assigned the active job;
2. allow modules from any published package matching the asset type;
3. require Admin/SI-published runtime-add package subsets.

The safe first step is to make published module snapshots convertible into runtime-add `JobModuleInstance` records with tests.

## Future integration

The Add Module sheet should eventually present sources in this order:

1. Published governed runtime-add catalogue candidates.
2. Emergency/manual seed catalogue fallback, with current elevated warnings and supervisor/Admin/SI confirmation for safety/shared/closure-critical modules.

For governed active jobs, the UI should show whether the selected module source is:

- `Published TemplateVersion runtime add`; or
- `Emergency/manual seed catalogue`.

## Safety invariant

Published runtime-add modules are new runtime instances. They must never mutate the published `TemplateVersion` snapshot. The published version remains frozen; the active job receives its own immutable module snapshot copy.

## 45B integration note

The active planned-job Add Module flow now checks whether the job was assigned
from a published governed TemplateVersion. When the published version is locally
available and contains runtime-add candidates for the job asset type, the UI
shows the published governed catalogue first. Operators may explicitly fall back
to the Emergency/manual seed catalogue when the published catalogue does not
contain the required additional module.

Safety-critical, shared, or closure-critical runtime additions still require
Supervisor/Admin/SI control. This is enforced in the UI and by the repository
create guard for all runtime-added modules, not only emergency/manual seed
modules.

No schema, Firestore rules, sync convergence, or published TemplateVersion
immutability behavior is changed by this integration.
