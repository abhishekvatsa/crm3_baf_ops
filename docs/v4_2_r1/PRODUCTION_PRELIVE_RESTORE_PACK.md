# Production Pre-Live Restore Pack

Status: PRIVATE PACK SEALED AND INDEPENDENTLY VERIFIED; LIVE MUTATION NOT AUTHORIZED

## Purpose

The restore pack is the Stage C stop boundary before any production Rules,
indexes, Functions, IAM, data migration or client rollout mutation. It binds
the currently deployed backend and the candidate source without claiming that
code rollback can reverse data already written by a future release.

The private collector is
`tools/release/New-ProductionRestorePack.ps1`. Generated output is written only
under ignored `release_output/` custody and must never be committed.

## Established Cloud State

On 2026-08-02 the dedicated bucket
`gs://crm3-baf-ops-b8638-firestore-restore` was created in `asia-south1` with:

- uniform bucket-level access;
- public access prevention enforced;
- object versioning enabled;
- a 90-day retention policy;
- seven-day soft-delete retention.

No additional IAM grant was added. The standard same-project Firestore service
agent already has the required bucket permissions.

Managed export operation
`projects/crm3-baf-ops-b8638/databases/(default)/operations/ASA3ZTc5MmU4M2ZmOTUtNzdhOS1iZDQ0LWExMDYtY2QzNzc2MWEkGnNlbmlsZXBpcAkKMxI`
completed `SUCCESSFUL` at `2026-08-02T11:00:56.255079Z` with prefix
`gs://crm3-baf-ops-b8638-firestore-restore/pre-live/20260802T110053Z-052fd55`.
It contains three generation-bound objects totaling 229,459 bytes. Creating
the bucket and export did not mutate Firestore documents or application
controls.

## Seal Receipt

The collector was executed from exact `main` commit
`f604c5e1966fc40f4ddd5d4eb75e483d807435eb` after all four jobs in post-merge
`release-gate` run `30747352624` passed. The private pack was sealed at
`2026-08-02T12:25:13.5813244Z` with:

- archive SHA-256
  `0FFB2A1DCD73AFD5C452E8978E21FF96D555FE063D32DC3B054B50229594CE08`;
- manifest SHA-256
  `AE0652127028B54E6386848DB8FA21B2F6E1C7AF4439AAF69D45787CDE30B3EF`;
- 44 manifest-recorded files and 45 archive entries including the manifest;
- all seven deployed production Function source archives;
- all three managed Firestore export objects;
- the exact governed Build 6 package.

An independent verification recalculated both hashes, checked every manifest
entry's size and hash, opened the ZIP, matched the complete disk/archive entry
sets and reverified the Function, export and Build 6 payloads. A second private
custody copy was hash-verified. The privacy-safe repository receipt is
`release/evidence/production-prelive-restore-pack-seal.json`.

An earlier attempt at collector commit `a7e1b0801b8f83e838ba421ec7266011dc7e8d10`
failed closed while handling normal Windows native-command progress output. It
created 12 partial files but no manifest, archive or sidecar, performed no
production mutation, and was corrected by PR #108 before the successful seal.

## Collector Boundary

The collector requires all of the following:

- exact clean `main` equal to freshly fetched `origin/main` and the supplied
  commit from the expected repository;
- explicit successful `release-gate` push run IDs for that exact commit, with
  the complete four-job inventory;
- the exact successful managed-export operation and prefix above;
- the governed Build 6 package with SHA-256
  `E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E`;
- the exact seven active production Functions;
- the exact retained bucket safety settings.

It then captures:

1. a Git source archive, Git bundle and commit record;
2. successful fresh-checkout CI receipts;
3. active Rules source/release, database and composite-index inventories;
4. full Function descriptions and generation-pinned deployed source archives;
5. the completed Firestore operation, bucket policy and the exact export-object
   inventory, with generation, size, cloud MD5 and local SHA-256 custody;
6. the governed Build 6 package and finalization evidence;
7. a stop/rollback guide;
8. a SHA-256 manifest, ZIP and sidecar.

The script contains no export, import, deployment, deletion, bucket-creation or
IAM-mutation command. It consumes the existing export and performs readback and
download only.

## Execution

For an explicitly authorized future refresh, execute from exact clean `main`
after its post-merge CI run succeeds:

```powershell
.\tools\release\New-ProductionRestorePack.ps1 `
  -ExpectedMainCommit <exact-post-merge-main> `
  -CiRunIds <successful-post-merge-run-id> `
  -ExportOperationName 'projects/crm3-baf-ops-b8638/databases/(default)/operations/ASA3ZTc5MmU4M2ZmOTUtNzdhOS1iZDQ0LWExMDYtY2QzNzc2MWEkGnNlbmlsZXBpcAkKMxI' `
  -ExportPrefix 'gs://crm3-baf-ops-b8638-firestore-restore/pre-live/20260802T110053Z-052fd55' `
  -Build6PackagePath <private-custody-governed-package>
```

The generated archive is private because it contains the production Firestore
export and deployed Function source packages. Only a privacy-safe receipt with
hashes and non-secret control metadata may enter the repository.

## Rollback Limits

Rules and individual Functions can be restored from the sealed pack only after
a separate live rollback decision. Additive indexes are not removed
automatically. The Firestore export must first be import-rehearsed in an
isolated recovery target; production import or reset requires separate explicit
authority and a collision plan.

`STAGE2D-F4`, `P-07` and pilot handout remain open after the pack is sealed.
