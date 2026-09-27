# Local business journey checks

`http_journey.py` signs real test users into the Auth emulator, submits business
commands to the Functions emulator over HTTP, and checks Firestore readback.
Approved-user readback also exercises the deployed local Firestore Rules. It
does not import backend handlers or replace services with success fakes.

Start the normal development emulator suite, finish any backend build, then run
from the repository root:

```powershell
python tool/dev/http_journey.py --output tmp/http-journey/latest.json
```

Use `--groups quality,directives,workflow` to run selected scenarios. The default
also includes `authority,inner_covers,burners,templates,inspections,manual_condition,maintenance_cadence`. Each run
creates new `hj-...` fixture identities. Auth users, fixtures, generated business
records, and acceptance evidence remain available for inspection. The script
never clears a database or modifies the existing development account. It accepts
only `demo-` project IDs and literal loopback addresses on the development ports
9099, 8080, and 5001. Master-data/user setup uses the emulator owner credential;
every business command uses the signed-in test user's token.

The JSON report includes each assertion, timing, persisted document paths,
endpoint/operation/role outcomes, original intent IDs, and any failure. Tokens and passwords are never
included. A failed run exits nonzero. Functions must not be rebuilt concurrently:
the build intentionally removes emitted output before replacing it, and emulator
workers loading during that interval can fail.

| Group | Persisted journeys and boundaries |
| --- | --- |
| `quality` | Governed abnormality creates a visible Quality warning; Operations records required/completed RA; SI decides; Admin reopens/corrects while retaining physical RA. Monitoring correction preserves original context, cancellation remains distinct from completion, and completed monitoring has bounded recent visibility. |
| `directives` | Admin issues/amends; recipient acknowledges current wording and completes; changed wording invalidates old acknowledgement. Historical creation replay preserves completion. |
| `workflow` | Mechanical and Instrumentation act on their own maintenance lanes. SI adds a lane without losing previous work, completes the Operations lane under current policy, and resolves coordinated work. Critical alarms progress through response support to resolution. |
| `authority` | Admin revokes and restores the run's own Operations actor; revoked/self-restoring/stale requests fail; replay of a historical revocation preserves later restoration. |
| `inner_covers` | Registration, inspection acceptance, installation with consistent serial/Base/linkage custody, physical removal invalidating assurance, and fresh reinspection retaining audit evidence. |
| `burners` | Eight-position full round, partial update retaining original observation time/source/observer for untouched fields with inherited provenance, stale refusal, and historical retry after another survey. |
| `templates` | SI assigns a published governed custom template; execution, frozen modules and receipt are persisted together. Exact retry preserves their identities; changed intent on the same request is refused. Template publication itself is fixture setup. |
| `inspections` | Actual definition, campaign, adverse observation and finding. Missing evidence/unaccounted findings block closure; reviewed corrective linkage permits survey closure while repair and finding remain unresolved. Historical retry retains closure; adverse evidence cannot certify resolution. |
| `manual_condition` | Explicit reviewed replacement of manual Down/Unfit evidence, refusal to silently replace current evidence, and retirement preserving unresolved assessment history. |
| `maintenance_cadence` | Different clocks within the same Indian plant day create a review-required conflict with no invented due date. A later unambiguous physical service establishes a new basis while earlier conflicting records remain; adjudication of the old conflict is not exercised. |
| `morning_review` | Explicit opt-in daily meeting; attendance, entry, role reassignment, completion, audited reopening/cancellation, finalization and unchanged frozen minutes on retry. |

Every run also verifies an approved server clock, unapproved clock refusal and
the actual Firestore event trigger's synchronization timestamp. The modules
`http_journey_operations.py` and `http_other_domains.py` keep domain recipes
separate from shared transport and reporting.

Morning Review uses the plant day's actual singleton ID. Run it explicitly only
when that day's local meeting is absent:

```powershell
python tool/dev/http_journey.py --groups morning_review --output tmp/http-journey/morning-review.json
```

It preserves any existing session, leaves clearly labelled development minutes
finalized, and never resets the daily singleton. Admin can open the test outside
the SI start window; the out-of-window SI refusal is checked when applicable.

Fixture masters include the metadata required by the phone's strict readers.
Each run deliberately leaves evidence available. Repeated runs create multiple
active legacy-mapped fixture asset classes; legacy-only selection can then be
ambiguous in other journeys. Use a disposable emulator data snapshot for broad
repeat testing, or retire only recorded test fixtures deliberately after review.
The published-template scenario uses a unique governed custom class and does not
change existing mappings to avoid this ambiguity.

These checks establish local backend/Rules integration, including role refusal,
stale evidence, exact retry and historical acceptance. They do not establish the
Android screen journey, local saved-work recovery after process death, production
IAM/App Check/notifications, or release-build behavior. Unit and database-emulator
tests provide deeper domain coverage; device journeys remain complementary.

The final September 26 consolidated run recorded 104 passing checks in
`output/dev-business-validation-20260926/http-business-journeys-complete.json`.
It includes the earlier 78-check run and the inspection, manual-condition and
cadence extensions; their earlier reports are retained, not additional unique
coverage counts. The
separate Morning Review report records 19 verified checks (including four
duplicated setup/synchronization checks). Its final assertion was corrected from
`summary` to the actual `finalSummary` contract and verified by replaying the
original accepted finalization; the report records this correction explicitly.
The separate inspection run recorded eight passing business checks plus setup in
`output/dev-business-validation-20260926/http-inspection-journey.json`.

## Issue-origin Quality journey

`http_issue_quality_journey.py` starts by raising a Maintenance issue with
suspected Quality impact. It uses real Auth sign-in, the
`executeMaintenanceWorkflowCommandV2` and `mutateChargeAbnormalityV2` callable
endpoints, and persisted Firestore readback, including approved-user Rules reads.
Run it separately from the repository root after the emulator suite and backend
build are ready:

```powershell
python tool/dev/http_issue_quality_journey.py --project demo-crm3-baf-ops --charge 91341 --output tmp/http-journey/issue-quality-latest.json
```

The September 26 run passed **15/15 checks**: one fixture setup check and fourteen
business checks, using **21 actual callable requests**, including retries and
expected refusals. Its evidence is
`output/dev-business-validation-20260926/http-issue-quality-journey.json`, with
fixture prefix `hj-20260926154439-eaf8d4`. These are separate results from the
104-check consolidated run, the Morning Review report, and earlier retained
reports; they are not a revised consolidated total.

The verified transitions and boundaries are:

- Operations raises an issue, atomically creating its Quality warning and linked
  pending abnormality. SI adjudicates the coil acceptable: the warning closes,
  RA becomes `notRequired`, and the physical Maintenance issue remains open.
- A second issue on the same source charge creates a separate pending case.
  Operations declares RA required, then records completion against charge
  `91342`. This moves the warning to review (`closureRequested`); SI closes it
  using that recorded RA charge. Its physical Maintenance issue also remains open.
- Two independent abnormalities on the same source charge `91341`, one with
  `notApplicable` RA and one with completed RA against `91343`, each retain their
  own open warning. Their creation preserves both earlier issue decisions and
  evidence. A shared charge number does not merge case identities: issue warnings
  use `issue_<ticketId>` with abnormality `issue_quality_<ticketId>`, while direct
  abnormality warnings use `abnormality_<abnormalityId>`.
- The server refuses an unapproved issue creator, missing suspected-Quality
  classification, Operations attempting formal adjudication, non-RA adjudication
  while RA is required, the source charge reused as the resulting RA charge, and
  an adjudicator substituting a different charge for recorded RA. Refusals preserve
  the inspected business records. Exact retries preserve accepted creation,
  completion, and adjudication results.

Each run creates distinct prefixed actors and full-reader fixtures using its own
governed custom class without a legacy Base/Furnace mapping. It leaves the records
available for inspection and does not alter existing development accounts. This
standalone scenario does not include the shared suite's clock checks. Its results
establish local backend/Rules behavior, not a completed phone journey.

To prepare the separate stable SI account for a phone journey, run:

```powershell
python tool/dev/seed_quality_phone_actor.py
```

This creates or verifies `dev.quality-si@example.invalid` with development password
`emulator-local-only`, verified email, and a complete approved profile with exactly
`[si]` roles. It is restricted to `demo-crm3-baf-ops` and fixed literal-loopback
Auth/Firestore addresses. Existing identity or role mismatches are refused rather
than overwritten. The helper verifies password sign-in and a token-authenticated
profile Rules read, prints no tokens, and leaves the default Operations account
and all business records untouched. Initial creation and repeat reuse were both
verified; this is fixture setup evidence only.
