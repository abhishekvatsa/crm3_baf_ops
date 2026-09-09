// Enforces the recorded build/test dependency audit exception.
//
// The release gate scopes the root and Cloud Functions audits to the runtime
// population. That scoping assesses what ships; it says nothing about the
// omitted build/test population. This checker assesses that population against
// a recorded, dated, owned exception, so a deferral stays narrow instead of
// becoming an open-ended "ignore every development advisory".

import {execFileSync} from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

export const EXCEPTION_PATH =
  "governance/build-test-dependency-audit-exception-v1.json";

/**
 * npm reports one entry per affected package, so a single advisory reaching a
 * dependent shows as two "vulnerabilities". Only `via` entries that are objects
 * are advisories; string entries name the package the effect arrives through.
 * Resolving to advisory identity is what makes the exception narrow: a count
 * would silently admit a second, unrelated advisory.
 */
export function resolveAdvisories(report) {
  const found = new Map();
  const vulnerabilities = report?.vulnerabilities;
  if (!vulnerabilities || typeof vulnerabilities !== "object") return found;
  for (const [name, entry] of Object.entries(vulnerabilities)) {
    for (const via of entry?.via ?? []) {
      if (!via || typeof via !== "object") continue;
      const id = String(via.url ?? "").split("/").pop();
      if (!id) continue;
      const existing = found.get(id) ?? {
        advisory: id,
        severity: via.severity ?? entry?.severity ?? "unknown",
        packages: new Set(),
        ranges: new Set(),
      };
      existing.packages.add(via.name ?? name);
      if (entry?.range) existing.ranges.add(entry.range);
      found.set(id, existing);
    }
  }
  return found;
}

/**
 * Pure decision so the outcomes can be tested without invoking npm.
 * `auditOk` is false when the audit could not produce a valid report; an
 * unavailable assessment is never treated as a clean one.
 */
export function assess({report, exception, population, now, auditOk = true}) {
  if (!auditOk || !report || typeof report !== "object") {
    return {
      ok: false,
      reason: "audit-unavailable",
      message:
        `Dependency assessment unavailable for ${population}. An audit that ` +
        "cannot be read is not evidence that the population is clean.",
    };
  }

  const reviewBy = new Date(`${exception.reviewBy}T00:00:00Z`);
  if (Number.isNaN(reviewBy.getTime())) {
    return {ok: false, reason: "exception-invalid", message: "reviewBy is not a date."};
  }

  const advisories = resolveAdvisories(report);
  const accepted = new Map(
    (exception.accepted ?? [])
      .filter((row) => (row.populations ?? []).includes(population))
      .map((row) => [row.advisory, row]),
  );

  const unexpected = [...advisories.keys()].filter((id) => !accepted.has(id));
  if (unexpected.length > 0) {
    return {
      ok: false,
      reason: "unrecorded-advisory",
      message:
        `Unrecorded advisory in the ${population} build/test population: ` +
        `${unexpected.join(", ")}. Assess it rather than widening the ` +
        "existing exception.",
      unexpected,
    };
  }

  // Expiry is only reached when a recorded advisory is still present. An
  // exception whose findings have gone is eligible for closure, not a failure.
  const present = [...advisories.keys()];
  if (present.length > 0 && now.getTime() > reviewBy.getTime()) {
    return {
      ok: false,
      reason: "exception-expired",
      message:
        `The build/test dependency exception passed its ${exception.reviewBy} ` +
        "review date while still in use. Correct the advisory or record a " +
        "renewed, reassessed exception.",
      present,
    };
  }

  if (present.length === 0) {
    return {
      ok: true,
      reason: "exception-closable",
      message:
        `No advisory remains in the ${population} build/test population. The ` +
        "recorded exception is eligible for closure.",
    };
  }

  return {
    ok: true,
    reason: "exception-applies",
    message:
      `Deferred under the recorded exception (review by ${exception.reviewBy}): ` +
      present
        .map((id) => `${id} [${advisories.get(id).severity}] ` +
          `${[...advisories.get(id).packages].join(", ")}`)
        .join("; "),
    present,
  };
}

function runAudit(command, repositoryRoot) {
  try {
    const stdout = execFileSync(command[0], command.slice(1), {
      cwd: repositoryRoot,
      encoding: "utf8",
      shell: process.platform === "win32",
      maxBuffer: 64 * 1024 * 1024,
    });
    return {auditOk: true, report: JSON.parse(stdout)};
  } catch (error) {
    // npm audit exits non-zero when findings exist, and still prints the
    // report. Only an unparseable payload counts as unavailable.
    const stdout = error?.stdout?.toString?.() ?? "";
    try {
      return {auditOk: true, report: JSON.parse(stdout)};
    } catch {
      return {auditOk: false, report: null, error: String(error?.message ?? error)};
    }
  }
}

function main() {
  const repositoryRoot = process.argv[2] ?? process.cwd();
  const exception = JSON.parse(
    fs.readFileSync(path.join(repositoryRoot, EXCEPTION_PATH), "utf8"),
  );
  let failed = false;
  for (const [population, config] of Object.entries(exception.populations)) {
    const {auditOk, report} = runAudit(config.auditCommand, repositoryRoot);
    const verdict = assess({
      report,
      exception,
      population,
      now: new Date(),
      auditOk,
    });
    const label = verdict.ok ? "ACCEPTED" : "BLOCKED";
    console.log(`${label} [${population}] ${verdict.reason}: ${verdict.message}`);
    if (!verdict.ok) failed = true;
  }
  console.log(`Recorded exception: ${exception.humanRecord}`);
  process.exit(failed ? 1 : 0);
}

import {pathToFileURL} from "node:url";

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
