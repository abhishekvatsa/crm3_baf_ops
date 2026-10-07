# Build31 business release path

This document describes the executable source path. It is not an enrollment,
deployment decision, successful hosted replay, build reservation or release
approval. Those records must come from the actual selected source and actions.

## Identities and boundaries

- **V** is the independently enrolled immutable verifier. Every executable
  helper it loads belongs to its externally committed file population.
- **M** is the final qualified backend source. A previous source qualification
  cannot cover later executable changes.
- **S** is the exact client candidate. Its real Git ancestry, permitted metadata
  changes, policy, approval, backend custody pointers and App Check choice are
  measured against M. Public pull-request measurements name the actual PR head.
- Private evidence and the original client authorization message stay inside the
  single protected V workflow. Public consumers receive bounded measurements and
  commitments. They receive no private-message, WIF or signing credentials.

The historical runtime-only route remains separate. Business selection, including
a malformed business signal, cannot fall through to a legacy route. Existing
historical pilot verifiers and unrelated policy/source/ledger gates still apply.

## Public source gates

`Initialize-Business31Controller.ps1` provisions only the independently selected
V file population and verifies the selected Node and Git binaries. Workflows
check its source hash against the enrolled configuration before invoking it.
The initializer uses complete local Git custody, refuses redirection and partial
clones, and disables lazy fetch and network protocols during verifier export.
It installs no dependencies and creates no cloud configuration.

The independent public enrollment uses:

- `BUSINESS31_CONTROLLER_CONFIG_JSON` and its exact UTF-8
  `BUSINESS31_CONTROLLER_CONFIG_SHA256`;
- `BUSINESS31_POLICY_REQUEST_JSON`, naming one actual completed policy replay.

The initializer exports local paths for the configuration, complete V, approved
Node/Git and request. Local callers may supply those same independently enrolled
selectors directly. A path or digest supplied by S is not independent enrollment.
The remote Linux verifier and a Windows public controller may have different
approved runtime hashes; neither can select arbitrary current-host bytes.

The common adapter starts the pinned `business31PolicyInvocation.cjs` in a fresh
process. It validates real Git pointers and the unchanged historical pilot, then
calls `business31PolicyResult.cjs` to authenticate the exact completed V run and
artifact through read-only platform APIs. It measures again before returning.
The result is useful only for policy checks. It cannot grant deployment,
construction, signing or distribution permission.

The public source job checks the exact PR head; other release jobs retain their
existing merge-checkout coverage. Neither result substitutes for actual-main
gates after merge. There is no latest-run search, status-name shortcut or stored
PASS input. A missing, stale or expired locator fails visibly. Creating the
policy replay is a separate trusted operation and must not depend on this
consumer already passing.

## Construction and package verification

1. The protected production workflow proves the selected live main, dispatch
   identity, environment review, enrolled tools and source policy. Cheap gates
   remain ahead of dependencies and package construction.
2. Before exposing signing secrets or consuming the build number, the pinned
   bridge starts a fresh construction challenge. The controller uses the exact
   run ID returned by workflow dispatch. It never guesses a run or blindly
   retries an ambiguous dispatch.
3. V performs full private replay and exact client/source-policy measurements.
   The controller authenticates the completed artifact, original challenge,
   live production parent, current S and local bytes. Only then is a public
   request locator retained for this same still-live parent.
4. The builder and its internal policy checks reauthenticate that completed
   construction request. They do not dispatch a second construction replay.
   The configuration commitment, candidate, parent run/attempt and original
   challenge expiry remain exact. Reauthentication does not restart its clock.
5. The normal reservation, signing, package identity and custody checks remain
   required. The package retains the original public construction observation
   bytes and their hash; this historical observation is not reusable authority.
6. Independent package verification requests a new package-purpose replay. Its
   challenge binds the source archive, manifest and both Android artifacts. The
   packaged helpers must match external V, real S Git bytes and the archive
   before import. Source and artifact drift are rejected before this expensive
   replay. Stable V/M/S, client, descriptor, closure and evidence commitments
   must agree with construction; fresh run IDs and nonces must not be treated as
   equal to the historical request.

Public policy results and operational prerequisite results have distinct schemas.
App Check joins either authenticated measurement to the actual approval and
closure; it preserves the separate mutating and identity enforcement scopes.
The compiler choice is not evidence that a Play-installed app attested.

Each replay has an explicit maximum wait of 150 minutes; the protected remote
job has its own 125-minute limit. The production job allows up to 360 minutes for
two separate replay windows and the existing build work. These are failure
bounds, not completion estimates. An expired construction request cannot be
renewed silently or replaced after a number has been consumed.

## Completion and remaining external evidence

Source preparation is complete only after the entire connected path is reviewed
and its actual exact-head and main gates pass. It does not mean the protected
environment, private input, credential context or deployment has been configured.
Those must be independently enrolled and verified; no placeholder can authorize
their use. The protected V workflow separately selects its trust, source
manifest, runtimes, client inputs and original message in its own environment.

Before actual controller capture, the qualified build root also needs complete,
self-contained Git metadata for the selected M, with its main and origin/main
identities verified. The qualification collector's source export has no `.git`.
Preparing that metadata must preserve every qualified source, dependency and
emitted-output byte. Controller completion retains the three captured cohorts;
it does not create final control readbacks or a deployed closure. Those original
observations and the closure assembly remain separate, verified release actions.

Before distributing Build31, retain the final source qualification, genuine
exact-source deployment decision and verified closure, fresh platform controls,
current Play inventory/reservation evidence, client compatibility and App Check
decision, exact metadata/main gates, one protected signing run and required
artifact custody proofs. Then qualify the actual Play upgrade with saved work
preserved. Earlier DEV or emulator evidence does not establish that upgrade.

Original failures and incomplete attempts remain retained. Tests that mock the
platform or use synthetic Git repositories establish only their stated local
scope; they are never relabelled as private hosted replay or production execution.
