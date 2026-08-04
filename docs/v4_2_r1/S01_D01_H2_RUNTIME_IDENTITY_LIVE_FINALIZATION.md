# S-01, D-01 and H2 Runtime Identity Live Finalization

Status: DEPLOYED AND LIVE READBACK PASS; SOURCE/CI ADJUDICATION PENDING

The complete production Function fleet was deployed from exact clean `main`
`bdc5c6ed870e7f947c40ea053cd587a56d77d48a` after four-job release-gate run
`30913630958` passed. Fourteen active Generation 2 Functions now use their exact
dedicated runtime identities. Callable probes, event functions and the bounded
scheduler invocation passed, with scheduler backlog zero.

The final phase first repeated the generation-pinned dependency readback. Only
after that posture passed did it remove Default Compute `roles/editor`,
`roles/eventarc.eventReceiver` and project `roles/run.invoker`, together with
obsolete global-pull logging and project invoker grants. The final fleet probe
then passed all 24 controls and the final dependency readback passed all 17
controls. Automatic Editor restoration was armed but was not needed.

The final least-privilege posture is:

- Default Compute: `roles/cloudbuild.builds.builder` only;
- global-pull reader: `roles/datastore.viewer` only;
- global-pull writer: `roles/datastore.user` and the required
  `roles/eventarc.eventReceiver`;
- deployed Functions using Default Compute: zero;
- deployed runtime identities with broad project grants: zero; and
- Functions with dependency inventory or selected-version drift: zero of 14.

The privacy-minimized source receipt is
`release/evidence/s01-d01-h2-runtime-identity-live-finalization.json`. It binds
all nine external campaign receipts by both file SHA-256 and their canonical
receipt SHA-256. The external receipts retain no user identity, business
document ID or business payload.

This live result makes `H2-IAM`, `S-01` and `D-01` closure-ready. Their ledger
transition remains pending until this receipt and its contract test pass exact
pull-request CI. It does not close `STAGE2D-F4`, authorize pilot handout, enable
App Check or authorize distribution.
