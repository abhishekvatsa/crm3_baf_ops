# Local-only `57be731…` Delta Adjudication

The repository authority capture found local branch `feat/70i-b2-o05-free-offline-signing` at:

`57be731673d42b1da41d186fe401087a41e4e821`

It contains two commits not in current main and diverges from the historical `5567003…` merge base. Its eight-path delta implements an unsigned GitHub CI candidate followed by future offline production signing.

## Decision

**Do not merge or transplant this branch wholesale into v4.2_R1.**

Reasons:

- it is 37 current-main commits behind;
- it replaces the current signed-artifact workflow and release-policy schema as a unit;
- its offline signer and independent completion stages were explicitly still pending;
- production artifact issuance is not on the current local-build/emulator/staging critical path;
- applying it now would enlarge the audit surface without helping prove the successor application.

## Useful semantics retained for later

The following ideas remain valid future release requirements:

- production private keys must not be placed in GitHub Free/private repository secrets;
- unsigned CI output and offline signing must be separate custody stages;
- reservation and built tags must remain distinct;
- unsigned output must never claim distribution authority;
- committed Firebase build-file hashes must remain distinct from historical registration-source hashes.

They should be reimplemented, if still required, on a fresh branch from the then-current canonical main after the successor source, emulator and staging gates pass.
