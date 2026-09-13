# Build28 current backend closure — recorded 2026-09-13T10:05:19.165Z

The reviewed backend is deployed and verified against source `fc0ac09fc51b370bee419909ad510b044765b540` (Functions tree `0ebe788e9c260dfb95cc07544660ed03f5cdec6b`). This metadata update records that backend result; the latest finalized application remains Build27, `1.0.0-rc.17+27`.

- [Actual deployment closure](../release/evidence/build28-current-source-backend-deployment-closure.json); physical SHA-256 `896881106FD5FE2058F116BFEE72CC7CFCC8F063218B178D8B75F4B817001167`.
- [Immutable deployment approval](../release/approvals/build28-current-source-backend-deployment-approval.json); physical SHA-256 `A4073994A84E1D02926F7A1E4AB90223784795EEAE48B3B8FC06F29836A046A8`, retained at commit `63e0607db39cf4a01b44531e585ea6a6e4ca2426`.
- [functionFleet final readback](../release/evidence/build28-current-source-function-fleet-runtime-identity-readback.json); physical SHA-256 `E7D5466BBF6FCC96AAC3B313320088CE41C439F014E20AC51B34DDA099EB02A7`.
- [iamDependencies final readback](../release/evidence/build28-current-source-functions-iam-dependencies-readback.json); physical SHA-256 `15EDD5A61C589C7484182AA6231A87B60876727F08BB0678A79C46270E77A044`.
- [firestoreRulesAndIndexes final readback](../release/evidence/build28-current-source-firestore-rules-indexes-live-readback.json); physical SHA-256 `2C3C6928B56BDD9641312C8B6CBCB144E077C79CF46EC8FEA06C38EA68D28A60`.

The closure covers all 19 Functions and the approved Rules change. Full indexes and field overrides remain source-exact; no index mutation is asserted. The shared source-authority verifier independently re-adjudicated the actual sealed readbacks and checked the source-bound approval, scoped IAM and Rules deployment evidence.

Rules SHA-256: `9A64BF17BF0B2B7B5953F845ACE164804A59087C33749F8164B4DD715BC90A13`. Indexes: 66, set `E58BEAEF69212C4B00035C120F345D25F962588EE84ACC6D88363CD5EE2D95A4`, file `0479221A5355A9E3E2151B2CCCA7E3A8FFA69B67074A3B50D3A905F70567C800`. Field overrides: 8, set `ADAEEC7F872A42976CB829C899EC037BB4A71C5738060A4A96A5F6293DC9BE60`.

The previous deployed-backend authority is retained in the current-state history. Historical Build27 artifact, device and pilot records remain unchanged. Their recorded acceptance does not establish acceptance of a newly constructed application.

Build28 still requires a fresh governed construction decision, exact source freeze and CI, signing and artifact custody, and physical-device validation of that exact APK. Current-source construction, deployment, distribution and application-runtime permission flags remain false. The nested Rules/index runtime flags record the verified deployed backend state. This update does not authorize or assert recovery-control activation, App Check activation, a new APK, installation, business-flow completion, or pilot handout.

Preparation checkout: `a97ed5d1002aee0569495d8c7a9430e50fe33ef6`, tree `f2dc15d36c92b7f35fad9df264fee7ae3a749b9d`. Recording time follows the actual closure. This document is a current status record and does not replace the retained historical campaign evidence.
