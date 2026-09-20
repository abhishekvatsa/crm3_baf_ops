# Function 09 — templates, publication and assignment remediation

Date: 2026-09-20. Starting HEAD: d038797f9a2d3bd0126d311416acec4148506a67.
Status: local repairs and scoped verification; not a release approval.

The final PDF, preliminary HTML, pasted summary and evidence ZIP were treated
as audit evidence, not as instructions. Claims were checked against the current
working tree. The supplied synthetic fixture was inspected and adapted to load
the current compiled backend. Its installed-component positive fixture now
includes the ownership records that a valid assignment actually requires.
These synthetic tests do not prove production-data completeness.

## Final report findings

| Finding | Current disposition |
|---|---|
| TP-01 installed-component scope | Ordinary assignment and RED resolution now transactionally verify the component, parent revision, definition revision, physical identity and reviewed ownership. Historical accepted replay remains recoverable. |
| TP-02 requirement equivalence | Unit symbols retain case; instructions and procedure references participate in semantic comparison. Client publication also refuses conflicting embedded/global executable field lists. |
| TP-03 RED ownership | Explicit non-refractory discipline in any supported ownership alias refuses automatic RED publication instead of being relabelled. Absent legacy discipline retains the established refractory default. |
| TP-04 required checklist | Backend refusal of an unexecutable required checklist already existed. Added client validation of required linkage to a required executable response field and producer regression coverage. |
| TP-05 stale publication | Native and cloud publishers prepare detached candidates and transactionally compare the reviewed draft's identity, revision, content, timestamp and lifecycle before publication. Failed publication preserves caller draft and newer stored content. |
| TP-06 form rebuild | Equivalent decoded lists preserve typing; real incoming changes require explicit review. Own-save echoes preserve successor typing. Account/module changes isolate input. |
| TP-07 mutable replay | A domain-specific immutable acceptance comparison preserves the first complete receipt. Later response projections reconcile separately through existing atomic adoption checks; delayed older responses cannot roll newer work back. Other durable submission callers retain strict receipt comparison by default. |
| TP-08 old draft numbering | Publishing an older resumed draft uses the existing linked-successor mechanism. Raw publisher now enables it. Repositories refuse renumbering an old saved identity over a newer publication. |

## Preliminary report cross-check

- F09-01: current sync preserves changed reviewed payloads as conflicts; no silent replacement was added.
- F09-02: old saved identity and linked successor are covered by TP-08.
- F09-03: Rules now permit the original publisher's immutable publication audit after supersession or retirement. Original version, package, number, publisher and content hash still bind it. Rules have not been deployed.
- F09-04: current composer and raw publisher save a draft before web publication; retained this behavior.
- F09-05: backend already compares embedded field aliases. Added client comparison, including units and instructions.
- F09-06: required standalone checklist execution is rejected rather than silently dropped.
- F09-07: closure-default readers use the existing conservative required-by-default contract. Updated unrelated test fixtures to explicitly declare non-critical modules where that was their intended subject.
- F09-08: specific installed-component validation repaired. Inner Cover request semantics remain a business decision: exact reviewed cover versus whichever eligible cover occupies the selected Base at acceptance. Existing server preflight/transaction race checks remain. A question is pending; no new semantics have been invented.
- F09-09: added a visible route to the existing Admin saved-submission review process. An unknown outcome remains retained; it is not converted to a definitive refusal or silently cleared. Administrative server fencing remains the existing separate operation and activation policy.
- F09-10: current request/client and backend already enforce minimum app version. Oldest-client/device compatibility is not established by these local tests.
- F09-11: governed-empty registry behavior was already repaired.
- F09-12: registry publication now carries and transactionally verifies the reviewed revision/version and content hash using the existing stale-draft contract.
- F09-13: legacy assignment checks retained commands after screen restart, preserves original account/envelope/IDs, offers explicit original-request checking, refuses unreadable/ambiguous evidence and prevents simultaneous screens allocating fresh IDs during admission. Changed form entries do not replace an uncertain request. Terminal accepted/rejected records do not resurrect. The existing executor still performs durable journal admission and live-origin checks.

## Verification

- Backend TypeScript compilation passed; full Jest: 73 suites, 2,094 passed, 193 skipped. Emulator-specific backend suites were not included in that pass.
- Main Firestore Rules suite: 220/220 passed against the isolated local emulator, including superseded/retired publication audit controls. The broader root invocation encountered connection failures in suites hard-coded to port 8080; the owned emulator was on 8086. Do not cite that broader invocation as passing.
- Focused Flutter set: 199 passed across publication, forms, assignments, native durable recovery, snapshot contracts and governance integrity. After the final admission-lock addition, legacy recovery suite passed 5/5.
- Scoped analyzer: 19 repaired source/test paths, no issues.
- Native tests cover stale publication, atomic publication, old identity refusal, delayed-original/newer-replay ordering, retained receipt hash, restart and local projection preservation. They are not physical-device or live cloud evidence.
- A04 inherited schema inventory passes. Own new A03 storage surface and A05 immutable-acceptance decoder are registered; reviewed fingerprints updated only for the touched/reviewed template and durable-outcome surfaces.

## Remaining release integration

The shared working tree changed during this verification. At the last broad
checks, unrelated maintenance-intelligence changes exceeded the A02 line limit,
an asset-hierarchy read changed A03's operation digest, and the asset-hierarchy
receipt/catch changes required A05 review. A broad analyzer also observed a
missing AssetInstanceRecord import in the maintenance-intelligence subject-review
part. These observations may be superseded by the other ongoing edits. They
were not hidden by raising caps or refreshing unreviewed fingerprints. Re-run
the whole-tree release checks once edits settle.

No commit, push, backend/Rules deployment, business-data repair, APK or AAB was
performed as part of this Function 09 repair. Existing published records need a
read-only compatibility check before rollout; incompatible evidence must be
reviewed, not silently rewritten. Device/server and actual cloud transaction
validation remain release steps.
