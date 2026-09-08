# Governed dependency compatibility

`npm run test:dependency-compat` verifies the interfaces used by the pinned
Firebase CLI and the other locked dependency trees. These checks perform no
Firebase account import, deployment, or business-data operation.

The Firebase CLI remains at 15.22.4. Its CSV parser is overridden to the upstream
patched `csv-parse@7.0.2` for
[GHSA-8cw4-87c7-c6xx](https://github.com/advisories/GHSA-8cw4-87c7-c6xx).
The CLI's sole CSV consumer is `auth:import`, which uses the CommonJS `parse()`
Node stream with default options. Tests verify that interface, conversion through
the CLI's actual account mapper, malformed input, split UTF-8, and the advisory's
duplicate-column prototype replacement case. The override is confined to CLI
tooling; it does not change the Android app or Functions runtime dependencies.
