import {createHash} from "crypto";

import {WORKFLOW_ROLE_UNIVERSE} from "./maintenanceWorkflow/policy.generated";

export type UserAuthorityJsonMap = {[key: string]: unknown};

export interface CanonicalUserAuthorityCapsule {
  readonly isApproved: boolean;
  readonly roles: ReadonlySet<string>;
}

export interface CanonicalApprovedUserAuthority {
  /** The exact document map that passed canonical approval validation. */
  readonly data: UserAuthorityJsonMap;
  readonly roles: ReadonlySet<string>;
}

const CANONICAL_ROLE_SET = new Set<string>(WORKFLOW_ROLE_UNIVERSE);
const AUTHORITY_DIGEST_PREFIX = "auth1-sha256:";

export function canonicalUserAuthorityCapsule(
  value: unknown,
): CanonicalUserAuthorityCapsule | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const data = value as UserAuthorityJsonMap;
  if (typeof data.isApproved !== "boolean" || !Array.isArray(data.roles)) {
    return null;
  }
  if (data.roles.length === 0 || data.roles.length > CANONICAL_ROLE_SET.size) {
    return null;
  }
  const roles = new Set<string>();
  for (const raw of data.roles) {
    if (typeof raw !== "string" || !CANONICAL_ROLE_SET.has(raw)) {
      return null;
    }
    roles.add(raw);
  }
  if (roles.size === 0) return null;
  return {isApproved: data.isApproved, roles};
}

export function normalizeCanonicalUserRoles(
  roles: Iterable<string>,
): ReadonlyArray<string> {
  const normalized = new Set<string>();
  for (const role of roles) {
    if (!CANONICAL_ROLE_SET.has(role)) {
      throw new Error(`Unknown canonical user role: ${role}`);
    }
    normalized.add(role);
  }
  if (normalized.size === 0 || normalized.size > CANONICAL_ROLE_SET.size) {
    throw new Error("Canonical user roles must be a non-empty bounded set.");
  }
  return [...normalized].sort();
}

export function canonicalUserAuthorityDigest(
  capsule: CanonicalUserAuthorityCapsule,
): string {
  const canonical = JSON.stringify({
    isApproved: capsule.isApproved,
    roles: normalizeCanonicalUserRoles(capsule.roles),
  });
  return `${AUTHORITY_DIGEST_PREFIX}${
    createHash("sha256").update(canonical, "utf8").digest("hex")
  }`;
}

/**
 * Canonical backend approval predicate.
 *
 * This intentionally validates identity/approval authority only. Firestore
 * Rules separately enforce the permitted stored user-document shape.
 * Legacy aliases such as `approved`, `status: approved`, and singular `role`
 * never grant authority.
 */
export function canonicalApprovedUserAuthority(
  value: unknown,
): CanonicalApprovedUserAuthority | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const data = value as UserAuthorityJsonMap;
  const capsule = canonicalUserAuthorityCapsule(data);
  if (capsule == null || !capsule.isApproved) return null;
  return {data, roles: capsule.roles};
}

export function canonicalUserHasAnyRole(
  value: unknown,
  allowedRoles: ReadonlySet<string>,
): boolean {
  const authority = canonicalApprovedUserAuthority(value);
  if (authority == null) return false;
  for (const role of authority.roles) {
    if (allowedRoles.has(role)) return true;
  }
  return false;
}

export function canonicalRoleUniverseForTest(): ReadonlyArray<string> {
  return [...CANONICAL_ROLE_SET].sort();
}
