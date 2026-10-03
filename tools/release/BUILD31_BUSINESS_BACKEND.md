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
