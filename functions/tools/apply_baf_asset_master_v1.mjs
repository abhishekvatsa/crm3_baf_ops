import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {createRequire} from "node:module";
import {fileURLToPath, pathToFileURL} from "node:url";

const require = createRequire(import.meta.url);
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const functionsDir = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(functionsDir, "..");
const defaultManifestPath = path.join(
  repoRoot,
  "tools",
  "assets",
  "baf_asset_master_v1.json",
);
const namespaceUuid = "7a23d7b7-6fdc-4a2d-8e85-1879c4df786d";
const expectedProjectId = "crm3-baf-ops-b8638";

function uuidBytes(uuid) {
  return Buffer.from(uuid.replaceAll("-", ""), "hex");
}

export function deterministicUuid(kind, key) {
  const digest = crypto.createHash("sha1")
    .update(uuidBytes(namespaceUuid))
    .update(`${kind}:${key}`, "utf8")
    .digest()
    .subarray(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = digest.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function normalizeTag(value) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, "");
}

function expandRanges(ranges) {
  const numbers = [];
  for (const range of ranges) {
    assert.ok(Array.isArray(range) && range.length === 2, "Asset ranges must contain start/end pairs.");
    const [start, end] = range;
    assert.ok(Number.isSafeInteger(start) && Number.isSafeInteger(end) && start > 0 && start <= end);
    for (let value = start; value <= end; value += 1) numbers.push(value);
  }
  assert.equal(new Set(numbers).size, numbers.length, "Asset-number ranges must not overlap.");
  return numbers;
}

function formatAssetName(format, assetNumber) {
  return format
    .replace("{number:02}", String(assetNumber).padStart(2, "0"))
    .replace("{number}", String(assetNumber));
}

function nodeDraft(node, parentNodeId, sortOrder) {
  const roles = node.ownerRoleKeys ?? [];
  return {
    parentNodeId,
    nodeType: node.nodeType,
    name: node.name,
    componentTag: node.componentTag ?? null,
    shortDescription: node.shortDescription ?? null,
    longDescription: node.longDescription ?? null,
    discipline: node.discipline ?? null,
    operatingType: node.operatingType ?? null,
    normalState: node.normalState ?? null,
    failState: node.failState ?? null,
    contactArrangement: node.contactArrangement ?? "notStated",
    manufacturer: null,
    model: null,
    applicability: node.applicability ?? null,
    sourceReference: node.sourceReference ?? null,
    ownershipStatus: roles.length === 0 ? "unassigned" : "provisional",
    ownerDiscipline: roles.length === 0 ? null : node.discipline,
    accountableRoleKeys: roles,
    sortOrder,
  };
}

function flattenNodes(assetClass, classId) {
  const rows = [];
  const visit = (nodes, parentPath, parentNodeId) => {
    nodes.forEach((node, index) => {
      const nodePath = parentPath.length === 0 ? node.key : `${parentPath}/${node.key}`;
      const nodeId = deterministicUuid("node", `${assetClass.code}:${nodePath}`);
      const requestId = deterministicUuid("request", `CREATE_NODE:${assetClass.code}:${nodePath}`);
      rows.push({
        entityType: "node",
        entityId: nodeId,
        requestId,
        data: {
          requestId,
          operation: "CREATE_NODE",
          assetClassId: classId,
          expectedAssetClassVersion: 1,
          nodeId,
          reason: "Initial governed BAF hierarchy population from the approved manual-derived source baseline.",
          allowTagTransfer: false,
          nodeDraft: nodeDraft(node, parentNodeId, (index + 1) * 100),
        },
        source: node,
        path: nodePath,
      });
      visit(node.children ?? [], nodePath, nodeId);
    });
  };
  visit(assetClass.hierarchy, "", null);
  return rows;
}

export async function loadManifest(manifestPath = defaultManifestPath) {
  return JSON.parse(await fs.readFile(manifestPath, "utf8"));
}

export function buildPlan(manifest) {
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.productionProjectId, expectedProjectId);
  assert.equal(manifest.assetClasses.length, 4);
  assert.deepEqual(
    manifest.assetClasses.map((item) => item.key).sort(),
    ["base", "forceCooler", "furnace", "innerCover"],
  );

  const classes = [];
  const nodes = [];
  const assets = [];
  const tags = new Set();
  const entityIds = new Set();
  const requestIds = new Set();
  let pendingInnerCoverCount = 0;

  for (const assetClass of manifest.assetClasses) {
    const classId = deterministicUuid("class", assetClass.code);
    const requestId = deterministicUuid("request", `CREATE_CLASS:${assetClass.code}`);
    const classEntry = {
      entityType: "class",
      entityId: classId,
      requestId,
      classKey: assetClass.key,
      data: {
        requestId,
        operation: "CREATE_CLASS",
        assetClassId: classId,
        reason: "Initial governed BAF asset-class population approved by the plant owner.",
        classDraft: {
          code: assetClass.code,
          name: assetClass.name,
          majorArea: assetClass.majorArea,
          shortDescription: assetClass.shortDescription,
          longDescription: assetClass.longDescription,
          legacyAssetTypeKey: assetClass.legacyAssetTypeKey,
        },
      },
    };
    classes.push(classEntry);

    for (const node of flattenNodes(assetClass, classId)) {
      const tag = node.data.nodeDraft.componentTag;
      if (tag != null) {
        const normalized = normalizeTag(tag);
        assert.ok(normalized.length > 0, `Tag ${tag} must normalize to a non-empty value.`);
        assert.ok(!tags.has(normalized), `Duplicate hierarchy tag ${tag}.`);
        tags.add(normalized);
      }
      assert.ok(node.data.nodeDraft.shortDescription?.length > 0, `${node.path} needs a short description.`);
      assert.ok(node.data.nodeDraft.sourceReference?.length > 0, `${node.path} needs a source reference.`);
      if (node.data.nodeDraft.ownershipStatus === "provisional") {
        assert.ok(node.data.nodeDraft.ownerDiscipline?.length > 0, `${node.path} needs a provisional discipline.`);
      }
      nodes.push(node);
    }

    const assetNumbers = expandRanges(assetClass.assetNumberRanges);
    if (assetClass.key === "innerCover") {
      assert.equal(assetNumbers.length, 0, "Inner Covers must not receive fabricated numeric identities.");
      pendingInnerCoverCount = assetClass.pendingSerialIntakeCount;
      assert.equal(pendingInnerCoverCount, 44);
      continue;
    }
    assert.ok(typeof assetClass.assetNameFormat === "string" && assetClass.assetNameFormat.length > 0);
    for (const assetNumber of assetNumbers) {
      const assetId = deterministicUuid("asset", `${assetClass.code}:${assetNumber}`);
      const assetRequestId = deterministicUuid(
        "request",
        `CREATE_ASSET_INSTANCE:${assetClass.code}:${assetNumber}`,
      );
      assets.push({
        entityType: "asset",
        entityId: assetId,
        requestId: assetRequestId,
        classKey: assetClass.key,
        data: {
          requestId: assetRequestId,
          operation: "CREATE_ASSET_INSTANCE",
          assetClassId: classId,
          assetInstanceId: assetId,
          expectedAssetClassVersion: 1,
          reason: "Initial governed BAF physical-asset population from the owner-approved plant numbering range.",
          assetDraft: {
            assetNumber,
            name: formatAssetName(assetClass.assetNameFormat, assetNumber),
            plantTag: null,
            location: null,
            manufacturer: null,
            model: null,
            serialNumber: null,
            commissionedOn: null,
            serviceState: "inService",
            ownershipStatus: "unassigned",
            ownerDiscipline: null,
            accountableRoleKeys: [],
          },
        },
      });
    }
  }

  for (const entry of [...classes, ...nodes, ...assets]) {
    assert.ok(!entityIds.has(entry.entityId), `Duplicate entity ID ${entry.entityId}.`);
    assert.ok(!requestIds.has(entry.requestId), `Duplicate request ID ${entry.requestId}.`);
    entityIds.add(entry.entityId);
    requestIds.add(entry.requestId);
  }
  assert.equal(assets.filter((item) => item.classKey === "base").length, 47);
  assert.equal(assets.filter((item) => item.classKey === "furnace").length, 26);
  assert.equal(assets.filter((item) => item.classKey === "forceCooler").length, 25);
  assert.equal(assets.length, 98);

  return {
    classes,
    nodes,
    assets,
    pendingInnerCoverIntake: Array.from(
      {length: pendingInnerCoverCount},
      (_, index) => ({
        intakeSlot: index + 1,
        serialNumber: null,
        status: "awaiting-real-serial",
        createsOperationalIdentity: false,
      }),
    ),
  };
}

function parseArgs(argv) {
  const options = {
    apply: false,
    projectId: null,
    actorUid: null,
    manifestPath: defaultManifestPath,
    reportPath: path.join(
      repoRoot,
      "release",
      "evidence",
      "baf-primary-asset-master-v1-production.json",
    ),
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--apply") options.apply = true;
    else if (argument === "--project") options.projectId = argv[++index];
    else if (argument === "--actor-uid") options.actorUid = argv[++index];
    else if (argument === "--manifest") options.manifestPath = path.resolve(argv[++index]);
    else if (argument === "--report") options.reportPath = path.resolve(argv[++index]);
    else throw new Error(`Unsupported argument: ${argument}`);
  }
  assert.equal(options.projectId, expectedProjectId, `--project must be ${expectedProjectId}.`);
  assert.ok(
    typeof options.actorUid === "string" && options.actorUid.trim().length > 0,
    "--actor-uid must identify the approved Admin executing the migration.",
  );
  options.actorUid = options.actorUid.trim();
  return options;
}

async function collectionMap(db, collectionName) {
  const snapshot = await db.collection(collectionName).get();
  return new Map(snapshot.docs.map((document) => [document.id, document.data()]));
}

function sameRoles(actual, expected) {
  return JSON.stringify([...(actual ?? [])].sort()) === JSON.stringify([...expected].sort());
}

function ensureExpectedCollection(actual, expected, collectionName) {
  const expectedIds = new Set(expected.map((entry) => entry.entityId));
  const unexpected = [...actual.keys()].filter((id) => !expectedIds.has(id));
  assert.deepEqual(unexpected, [], `${collectionName} contains unexpected production records.`);
  const existingEntryKeys = new Set();
  for (const entry of expected) {
    const current = actual.get(entry.entityId);
    if (current == null) continue;
    existingEntryKeys.add(`${entry.entityType}:${entry.entityId}`);
    assert.equal(current.status, "active", `${collectionName}/${entry.entityId} must be active.`);
    if (entry.entityType === "class") {
      const draft = entry.data.classDraft;
      assert.equal(current.assetClassId, entry.entityId);
      assert.equal(current.code, draft.code);
      assert.equal(current.name, draft.name);
      assert.equal(current.majorArea, draft.majorArea);
      assert.equal(current.shortDescription, draft.shortDescription);
      assert.equal(current.longDescription, draft.longDescription);
      assert.equal(current.legacyAssetTypeKey, draft.legacyAssetTypeKey);
    } else if (entry.entityType === "node") {
      const draft = entry.data.nodeDraft;
      assert.equal(current.nodeId, entry.entityId);
      assert.equal(current.assetClassId, entry.data.assetClassId);
      for (const field of [
        "parentNodeId", "nodeType", "name", "componentTag", "shortDescription",
        "longDescription", "discipline", "operatingType", "normalState", "failState",
        "contactArrangement", "manufacturer", "model", "applicability", "sourceReference",
        "ownershipStatus", "ownerDiscipline", "sortOrder",
      ]) {
        assert.equal(current[field] ?? null, draft[field] ?? null, `${collectionName}/${entry.entityId}.${field} drifted.`);
      }
      assert.ok(sameRoles(current.accountableRoleKeys, draft.accountableRoleKeys));
      assert.equal(
        current.normalizedComponentTag ?? null,
        draft.componentTag == null ? null : normalizeTag(draft.componentTag),
      );
    } else {
      const draft = entry.data.assetDraft;
      assert.equal(current.assetInstanceId, entry.entityId);
      assert.equal(current.assetClassId, entry.data.assetClassId);
      for (const field of [
        "assetNumber", "name", "plantTag", "location", "manufacturer", "model",
        "serialNumber", "serviceState", "ownershipStatus", "ownerDiscipline",
      ]) {
        assert.equal(current[field] ?? null, draft[field] ?? null, `${collectionName}/${entry.entityId}.${field} drifted.`);
      }
      assert.ok(sameRoles(current.accountableRoleKeys, draft.accountableRoleKeys));
    }
  }
  return existingEntryKeys;
}

async function productionPreflight(db, plan, actorUid) {
  const [users, classes, nodes, assets, profiles] = await Promise.all([
    collectionMap(db, "users"),
    collectionMap(db, "asset_classes"),
    collectionMap(db, "asset_hierarchy_nodes"),
    collectionMap(db, "asset_instances"),
    collectionMap(db, "inner_cover_profiles"),
  ]);
  const actor = users.get(actorUid);
  assert.equal(actor?.isApproved, true, "The selected migration actor must be approved.");
  assert.ok(Array.isArray(actor?.roles) && actor.roles.includes("admin"), "The selected migration actor must be an Admin.");
  const existingEntryKeys = new Set([
    ...ensureExpectedCollection(classes, plan.classes, "asset_classes"),
    ...ensureExpectedCollection(nodes, plan.nodes, "asset_hierarchy_nodes"),
    ...ensureExpectedCollection(assets, plan.assets, "asset_instances"),
  ]);
  assert.equal(profiles.size, 0, "Inner Cover profiles already exist; serial reconciliation is required before this migration.");
  return {
    summary: {
      existingClasses: classes.size,
      existingNodes: nodes.size,
      existingAssets: assets.size,
      existingInnerCoverProfiles: profiles.size,
    },
    existingEntryKeys,
  };
}

async function verifyReceiptsAndAudits(db, plan) {
  const entries = [...plan.classes, ...plan.nodes, ...plan.assets];
  const receiptRefs = entries.map((entry) => db.collection("asset_hierarchy_mutation_receipts").doc(entry.requestId));
  const auditRefs = entries.map((entry) => {
    const prefix = entry.entityType === "asset" ? "asset_registry" : "asset_hierarchy";
    return db.collection("asset_hierarchy_audits").doc(`${prefix}_${entry.requestId}`);
  });
  const snapshots = await db.getAll(...receiptRefs, ...auditRefs);
  const missing = snapshots.filter((snapshot) => !snapshot.exists).map((snapshot) => snapshot.ref.path);
  assert.deepEqual(missing, [], "Every migration entity must have a receipt and audit record.");
  return {receiptCount: receiptRefs.length, auditCount: auditRefs.length};
}

function gitValue(args) {
  return execFileSync("git", args, {cwd: repoRoot, encoding: "utf8"}).trim();
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, undefined, "Production migration cannot run against an emulator environment.");
  const manifestBytes = await fs.readFile(options.manifestPath);
  const manifest = JSON.parse(manifestBytes.toString("utf8"));
  const plan = buildPlan(manifest);
  const admin = require("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: options.projectId,
    });
  }
  const db = admin.firestore();
  const before = await productionPreflight(db, plan, options.actorUid);
  const summary = {
    manifestId: manifest.manifestId,
    mode: options.apply ? "apply" : "dry-run",
    projectId: options.projectId,
    classCount: plan.classes.length,
    hierarchyNodeCount: plan.nodes.length,
    physicalAssetCount: plan.assets.length,
    physicalAssetCounts: {
      base: plan.assets.filter((entry) => entry.classKey === "base").length,
      furnace: plan.assets.filter((entry) => entry.classKey === "furnace").length,
      forceCooler: plan.assets.filter((entry) => entry.classKey === "forceCooler").length,
    },
    pendingInnerCoverSerialIntakeCount: plan.pendingInnerCoverIntake.length,
    preflight: before.summary,
  };
  if (!options.apply) {
    console.log(JSON.stringify(summary, null, 2));
    return;
  }

  const {mutateAssetHierarchyWithDb} = require(path.join(functionsDir, "lib", "assetHierarchyMutation.js"));
  const {mutateAssetRegistryWithDb} = require(path.join(functionsDir, "lib", "assetRegistryMutation.js"));
  const common = {
    db,
    authUid: options.actorUid,
    timestampFromDate: admin.firestore.Timestamp.fromDate,
  };
  let completed = 0;
  let skipped = 0;
  for (const entry of [...plan.classes, ...plan.nodes, ...plan.assets]) {
    if (before.existingEntryKeys.has(`${entry.entityType}:${entry.entityId}`)) {
      skipped += 1;
      continue;
    }
    const mutate = entry.entityType === "asset" ? mutateAssetRegistryWithDb : mutateAssetHierarchyWithDb;
    await mutate({...common, data: entry.data});
    completed += 1;
    if (completed % 25 === 0) console.log(`Applied ${completed} governed mutations.`);
  }

  const after = await productionPreflight(db, plan, options.actorUid);
  assert.equal(after.summary.existingClasses, plan.classes.length);
  assert.equal(after.summary.existingNodes, plan.nodes.length);
  assert.equal(after.summary.existingAssets, plan.assets.length);
  const evidence = await verifyReceiptsAndAudits(db, plan);
  const report = {
    schemaVersion: 1,
    evidenceType: "BAF_PRIMARY_ASSET_MASTER_PRODUCTION_POPULATION",
    generatedAt: new Date().toISOString(),
    manifestId: manifest.manifestId,
    manifestSha256: crypto.createHash("sha256").update(manifestBytes).digest("hex"),
    projectId: options.projectId,
    sourceCommit: gitValue(["rev-parse", "HEAD"]),
    sourceTree: gitValue(["rev-parse", "HEAD^{tree}"]),
    actorUidSha256: crypto.createHash("sha256").update(options.actorUid).digest("hex"),
    authorizationBasis: "Owner instruction dated 2026-08-18",
    executionBoundary: "One-time ADC-backed invocation of the production mutation services with preflight and in-transaction Admin revalidation, deterministic receipts and audits. Callable admission and rate limiting were not used.",
    counts: {
      assetClasses: plan.classes.length,
      hierarchyNodes: plan.nodes.length,
      physicalAssets: plan.assets.length,
      bases: summary.physicalAssetCounts.base,
      furnaces: summary.physicalAssetCounts.furnace,
      forcedCoolers: summary.physicalAssetCounts.forceCooler,
      registeredInnerCovers: 0,
      pendingRealSerialIntakeSlots: plan.pendingInnerCoverIntake.length,
      receipts: evidence.receiptCount,
      audits: evidence.auditCount,
    },
    innerCoverIdentityDecision: {
      operationalProfilesCreated: false,
      reason: "Real serial number is the permanent Inner Cover identity; placeholders are prohibited.",
      nextAction: "Register each of the 44 covers through REGISTER_INNER_COVER when its real serial and source details are supplied.",
    },
    result: "PASS",
  };
  await fs.mkdir(path.dirname(options.reportPath), {recursive: true});
  await fs.writeFile(options.reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(JSON.stringify({
    ...summary,
    appliedMutations: completed,
    resumedExistingMutations: skipped,
    postReadback: after.summary,
    evidence,
    reportPath: options.reportPath,
  }, null, 2));
}

const invokedPath = process.argv[1] == null ? null : pathToFileURL(path.resolve(process.argv[1])).href;
if (invokedPath === import.meta.url) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
