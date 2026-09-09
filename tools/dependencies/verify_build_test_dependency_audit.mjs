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
 * A parseable payload is not an audit report. npm can emit a JSON error
 * envelope, and an unrecognised or empty shape carries no findings for a reason
 * that is not "there are none". Anything unrecognised must fail closed, because
 * an assessment that could not be made is not an assessment that passed.
 */
export function validateAuditReport(report) {
  if (report === null || typeof report !== "object" || Array.isArray(report)) {
    const kind = Array.isArray(report) ? "an array" : typeof report;
    return {ok: false, detail: `expected an audit report object, received ${kind}`};
  }
  if (report.error !== undefined) {
    const code = report.error?.code ?? "unspecified";
    const summary = report.error?.summary ?? "no summary";
    return {ok: false, detail: `npm reported an audit error (${code}): ${summary}`};
  }
  if (!Number.isInteger(report.auditReportVersion)) {
    return {ok: false, detail: "report has no auditReportVersion"};
  }
  if (report.auditReportVersion !== 2) {
    return {
      ok: false,
      detail: `unsupported auditReportVersion ${report.auditReportVersion}`,
    };
  }
  const vulnerabilities = report.vulnerabilities;
  if (
    vulnerabilities === null ||
    typeof vulnerabilities !== "object" ||
    Array.isArray(vulnerabilities)
  ) {
    return {ok: false, detail: "report has no vulnerabilities object"};
  }
  return {ok: true};
}

/**
 * npm reports one entry per affected package, so a single advisory reaching a
 * dependent shows as two "vulnerabilities". Only `via` entries that are objects
 * are advisories; string entries name the package the effect arrives through.
 * Resolving to advisory identity is what makes the exception narrow: a count
 * would silently admit a second, unrelated advisory.
 *
 * An advisory-shaped entry without a usable identity is reported as unresolved
 * rather than dropped, so it cannot disappear into an empty result.
 */
export function resolveAdvisories(report) {
  const found = new Map();
  const unresolved = [];
  for (const [name, entry] of Object.entries(report.vulnerabilities)) {
    for (const via of entry?.via ?? []) {
      if (!via || typeof via !== "object") continue;
      const id = String(via.url ?? "").split("/").filter(Boolean).pop();
      if (!id || !id.startsWith("GHSA-")) {
        unresolved.push(`${name}: ${JSON.stringify(via.url ?? via)}`);
        continue;
      }
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
  return {found, unresolved};
}

/**
 * Pure decision so the outcomes can be tested without invoking npm.
 * `auditOk` is false when the audit could not produce a valid report; an
 * unavailable assessment is never treated as a clean one.
 */
export function assess({report, exception, population, now, auditOk = true}) {
  const envelope = auditOk
    ? validateAuditReport(report)
    : {ok: false, detail: "the audit process produced no readable output"};
  if (!envelope.ok) {
    return {
      ok: false,
      reason: "audit-unavailable",
      message:
        `Dependency assessment unavailable for ${population}: ${envelope.detail}. ` +
        "An audit that cannot be read is not evidence that the population is clean.",
      detail: envelope.detail,
    };
  }

  const reviewBy = new Date(`${exception.reviewBy}T00:00:00Z`);
  if (Number.isNaN(reviewBy.getTime())) {
    return {ok: false, reason: "exception-invalid", message: "reviewBy is not a date."};
  }

  const {found: advisories, unresolved} = resolveAdvisories(report);
  if (unresolved.length > 0) {
    return {
      ok: false,
      reason: "advisory-unresolvable",
      message:
        `An advisory in the ${population} build/test population could not be ` +
        `identified: ${unresolved.join("; ")}. An unidentifiable advisory ` +
        "cannot be matched against the exception and must be assessed.",
      unresolved,
    };
  }

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

  // The recorded package, range and severity are the scope of the exception,
  // not decoration. An advisory that has widened to another package, another
  // version range or a higher severity is no longer the one that was assessed.
  const outOfScope = [];
  for (const [id, finding] of advisories) {
    const row = accepted.get(id);
    if (!finding.packages.has(row.package)) {
      outOfScope.push(
        `${id} now affects ${[...finding.packages].join(", ")}, not ${row.package}`,
      );
      continue;
    }
    if (row.vulnerableRange && finding.ranges.size > 0 &&
        ![...finding.ranges].includes(row.vulnerableRange)) {
      outOfScope.push(
        `${id} range is now ${[...finding.ranges].join(", ")}, ` +
        `recorded as ${row.vulnerableRange}`,
      );
      continue;
    }
    if (row.severity && finding.severity !== row.severity) {
      outOfScope.push(
        `${id} severity is now ${finding.severity}, recorded as ${row.severity}`,
      );
    }
  }
  if (outOfScope.length > 0) {
    return {
      ok: false,
      reason: "exception-scope-exceeded",
      message:
        `The recorded exception no longer describes what was found in the ` +
        `${population} build/test population: ${outOfScope.join("; ")}.`,
      outOfScope,
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
