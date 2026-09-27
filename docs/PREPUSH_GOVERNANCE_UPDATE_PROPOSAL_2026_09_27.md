# Proposed source-inventory update — 27 September 2026

Status: **approved and applied**. After reviewing the exact three-file proposal,
the user replied “do what you think is suitable,” authorizing this bounded update.
Automatic approval review had previously rejected the changes pending that
explicit approval. The exact reviewed diff is
`.dart_tool/prepush-governance-proposal.patch` (local, ignored artifact).

The applied source-inventory update changes only:

- `governance/a04-persisted-schema-v1.json`
- `tools/v4/v4_2_r1_canonical_audit.py` (current A-03/A-04 source inventory checks)
- `test/a04_persisted_schema_contract_test.dart` (exact inherited decoder count)

## Reviewed additions

The existing A-05 source inventory already classifies these three new surfaces.
The proposal makes A-04 inherit those exact classifications:

| Surface | Persisted evidence and rejection boundary |
| --- | --- |
| `abnormality-structured-assessment` / `AbnormalityAssessment` and `CandidateProcessCause` | Versioned observation, candidate causes, explicit RA occurrence and post-RA evidence. Unknown keys/enums, duplicate cause IDs and malformed dates/text are rejected. Confirmation and assessed results require evidence; missing historic occurrence dates remain unknown. |
| `maintenance-component-identification` / `MaintenanceComponentIdentification` | Versioned governed component identity on the original physical asset, with actor/time/basis. Malformed structured context fails closed. Pre-feature opaque metadata remains preserved, without becoming component authority. |
| `template-closure-review-chronology` / closure-review helpers | New drafts require fresh review after creation; inherited review is cleared on the successor while predecessor history remains intact. Strict template validation remains required before persistence. |

Two existing inherited descriptions are also synchronized with their approved
A-05 definitions: the user-profile decoder now explicitly rejects malformed
nested authority reason fields, and audit read failures expose incomplete history
with retained local rows rather than presenting local-only history as complete.
Their regression references are additive.

## Exact measured inventory

| Inventory | Previous assertion | Proposed exact assertion |
| --- | --- | --- |
| A-03 operations | 629 | 629 |
| A-03 sites / classified files | 2,191 / 84 | 2,201 / 86 |
| A-04 schema fields | 55 | 55 |
| A-04 JSON strings / dynamic values | 49 / 6 | 49 / 6 |
| A-04 extension bags / registered extension keys | 3 / 0 | 3 / 0 |
| A-04 inherited decoder surfaces | 123 | 126 |

Current measured A-03 digest:
`CECD44B3F5AFA93D052BC83F90CA14B34E7C2A17A0783DB5D06DEAD082A9B53C`.

Current measured A-04 digest:
`121CC1499DAFFE6CDFF5BA681E6F89C6826681D8E8C4378D5759A7C5BA4EA3DA`.

Inherited A-05 manifest canonical text SHA-256:
`62742297740653888E7A03F504AAAA45467FC6F3F3F501937BE857F29AC7DECA`.

The A-03 classified-file increase comprises the read-only abnormality cause
evidence reader and the read-only Base–Inner Cover register provider. The form's
direct Firestore lookup was moved into the former service, retaining the same
server-only query and selection rules. Existing authority profiles and existing
store/access classifications were preserved.

## Preserved constraints and verification

All 55 A-04 field policies remain byte-for-byte equivalent as decoded JSON. The
extension policy remains unchanged: zero registered fields, no authority or
business-invariant extensions, and fail-closed handling of unknown present keys.
No source ceiling is increased. Exact current-source assertions remain exact;
the proposal does not replace them with ranges or bypass inventory enforcement.

The A-02/A-03 inventory contracts and affected runtime tests passed locally. The
pre-update A-04 discovery reported only inventory digest drift, inherited A-05
manifest drift and inherited decoder surface drift. Its generated field policies
were identical to the retained manifest. After applying the approved patch, the
governed A-04 tool passed with 55 fields, 126 inherited decoder surfaces and no
failures (`.dart_tool/prepush-a04-final.json`). The final Flutter contract and
canonical post-codegen audit remain separate validation steps.

This proposal does not edit historical build approvals, deployed-source receipts,
release authority, production permissions, source ceilings, or deployment state.
Separate release-authority failures remain independently reportable. It grants no
production build, deployment or distribution approval.
