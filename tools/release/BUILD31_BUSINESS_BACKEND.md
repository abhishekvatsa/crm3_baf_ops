# Build 31 business-source preparation

The business source now includes Inner Cover disposition and inspection reading
contracts. The existing `build31-exact-grpc-runtime-backend-v1` profile admits
only its original dependency delta. These changes cannot be relabelled as that
profile or as the historical Build 30 deployment.

This directory currently provides unprivileged preparation primitives for the
separate `build31-exact-business-backend-v1` profile. They are not selected by
production release policy, and none grants deployment, private-credential,
client-compatibility or artifact-construction authority. Build 31 allocation
and construction remain separate guarded steps.

## Input boundaries

`business31TrustedInput.cjs` reads a self-contained local Git repository using
an independently supplied, hash-bound Git executable. It refuses shallow or
indirect repositories, unsafe paths/configuration, corrupted objects and
unbounded inputs. It checks actual immutable trees and ancestry, with the
trusted verifier V unchanged in source M and metadata candidate S. The M-to-S
boundary permits only its finite metadata paths and the Build 31 version line.
It does not execute candidate code, fetch credentials or claim that metadata
contents or GitHub/platform identities have been authenticated.

`business31SourceAdmission.cjs` compares the complete protected source
population at the historical deployed baseline F and exact source M. Its
manifest binds every allowed change and mode, the full populations and exact
Functions/CLI dependency bytes. Changes to Rules, indexes, Firebase controls,
Android configuration, protected fleet policies, held submission recovery,
unlisted files or executable modes are refused. A caller-created manifest
hash is only a local measurement: the future trusted controller must select
and authenticate the approved manifest independently. The source measurement
cannot become a deployment decision by adding a success flag.

## Recorded backend preparation

`business31BackendAuthority.cjs` binds an exact normal source merge, its
separate later decision-custody commit, original command and audit records,
installed dependency populations, and the complete compiled output population
of that source. Changed business outputs are compared with the approved new
source rather than required to equal the historical deployed backend.

This is a preparation measurement only. Retaining an original human message
or CI response does not authenticate its origin, and caller-supplied time is
not a trusted clock. The result explicitly withholds control-semantic replay,
closed-chain verification and every operational authority. The future trusted
controller must establish those separate prerequisites from original evidence
before any deployment or private-credential access.

## Recorded execution and closure

`business31ExecutionContract.cjs` binds the prepared source, intended package
and ordered endpoint inputs, settled review and observer identity before the
owner decision. Schema 2 decision/owner records additionally bind this exact
contract. Schema 1 decision/owner records remain readable for their original
scope and cannot authorize the schema 2 execution path.

`business31BackendClosure.cjs` replays the recorded 13 callable, five event and
one scheduler cohorts. It checks original command records, mutation requests
and responses, actual uploaded ZIPs, controls and final readbacks using the
unchanged runtime validators. Initiation and completion orders are independent;
a concurrent request completion is not rewritten into an invented serial order.
Its result measures recorded semantics and explicitly withholds authenticated
owner/platform/clock, deployment, client construction and distribution authority.

Successful mutation replay requires **mutation schema 3**. Each mutation's
`responseBinding` pointer binds the retained raw response bytes, content encoding,
completion state, byte count and observed HTTP status. Replay verifies those
immutable pointers, requires a completed successful response, and compares both
the observed status and the bounded, strictly decoded UTF-8 body with the derived
response used by the transport guard. Encoded and decoded response bodies retain
the capture writer's fixed 16 MiB limits; empty successful upload bodies remain
valid. A derived success response alone is insufficient.

Each schema 3 mutation also records `requestAdmittedAtUtc` immediately before
the original HTTP request and `firstOutboundAtUtc` immediately before its first
underlying write or end. These are samples from the live guard's wall clock,
not the earlier injectable record clock. Replay requires both samples, in order
between record initiation and response completion, inside the exact decision's
execution window. Closure, cohort and preparation starts remain inside that
window. An already-admitted request may settle afterward; process completion,
final readbacks, after-controls, recording and custody retain their existing
chronology checks. A later request or cohort cannot inherit that settlement
permission. Subsequent bytes of the same admitted request are settlement, not a
new request; the guard does not claim it can undo bytes already sent.

Legacy schema 1 and 2 mutation transcripts are explicitly refused by this
closure path. Schema 1 lacks response-wire binding; schema 2 lacks these live
forwarding samples. Missing evidence is never reconstructed or promoted.
Historical source snapshots, failed attempts and synthetic replay receipts
remain unchanged and qualified to their original verifier and scope; they do
not prove the new schema 3 path or authenticate deployment. This mutation
version is independent of decision, runtime-proof and descriptor schema versions.

`captureBusiness31PreparedInputs.cjs`, `captureBusiness31PreparedHook.cjs` and
`business31CaptureSession.cjs` retain prepared package inputs and the request
transcript. The session enforces phase order and once-only use, refuses further
work after failure, and restores only hooks that it still owns. A persistence
failure or foreign hook change is retained as a failure, not reported as a
successful deployment. Exact dependency hashes use the repository's canonical
LF bytes; verification never normalizes or accepts alternate hashes.

`business31CaptureBootstrap.cjs` replaces unsupported shared-process startup of
these capture APIs with a fixed, fresh component-test entry. The component
launcher checks the selected Node and source bytes, supplies explicit arguments
and a scrubbed environment, and accepts only fixed suite/case identifiers and
bounded data. Requests cannot supply a module, driver or observer callback.
Before helper or CLI imports, the child rejects an inherited helper cache and
installs the source, resolution-metadata and loader checks. A failed admission
or the final CLI lease ends that process's capture eligibility; cleanup does
not reopen it. This clean-entry requirement excludes a registrar reference
saved by earlier caller code; it does not revoke an already escaped reference
or make an arbitrary shared process trustworthy.

This is a component-test launcher, not the operational deployment launcher.
`launchBusinessCapture31` explicitly refuses execution. The externally admitted
Node/bootstrap/source launch, fixed authenticated observer, real CLI controller
and existing three-child receipt integration remain unimplemented. The finite
Windows toolchain profile is described below; its enrollment supplies byte
identity, not operational qualification. A child consistency hash, caller flag
or successful component measurement supplies none of that authority.
The existing three-child closure contract and immutable historical verifiers
are unchanged; component children cannot stand in for deployment receipts.

The capture-session tests use the installed Firebase hash, API and upload
modules with a fresh synthetic Git repository and source ZIP, while HTTPS
responses are supplied locally. They exercise the once-only 13/5/1 cohorts,
all 25 original requests, separate initiation and completion order, lost-response
refusal, and hook cleanup under persistence failures or foreign changes. This
is local component integration: it does not invoke full Firebase preparation
or a deployment child, authenticate an observer, owner or clock, or establish
real cloud completion. Its measurement cannot substitute for original process
receipts, authenticated controls or complete private closure replay.

## Descriptor and original-path replay

`business31PrivateDescriptor.cjs` verifies actual Git V/M/S identities, the
complete producer population, finite metadata changes, historical closure and
exact decision/closure pointer bytes. Its source-manifest commitment comes from
an independent caller input. A matching digest does not authenticate the caller.

`business31OriginalPathReplay.cjs` composes this boundary with the bounded bundle
reader and the full business closure entrypoint. It requires the recorded
original paths to be unavailable, verifies the complete extracted inventory,
and resolves their unchanged identities through the existing relocation layer.
It binds every executing helper before replay and checks retained bytes again
afterward. Callback results, tokens and supplied success summaries cannot stand
in for the original evidence. A local synthetic replay does not establish real
cloud deployment or hosted credential isolation.

## Private bundle transport

`privateEvidenceBundle31.cjs` contains shared bounded byte-custody, gzip-member,
extraction and exact-generation Google Storage transport operations. The only
permitted namespaces are the existing runtime backend and the separately
named business backend. Bundle types cannot cross those namespaces; the
bucket, generation and byte/digest limits stay fixed. Portable member checks
also reject trailing-dot components and differently cased directory prefixes,
which otherwise have inconsistent identities across Windows filesystem APIs.
No transport result substitutes for replaying the complete original evidence.

The existing `runtimeBackendPrivateReplay31.cjs` still validates its strict
original profile before loading the shared helper. Its repository entrypoint
binds the complete source producer population before using a read credential;
the new helper is an explicit producer. Historical descriptors and source
snapshots are not rewritten. A descriptor without the required producer
binding fails closed, rather than inheriting a newer verifier silently.

## Verification and remaining integration

The existing eight runtime suites remain selected in CI. The narrowly named
`business31*.test.cjs` family and `privateEvidenceBundle31.test.cjs` are added
to that same group, with discovery failures treated as failures. Local source
checks select the same new family. Tests distinguish synthetic inventories
from actual Git-object fixtures and do not contact production or mint tokens.

A usable release route still requires the separately reviewed business
admission/controller and caller integration, actual exact-source owner and
platform authority, replay of original runtime/control/execution/closure
records, and a protected hosted verifier with narrow private-evidence access.
Public PR code must never receive that credential or raw private evidence.
A successful preparation test or public hash attestation does not satisfy
those requirements. The original immutable verifier family stays unchanged.

After final reviewed source and its actual main gates, fresh exact-source
controls, a concrete production decision and verified deployed closure must
precede client/metadata authority and protected signing. Inspection labelled
reading authoring remains default closed until the reader rollout requirements
in [the inspection rollout document](../../docs/INSPECTION_V2_ROLLOUT.md) are
satisfied. None of these source files enables the production writer switch.

## Measured npm executable materialization

Current source requires runtime-proof schema 3, including the source-approved
toolchain and tested-output joins below. The materializer remains a fixed member
of the complete verifier/source population. Older schema-1 link-free and
schema-2 materialization records remain historical evidence under their original
verifier/source snapshots; never rewrite them as current schema-3 success.

Use the materializer only in a newly owned build tree, after all three exact npm
clean installs and before any build, test, installed-graph check or audit. It
covers root, Functions and governed CLI dependency populations, including nested
`node_modules/.bin` directories. On POSIX, only relative, package-declared file
aliases targeting an unchanged regular Node script inside the same dependency
population are supported. Directory links, chained/escaping/dangling targets,
backslash target spellings, undeclared commands and unsupported interpreters or
flags fail closed. Windows keeps npm's regular launchers and refuses a symbolic
alias population. No existing development install or retained evidence is
normalized in place.

Windows preparation and receipt replay validate every bare, `.cmd` and `.ps1`
launcher as one complete package-owned triplet. Each file must match the finite
Node/no-flags cmd-shim 7 template, its package's declared bin target and supported
Node shebang. Missing, altered, extra or ambiguously owned launchers, alternate
Windows directory casing and local Node interpreter shadows are refused. The
existing shim bytes are never rewritten or executed by this check. Template
inspection of installed npm 10.9.2/cmd-shim 7 and read-only Windows fixtures does
not establish approved npm 10.9.8 execution; unsupported templates fail closed.
External PATH and command-interpreter trust remain live-collector prerequisites.

The producer replaces each verified POSIX alias with a deterministic regular
0755 shell launcher. That launcher invokes the exact bound Node executable and
the original package script with unchanged arguments; it does not copy JavaScript
into `.bin`. The original target must have owner-execute permission and its bytes
and recorded mode remain unchanged. The receipt retains the original lexical
link, owning package declaration/hash, target/hash/mode, generated launcher/hash/
mode, complete before/after file commitments and counts. All non-alias bytes stay
unchanged. Unsupported materialization leaves a failed, retained preparation;
there is no success receipt or automatic retry.

The materialization fields, introduced in runtime-proof schema 2 and retained
in schema 3, add the pointed materialization receipt and the root
installed-file map alongside Functions and CLI. The exact producer command's
retained stdout must equal that receipt. Every install must complete before the
producer starts, and all subsequent runtime commands and audits must start after
it completes. Original build-root strings are preserved in command records even
when read through the immutable relocation adapter. These remain recorded
semantics, not authenticated process or deployment authority.

The bundle and source walkers continue to reject all symbolic links. The same
normalized regular bytes enter custody and extraction; extraction deliberately
uses mode 0600. Replay checks original recorded executable modes and current
content commitments without executing or chmod-ing extracted launchers. A local
Windows copy or clean-install check is not a Linux result: selected Ubuntu CI must
exercise actual npm-created POSIX links, launcher argument behavior and the
0755-preparation to 0600-extraction boundary. Fixed file/byte custody limits are
unchanged and must be checked before any full replay fixture is constructed.

## Source-approved Node and npm identity

Current runtime-proof schema 3 requires `business31ToolchainIdentity.cjs` and
the fixed `business31ToolchainProfiles.json` data file. The independently selected
verifier V, source M and decision-custody commit must contain identical regular
profile-data bytes; a runtime record cannot select another approval file or
provide its own trusted hashes. The JSON stays non-executable source data outside
the descriptor code-producer map; existing complete-source M-to-S and exact
custody-delta checks cannot change its path. The helper is an exact executing
producer and must appear in descriptor, closure and capture-session bindings.

The checked-in table contains one finite profile:
`win32-x64-node22-23-1-npm10-9-8`. Its Node 22.23.1 Windows x64 archive was
verified against the Node release signature and signed checksums. npm 10.9.8
was verified against its registry ECDSA signature and SHA-512 integrity, with the
exact registry public-key bytes independently corroborated by pinned Corepack
source. Every one of the 2,009 regular npm package files, including bundled
dependencies, is bound. The retained independent archive review has digest
`216BAE18CD673E4BE709207722D5A5932364FA2BC0A53A96780274B94F463C75`.
These checks establish release/registry authenticity; they do not claim npm
author OIDC provenance.

This source profile does not approve the current host's installed tools or
establish successful runtime execution. The exact approved bytes, real version
probes, clean-install/test records and all remaining authority checks are still
required. Other platforms have no implicit profile. Empty or unknown profile
selections still refuse. Synthetic profiles in synthetic test repositories
qualify only those tests.

A finite platform/architecture profile binds the exact Node binary hash, policy
Node/npm versions, fixed `bin/npm-cli.js` entry, and every regular file in the npm
package including bundled dependencies. It records distribution digest/integrity
and an independent provenance-review digest. Complete package inventory and
package name/version must agree; extra, missing, changed or redirected files
refuse. Executable-format inspection joins platform/architecture to the approved
Node bytes; it is not independent publisher authentication. No current-host hash
or reported version can create a profile automatically.

Before interpreting command success, replay verifies these approved bytes, then
requires original `node-version` and `npm-version` schema-1 process records. Their
argv, executable, source, working directory and times are exact; stdout must be
the expected version with one LF or CRLF line ending, and stderr must be empty. Node's probe precedes
npm's probe, and both finish before every clean install. The local collector
runs the same identity check before executing either tool and preserves all
original process results. The profile supplies an independently verified byte
identity; this verifier alone does not collect or authenticate actual execution.

Offline replay resolves retained original paths through the existing evidence
access adapter and reads bytes only. It never executes extracted Node/npm files
or treats their stripped executable modes as original preparation. Retained
process output remains unauthenticated until a trusted controller establishes
its origin; all operational-authority flags remain false.

## Tested emitted outputs

Runtime-proof schema 3 additionally binds `testedEmittedFiles` for the standalone
Functions build, host tests and governed emulator tests. Each of these three
process records uses schema 2 and points by `emittedFilesAfterSha256` to its
complete emitted-file map. The standalone build must finish before host tests,
which must finish before emulator tests. Both test commands rebuild internally,
so all three recorded output maps must equal the final complete emitted bytes.
Later rebuilding different bytes cannot inherit earlier test success. Other
process records and tool version probes remain schema 1. Historical runtime
proofs are not relabelled to satisfy these new joins.

## Windows runtime collection

`collectBusinessRuntime31.cjs` collects local schema-3 evidence from one explicit
JSON input file. Its input names an exact source commit, tree and Functions tree;
a self-contained trusted Git repository; a selected source-approved Node/npm
profile; bound Git, Python and Windows support files; the private attempt path;
the completed-CI lower time bound; and finite process/output limits. Selection
and authentication of the collector, host, tools and CI remain external gates.
The collector does not create an owner decision or authorize deployment.

The attempt path must be new. Complete source blobs are exported into its build
folder, and the approved Node executable and whole npm package are copied into
a private conventional prefix. Private home, temporary, npm-cache and emulator
cache folders keep the child environment independent of user credentials and
configuration. External ancestor `node_modules/.bin` directories are rejected;
a fixed PATH alone is insufficient for nested npm scripts. Real governed
emulator collection requires its exact Java/cache prerequisites and free fixed
ports; it cannot take over an existing owner emulator.

The collector executes the fixed sequence: Node and npm version probes; three
clean installs; npm executable materialization; Functions build, host tests and
governed emulator tests; dependency compatibility; installed runtime inventory;
and five strict audits. Each command runs through the fixed data-only Python
bridge and Windows Job Object supervisor. Child creation assigns the private
kill-on-close job atomically before resume. Completion requires the owned tree
and both captured streams to finish. Timeout, parent loss, cancellation and
capture failure do not leave owned children running.

Original stdout, stderr, process results and failures remain in the attempt.
The first unsuccessful command stops collection without retrying. Known generated
Firebase/Firestore logs are retained in private evidence after the owned process
tree settles, before the unchanged exact-source check; unknown generated files
are not ignored. Build and both test commands each bind the complete emitted
population. All three maps must match the final outputs.

Success is written only after the unchanged `verifyRuntimeProof31` accepts the
original process pointers, command ordering, source identity, installed file
populations, audit outputs and tested emitted files. A completed local measurement
still reports `authenticated: false` and `deploymentAuthorized: false`. Synthetic
collector tests execute real owned processes against explicitly inert source/npm
fixtures; they do not establish real dependency installation, emulator acceptance,
backend deployment or a delivered client upgrade.

The Windows integration test requires an explicit private host configuration at
`BUSINESS31_COLLECTOR_TEST_HOST_CONFIG`, containing absolute `gitExecutable`,
`pythonRoot` and `systemRoot` paths. Its current fixture uses Python 3.13 and
checks the executable, Python DLL, ctypes and libffi files. Missing Windows
configuration fails visibly. Other platforms report the Windows integration as
skipped and cannot establish its acceptance. Test output names the retained
synthetic evidence directory; no fixture or original failed attempt is deleted.
