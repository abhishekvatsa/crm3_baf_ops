import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  EXCEPTION_PATH,
  assess,
  resolveAdvisories,
} from "./verify_build_test_dependency_audit.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "../..");
const exception = JSON.parse(
  fs.readFileSync(path.join(repositoryRoot, EXCEPTION_PATH), "utf8"),
);

const recorded = "GHSA-2883-xcg3-v3hh";
const withinPeriod = new Date("2026-09-09T00:00:00Z");
const afterReview = new Date("2027-01-01T00:00:00Z");

// Shaped exactly like npm audit --json: one advisory reaching a dependent
// appears as two vulnerability entries, and only object `via` members are
// advisories.
function reportWith(advisories) {
  const vulnerabilities = {};
  for (const {id, pkg, range, severity, dependent} of advisories) {
    vulnerabilities[pkg] = {
      severity,
      range,
      isDirect: true,
      via: [{
        source: 1,
        name: pkg,
        url: `https://github.com/advisories/${id}`,
        severity,
      }],
      effects: dependent ? [dependent] : [],
    };
    if (dependent) {
      vulnerabilities[dependent] = {
        severity,
        range: "",
        isDirect: false,
        via: [pkg],
        effects: [],
      };
    }
  }
  return {auditReportVersion: 2, vulnerabilities};
}

const jsYaml = {
  id: recorded,
  pkg: "js-yaml",
  range: "3.0.0 - 3.15.1",
  severity: "high",
  dependent: "@istanbuljs/load-nyc-config",
};

test("one advisory reaching a dependent resolves to one advisory, not two findings", () => {
  const resolved = resolveAdvisories(reportWith([jsYaml]));
  assert.equal(resolved.size, 1);
  assert.ok(resolved.has(recorded));
  // npm would report two vulnerable packages here; the exception is written
  // against advisory identity so a count could not admit a second advisory.
  assert.equal(Object.keys(reportWith([jsYaml]).vulnerabilities).length, 2);
});

test("the recorded advisory is permitted within its review period", () => {
  for (const population of ["root", "functions"]) {
    const verdict = assess({
      report: reportWith([jsYaml]),
      exception,
      population,
      now: withinPeriod,
    });
    assert.equal(verdict.ok, true, verdict.message);
    assert.equal(verdict.reason, "exception-applies");
  }
});

test("an unrelated advisory is rejected", () => {
  const verdict = assess({
    report: reportWith([
      jsYaml,
      {id: "GHSA-xxxx-yyyy-zzzz", pkg: "left-pad", range: "<1.0.0", severity: "critical"},
    ]),
    exception,
    population: "root",
    now: withinPeriod,
  });
  assert.equal(verdict.ok, false);
  assert.equal(verdict.reason, "unrecorded-advisory");
  assert.deepEqual(verdict.unexpected, ["GHSA-xxxx-yyyy-zzzz"]);
});

test("an expired exception is rejected while its advisory is still present", () => {
  const verdict = assess({
    report: reportWith([jsYaml]),
    exception,
    population: "root",
    now: afterReview,
  });
  assert.equal(verdict.ok, false);
  assert.equal(verdict.reason, "exception-expired");
});

test("an unavailable audit is not treated as clean", () => {
  for (const bad of [
    {report: null, auditOk: false},
    {report: undefined, auditOk: true},
    {report: "not a report", auditOk: true},
  ]) {
    const verdict = assess({
      ...bad,
      exception,
      population: "root",
      now: withinPeriod,
    });
    assert.equal(verdict.ok, false, JSON.stringify(bad));
    assert.equal(verdict.reason, "audit-unavailable");
  }
});

test("a cleared population reports the exception as closable, not expired", () => {
  const verdict = assess({
    report: reportWith([]),
    exception,
    population: "root",
    now: afterReview,
  });
  assert.equal(verdict.ok, true);
  assert.equal(verdict.reason, "exception-closable");
});

test("the exception does not apply to a population it was not recorded for", () => {
  const scoped = {
    ...exception,
    accepted: [{...exception.accepted[0], populations: ["functions"]}],
  };
  const verdict = assess({
    report: reportWith([jsYaml]),
    exception: scoped,
    population: "root",
    now: withinPeriod,
  });
  assert.equal(verdict.ok, false);
  assert.equal(verdict.reason, "unrecorded-advisory");
});

test("the machine-readable exception and its human record agree", () => {
  assert.equal(exception.schemaVersion, 1);
  assert.ok(fs.existsSync(path.join(repositoryRoot, exception.humanRecord)));
  const record = fs.readFileSync(
    path.join(repositoryRoot, exception.humanRecord),
    "utf8",
  );
  for (const row of exception.accepted) {
    assert.ok(record.includes(row.advisory), `${row.advisory} absent from the record`);
    assert.ok(record.includes(row.package), `${row.package} absent from the record`);
  }
  assert.ok(record.includes(exception.reviewBy), "review date absent from the record");
  assert.ok(exception.owner && exception.owner.length > 0);
});
