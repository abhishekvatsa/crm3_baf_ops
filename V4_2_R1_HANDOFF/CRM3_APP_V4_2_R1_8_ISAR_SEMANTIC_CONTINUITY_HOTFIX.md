# v4.2_R1.8 — Isar Semantic-Continuity Hotfix

## Scope

R1.8 changes the local-laboratory continuity interpretation only. Product behavior, models, generated provisional bindings, Functions, Rules, Android configuration, dependencies, Firebase identities and governance authority are unchanged from R1.7.

## Previous defect

`verify_canonical_main_isar_continuity.py` compared the complete generated property definition:

```text
{id, type}
```

and failed whenever a generator-local property position changed. Additive successor fields therefore produced 101 false continuity failures after authentic code generation even though every inherited name and type remained present.

## Corrected contract

R1.8 fails closed on:

- missing inherited collection;
- changed inherited collection ID;
- duplicate collection ID;
- missing inherited property;
- changed inherited property type;
- missing inherited index;
- changed inherited index definition.

R1.8 permits and records:

- additive successor collections;
- additive properties and indexes;
- generated property-position changes where the inherited name and type remain exact.

Each position change is emitted as:

```text
generated-property-position-changed
```

with collection, property, baseline position, generated position and type.

## Pilot policy

The initial controlled pilot remains a clean-cutover/fresh-local-database trial. No old development database must be preserved merely to constrain the successor architecture.

A future requirement to support in-place upgrade of retained local data would be governed by a separate old-database migration probe. It is not conflated with the generated-position report.

## Safety

The harness remains read-only to the canonical repository and performs no Git remote mutation, Firebase deployment, production data write, app uninstall or device-data clear.
