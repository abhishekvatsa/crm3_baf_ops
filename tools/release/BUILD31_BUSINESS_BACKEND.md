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
contract. Schema 1 preparation records remain readable for their original
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
version does not change decision, runtime-proof or descriptor schema versions.

`captureBusiness31PreparedInputs.cjs`, `captureBusiness31PreparedHook.cjs` and
`business31CaptureSession.cjs` retain prepared package inputs and the request
transcript. The session enforces phase order and once-only use, refuses further
work after failure, and restores only hooks that it still owns. A persistence
failure or foreign hook change is retained as a failure, not reported as a
successful deployment. Exact dependency hashes use the repository's canonical
LF bytes; verification never normalizes or accepts alternate hashes.

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

New source containing `business31NpmBinMaterialization.cjs` requires runtime-proof
schema 2. Its fixed producer belongs to the complete verifier/source population.
The older schema-1 link-free records remain historical evidence under their
original verifier/source snapshots; they cannot downgrade new source to omit this
step. Never rewrite an old record as a schema-2 success.

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

The producer replaces each verified POSIX alias with a deterministic regular
0755 shell launcher. That launcher invokes the exact bound Node executable and
the original package script with unchanged arguments; it does not copy JavaScript
into `.bin`. The original target must have owner-execute permission and its bytes
and recorded mode remain unchanged. The receipt retains the original lexical
link, owning package declaration/hash, target/hash/mode, generated launcher/hash/
mode, complete before/after file commitments and counts. All non-alias bytes stay
unchanged. Unsupported materialization leaves a failed, retained preparation;
there is no success receipt or automatic retry.

Runtime-proof schema 2 adds the pointed materialization receipt and the root
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
