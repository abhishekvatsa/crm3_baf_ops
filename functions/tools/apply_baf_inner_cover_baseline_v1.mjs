import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {createRequire} from "node:module";
import {fileURLToPath, pathToFileURL} from "node:url";

import {deterministicUuid} from "./apply_baf_asset_master_v1.mjs";

const require = createRequire(import.meta.url);
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const functionsDir = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(functionsDir, "..");
const expectedProjectId = "crm3-baf-ops-b8638";
const expectedManifestId = "crm3-baf-inner-cover-baseline-v1";
const expectedManifestSha256 =
  "c71d471c08dd56b94c18c51687e16dc3ab223bc4e1514690823bb777e492789c";
const defaultManifestPath = path.join(
  repoRoot,
  "tools",
  "assets",
  "baf_inner_cover_baseline_v1.json",
);
const defaultReportPath = path.join(
  repoRoot,
  "release",
  "evidence",
  "baf-inner-cover-baseline-v1-production.json",
);
const baselineInstant = "2026-08-22T00:00:00.000Z";
const fabricationSectionTypes = [
  "lowerAssembly",
  "flatVertical",
  "corrugatedShell",
  "topCover",
];
const originClassifications = new Set([
  "ownerDeclaredFabricated",
  "ownerDeclaredNew",
  "legacyUndocumented",
]);

const normalizeSerial = (value) =>
  value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, "");

const sha256Hex = (value) =>
  crypto.createHash("sha256").update(value).digest("hex");

const exactIsoDate = (value, label) => {
  assert.match(value, /^\d{4}-\d{2}-\d{2}$/, `${label} must be YYYY-MM-DD.`);
  const date = new Date(`${value}T12:00:00.000Z`);
  assert.equal(
    date.toISOString(),
    `${value}T12:00:00.000Z`,
    `${label} must be a real calendar date.`,
  );
  assert.ok(date <= new Date(baselineInstant), `${label} cannot be in the future.`);
  return date.toISOString();
};

const sourceTypeFor = (origin) =>
  origin === "ownerDeclaredFabricated" ? "fabricated" : "legacyExisting";

const expectedTraceabilityFor = (origin) =>
  origin === "ownerDeclaredNew" ? "T1" : "T0";

const fabricatedSectionsFor = (serialNumber) =>
  fabricationSectionTypes.map((sectionType) => ({
    sectionId: deterministicUuid(
      "inner-cover-section",
      `${serialNumber}:${sectionType}`,
    ),
    sectionType,
    materialSource: "reusedUnknownLegacyDonor",
    donorInnerCoverId: null,
    donorSectionKey: null,
    donorExpectedVersion: null,
    lengthMm: null,
    cutCount: 1,
    notes: "Historical section ancestry was not documented at baseline intake.",
  }));

export async function loadManifest(manifestPath = defaultManifestPath) {
  return JSON.parse(await fs.readFile(manifestPath, "utf8"));
}

export function buildPlan(manifest) {
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.manifestId, expectedManifestId);
  assert.equal(manifest.productionProjectId, expectedProjectId);
  assert.equal(manifest.records.length, 38);
  assert.equal(
    manifest.baselineAcceptanceReference,
    "OWNER-BASELINE-2026-08-22",
  );
  const baseNumbers = new Set();
  const serials = new Set();
  const records = manifest.records.map((record) => {
    assert.ok(Number.isSafeInteger(record.baseNumber) && record.baseNumber > 0);
    assert.ok(!baseNumbers.has(record.baseNumber), `Duplicate Base ${record.baseNumber}.`);
    baseNumbers.add(record.baseNumber);
    assert.equal(typeof record.serialNumber, "string");
    const serialNumber = normalizeSerial(record.serialNumber);
    assert.equal(serialNumber, record.serialNumber, `Serial ${record.serialNumber} is not canonical.`);
    assert.ok(!serials.has(serialNumber), `Duplicate serial ${serialNumber}.`);
    serials.add(serialNumber);
    assert.ok(
      originClassifications.has(record.declaredOrigin),
      `Unsupported declared origin for ${serialNumber}.`,
    );
    if (serialNumber.startsWith("GR")) {
      assert.equal(record.declaredOrigin, "ownerDeclaredFabricated");
    } else if (serialNumber.startsWith("N")) {
      assert.equal(record.declaredOrigin, "ownerDeclaredNew");
    } else {
      assert.equal(record.declaredOrigin, "legacyUndocumented");
    }
    const incorporatedOn = exactIsoDate(
      record.incorporatedOn,
      `${serialNumber}.incorporatedOn`,
    );
    const innerCoverId = deterministicUuid("inner-cover", serialNumber);
    const registerRequestId = deterministicUuid(
      "request",
      `INNER_COVER_BASELINE_V1:REGISTER:${serialNumber}`,
    );
    const acceptRequestId = deterministicUuid(
      "request",
      `INNER_COVER_BASELINE_V1:ACCEPT:${serialNumber}`,
    );
    const linkRequestId = deterministicUuid(
      "request",
      `INNER_COVER_BASELINE_V1:LINK:${serialNumber}:BASE:${record.baseNumber}`,
    );
    const origin = record.declaredOrigin;
    return {
      baseNumber: record.baseNumber,
      serialNumber,
      sourceDateText: record.sourceDateText ?? null,
      dateResolution: record.dateResolution ?? null,
      sourceSerialText: record.sourceSerialText ?? null,
      incorporatedOn,
      declaredOrigin: origin,
      sourceType: sourceTypeFor(origin),
      expectedTraceabilityGrade: expectedTraceabilityFor(origin),
      innerCoverId,
      registerRequestId,
      acceptRequestId,
      linkRequestId,
      linkageId: `link_${linkRequestId}`,
      fabricationSections:
        origin === "ownerDeclaredFabricated" ?
          fabricatedSectionsFor(serialNumber) : [],
    };
  });
  const originCounts = Object.fromEntries(
    [...originClassifications].map((origin) => [
      origin,
      records.filter((record) => record.declaredOrigin === origin).length,
    ]),
  );
  assert.deepEqual(originCounts, {
    ownerDeclaredFabricated: 14,
    ownerDeclaredNew: 8,
    legacyUndocumented: 16,
  });
  return {
    manifestId: manifest.manifestId,
    authorizationBasis: manifest.authorizationBasis,
    baselineAcceptanceReference: manifest.baselineAcceptanceReference,
    records,
    originCounts,
  };
}

function parseArgs(argv) {
  const options = {
    apply: false,
    projectId: null,
    actorUid: null,
    manifestPath: defaultManifestPath,
    reportPath: defaultReportPath,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--apply") options.apply = true;
    else if (argument === "--project") options.projectId = argv[++index];
    else if (argument === "--actor-uid") options.actorUid = argv[++index];
    else if (argument === "--manifest") {
      options.manifestPath = path.resolve(argv[++index]);
    } else if (argument === "--report") {
      options.reportPath = path.resolve(argv[++index]);
    } else {
      throw new Error(`Unsupported argument: ${argument}`);
    }
  }
  assert.equal(options.projectId, expectedProjectId);
  assert.ok(typeof options.actorUid === "string" && options.actorUid.trim());
  options.actorUid = options.actorUid.trim();
  return options;
}

const collectionMap = async (db, name) => {
  const snapshot = await db.collection(name).get();
  return new Map(snapshot.docs.map((document) => [document.id, document.data()]));
};

const timestampIso = (value, label) => {
  const date = value instanceof Date ? value : value?.toDate?.();
  assert.ok(date instanceof Date && Number.isFinite(date.getTime()), `${label} must be a timestamp.`);
  return date.toISOString();
};

const exactClass = (classes, key) => {
  const matches = [...classes.entries()].filter(([, value]) =>
    value.legacyAssetTypeKey === key && value.status === "active",
  );
  assert.equal(matches.length, 1, `Exactly one active ${key} class is required.`);
  return {id: matches[0][0], ...matches[0][1]};
};

function verifyProfile(record, profile, innerClassId) {
  assert.equal(profile.schemaVersion, 1);
  assert.equal(profile.innerCoverId, record.innerCoverId);
  assert.equal(profile.assetClassId, innerClassId);
  assert.equal(profile.serialNumber, record.serialNumber);
  assert.equal(profile.normalizedSerialNumber, record.serialNumber);
  assert.equal(profile.sourceType, record.sourceType);
  assert.equal(profile.originClassification, record.declaredOrigin);
  assert.equal(profile.traceabilityGrade, record.expectedTraceabilityGrade);
  assert.equal(timestampIso(profile.incorporatedOn, `${record.serialNumber}.incorporatedOn`), record.incorporatedOn);
}

async function preflight(db, plan, actorUid) {
  const [actorSnapshot, classes, assets, profiles, assignments] = await Promise.all([
    db.collection("users").doc(actorUid).get(),
    collectionMap(db, "asset_classes"),
    collectionMap(db, "asset_instances"),
    collectionMap(db, "inner_cover_profiles"),
    collectionMap(db, "base_inner_cover_assignments"),
  ]);
  const actor = actorSnapshot.data();
  assert.equal(actor?.isApproved, true, "Migration actor must be approved.");
  assert.ok(actor?.roles?.includes("admin"), "Migration actor must be an Admin.");
  const baseClass = exactClass(classes, "base");
  const innerClass = exactClass(classes, "innerCover");
  const baseByNumber = new Map();
  for (const [id, asset] of assets) {
    if (asset.assetClassId !== baseClass.id || asset.status !== "active") continue;
    assert.ok(!baseByNumber.has(asset.assetNumber), `Duplicate governed Base ${asset.assetNumber}.`);
    baseByNumber.set(asset.assetNumber, {id, ...asset});
  }
  const expectedProfileIds = new Set(plan.records.map((record) => record.innerCoverId));
  for (const profileId of profiles.keys()) {
    assert.ok(expectedProfileIds.has(profileId), `Unexpected Inner Cover profile ${profileId}; reconciliation is required.`);
  }
  const expectedBaseIds = new Set();
  const progress = {pending: 0, registered: 0, accepted: 0, installed: 0};
  for (const record of plan.records) {
    const base = baseByNumber.get(record.baseNumber);
    assert.ok(base, `Governed Base ${record.baseNumber} was not found.`);
    expectedBaseIds.add(base.id);
    record.base = base;
    const profile = profiles.get(record.innerCoverId);
    if (profile == null) {
      progress.pending += 1;
      continue;
    }
    verifyProfile(record, profile, innerClass.id);
    if (profile.lifecycleState === "awaitingInspection" && profile.version === 1) {
      progress.registered += 1;
    } else if (profile.lifecycleState === "available" && profile.version === 2) {
      progress.accepted += 1;
    } else if (profile.lifecycleState === "installed" && profile.version === 3) {
      const assignment = assignments.get(base.id);
      assert.equal(assignment?.innerCoverId, record.innerCoverId);
      assert.equal(assignment?.innerCoverSerialNumber, record.serialNumber);
      assert.equal(assignment?.linkageId, record.linkageId);
      progress.installed += 1;
    } else {
      assert.fail(`${record.serialNumber} has an unsupported baseline state/version.`);
    }
  }
  for (const assignmentId of assignments.keys()) {
    assert.ok(expectedBaseIds.has(assignmentId), `Unexpected Base assignment ${assignmentId}; reconciliation is required.`);
  }
  return {actor, baseClass, innerClass, progress};
}

const registrationRequest = (record, innerClassId) => ({
  requestId: record.registerRequestId,
  operation: "REGISTER_INNER_COVER",
  innerCoverId: record.innerCoverId,
  innerCoverAssetClassId: innerClassId,
  reason: `Owner-authorized baseline registration of Inner Cover ${record.serialNumber} currently associated with Base ${record.baseNumber}.`,
  registrationDraft: {
    serialNumber: record.serialNumber,
    sourceType: record.sourceType,
    originClassification: record.declaredOrigin,
    supplierOrFabricator: null,
    receivedOrCompletedOn: null,
    incorporatedOn: record.incorporatedOn,
    drawingReference: null,
    materialGrade: null,
    notes: "Owner-declared current identity and Base association. Historical source and inspection documentation was not asserted.",
    fabricationSections: record.fabricationSections,
  },
});

const acceptanceRequest = (record, reference) => ({
  requestId: record.acceptRequestId,
  operation: "ACCEPT_INNER_COVER",
  innerCoverId: record.innerCoverId,
  expectedVersion: 1,
  reason: `Establish the owner-authorized digital baseline before recording the current Base ${record.baseNumber} position.`,
  acceptanceDraft: {
    inspectedOn: baselineInstant,
    acceptanceReference: reference,
    leakTestReference: null,
    ndtReference: null,
    notes: "Administrative baseline acceptance of the declared current installation; no historical technical inspection record is claimed.",
  },
});

const linkRequest = (record) => ({
  requestId: record.linkRequestId,
  operation: "LINK_INNER_COVER",
  innerCoverId: record.innerCoverId,
  expectedVersion: 2,
  targetBaseAssetInstanceId: record.base.id,
  reason: `Record the owner-declared current pairing of Inner Cover ${record.serialNumber} with Base ${record.baseNumber}.`,
});

async function applyPlan(db, plan, innerClassId, actorUid, admin) {
  const {mutateInnerCoverLifecycleWithDb} = require(
    path.join(functionsDir, "lib", "innerCoverLifecycleMutation.js"),
  );
  const invoke = (data) => mutateInnerCoverLifecycleWithDb({
    db,
    authUid: actorUid,
    data,
    timestampFromDate: admin.firestore.Timestamp.fromDate,
  });
  const applied = {registered: 0, accepted: 0, linked: 0, resumed: 0};
  for (const record of plan.records) {
    let snapshot = await db.collection("inner_cover_profiles").doc(record.innerCoverId).get();
    if (!snapshot.exists) {
      await invoke(registrationRequest(record, innerClassId));
      applied.registered += 1;
      snapshot = await snapshot.ref.get();
    } else {
      applied.resumed += 1;
    }
    let profile = snapshot.data();
    if (profile.lifecycleState === "awaitingInspection" && profile.version === 1) {
      await invoke(acceptanceRequest(record, plan.baselineAcceptanceReference));
      applied.accepted += 1;
      profile = (await snapshot.ref.get()).data();
    }
    if (profile.lifecycleState === "available" && profile.version === 2) {
      await invoke(linkRequest(record));
      applied.linked += 1;
    }
  }
  return applied;
}

async function verifyReadback(db, plan, innerClassId, actorUid) {
  const receiptIds = [];
  const auditIds = [];
  let fabricationCount = 0;
  for (const record of plan.records) {
    const [profileSnapshot, assignmentSnapshot, linkageSnapshot] = await db.getAll(
      db.collection("inner_cover_profiles").doc(record.innerCoverId),
      db.collection("base_inner_cover_assignments").doc(record.base.id),
      db.collection("inner_cover_linkages").doc(record.linkageId),
    );
    assert.ok(profileSnapshot.exists && assignmentSnapshot.exists && linkageSnapshot.exists);
    const profile = profileSnapshot.data();
    verifyProfile(record, profile, innerClassId);
    assert.equal(profile.lifecycleState, "installed");
    assert.equal(profile.currentBaseAssetInstanceId, record.base.id);
    assert.equal(profile.currentBaseAssetNumber, record.baseNumber);
    assert.equal(profile.currentLinkageId, record.linkageId);
    assert.equal(profile.version, 3);
    const assignment = assignmentSnapshot.data();
    assert.equal(assignment.baseAssetNumber, record.baseNumber);
    assert.equal(assignment.innerCoverId, record.innerCoverId);
    assert.equal(assignment.innerCoverSerialNumber, record.serialNumber);
    assert.equal(assignment.linkageId, record.linkageId);
    const linkage = linkageSnapshot.data();
    assert.equal(linkage.active, true);
    assert.equal(linkage.innerCoverId, record.innerCoverId);
    assert.equal(linkage.baseAssetInstanceId, record.base.id);
    if (record.declaredOrigin === "ownerDeclaredFabricated") {
      const dossier = await db.collection("inner_cover_fabrications").doc(record.innerCoverId).get();
      assert.ok(dossier.exists);
      assert.equal(dossier.data().originClassification, "ownerDeclaredFabricated");
      assert.equal(dossier.data().traceabilityGrade, "T0");
      assert.equal(dossier.data().sections.length, 4);
      assert.ok(dossier.data().sections.every((section) =>
        section.materialSource === "reusedUnknownLegacyDonor"));
      fabricationCount += 1;
    }
    for (const requestId of [
      record.registerRequestId,
      record.acceptRequestId,
      record.linkRequestId,
    ]) {
      receiptIds.push(requestId);
      auditIds.push(`inner_cover_${requestId}`);
    }
  }
  const receipts = await db.getAll(...receiptIds.map((id) =>
    db.collection("inner_cover_lifecycle_receipts").doc(id)));
  const audits = await db.getAll(...auditIds.map((id) =>
    db.collection("inner_cover_lifecycle_audits").doc(id)));
  assert.ok(receipts.every((snapshot) => snapshot.exists));
  assert.ok(audits.every((snapshot) => snapshot.exists));
  assert.ok(receipts.every((snapshot) => snapshot.data().actorUid === actorUid));
  return {
    profiles: plan.records.length,
    assignments: plan.records.length,
    activeLinkages: plan.records.length,
    fabricationDossiers: fabricationCount,
    receipts: receipts.length,
    audits: audits.length,
  };
}

const gitValue = (args) =>
  execFileSync("git", args, {cwd: repoRoot, encoding: "utf8"}).trim();

async function main() {
  const options = parseArgs(process.argv.slice(2));
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, undefined);
  const manifestBytes = await fs.readFile(options.manifestPath);
  const manifest = JSON.parse(manifestBytes.toString("utf8"));
  if (options.apply) {
    assert.equal(
      sha256Hex(manifestBytes),
      expectedManifestSha256,
      "Production apply requires the exact owner-authorized manifest bytes.",
    );
  }
  const plan = buildPlan(manifest);
  const admin = require("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: options.projectId,
    });
  }
  const db = admin.firestore();
  const before = await preflight(db, plan, options.actorUid);
  const summary = {
    manifestId: plan.manifestId,
    manifestSha256: sha256Hex(manifestBytes),
    projectId: options.projectId,
    mode: options.apply ? "apply" : "dry-run",
    records: plan.records.length,
    originCounts: plan.originCounts,
    progress: before.progress,
  };
  if (!options.apply) {
    console.log(JSON.stringify(summary, null, 2));
    await admin.app().delete();
    return;
  }
  const applied = await applyPlan(
    db,
    plan,
    before.innerClass.id,
    options.actorUid,
    admin,
  );
  const after = await preflight(db, plan, options.actorUid);
  assert.deepEqual(after.progress, {pending: 0, registered: 0, accepted: 0, installed: 38});
  const readback = await verifyReadback(
    db,
    plan,
    before.innerClass.id,
    options.actorUid,
  );
  const report = {
    schemaVersion: 1,
    evidenceType: "BAF_INNER_COVER_BASELINE_PRODUCTION_POPULATION",
    generatedAt: new Date().toISOString(),
    manifestId: plan.manifestId,
    manifestSha256: sha256Hex(manifestBytes),
    projectId: options.projectId,
    sourceCommit: gitValue(["rev-parse", "HEAD"]),
    sourceTree: gitValue(["rev-parse", "HEAD^{tree}"]),
    actorUidSha256: sha256Hex(options.actorUid),
    authorizationBasis: plan.authorizationBasis,
    qualification: "The owner supplied current Base/serial associations and incorporation dates. GR means fabricated and N means new, both without prior source documentation. No historical technical inspection record is claimed.",
    dateResolution: "The supplied GR15 date 7/14/26 was interpreted as 14 July 2026 because the source list otherwise uses DD/MM/YY and month 14 is impossible.",
    counts: {
      suppliedPairs: plan.records.length,
      priorPlannedIntakeSlots: 44,
      unresolvedSerialIntakeSlots: 6,
      ...plan.originCounts,
      ...readback,
    },
    applied,
    result: "PASS",
  };
  await fs.mkdir(path.dirname(options.reportPath), {recursive: true});
  await fs.writeFile(options.reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(JSON.stringify({...summary, applied, postReadback: readback, reportPath: options.reportPath}, null, 2));
  await admin.app().delete();
}

const invokedPath = process.argv[1] == null ? null :
  pathToFileURL(path.resolve(process.argv[1])).href;
if (invokedPath === import.meta.url) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
