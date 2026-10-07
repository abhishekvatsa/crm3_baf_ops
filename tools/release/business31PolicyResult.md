# Public Build31 business policy measurement

`business31PolicyResult.cjs` is a read-only entry for the explicit business route.
It authenticates one independently selected locator against the actual completed
pinned-verifier workflow, its artifact and digest, its exact current candidate,
and the policy records read from actual Git. It never dispatches a workflow,
downloads private evidence, reads the original owner message, or grants an action.

Invoke the independently pinned entry with an independently selected Node binary:

```
node --no-global-search-paths business31PolicyResult.cjs --controller-config ABSOLUTE_CONFIG --controller-config-sha256 UPPERCASE_SHA256 --input ABSOLUTE_INPUT
```

The bootstrap must select the entry, configuration digest, controller runtime and
complete verifier file map independently of candidate metadata. The shared
`build31-business-prerequisite-controller-v1` configuration contains `replayTrust`
for the remote Linux job and a separate `controller` binary selection for the
public caller. Its `selected` record fixes the full candidate, descriptor pointer
and `clientSelectionSha256`. Controller producer bytes equal the selected V map;
the controller Node/Git binary hashes need not equal the remote Linux binaries.

The bounded JSON input has exactly these fields:

```
{
  "schemaVersion": 1,
  "profile": "build31-business-policy-result-input-v1",
  "repositoryRoot": "ABSOLUTE_SELF_CONTAINED_GIT_REPOSITORY",
  "gitExecutable": "ABSOLUTE_SELECTED_CONTROLLER_GIT",
  "request": "FULL_REQUEST_V2_OBJECT"
}
```

`request` is the full protocol request object, not a string in actual input. Its
challenge purpose must be `policy`; its candidate, descriptor and client selection
must match the independently enrolled configuration. The locator may name a recent
completed policy replay. It grants nothing until the actual artifact is retrieved
and authenticated. Schema 1 results, construction/package purposes, stale heads,
expired challenges/results and local PASS files are refused. There is no run-name
search or latest-run fallback.

The only network credential used is `GITHUB_TOKEN`. Public workflows must supply
read-only contents/actions access, never dispatch, WIF, signing or private-message
credentials. The artifact-storage redirect receives no GitHub credential. The
consumer performs the shared before/after artifact observations, actual committed
policy verification, and one further remote observation after those Git reads.

Successful output has profile `build31-business-policy-result-v1`, exact V/M/S and
descriptor/closure/commitments, run/attempt/artifact identities, the closed client2
projection and `policyMeasurementVerified: true`. It contains no local paths or
raw message/policy bytes. Human, host, clock, original-process and independently
selected-input authentication remain false, as do credential, deployment,
construction, signing and distribution grants.

Public policy and canonical callers must retain all unrelated existing checks.
This result supplies only the new business measurement clause. They must invoke
the pinned entry; parsing a saved output, trusting a status/check name, or accepting
candidate-provided executable/configuration selections is not equivalent. Final
manual exact-source gates must independently authenticate the completed V run.
Construction and package verification require their separate fresh challenges.

The caller needs an enrolled exact-S configuration and a completed policy locator.
If either is unavailable it fails closed. Creating the policy replay is a separate
trusted/manual operation; it must not wait for this consumer to succeed first.
