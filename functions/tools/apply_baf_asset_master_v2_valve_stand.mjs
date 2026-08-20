import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath, pathToFileURL} from "node:url";

import {
  buildPlan as buildV1Plan,
  deterministicUuid,
  loadManifest as loadV1Manifest,
} from "./apply_baf_asset_master_v1.mjs";

const require = createRequire(import.meta.url);
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const functionsDir = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(functionsDir, "..");
const expectedProjectId = "crm3-baf-ops-b8638";
const defaultManifestPath = path.join(
  repoRoot,
  "tools",
  "assets",
  "baf_asset_master_v2_valve_stand.json",
);

const nodeDraft = (node, parentNodeId, sortOrder) => {
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
};

export async function loadManifest(manifestPath = defaultManifestPath) {
  return JSON.parse(await fs.readFile(manifestPath, "utf8"));
}

export async function buildPlan(manifest, baselineManifest = null) {
  assert.equal(manifest.schemaVersion, 2);
  assert.equal(manifest.productionProjectId, expectedProjectId);
  assert.equal(manifest.assetClassCode, "BASE");
  assert.equal(manifest.parentPath, "atmosphere");
  assert.equal(manifest.reparentNodePaths.length, 5);

  const v1Plan = buildV1Plan(baselineManifest ?? await loadV1Manifest());
  const baseClass = v1Plan.classes.find((entry) => entry.data.classDraft.code === "BASE");
  assert.ok(baseClass, "The governed BASE class must exist in the v1 baseline.");
  const baselineNodes = new Map(
    v1Plan.nodes
      .filter((entry) => entry.data.assetClassId === baseClass.entityId)
      .map((entry) => [entry.path, entry]),
  );
  const parent = baselineNodes.get(manifest.parentPath);
  assert.ok(parent, `Baseline parent ${manifest.parentPath} was not found.`);

  const assemblyPath = `${manifest.parentPath}/${manifest.newAssembly.key}`;
  assert.equal(baselineNodes.has(assemblyPath), false, "Valve Stand already exists in the immutable v1 baseline.");
  const assemblyId = deterministicUuid("node", `BASE:${assemblyPath}`);
  const createRequestId = deterministicUuid(
    "request",
    `V2:CREATE_NODE:BASE:${assemblyPath}`,
  );
  const createAssembly = {
    entityType: "node",
    action: "create",
    entityId: assemblyId,
    requestId: createRequestId,
    path: assemblyPath,
    data: {
      requestId: createRequestId,
      operation: "CREATE_NODE",
      assetClassId: baseClass.entityId,
      expectedAssetClassVersion: 1,
      nodeId: assemblyId,
      reason: "Add the owner-approved Valve Stand assembly without changing existing hierarchy identities.",
      allowTagTransfer: false,
      nodeDraft: nodeDraft(manifest.newAssembly, parent.entityId, 600),
    },
  };

  const moveNodes = manifest.reparentNodePaths.map((sourcePath, index) => {
    const baseline = baselineNodes.get(sourcePath);
    assert.ok(baseline, `Baseline node ${sourcePath} was not found.`);
    const requestId = deterministicUuid(
      "request",
      `V2:UPDATE_NODE:BASE:${sourcePath}:PARENT:${assemblyPath}`,
    );
    return {
      entityType: "node",
      action: "reparent",
      entityId: baseline.entityId,
      requestId,
      path: sourcePath,
      data: {
        requestId,
        operation: "UPDATE_NODE",
        assetClassId: baseClass.entityId,
        nodeId: baseline.entityId,
        expectedVersion: 1,
        reason: "Place the existing Base atmosphere item under the owner-approved Valve Stand assembly while retaining its identity.",
        allowTagTransfer: false,
        nodeDraft: nodeDraft(baseline.source, assemblyId, (index + 1) * 100),
      },
    };
  });
  assert.equal(new Set(moveNodes.map((entry) => entry.entityId)).size, moveNodes.length);
  return {
    manifestId: manifest.manifestId,
    baseClassId: baseClass.entityId,
    parentNodeId: parent.entityId,
    assemblyId,
    entries: [createAssembly, ...moveNodes],
  };
}

function parseArgs(argv) {
  const options = {
    apply: false,
    projectId: null,
    actorUid: null,
    manifestPath: defaultManifestPath,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--apply") options.apply = true;
    else if (argument === "--project") options.projectId = argv[++index];
    else if (argument === "--actor-uid") options.actorUid = argv[++index];
    else if (argument === "--manifest") options.manifestPath = path.resolve(argv[++index]);
    else throw new Error(`Unsupported argument: ${argument}`);
  }
  assert.equal(options.projectId, expectedProjectId, `--project must be ${expectedProjectId}.`);
  assert.ok(typeof options.actorUid === "string" && options.actorUid.trim().length > 0);
  options.actorUid = options.actorUid.trim();
  return options;
}

async function preflight(db, plan, actorUid) {
  const [actor, assetClass, parent, assembly, ...moving] = await db.getAll(
    db.collection("users").doc(actorUid),
    db.collection("asset_classes").doc(plan.baseClassId),
    db.collection("asset_hierarchy_nodes").doc(plan.parentNodeId),
    db.collection("asset_hierarchy_nodes").doc(plan.assemblyId),
    ...plan.entries.slice(1).map((entry) =>
      db.collection("asset_hierarchy_nodes").doc(entry.entityId)),
  );
  const actorData = actor.data();
  assert.equal(actorData?.isApproved, true, "Migration actor must be approved.");
  assert.ok(actorData?.roles?.includes("admin"), "Migration actor must be an Admin.");
  assert.equal(assetClass.data()?.version, 1, "BASE class version drifted.");
  assert.equal(parent.data()?.status, "active", "Atmosphere parent must be active.");
  if (!assembly.exists) {
    for (let index = 0; index < moving.length; index += 1) {
      const data = moving[index].data();
      assert.equal(data?.version, 1, `${plan.entries[index + 1].path} version drifted.`);
      assert.equal(data?.parentNodeId, plan.parentNodeId, `${plan.entries[index + 1].path} parent drifted.`);
    }
    return "pending";
  }
  assert.equal(assembly.data()?.parentNodeId, plan.parentNodeId);
  assert.equal(assembly.data()?.name, "Valve Stand assembly");
  for (let index = 0; index < moving.length; index += 1) {
    const data = moving[index].data();
    assert.equal(data?.version, 2, `${plan.entries[index + 1].path} must be at v2 after migration.`);
    assert.equal(data?.parentNodeId, plan.assemblyId, `${plan.entries[index + 1].path} was not moved.`);
  }
  return "applied";
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, undefined);
  const manifestBytes = await fs.readFile(options.manifestPath);
  const manifest = JSON.parse(manifestBytes.toString("utf8"));
  const plan = await buildPlan(manifest);
  const admin = require("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp({credential: admin.credential.applicationDefault(), projectId: options.projectId});
  }
  const db = admin.firestore();
  const state = await preflight(db, plan, options.actorUid);
  const summary = {
    manifestId: manifest.manifestId,
    manifestSha256: crypto.createHash("sha256").update(manifestBytes).digest("hex"),
    projectId: options.projectId,
    mode: options.apply ? "apply" : "dry-run",
    state,
    assemblyId: plan.assemblyId,
    preservedNodeIds: plan.entries.slice(1).map((entry) => entry.entityId),
    governedMutations: plan.entries.length,
  };
  if (!options.apply || state === "applied") {
    console.log(JSON.stringify(summary, null, 2));
    return;
  }
  const {mutateAssetHierarchyWithDb} = require(path.join(functionsDir, "lib", "assetHierarchyMutation.js"));
  for (const entry of plan.entries) {
    await mutateAssetHierarchyWithDb({
      db,
      authUid: options.actorUid,
      data: entry.data,
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }
  assert.equal(await preflight(db, plan, options.actorUid), "applied");
  console.log(JSON.stringify({...summary, state: "applied", result: "PASS"}, null, 2));
}

const invokedPath = process.argv[1] == null ? null : pathToFileURL(path.resolve(process.argv[1])).href;
if (invokedPath === import.meta.url) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
