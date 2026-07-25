#!/usr/bin/env node
/**
 * Gate 1B read-only authority classifier for CRM3 v4.2_R1.
 *
 * Cloud access is deliberately limited to Firestore collection reads and
 * Firebase Auth listUsers pagination. The tool has no cloud mutation path.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {execFileSync} from 'node:child_process';
import {createHash, createHmac} from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PRODUCTION_PROJECT = 'crm3-baf-ops-b8638';
const DEFAULT_HMAC_KEY_ENV = 'CRM3_GATE1B_HMAC_KEY';
const POLICY_PATH = path.join(
  ROOT,
  'governance',
  'maintenance_workflow_policy_v1.json',
);
const POLICY_BYTES = fs.readFileSync(POLICY_PATH);
const WORKFLOW_POLICY = JSON.parse(POLICY_BYTES.toString('utf8'));

const USER_KEYS = new Set([
  'name',
  'email',
  'photoUrl',
  'roles',
  'isApproved',
  'fcmToken',
  'createdAt',
]);

export const GATE1B_DECISIONS = Object.freeze({
  pass: 'PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY',
  authorityHold: 'HOLD_AUTHORITY_FINDINGS_REQUIRE_ADJUDICATION',
  coverageHold: 'HOLD_INCOMPLETE_AUTH_OR_FIRESTORE_COVERAGE',
  custodyHold: 'HOLD_PRIVACY_OR_CUSTODY_FAILURE',
});

const AUTHORITY_DEFECT_CLASSIFICATIONS = new Set([
  'MISSING_AUTHORITY_FIELDS',
  'INVALID_IS_APPROVED_TYPE',
  'ROLES_NOT_LIST',
  'EMPTY_APPROVED_ROLES',
  'EMPTY_UNAPPROVED_ROLES',
  'EMPTY_ROLE_LIST',
  'TOO_MANY_ROLES',
  'NON_STRING_ROLE',
  'UNKNOWN_ROLE',
]);

const COLLECTION_CONTRACTS = {
  maintenance_workflows: {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  },
  job_lanes: {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'laneKey', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  },
  compliance_requests: {
    strings: ['firestoreId', 'jobExecutionFirestoreId', 'laneKey', 'status'],
    integers: ['version'],
    timestamps: ['createdAt', 'updatedAt'],
  },
  compliance_attempts: {
    strings: ['firestoreId', 'complianceRequestFirestoreId'],
    integers: ['attemptNumber'],
    timestamps: ['createdAt'],
  },
  equipment_status: {
    strings: ['firestoreId', 'assetTypeKey', 'state'],
    integers: ['assetNumber', 'version'],
    timestamps: ['updatedAt'],
  },
  workflow_commands: {
    strings: ['commandId', 'commandType', 'aggregateId'],
    integers: ['expectedVersion'],
    timestamps: ['createdAt'],
  },
  workflow_command_receipts: {
    strings: ['commandId', 'aggregateId'],
    timestamps: ['appliedAt'],
  },
  workflow_events: {
    strings: ['firestoreId', 'aggregateId', 'eventType'],
    timestamps: ['timestamp'],
  },
};

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value, key);
}

function unique(values) {
  return [...new Set(values)];
}

function sortedObject(counts) {
  return Object.fromEntries(
    [...counts.entries()].sort(([left], [right]) => left.localeCompare(right)),
  );
}

function increment(counts, key) {
  counts.set(key, (counts.get(key) ?? 0) + 1);
}

function actualType(value) {
  if (value == null) return String(value);
  if (Array.isArray(value)) return 'array';
  if (Number.isSafeInteger(value)) return 'integer';
  return typeof value;
}

function finding(collection, subjectPseudonym, field, reason, actual = null) {
  return {
    collection,
    subjectPseudonym,
    field,
    reason,
    actualType: actualType(actual),
  };
}

function requiredArgValue(argv, index, argument) {
  const value = argv[index + 1];
  if (value == null || value.startsWith('--')) {
    throw new Error(`${argument} requires a value.`);
  }
  return value;
}

export function parseArgs(argv) {
  const out = {
    hmacKeyEnv: DEFAULT_HMAC_KEY_ENV,
    includeOperationalContracts: false,
    skipAuth: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--project') {
      out.project = requiredArgValue(argv, i, arg);
      i += 1;
    } else if (arg === '--output') {
      out.output = requiredArgValue(argv, i, arg);
      i += 1;
    } else if (arg === '--confirm-project') {
      out.confirmProject = requiredArgValue(argv, i, arg);
      i += 1;
    } else if (arg === '--expected-source-commit') {
      out.expectedSourceCommit = requiredArgValue(argv, i, arg);
      i += 1;
    } else if (arg === '--expected-source-tree') {
      out.expectedSourceTree = requiredArgValue(argv, i, arg);
      i += 1;
    } else if (arg === '--hmac-key-env') {
      out.hmacKeyEnv = requiredArgValue(argv, i, arg);
      i += 1;
    } else if (arg === '--allow-production-read-only') {
      out.allowProduction = true;
    } else if (arg === '--include-operational-contracts') {
      out.includeOperationalContracts = true;
    } else if (arg === '--skip-auth') {
      out.skipAuth = true;
    } else if (arg === '--help') {
      out.help = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return out;
}

export function deriveWorkflowRoleUniverse(policy) {
  const roles = new Set();
  const append = (values, field) => {
    if (!Array.isArray(values) || values.some((value) => (
      typeof value !== 'string' || value.length === 0
    ))) {
      throw new Error(`Malformed workflow policy role list: ${field}`);
    }
    for (const role of values) roles.add(role);
  };

  append(policy.laneSetFinalizerRoles, 'laneSetFinalizerRoles');
  if (!Array.isArray(policy.lanes)) {
    throw new Error('Malformed workflow policy lanes.');
  }
  for (const lane of policy.lanes) {
    append(lane.ackRoles, `${lane.key}.ackRoles`);
    append(lane.workRoles, `${lane.key}.workRoles`);
    append(lane.closeRoles, `${lane.key}.closeRoles`);
  }
  if (roles.size === 0) {
    throw new Error('Workflow role universe cannot be empty.');
  }
  return [...roles].sort();
}

export const CANONICAL_AUTHORITY_ROLES = Object.freeze(
  deriveWorkflowRoleUniverse(WORKFLOW_POLICY),
);
const CANONICAL_ROLE_SET = new Set(CANONICAL_AUTHORITY_ROLES);

function isTimestamp(value) {
  return value != null &&
    typeof value.toDate === 'function' &&
    Number.isFinite(value.toMillis?.());
}

function isBoundedNonEmptyString(value, maxLength) {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    value.length <= maxLength;
}

function isOptionalBoundedString(value, maxLength) {
  return value == null ||
    (typeof value === 'string' && value.length <= maxLength);
}

function isSafeInteger(value) {
  return Number.isSafeInteger(value);
}

export function classifyUserAuthority(
  data,
  canonicalRoles = CANONICAL_AUTHORITY_ROLES,
) {
  const value = data != null && typeof data === 'object' && !Array.isArray(data)
    ? data
    : {};
  const roleSet = new Set(canonicalRoles);
  const classifications = [];
  const dataQualityWarnings = [];
  const hasApproved = hasOwn(value, 'isApproved');
  const hasRoles = hasOwn(value, 'roles');

  if (!hasApproved || !hasRoles) {
    classifications.push('MISSING_AUTHORITY_FIELDS');
  }
  if (hasApproved && typeof value.isApproved !== 'boolean') {
    classifications.push('INVALID_IS_APPROVED_TYPE');
  }

  if (hasRoles && !Array.isArray(value.roles)) {
    classifications.push('ROLES_NOT_LIST');
  } else if (hasRoles) {
    if (value.roles.length === 0) {
      if (value.isApproved === true) {
        classifications.push('EMPTY_APPROVED_ROLES');
      } else if (value.isApproved === false) {
        classifications.push('EMPTY_UNAPPROVED_ROLES');
      } else {
        classifications.push('EMPTY_ROLE_LIST');
      }
    }
    if (value.roles.length > roleSet.size) {
      classifications.push('TOO_MANY_ROLES');
    }

    const seen = new Set();
    for (const role of value.roles) {
      if (typeof role !== 'string') {
        classifications.push('NON_STRING_ROLE');
      } else if (!roleSet.has(role)) {
        classifications.push('UNKNOWN_ROLE');
      } else if (seen.has(role)) {
        dataQualityWarnings.push('DUPLICATE_CANONICAL_ROLE_WARNING');
      } else {
        seen.add(role);
      }
    }
  }

  const defects = unique(classifications);
  if (defects.length === 0) {
    defects.push(
      value.isApproved
        ? 'CANONICAL_APPROVED'
        : 'CANONICAL_UNAPPROVED_WITH_INTENDED_ROLES',
    );
  }

  return {
    canonical: defects.length === 1 && defects[0].startsWith('CANONICAL_'),
    isApproved: value.isApproved === true,
    classifications: defects,
    dataQualityWarnings: unique(dataQualityWarnings),
  };
}

export function validateUserProfile(subjectPseudonym, data) {
  const findings = [];
  for (const key of Object.keys(data)) {
    if (!USER_KEYS.has(key)) {
      findings.push(finding(
        'users',
        subjectPseudonym,
        'unexpectedTopLevelField',
        'unexpected-top-level-field',
        data[key],
      ));
    }
  }
  for (const key of ['name', 'email', 'createdAt']) {
    if (!hasOwn(data, key)) {
      findings.push(finding(
        'users',
        subjectPseudonym,
        key,
        'required-profile-field-missing',
      ));
    }
  }
  if (!isBoundedNonEmptyString(data.name, 160)) {
    findings.push(finding(
      'users',
      subjectPseudonym,
      'name',
      'invalid-required-string',
      data.name,
    ));
  }
  if (!isBoundedNonEmptyString(data.email, 320)) {
    findings.push(finding(
      'users',
      subjectPseudonym,
      'email',
      'invalid-required-string',
      data.email,
    ));
  }
  if (!isOptionalBoundedString(data.photoUrl, 2048)) {
    findings.push(finding(
      'users',
      subjectPseudonym,
      'photoUrl',
      'invalid-optional-string',
      data.photoUrl,
    ));
  }
  if (!isOptionalBoundedString(data.fcmToken, 4096)) {
    findings.push(finding(
      'users',
      subjectPseudonym,
      'fcmToken',
      'invalid-optional-string',
      data.fcmToken,
    ));
  }
  if (!isTimestamp(data.createdAt)) {
    findings.push(finding(
      'users',
      subjectPseudonym,
      'createdAt',
      'invalid-firestore-timestamp',
      data.createdAt,
    ));
  }
  return findings;
}

export function validateUserDocument(subjectPseudonym, data) {
  const findings = validateUserProfile(subjectPseudonym, data);
  const authority = classifyUserAuthority(data);

  for (const classification of authority.classifications) {
    if (classification.startsWith('CANONICAL_')) continue;
    const field = classification === 'INVALID_IS_APPROVED_TYPE'
      ? 'isApproved'
      : 'roles';
    const reason = {
      MISSING_AUTHORITY_FIELDS: 'required-authority-field-missing',
      INVALID_IS_APPROVED_TYPE: 'invalid-boolean',
      ROLES_NOT_LIST: 'invalid-nonempty-role-list',
      EMPTY_APPROVED_ROLES: 'invalid-nonempty-role-list',
      EMPTY_UNAPPROVED_ROLES: 'invalid-nonempty-role-list',
      EMPTY_ROLE_LIST: 'invalid-nonempty-role-list',
      TOO_MANY_ROLES: 'role-count-exceeds-canonical-bound',
      NON_STRING_ROLE: 'unknown-or-malformed-role',
      UNKNOWN_ROLE: 'unknown-or-malformed-role',
    }[classification];
    findings.push(finding(
      'users',
      subjectPseudonym,
      field,
      reason,
      data[field],
    ));
  }
  for (const warning of authority.dataQualityWarnings) {
    findings.push({
      ...finding(
        'users',
        subjectPseudonym,
        'roles',
        'duplicate-canonical-role',
        data.roles,
      ),
      severity: 'WARNING',
      classification: warning,
    });
  }
  return findings;
}

export function validateContractDocument(
  collection,
  subjectPseudonym,
  data,
  contract,
) {
  const findings = [];
  for (const field of contract.strings ?? []) {
    if (!isBoundedNonEmptyString(data[field], Number.MAX_SAFE_INTEGER)) {
      findings.push(finding(
        collection,
        subjectPseudonym,
        field,
        'invalid-required-string',
        data[field],
      ));
    }
  }
  for (const field of contract.integers ?? []) {
    if (!isSafeInteger(data[field])) {
      findings.push(finding(
        collection,
        subjectPseudonym,
        field,
        'invalid-required-integer',
        data[field],
      ));
    }
  }
  for (const field of contract.timestamps ?? []) {
    if (!isTimestamp(data[field])) {
      findings.push(finding(
        collection,
        subjectPseudonym,
        field,
        'invalid-firestore-timestamp',
        data[field],
      ));
    }
  }
  return findings;
}

export function assertHmacKey(value) {
  if (typeof value !== 'string' || Buffer.byteLength(value, 'utf8') < 32) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: ` +
      'the HMAC audit key must contain at least 32 UTF-8 bytes.',
    );
  }
  return value;
}

export function pseudonymizeSubject(hmacKey, namespace, stableIdentifier) {
  assertHmacKey(hmacKey);
  if (
    typeof namespace !== 'string' ||
    namespace.length === 0 ||
    typeof stableIdentifier !== 'string' ||
    stableIdentifier.length === 0
  ) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: ` +
      'a stable namespace and subject identifier are required.',
    );
  }
  return `hmac256:${
    createHmac('sha256', hmacKey)
      .update(`${namespace}\0${stableIdentifier}`, 'utf8')
      .digest('hex')
  }`;
}

function normalizeFirestoreUsers(users) {
  const result = new Map();
  for (const user of users) {
    if (
      user == null ||
      typeof user.uid !== 'string' ||
      user.uid.length === 0 ||
      user.data == null ||
      typeof user.data !== 'object' ||
      Array.isArray(user.data)
    ) {
      throw new Error('Malformed Firestore user inventory input.');
    }
    if (result.has(user.uid)) {
      throw new Error('Duplicate Firestore UID in inventory input.');
    }
    result.set(user.uid, user.data);
  }
  return result;
}

function normalizeAuthUsers(users) {
  const result = new Map();
  for (const user of users) {
    if (user == null || typeof user.uid !== 'string' || user.uid.length === 0) {
      throw new Error('Malformed Firebase Auth user inventory input.');
    }
    if (result.has(user.uid)) {
      throw new Error('Duplicate Firebase Auth UID in inventory input.');
    }
    result.set(user.uid, {
      disabled: user.disabled === true,
      customClaimCount: user.customClaims == null
        ? 0
        : Object.keys(user.customClaims).length,
    });
  }
  return result;
}

function deriveWriterCorrelationHypotheses(classificationCounts) {
  const hypotheses = [];
  if ([...AUTHORITY_DEFECT_CLASSIFICATIONS].some(
    (classification) => (classificationCounts.get(classification) ?? 0) > 0,
  )) {
    hypotheses.push({
      code: 'HISTORICAL_OR_PRIVILEGED_FIRESTORE_AUTHORITY_WRITE',
      attribution: 'HYPOTHESIS_ONLY',
      basis: 'One or more stored authority capsules violate current policy.',
    });
  }
  if ((classificationCounts.get('UNEXPECTED_CUSTOM_CLAIMS') ?? 0) > 0) {
    hypotheses.push({
      code: 'EXTERNAL_OR_LEGACY_CUSTOM_CLAIMS_WRITER',
      attribution: 'HYPOTHESIS_ONLY',
      basis: 'Tracked source defines no custom-claims authority writer.',
    });
  }
  if (
    (classificationCounts.get('AUTH_USER_MISSING') ?? 0) > 0 ||
    (classificationCounts.get('FIRESTORE_USER_MISSING') ?? 0) > 0 ||
    (classificationCounts.get('AUTH_USER_DISABLED_WHILE_APPROVED') ?? 0) > 0
  ) {
    hypotheses.push({
      code: 'AUTH_FIRESTORE_LIFECYCLE_DIVERGENCE',
      attribution: 'HYPOTHESIS_ONLY',
      basis: 'Firebase Auth and Firestore user state do not reconcile.',
    });
  }
  if ((classificationCounts.get('PROFILE_ONLY_CORRUPTION') ?? 0) > 0) {
    hypotheses.push({
      code: 'LEGACY_OR_PRIVILEGED_PROFILE_WRITE',
      attribution: 'HYPOTHESIS_ONLY',
      basis: 'Authority is canonical but the full client-write schema is not.',
    });
  }
  if ((classificationCounts.get('NO_ENABLED_APPROVED_ADMIN') ?? 0) > 0) {
    hypotheses.push({
      code: 'AUTHORITY_BOOTSTRAP_OR_QUORUM_GAP',
      attribution: 'HYPOTHESIS_ONLY',
      basis: 'No canonical approved Admin is present and enabled in Auth.',
    });
  }
  return hypotheses;
}

function affectedRuleCategories(classificationCounts) {
  const categories = [];
  if ([...AUTHORITY_DEFECT_CLASSIFICATIONS].some(
    (classification) => (classificationCounts.get(classification) ?? 0) > 0,
  )) {
    categories.push('AUTHORITY_CAPSULE');
  }
  if ([
    'AUTH_USER_MISSING',
    'FIRESTORE_USER_MISSING',
    'AUTH_USER_DISABLED_WHILE_APPROVED',
  ].some(
    (classification) => (classificationCounts.get(classification) ?? 0) > 0,
  )) {
    categories.push('AUTH_FIRESTORE_POPULATION');
  }
  if ((classificationCounts.get('UNEXPECTED_CUSTOM_CLAIMS') ?? 0) > 0) {
    categories.push('CUSTOM_CLAIMS_ABSENCE_ASSERTION');
  }
  if ((classificationCounts.get('PROFILE_ONLY_CORRUPTION') ?? 0) > 0) {
    categories.push('PROFILE_SCHEMA_NON_AUTHORITY');
  }
  if (
    (classificationCounts.get('DUPLICATE_CANONICAL_ROLE_WARNING') ?? 0) > 0
  ) {
    categories.push('AUTHORITY_DATA_QUALITY');
  }
  if ((classificationCounts.get('NO_ENABLED_APPROVED_ADMIN') ?? 0) > 0) {
    categories.push('AUTHORITY_ADMIN_QUORUM');
  }
  return categories;
}

export function buildAuthorityInventory({
  firestoreUsers,
  authUsers,
  authCoverageComplete,
  hmacKey,
}) {
  assertHmacKey(hmacKey);
  const firestoreByUid = normalizeFirestoreUsers(firestoreUsers);
  const authByUid = normalizeAuthUsers(authUsers);
  const allUids = new Set([
    ...firestoreByUid.keys(),
    ...(authCoverageComplete ? authByUid.keys() : []),
  ]);
  const classificationCounts = new Map();
  const subjects = [];
  let authorityDefectSubjectCount = 0;
  let reconciliationDefectSubjectCount = 0;
  let profileOnlyCorruptionCount = 0;
  let dataQualityWarningCount = 0;
  let canonicalApprovedAdminCount = 0;
  let enabledApprovedAdminCount = 0;
  const blockingSubjects = new Set();

  for (const uid of allUids) {
    const firestoreData = firestoreByUid.get(uid);
    const authData = authByUid.get(uid);
    const subjectPseudonym = pseudonymizeSubject(hmacKey, 'user', uid);
    const authority = firestoreData == null
      ? {canonical: false, isApproved: false, classifications: [], dataQualityWarnings: []}
      : classifyUserAuthority(firestoreData);
    const profileFindings = firestoreData == null
      ? []
      : validateUserProfile(subjectPseudonym, firestoreData);
    const reconciliationClassifications = [];
    const isCanonicalApprovedAdmin = firestoreData != null &&
      authority.canonical &&
      authority.isApproved &&
      firestoreData.roles.includes('admin');

    if (isCanonicalApprovedAdmin) {
      canonicalApprovedAdminCount += 1;
      if (
        authCoverageComplete &&
        authData != null &&
        authData.disabled !== true
      ) {
        enabledApprovedAdminCount += 1;
      }
    }

    if (authCoverageComplete) {
      if (firestoreData != null && authData == null) {
        reconciliationClassifications.push('AUTH_USER_MISSING');
      }
      if (firestoreData == null && authData != null) {
        reconciliationClassifications.push('FIRESTORE_USER_MISSING');
      }
      if (
        firestoreData != null &&
        authData?.disabled === true &&
        firestoreData.isApproved === true
      ) {
        reconciliationClassifications.push(
          'AUTH_USER_DISABLED_WHILE_APPROVED',
        );
      }
      if ((authData?.customClaimCount ?? 0) > 0) {
        reconciliationClassifications.push('UNEXPECTED_CUSTOM_CLAIMS');
      }
    }

    let profileClassification = 'NOT_APPLICABLE';
    if (firestoreData != null) {
      profileClassification = profileFindings.length === 0
        ? 'CANONICAL_PROFILE'
        : authority.canonical
          ? 'PROFILE_ONLY_CORRUPTION'
          : 'PROFILE_CORRUPTION_ALONGSIDE_AUTHORITY_FINDING';
    }

    const authorityDefects = authority.classifications.filter(
      (classification) => AUTHORITY_DEFECT_CLASSIFICATIONS.has(classification),
    );
    if (firestoreData != null && authorityDefects.length > 0) {
      authorityDefectSubjectCount += 1;
      blockingSubjects.add(subjectPseudonym);
    }
    if (reconciliationClassifications.length > 0) {
      reconciliationDefectSubjectCount += 1;
      blockingSubjects.add(subjectPseudonym);
    }
    if (profileClassification === 'PROFILE_ONLY_CORRUPTION') {
      profileOnlyCorruptionCount += 1;
    }
    dataQualityWarningCount += authority.dataQualityWarnings.length;

    for (const classification of [
      ...authority.classifications,
      ...reconciliationClassifications,
      ...(profileClassification === 'PROFILE_ONLY_CORRUPTION'
        ? [profileClassification]
        : []),
      ...authority.dataQualityWarnings,
    ]) {
      increment(classificationCounts, classification);
    }

    subjects.push({
      subjectPseudonym,
      presence: {
        firestore: firestoreData != null,
        firebaseAuth: authCoverageComplete ? authData != null : null,
      },
      authority: {
        canonical: firestoreData == null ? null : authority.canonical,
        classifications: authority.classifications,
      },
      authReconciliation: {
        coverage: authCoverageComplete ? 'COMPLETE' : 'NOT_RUN',
        classifications: reconciliationClassifications,
        unexpectedCustomClaimCount: authCoverageComplete
          ? authData?.customClaimCount ?? 0
          : null,
      },
      profile: {
        classification: profileClassification,
        findingCount: profileFindings.length,
        findings: profileFindings.map(({field, reason, actualType: type}) => ({
          field,
          reason,
          actualType: type,
        })),
      },
      dataQualityWarnings: authority.dataQualityWarnings,
    });
  }

  subjects.sort((left, right) => (
    left.subjectPseudonym.localeCompare(right.subjectPseudonym)
  ));

  const blockingSubjectCount = blockingSubjects.size;
  const populationBlockerCount = authCoverageComplete &&
    enabledApprovedAdminCount === 0
    ? 1
    : 0;
  if (populationBlockerCount > 0) {
    increment(classificationCounts, 'NO_ENABLED_APPROVED_ADMIN');
  }
  const blockingFindingCount = blockingSubjectCount + populationBlockerCount;
  const decision = !authCoverageComplete
    ? GATE1B_DECISIONS.coverageHold
    : blockingFindingCount > 0
      ? GATE1B_DECISIONS.authorityHold
      : GATE1B_DECISIONS.pass;

  return {
    coverage: {
      firestoreUsers: 'COMPLETE',
      firebaseAuthUsers: authCoverageComplete ? 'COMPLETE' : 'NOT_RUN',
      customClaims: authCoverageComplete ? 'COMPLETE' : 'NOT_RUN',
      firestoreUserCount: firestoreByUid.size,
      firebaseAuthUserCount: authCoverageComplete ? authByUid.size : null,
      joinedSubjectCount: subjects.length,
    },
    classificationCounts: sortedObject(classificationCounts),
    summary: {
      authorityDefectSubjectCount,
      reconciliationDefectSubjectCount,
      profileOnlyCorruptionCount,
      dataQualityWarningCount,
      canonicalApprovedAdminCount,
      enabledApprovedAdminCount: authCoverageComplete
        ? enabledApprovedAdminCount
        : null,
      blockingSubjectCount,
      populationBlockerCount,
      blockingFindingCount,
    },
    subjects,
    affectedRuleCategories: affectedRuleCategories(classificationCounts),
    writerCorrelationHypotheses: deriveWriterCorrelationHypotheses(
      classificationCounts,
    ),
    decision,
  };
}

export async function listAllAuthUsers(auth) {
  const users = [];
  const seenPageTokens = new Set();
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    if (!Array.isArray(page.users)) {
      throw new Error('Firebase Auth listUsers returned a malformed page.');
    }
    users.push(...page.users);
    pageToken = page.pageToken;
    if (pageToken != null) {
      if (seenPageTokens.has(pageToken)) {
        throw new Error('Firebase Auth listUsers repeated a page token.');
      }
      seenPageTokens.add(pageToken);
    }
  } while (pageToken != null);
  return users;
}

async function scanOperationalContracts(db, hmacKey) {
  const collectionCounts = {};
  const findings = [];
  for (const [collection, contract] of Object.entries(COLLECTION_CONTRACTS)) {
    // Full collection reads intentionally avoid orderBy blind spots.
    const snapshot = await db.collection(collection).get();
    collectionCounts[collection] = snapshot.size;
    for (const doc of snapshot.docs) {
      const subjectPseudonym = pseudonymizeSubject(
        hmacKey,
        `firestore:${collection}`,
        doc.id,
      );
      findings.push(...validateContractDocument(
        collection,
        subjectPseudonym,
        doc.data() ?? {},
        contract,
      ));
    }
  }
  return {
    readOnly: true,
    collectionCounts,
    findingCount: findings.length,
    findings,
    status: findings.length === 0
      ? 'PASS_OPTIONAL_OPERATIONAL_CONTRACT_SWEEP'
      : 'HOLD_OPTIONAL_OPERATIONAL_CONTRACT_FINDINGS',
  };
}

export function readGitSourceAuthority(root = ROOT) {
  const git = (...args) => execFileSync(
    'git',
    ['-C', root, ...args],
    {encoding: 'utf8'},
  ).trim();
  const status = git('status', '--porcelain', '--untracked-files=all');
  return {
    commit: git('rev-parse', 'HEAD'),
    tree: git('rev-parse', 'HEAD^{tree}'),
    branch: git('branch', '--show-current'),
    originMainCommit: git('rev-parse', 'refs/remotes/origin/main'),
    cleanWorktree: status.length === 0,
  };
}

function assertExactSource(args, source) {
  if (
    args.expectedSourceCommit != null &&
    args.expectedSourceCommit !== source.commit
  ) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: expected source commit mismatch.`,
    );
  }
  if (
    args.expectedSourceTree != null &&
    args.expectedSourceTree !== source.tree
  ) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: expected source tree mismatch.`,
    );
  }
}

function ambientProjectIds(env) {
  const projects = [
    env.GCLOUD_PROJECT,
    env.GOOGLE_CLOUD_PROJECT,
  ].filter((value) => typeof value === 'string' && value.length > 0);
  if (typeof env.FIREBASE_CONFIG === 'string') {
    try {
      const config = JSON.parse(env.FIREBASE_CONFIG);
      if (typeof config.projectId === 'string' && config.projectId.length > 0) {
        projects.push(config.projectId);
      }
    } catch {
      throw new Error(
        `${GATE1B_DECISIONS.custodyHold}: FIREBASE_CONFIG is not valid JSON.`,
      );
    }
  }
  return unique(projects);
}

export function assertProductionReadCustody(args, env, source) {
  assertExactSource(args, source);
  if (args.project !== PRODUCTION_PROJECT) return;

  const violations = [];
  if (args.allowProduction !== true) {
    violations.push('--allow-production-read-only is required');
  }
  if (args.confirmProject !== PRODUCTION_PROJECT) {
    violations.push('exact --confirm-project is required');
  }
  if (args.skipAuth === true) {
    violations.push('Firebase Auth coverage cannot be skipped');
  }
  if (args.expectedSourceCommit == null || args.expectedSourceTree == null) {
    violations.push('exact source commit and tree expectations are required');
  }
  if (!source.cleanWorktree) {
    violations.push('the source worktree must be clean');
  }
  if (source.branch !== 'main') {
    violations.push('the checked-out source branch must be main');
  }
  if (source.originMainCommit !== source.commit) {
    violations.push('HEAD must equal the fetched origin/main commit');
  }
  if (
    typeof env.FIRESTORE_EMULATOR_HOST === 'string' ||
    typeof env.FIREBASE_AUTH_EMULATOR_HOST === 'string'
  ) {
    violations.push('emulator hosts must be absent for production evidence');
  }
  const ambientMismatches = ambientProjectIds(env).filter(
    (projectId) => projectId !== PRODUCTION_PROJECT,
  );
  if (ambientMismatches.length > 0) {
    violations.push('ambient Firebase/Google project identity disagrees');
  }
  if (violations.length > 0) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: ${violations.join('; ')}.`,
    );
  }
}

export function assertNewEvidenceOutput(output) {
  if (typeof output !== 'string' || output.trim().length === 0) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: evidence output path is required.`,
    );
  }
  const resolved = path.resolve(output);
  const digestPath = `${resolved}.sha256`;
  const directory = path.dirname(resolved);
  if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: ` +
      'evidence output directory must already exist.',
    );
  }
  try {
    fs.accessSync(directory, fs.constants.W_OK);
  } catch {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: ` +
      'evidence output directory is not writable.',
    );
  }
  if (fs.existsSync(resolved) || fs.existsSync(digestPath)) {
    throw new Error(
      `${GATE1B_DECISIONS.custodyHold}: evidence output already exists.`,
    );
  }
  return {resolved, digestPath};
}

function writeEvidence(output, result) {
  const {resolved, digestPath} = assertNewEvidenceOutput(output);
  const body = `${JSON.stringify(result, null, 2)}\n`;
  const digest = createHash('sha256').update(body, 'utf8').digest('hex');
  fs.writeFileSync(resolved, body, {encoding: 'utf8', flag: 'wx'});
  fs.writeFileSync(
    digestPath,
    `${digest}  ${path.basename(resolved)}\n`,
    {encoding: 'utf8', flag: 'wx'},
  );
  return {resolved, digestPath, digest};
}

function usage() {
  return [
    'Usage:',
    '  node tools/v4/firestore_integrity_sweep.mjs',
    '    --project <id> --output <new-file>',
    '    [--hmac-key-env CRM3_GATE1B_HMAC_KEY]',
    '    [--skip-auth] [--include-operational-contracts]',
    '',
    'Production additionally requires:',
    '  --allow-production-read-only',
    `  --confirm-project ${PRODUCTION_PROJECT}`,
    '  --expected-source-commit <40-hex-commit>',
    '  --expected-source-tree <40-hex-tree>',
  ].join('\n');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }
  const projectId = args.project ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) throw new Error('A Firebase project ID is required.');
  if (!args.output) throw new Error('--output is required.');
  args.project = projectId;

  // Complete all local custody checks before opening a cloud read path.
  assertNewEvidenceOutput(args.output);
  const hmacKey = assertHmacKey(process.env[args.hmacKeyEnv]);
  const sourceAuthority = readGitSourceAuthority();
  assertProductionReadCustody(args, process.env, sourceAuthority);
  assertExactSource(args, sourceAuthority);

  const startedAt = new Date().toISOString();
  const require = createRequire(import.meta.url);
  const admin = require(path.join(ROOT, 'functions/node_modules/firebase-admin'));
  const app = admin.initializeApp(
    {projectId},
    `gate1b-read-only-${process.pid}-${Date.now()}`,
  );
  const db = app.firestore();

  // Full collection read: no orderBy and therefore no missing-field blind spot.
  const userSnapshot = await db.collection('users').get();
  const firestoreUsers = userSnapshot.docs.map((doc) => ({
    uid: doc.id,
    data: doc.data() ?? {},
  }));
  const authCoverageComplete = args.skipAuth !== true;
  const authUsers = authCoverageComplete
    ? await listAllAuthUsers(app.auth())
    : [];
  const inventory = buildAuthorityInventory({
    firestoreUsers,
    authUsers,
    authCoverageComplete,
    hmacKey,
  });
  const operationalIntegrity = args.includeOperationalContracts
    ? await scanOperationalContracts(db, hmacKey)
    : null;

  const result = {
    schemaVersion: 2,
    evidenceType: 'GATE_1B_READ_ONLY_AUTHORITY_INVENTORY',
    readOnly: true,
    cloudMutationCapability: 'NONE',
    startedAt,
    completedAt: new Date().toISOString(),
    project: {
      projectId,
      production: projectId === PRODUCTION_PROJECT,
      exactProductionConfirmation: projectId === PRODUCTION_PROJECT
        ? args.confirmProject
        : null,
      firestoreEmulator: process.env.FIRESTORE_EMULATOR_HOST ?? null,
      authEmulator: process.env.FIREBASE_AUTH_EMULATOR_HOST ?? null,
    },
    sourceAuthority,
    policy: {
      policyId: WORKFLOW_POLICY.policyId,
      policySchemaVersion: WORKFLOW_POLICY.schemaVersion,
      policySha256: createHash('sha256').update(POLICY_BYTES).digest('hex'),
      canonicalRoles: CANONICAL_AUTHORITY_ROLES,
      maximumRoleCount: CANONICAL_AUTHORITY_ROLES.length,
      unapprovedRolePolicy:
        'MODEL_B_CANONICAL_INTENDED_ROLES_RETAINED_NON_AUTHORIZING',
      customClaimsPolicy: 'ABSENCE_ASSERTION_NO_TRACKED_WRITER',
    },
    privacy: {
      subjectIdentifier: 'HMAC_SHA256',
      hmacKeyEnvironmentVariable: args.hmacKeyEnv,
      rawIdentifiersEmitted: false,
      customClaimValuesEmitted: false,
    },
    ...inventory,
    operationalIntegrity,
  };

  const evidence = writeEvidence(args.output, result);
  console.log(
    `${result.decision}: subjects=${result.coverage.joinedSubjectCount}; ` +
    `blockers=${result.summary.blockingFindingCount}; ` +
    `output=${evidence.resolved}; sha256=${evidence.digest}`,
  );
  process.exitCode = result.decision === GATE1B_DECISIONS.pass ? 0 : 2;
}

if (
  import.meta.url === `file://${process.argv[1]}` ||
  fileURLToPath(import.meta.url) === path.resolve(process.argv[1] ?? '')
) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
