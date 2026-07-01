import {
  getBackendReleaseIdentityWithDb,
} from "./backendReleaseIdentity";
import type {
  BackendIdentityJsonMap,
} from "./backendReleaseIdentity";

export type IdentityDeploymentBindingStatus =
  | "SOURCE_DEFINED_PENDING_DEPLOYMENT"
  | "SCHEMA_V2_DEPLOYED_EXACT"
  | "DEPLOYMENT_CONFIGURATION_MISMATCH";

export interface IdentityDeploymentBinding {
  status: IdentityDeploymentBindingStatus;
  observedSchemaVersion: string | null;
  observedAuthorityDigest: string | null;
  observedReleaseId: string | null;
  identityFunctionDeployedSourceCommit: string | null;
  mismatches: ReadonlyArray<string>;
}

const EXPECTED_SCHEMA_VERSION = "2";
const EXPECTED_AUTHORITY_DIGEST =
  "59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525";
const EXPECTED_RELEASE_ID =
  "prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd";
const SOURCE_COMMIT_PATTERN = /^[a-f0-9]{40}$/;

export const COMPOSITE_BACKEND_IDENTITY_V2 = Object.freeze(
{
  "schemaVersion": 2,
  "authorityClass": "verified-production-backend-composite",
  "authorityDigest": "59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525",
  "releaseId": "prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd",
  "environment": "production",
  "firebaseProjectId": "crm3-baf-ops-b8638",
  "productionReconstructionSourceCommit": "17f433b93b596e7730b58b337a42733a05f297a3",
  "mixedFleetDigest": "D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1",
  "firestoreRulesDigest": "DE05BE5BE8255351E7482E3D7693FB869DF2436F7A44F57A60D20CA107B3121C",
  "firestoreRulesReleaseId": "projects/crm3-baf-ops-b8638/rulesets/0b3868bf-d7bb-405b-9a32-eef175b61af7",
  "firestoreIndexesSourceDigest": "D0D7120DB00D8FAB3130861776AB6E956CE6E224FB40665B3A28CB1C7B7C7D33",
  "runtimeIamPosture": "OVER_PRIVILEGED_DEFAULT_COMPUTE_SERVICE_ACCOUNT",
  "runtimeServiceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
  "functionFleet": {
    "status": "MIXED_DEPLOYMENT_FLEET",
    "singleHomogeneousDeployment": false,
    "entries": [
      {
        "name": "assignPublishedTemplateVersion",
        "cloudRunRevision": "assignpublishedtemplateversion-00002-xew",
        "deployedArchiveSha256": "B7E773CB5C5BDE8E050C3F02EBC3AAA523710562CC91D8B87B37B44FB40689FD",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "EXACT",
        "entryImplementationStatus": "EXACT"
      },
      {
        "name": "completePlannedJobExecution",
        "cloudRunRevision": "completeplannedjobexecution-00002-laf",
        "deployedArchiveSha256": "B7E773CB5C5BDE8E050C3F02EBC3AAA523710562CC91D8B87B37B44FB40689FD",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "EXACT",
        "entryImplementationStatus": "EXACT"
      },
      {
        "name": "getBackendReleaseIdentity",
        "cloudRunRevision": "getbackendreleaseidentity-00001-dos",
        "deployedArchiveSha256": "121FD191C5324B5857B494C774134C0C7F5CA51624AA3DA83797730E26E2965F",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "DIFFERENT",
        "entryImplementationStatus": "EXACT"
      },
      {
        "name": "mutateRuntimeJobModulePopulation",
        "cloudRunRevision": "mutateruntimejobmodulepopulation-00001-voj",
        "deployedArchiveSha256": "B7E773CB5C5BDE8E050C3F02EBC3AAA523710562CC91D8B87B37B44FB40689FD",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "EXACT",
        "entryImplementationStatus": "EXACT"
      },
      {
        "name": "onJobAssigned",
        "cloudRunRevision": "onjobassigned-00002-yef",
        "deployedArchiveSha256": "818BBA58521A18DE07113802C7C533181DA3760EF1CDBCB490A461650C7FAC5F",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "DIFFERENT",
        "entryImplementationStatus": "EXACT"
      },
      {
        "name": "onTicketCreated",
        "cloudRunRevision": "onticketcreated-00002-lux",
        "deployedArchiveSha256": "818BBA58521A18DE07113802C7C533181DA3760EF1CDBCB490A461650C7FAC5F",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "DIFFERENT",
        "entryImplementationStatus": "EXACT"
      },
      {
        "name": "onTicketResolved",
        "cloudRunRevision": "onticketresolved-00002-bab",
        "deployedArchiveSha256": "818BBA58521A18DE07113802C7C533181DA3760EF1CDBCB490A461650C7FAC5F",
        "serviceAccountEmail": "894346496105-compute@developer.gserviceaccount.com",
        "strictBundleComparison": "DIFFERENT",
        "entryImplementationStatus": "EXACT"
      }
    ]
  }
}
);

function normalizedEnvironmentValue(
  environment: NodeJS.ProcessEnv,
  key: string,
): string | null {
  const value = environment[key]?.trim();
  return value == null || value.length === 0 ? null : value;
}

export function evaluateIdentityDeploymentBinding(
  environment: NodeJS.ProcessEnv,
): IdentityDeploymentBinding {
  const observedSchemaVersion = normalizedEnvironmentValue(
    environment,
    "BACKEND_AUTHORITY_SCHEMA_VERSION",
  );
  const observedAuthorityDigest = normalizedEnvironmentValue(
    environment,
    "BACKEND_AUTHORITY_DIGEST",
  );
  const observedReleaseId = normalizedEnvironmentValue(
    environment,
    "BACKEND_AUTHORITY_RELEASE_ID",
  );
  const identityFunctionDeployedSourceCommit = normalizedEnvironmentValue(
    environment,
    "BACKEND_IDENTITY_DEPLOYED_SOURCE_COMMIT",
  );

  const observed = [
    observedSchemaVersion,
    observedAuthorityDigest,
    observedReleaseId,
    identityFunctionDeployedSourceCommit,
  ];
  if (observed.every((value) => value == null)) {
    return {
      status: "SOURCE_DEFINED_PENDING_DEPLOYMENT",
      observedSchemaVersion,
      observedAuthorityDigest,
      observedReleaseId,
      identityFunctionDeployedSourceCommit,
      mismatches: [],
    };
  }

  const mismatches: string[] = [];
  if (observedSchemaVersion !== EXPECTED_SCHEMA_VERSION) {
    mismatches.push("BACKEND_AUTHORITY_SCHEMA_VERSION");
  }
  if (observedAuthorityDigest !== EXPECTED_AUTHORITY_DIGEST) {
    mismatches.push("BACKEND_AUTHORITY_DIGEST");
  }
  if (observedReleaseId !== EXPECTED_RELEASE_ID) {
    mismatches.push("BACKEND_AUTHORITY_RELEASE_ID");
  }
  if (
    identityFunctionDeployedSourceCommit == null ||
    !SOURCE_COMMIT_PATTERN.test(identityFunctionDeployedSourceCommit)
  ) {
    mismatches.push("BACKEND_IDENTITY_DEPLOYED_SOURCE_COMMIT");
  }

  return {
    status: mismatches.length === 0
      ? "SCHEMA_V2_DEPLOYED_EXACT"
      : "DEPLOYMENT_CONFIGURATION_MISMATCH",
    observedSchemaVersion,
    observedAuthorityDigest,
    observedReleaseId,
    identityFunctionDeployedSourceCommit,
    mismatches,
  };
}

/**
 * The legacy helper remains the mandatory authentication, role and Firestore
 * validation gate. This projection replaces ambiguous scalar release identity
 * only after that gate succeeds.
 */
export function buildCompositeBackendReleaseIdentity(
  legacyIdentity: BackendIdentityJsonMap,
  environment: NodeJS.ProcessEnv = process.env,
): BackendIdentityJsonMap {
  const authority = COMPOSITE_BACKEND_IDENTITY_V2;
  const binding = evaluateIdentityDeploymentBinding(environment);

  return {
    ...legacyIdentity,
    schemaVersion: authority.schemaVersion,
    authorityClass: authority.authorityClass,
    authorityDigest: authority.authorityDigest,
    environment: authority.environment,
    firebaseProjectId: authority.firebaseProjectId,
    releaseId: authority.releaseId,

    // This compatibility field is identity-Function-specific only. It is null
    // until an exact deployment binding supplies the deployed source commit.
    backendGitCommit: binding.status === "SCHEMA_V2_DEPLOYED_EXACT"
      ? binding.identityFunctionDeployedSourceCommit
      : null,
    backendGitCommitScope:
      "IDENTITY_FUNCTION_DEPLOYED_SOURCE_COMMIT_ONLY",
    productionReconstructionSourceCommit:
      authority.productionReconstructionSourceCommit,
    identityFunctionDeployedSourceCommit:
      binding.identityFunctionDeployedSourceCommit,
    mixedFleetDigest: authority.mixedFleetDigest,

    firestoreRulesReleaseId: authority.firestoreRulesReleaseId,
    firestoreRulesDigest: authority.firestoreRulesDigest,
    firestoreIndexesSourceDigest:
      authority.firestoreIndexesSourceDigest,
    deployedIndexesParityStatus: "proven",
    functionsDeployedDigest: authority.mixedFleetDigest,
    functionsDigestSemantics: "MIXED_FUNCTION_FLEET_DIGEST",

    identityProjectionStatus: binding.status,
    identityDeploymentBinding: binding,
    releaseModel: {
      type: "COMPOSITE_LIVE_STATE",
      singleHomogeneousDeployment: false,
      functionFleetStatus: authority.functionFleet.status,
      identityProjectionStatus: binding.status,
    },
    functionFleet: authority.functionFleet,
    functionFleetDigest: authority.mixedFleetDigest,
    runtimeIam: {
      posture: authority.runtimeIamPosture,
      serviceAccountEmail: authority.runtimeServiceAccountEmail,
      leastPrivilegeRemediationAuthorized: false,
    },
    legacyScalarProjectionStatus: "SUPERSEDED_BY_SCHEMA_V2",
  } as unknown as BackendIdentityJsonMap;
}

export async function getCompositeBackendReleaseIdentityWithDb(
  args: Parameters<typeof getBackendReleaseIdentityWithDb>[0],
): Promise<BackendIdentityJsonMap> {
  const legacyIdentity = await getBackendReleaseIdentityWithDb(args);
  return buildCompositeBackendReleaseIdentity(legacyIdentity, process.env);
}
