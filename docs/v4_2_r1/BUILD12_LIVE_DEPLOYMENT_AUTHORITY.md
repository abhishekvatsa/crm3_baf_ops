# Build 12 live deployment authority

## Decision

The Build 12 backend, runtime IAM, Firestore Rules and Firestore indexes are
deployed and independently read back in production. This authority does not
authorize a pilot handout, unrestricted distribution or App Check activation.

## Exact bindings

- operator deployment authority: `BAF-FIREBASE-DEPLOY-012`
- Build 12 live-deployment authority: `ce2a85acc9eca322dc1288c1df600d4c84f0e738`
- Build 12 live-deployment tree: `84bba6dcb204c141924450a149d84cd7a92a00de`
- deployed Functions authority: `08ee9eb70c930204f942d1094eb9257ef1e192c5`
- exact application post-merge release gate: `32083536385`
- production project: `crm3-baf-ops-b8638`
- region: `asia-south1`

The Functions source and dependency manifests are unchanged between the
deployment commit and the Build 12 live-deployment authority. Later source changes
in this interval are confined to Firestore Rules, Rules tests and governance
records.

The deployment authority is recorded at
`release/approvals/build12-backend-rules-indexes-deployment-authorization.json`.
It transparently records a pre-existing project-owner instruction after the
deployment event; it is not backdated and does not claim independent approval.

## Live outcomes

- all 15 required second-generation Functions are active;
- every Function uses its governed runtime identity;
- Default Compute is build-only and has no Editor role;
- the Build 12 Firestore Rules are byte-exact at 160,754 bytes with SHA-256
  `ED6D3E0A67E7C2353BE0B691594E27EEC230596155EAA4365DDA97EBCDB6D87A`;
- all 61 declared indexes match the CLI and Firestore API inventories;
- all 61 indexes report `READY`.

Google's Rules `projects:test` endpoint returned HTTP 503 during the release
window. After three standard CLI attempts, the governed fallback used the
official `rulesets.create` compiling boundary. That boundary accepted the exact
file on its fourth bounded attempt. Although the subsequent release update
returned a 503 response, immediate and independent live readback proved that
the new ruleset became active and was byte-exact. No policy was weakened.

## Evidence custody

The complete external receipts remain outside the repository. The privacy-safe
authority record at `release/build12-live-deployment-authority.json` preserves
their file hashes, internal receipt hashes, decisions, source bindings, counts
and authority limits without retaining user data, business data or operator
identity.

## Remaining boundary

Build 12 is still unsigned and absent from the device. The remaining sequence
is remote production signing and finalization, followed by an in-place physical
device upgrade that preserves application data and proves the successor
features and UI. The signed artifact will be bound separately to the exact
evidence-merge dispatch commit. Pilot handout remains separately prohibited.
