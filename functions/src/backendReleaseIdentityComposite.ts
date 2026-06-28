import {
  getBackendReleaseIdentityWithDb,
} from "./backendReleaseIdentity";
import type {
  BackendIdentityJsonMap,
} from "./backendReleaseIdentity";

/**
 * Schema-v2 projection of the independently reconstructed production backend.
 *
 * This object intentionally excludes the stale scalar environment snapshot and
 * raw storage-source locations retained in the full release authority record.
 * The full, digest-bound record remains in release/backend-authority.prod.json.
 */
export const COMPOSITE_BACKEND_IDENTITY_V2 = Object.freeze(
{
  "authorityClass": "verified-production-backend-composite",
  "authorityDigest": "8F369ADB7BE04AC64B39E199E668C6841D1B5C0048CBCDA1827D411192AD0CF6",
  "authorityGeneratedAtUtc": "2026-06-28T17:40:14.412521+00:00",
  "authorityStatus": "CURRENT_LIVE_STATE_RECORDED",
  "effectiveFromUtc": "2026-06-28T17:11:15.918470Z",
  "environment": "production",
  "evidenceChain": [
    {
      "filename": "CRM3_Live_Backend_Rules_Parity_Hardened_Hybrid_v7_2_COMPLETE_WITH_FINDINGS_20260628_214116.zip",
      "role": "LIVE_PARITY_AND_FUNCTION_FLEET",
      "sha256": "035EF7B582EE6EAF99C64DC74D7C414FDA4ACA25A986A8E6F6189DE5C506B700"
    },
    {
      "filename": "CRM3_Stage1_Firestore_Rules_Only_Correction_v1_3_PASS_20260628_224300.zip",
      "role": "RULES_ONLY_MUTATION_AND_POST_VERIFICATION",
      "sha256": "8F2F87AD268E528ACE7C2DAD38E618CE0147EDDF4A8746C3637BF7203377B4B2"
    },
    {
      "filename": "CRM3_StageB_Firestore_Rules_Only_Deployment_Governed_v2_PASS_ALREADY_EXACT_NO_MUTATION_20260628_224407.zip",
      "role": "INDEPENDENT_RULES_EXACT_NO_MUTATION_CONFIRMATION",
      "sha256": "151B7437B6235EFE189BCE34B3C4DF83730A84AE52A71284BE312B24FDFE7D1D"
    }
  ],
  "firebaseProjectId": "crm3-baf-ops-b8638",
  "firestore": {
    "databaseId": "(default)",
    "indexes": {
      "allReady": true,
      "deployedCompositeIndexes": 28,
      "fieldOverrideCount": 0,
      "fieldOverrideFingerprint": "4F53CDA18C2BAA0C0354BB5F9A3ECBE5ED12AB4D8E11BA873C2F11161202B945",
      "indexIdentityFingerprint": "AFAB9E0C800AD37F9E90011648C0D322E3DF9CD26C8D9FEC05CAE66A654E8134",
      "sourceCompositeIndexes": 28,
      "sourceSha256": "D0D7120DB00D8FAB3130861776AB6E956CE6E224FB40665B3A28CB1C7B7C7D33",
      "status": "EXACT"
    },
    "rules": {
      "deployedCanonicalSha256": "DE05BE5BE8255351E7482E3D7693FB869DF2436F7A44F57A60D20CA107B3121C",
      "deployedRawSha256": "DE05BE5BE8255351E7482E3D7693FB869DF2436F7A44F57A60D20CA107B3121C",
      "releaseName": "projects/crm3-baf-ops-b8638/releases/cloud.firestore",
      "releaseUpdateTime": "2026-06-28T17:11:15.918470Z",
      "rulesetCreateTime": "2026-06-28T17:11:12.239487Z",
      "rulesetName": "projects/crm3-baf-ops-b8638/rulesets/0b3868bf-d7bb-405b-9a32-eef175b61af7",
      "sourceSha256": "DE05BE5BE8255351E7482E3D7693FB869DF2436F7A44F57A60D20CA107B3121C",
      "status": "EXACT"
    }
  },
  "functionFleet": {
    "entries": [
      {
        "cloudRunRevision": "assignpublishedtemplateversion-00002-xew",
        "entryImplementationSourceSha256": "6AF4338D2E37EA71916190414F3CCAA0A3340C97D32FA311BAEFD4876AE0B5C1",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-06-26T18:42:30.091517185Z",
        "name": "assignPublishedTemplateVersion",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "EXACT"
      },
      {
        "cloudRunRevision": "completeplannedjobexecution-00002-laf",
        "entryImplementationSourceSha256": "13E130181353E7293DF3096CA6C52EF6DF801D3A7C5BDA55C74AB00D7C8D8F3C",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-06-26T18:42:29.640713164Z",
        "name": "completePlannedJobExecution",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "EXACT"
      },
      {
        "cloudRunRevision": "getbackendreleaseidentity-00001-dos",
        "entryImplementationSourceSha256": "6293F7507E49C31BB382D6E6EE259EE14BA2370483EEA302BCFBDFAE771B4264",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-06-19T19:14:45.246337100Z",
        "name": "getBackendReleaseIdentity",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "DIFFERENT"
      },
      {
        "cloudRunRevision": "mutateruntimejobmodulepopulation-00001-voj",
        "entryImplementationSourceSha256": "A53C937CFE89B6BB46F2CD22CDDDF0CFAE6A21C458D2AF01BA57255425126AA9",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-06-26T18:42:25.037518122Z",
        "name": "mutateRuntimeJobModulePopulation",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "EXACT"
      },
      {
        "cloudRunRevision": "onjobassigned-00002-yef",
        "entryImplementationSourceSha256": "7905A190E56EB345BC50798D094FBD783BAD9A727B8E2E8774BB99767950A25A",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-05-16T14:08:37.448337696Z",
        "name": "onJobAssigned",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "DIFFERENT"
      },
      {
        "cloudRunRevision": "onticketcreated-00002-lux",
        "entryImplementationSourceSha256": "7905A190E56EB345BC50798D094FBD783BAD9A727B8E2E8774BB99767950A25A",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-05-16T14:08:37.875767149Z",
        "name": "onTicketCreated",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "DIFFERENT"
      },
      {
        "cloudRunRevision": "onticketresolved-00002-bab",
        "entryImplementationSourceSha256": "7905A190E56EB345BC50798D094FBD783BAD9A727B8E2E8774BB99767950A25A",
        "entryImplementationStatus": "EXACT",
        "functionUpdateTime": "2026-05-16T14:08:37.082900468Z",
        "name": "onTicketResolved",
        "region": "asia-south1",
        "runtime": "nodejs22",
        "strictBundleComparison": "DIFFERENT"
      }
    ],
    "expectedExports": 7,
    "fleetDigest": "D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1",
    "fleetDigestAlgorithm": "SHA-256 of canonical JSON per-function deployment identity and source-comparison status",
    "inventoryFingerprint": "7B036E213817CF668F10CA4FF4992311906BE34295964594EB097AD4AA1CDFC2",
    "liveExports": 7,
    "singleHomogeneousDeployment": false,
    "sourceTargetCompositeDigest": "DA7D78CC6C5D5D77F5B9E97C3789BBCC999C1A51313D62C436BDBB93245A6F29",
    "status": "MIXED_DEPLOYMENT_FLEET"
  },
  "releaseId": "prod-composite-20260628T171115Z-rules-0b3868bf",
  "releaseModel": {
    "functionFleetStatus": "MIXED_DEPLOYMENT_FLEET",
    "identityProjectionStatus": "SCHEMA_V2_SOURCE_ADOPTED_PENDING_DEPLOYMENT",
    "singleHomogeneousDeployment": false,
    "type": "COMPOSITE_LIVE_STATE"
  },
  "repositoryAuthority": {
    "branch": "main",
    "commit": "17f433b93b596e7730b58b337a42733a05f297a3",
    "purpose": "Current governed source target and authority-generation anchor; not a claim that every live Function archive was built from this one commit.",
    "repository": "abhishekvatsa/crm3_baf_ops",
    "tree": "0496b940a20e04ca9789f2ba11b840dca6aeb56c"
  },
  "schemaVersion": 2,
  "sourceAdoption": {
    "allowedChangedPaths": [
      "functions/src/backendReleaseIdentityComposite.ts",
      "functions/src/index.ts",
      "functions/test/backendReleaseIdentityComposite.test.js",
      "release/backend-authority-composite-v2.schema.json",
      "release/backend-authority.prod.json"
    ],
    "baseBranch": "main",
    "baseCommit": "17f433b93b596e7730b58b337a42733a05f297a3",
    "baseTree": "0496b940a20e04ca9789f2ba11b840dca6aeb56c",
    "branch": "feat/stage2b-backend-authority-schema-v2",
    "derivedFromStage2ACandidateDigest": "11BA28BAEC83767C9C195039EA1B321FAC155C41B55963F5CADE9ABBC8C983B3",
    "legacyValidatorRetained": true,
    "productionDeploymentPerformed": false,
    "stage": "Stage2B",
    "status": "SOURCE_ONLY_ADOPTED_PENDING_PR_MERGE_AND_DEPLOYMENT"
  },
  "topology": {
    "eventarcStableIdentityFingerprint": "39A69B23408616CF8299F069401C51D7EE3CBABDA2A4A278A632F7C425F66093",
    "eventarcStatus": "EXACT",
    "eventarcTriggerCount": 3,
    "functionIamFingerprint": "0AE4AEE9E3F1B20AAE441E22FA5A76AA9664A38F95D9AE8E849AACFD55144CA7",
    "functionIamStatus": "EXACT",
    "projectIamFingerprint": "215B6D939C6FBFFA5BE7E0F2EDCCF3EC42BFD693D24DC8B8EC5E8FFEC8937367",
    "projectIamStatus": "EXACT"
  }
}
);

/**
 * Preserve the proven scalar function's authentication, role and Firestore
 * validation path, then replace ambiguous release scalars with an honest
 * composite-fleet projection.
 */
export function buildCompositeBackendReleaseIdentity(
  legacyIdentity: BackendIdentityJsonMap,
): BackendIdentityJsonMap {
  const authority = COMPOSITE_BACKEND_IDENTITY_V2;

  return {
    ...legacyIdentity,

    schemaVersion: authority.schemaVersion,
    authorityClass: authority.authorityClass,
    authorityStatus: authority.authorityStatus,
    authorityDigest: authority.authorityDigest,
    authorityGeneratedAtUtc: authority.authorityGeneratedAtUtc,
    effectiveFromUtc: authority.effectiveFromUtc,
    environment: authority.environment,
    firebaseProjectId: authority.firebaseProjectId,
    releaseId: authority.releaseId,

    // Compatibility keys retained with current, explicitly described semantics.
    backendGitCommit: authority.repositoryAuthority.commit,
    backendGitCommitSemantics:
      "CURRENT_GOVERNED_SOURCE_TARGET_NOT_HOMOGENEOUS_DEPLOYMENT_CLAIM",
    deployedAtUtc: authority.effectiveFromUtc,
    firestoreRulesReleaseId: authority.firestore.rules.rulesetName,
    firestoreRulesDigest: authority.firestore.rules.deployedRawSha256,
    firestoreIndexesSourceDigest: authority.firestore.indexes.sourceSha256,
    deployedIndexesParityStatus: authority.firestore.indexes.status === "EXACT"
      ? "proven"
      : "not-proven",
    functionsDeployedDigest: authority.functionFleet.fleetDigest,
    functionsDigestSemantics:
      "CANONICAL_COMPOSITE_PER_FUNCTION_DEPLOYMENT_IDENTITY_DIGEST",

    releaseModel: authority.releaseModel,
    repositoryAuthority: authority.repositoryAuthority,
    firestore: authority.firestore,
    functionFleet: authority.functionFleet,
    functionFleetDigest: authority.functionFleet.fleetDigest,
    topology: authority.topology,
    evidenceChain: authority.evidenceChain,
    sourceAdoption: authority.sourceAdoption,

    sourceCustody: {
      repositoryAuthority: authority.repositoryAuthority,
      firestoreRulesSourceSha256: authority.firestore.rules.sourceSha256,
      firestoreIndexesSourceSha256: authority.firestore.indexes.sourceSha256,
      functionFleetDigest: authority.functionFleet.fleetDigest,
      functionInventoryFingerprint: authority.functionFleet.inventoryFingerprint,
    },
    legacyScalarProjectionStatus: "SUPERSEDED_BY_SCHEMA_V2",
  } as unknown as BackendIdentityJsonMap;
}

export async function getCompositeBackendReleaseIdentityWithDb(
  args: Parameters<typeof getBackendReleaseIdentityWithDb>[0],
): Promise<BackendIdentityJsonMap> {
  // This call is deliberately retained: it is the existing, already-tested
  // authorization and backend-document validation gate.
  const legacyIdentity = await getBackendReleaseIdentityWithDb(args);
  return buildCompositeBackendReleaseIdentity(legacyIdentity);
}
