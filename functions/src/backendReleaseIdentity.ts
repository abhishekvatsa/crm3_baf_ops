import {canonicalApprovedUserAuthority} from "./userAuthority";

export type BackendIdentityJsonMap = {[key: string]: unknown};

export type BackendIdentityFirestoreLike = {
  collection: (name: string) => {
    doc: (id: string) => {
      get: () => Promise<{
        exists: boolean;
        data: () => BackendIdentityJsonMap | undefined;
      }>;
    };
  };
};

export type BackendReleaseEnvironment = {
  releaseId?: string | null;
  firebaseProjectId?: string | null;
  environment?: string | null;
  gitCommit?: string | null;
  functionsRevision?: string | null;
  functionsDigest?: string | null;
  firestoreRulesReleaseId?: string | null;
  firestoreRulesDigest?: string | null;
  firestoreIndexesDigest?: string | null;
  deployedAt?: string | null;
};

export type BackendIdentityHttpsErrorCode =
  | "not-found"
  | "permission-denied"
  | "internal"
  | "unauthenticated";

export class BackendIdentityValidationError extends Error {
  readonly code: BackendIdentityHttpsErrorCode;
  readonly details?: unknown;

  constructor(
    code: BackendIdentityHttpsErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "BackendIdentityValidationError";
    this.code = code;
    this.details = details;
  }
}

function clean(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function normalizedIsoDate(value: unknown): string | null {
  const text = clean(value);
  if (text == null) return null;
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

export function buildBackendReleaseIdentity(
  environment: BackendReleaseEnvironment,
): BackendIdentityJsonMap {
  const releaseId = clean(environment.releaseId);
  const firebaseProjectId = clean(environment.firebaseProjectId);
  const environmentName = clean(environment.environment);

  if (
    releaseId == null ||
    releaseId === "unidentified" ||
    releaseId === "unavailable"
  ) {
    throw new BackendIdentityValidationError(
      "not-found",
      "Backend release identity has not been deployed.",
      {reasonCode: "backend-release-id-missing"},
    );
  }
  if (firebaseProjectId == null) {
    throw new BackendIdentityValidationError(
      "internal",
      "Backend release identity is missing the Firebase project ID.",
      {reasonCode: "firebase-project-id-missing"},
    );
  }
  if (environmentName == null) {
    throw new BackendIdentityValidationError(
      "internal",
      "Backend release identity is missing its environment name.",
      {reasonCode: "backend-environment-missing"},
    );
  }

  return {
    releaseId,
    firebaseProjectId,
    environment: environmentName,
    gitCommit: clean(environment.gitCommit),
    functionsRevision: clean(environment.functionsRevision),
    functionsDigest: clean(environment.functionsDigest),
    firestoreRulesReleaseId: clean(
      environment.firestoreRulesReleaseId,
    ),
    firestoreRulesDigest: clean(environment.firestoreRulesDigest),
    firestoreIndexesDigest: clean(
      environment.firestoreIndexesDigest,
    ),
    deployedAt: normalizedIsoDate(environment.deployedAt),
  };
}

export function backendReleaseEnvironmentFromProcess(
  env: NodeJS.ProcessEnv,
  fallbackProjectId?: string | null,
): BackendReleaseEnvironment {
  return {
    releaseId: env.BACKEND_RELEASE_ID,
    firebaseProjectId:
      env.GCLOUD_PROJECT ??
      env.GOOGLE_CLOUD_PROJECT ??
      fallbackProjectId ??
      null,
    environment: env.BACKEND_ENVIRONMENT ?? "production",
    gitCommit: env.BACKEND_GIT_COMMIT ?? env.GIT_COMMIT,
    functionsRevision: env.K_REVISION,
    functionsDigest: env.FUNCTIONS_DIGEST,
    firestoreRulesReleaseId: env.FIRESTORE_RULES_RELEASE_ID,
    firestoreRulesDigest: env.FIRESTORE_RULES_DIGEST,
    firestoreIndexesDigest: env.FIRESTORE_INDEXES_DIGEST,
    deployedAt: env.BACKEND_DEPLOYED_AT,
  };
}

export async function getBackendReleaseIdentityWithDb(args: {
  db: BackendIdentityFirestoreLike;
  authUid: string | null;
  environment: BackendReleaseEnvironment;
}): Promise<BackendIdentityJsonMap> {
  const {db, authUid, environment} = args;
  if (authUid == null || authUid.trim().length === 0) {
    throw new BackendIdentityValidationError(
      "unauthenticated",
      "Sign in before reading backend release identity.",
    );
  }

  const userSnapshot = await db.collection("users").doc(authUid).get();
  if (!userSnapshot.exists) {
    throw new BackendIdentityValidationError(
      "permission-denied",
      "Backend release identity is visible only to approved users.",
      {reasonCode: "user-record-missing"},
    );
  }
  const userData = userSnapshot.data() ?? {};
  if (canonicalApprovedUserAuthority(userData) == null) {
    throw new BackendIdentityValidationError(
      "permission-denied",
      "Backend release identity is visible only to canonically approved users.",
      {reasonCode: "user-not-approved-or-malformed"},
    );
  }

  return buildBackendReleaseIdentity(environment);
}
