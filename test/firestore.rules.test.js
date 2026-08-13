const fs = require("fs");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  getDocs,
  collection,
  query,
  where,
  Timestamp,
  serverTimestamp,
  deleteField,
  writeBatch,
  runTransaction,
  setLogLevel,
} = require("firebase/firestore");

function hierarchyAuditPayload({
  auditId,
  entityType,
  entityId,
  assetClassId,
  action,
  fromVersion,
  toVersion,
}) {
  return {
    schemaVersion: 1,
    auditId,
    entityType,
    entityId,
    assetClassId,
    action,
    reason: "Approved hierarchy test change",
    beforeJson: fromVersion === 0 ? null : "{}",
    afterJson: "{}",
    fromVersion,
    toVersion,
    performedByUid: "admin1",
    performedByName: "admin1",
    performedAt: serverTimestamp(),
  };
}

function assetClassPayload({id, mutationId}) {
  return {
    schemaVersion: 1,
    assetClassId: id,
    code: "FURNACE",
    name: "Furnace",
    majorArea: "BAF Shop Equipment",
    shortDescription: "Movable direct-fired heating package.",
    longDescription: null,
    status: "active",
    version: 1,
    createdAt: serverTimestamp(),
    createdByUid: "admin1",
    createdByName: "admin1",
    updatedAt: serverTimestamp(),
    updatedByUid: "admin1",
    updatedByName: "admin1",
    lastMutationId: mutationId,
  };
}

function hierarchyNodePayload({
  id,
  classId,
  mutationId,
  parentNodeId = null,
  ancestors = [],
}) {
  return {
    schemaVersion: 1,
    nodeId: id,
    assetClassId: classId,
    parentNodeId,
    nodeType: "component",
    name: id,
    componentTag: null,
    shortDescription: "Test component.",
    longDescription: null,
    discipline: "Mechanical",
    operatingType: "Passive",
    normalState: null,
    failState: null,
    contactArrangement: "notApplicable",
    manufacturer: null,
    model: null,
    applicability: null,
    sourceReference: null,
    sortOrder: 10,
    ancestorNodeIds: ancestors,
    activeChildCount: 0,
    status: "active",
    version: 1,
    createdAt: serverTimestamp(),
    createdByUid: "admin1",
    createdByName: "admin1",
    updatedAt: serverTimestamp(),
    updatedByUid: "admin1",
    updatedByName: "admin1",
    lastMutationId: mutationId,
  };
}

async function createGovernedAssetClass(db, id = "class-1") {
  const auditId = `audit-${id}`;
  await runTransaction(db, async (transaction) => {
    transaction.set(doc(db, `asset_classes/${id}`), assetClassPayload({
      id,
      mutationId: auditId,
    }));
    transaction.set(doc(db, "asset_class_codes/furnace"), {
      schemaVersion: 1,
      code: "FURNACE",
      assetClassId: id,
      createdAt: serverTimestamp(),
      createdByUid: "admin1",
    });
    transaction.set(
      doc(db, `asset_hierarchy_audits/${auditId}`),
      hierarchyAuditPayload({
        auditId,
        entityType: "asset_class",
        entityId: id,
        assetClassId: id,
        action: "create",
        fromVersion: 0,
        toVersion: 1,
      })
    );
  });
}

let testEnv;

const PROJECT_ID = "crm3-baf-ops-b8638";

function userDoc(uid, roles, isApproved = true) {
  return {
    name: uid,
    email: `${uid}@test.local`,
    roles,
    isApproved,
    createdAt: Timestamp.now(),
  };
}

function pendingUserPayload(email) {
  return {
    name: "Pending User",
    email,
    roles: ["operations"],
    isApproved: false,
    createdAt: Timestamp.now(),
  };
}

function notificationInstallationPayload(overrides = {}) {
  return {
    schemaVersion: 1,
    token: "installation-token",
    platform: "android",
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function auditEventPayload(overrides = {}) {
  return {
    entityType: "maintenance",
    entityId: "ticket1",
    action: "update",
    performedByUid: "ops1",
    performedByName: "Operations User",
    timestamp: Timestamp.now(),
    severity: "low",
    summary: "Updated ticket",
    beforeJson: "{}",
    afterJson: "{}",
    ...overrides,
  };
}

async function seedUser(uid, roles, isApproved = true) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "users", uid),
      userDoc(uid, roles, isApproved)
    );
  });
}

async function seedDoc(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

function dbAs(uid, token = {}) {
  return testEnv.authenticatedContext(uid, token).firestore();
}

beforeAll(async () => {
  setLogLevel("error");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
}, 120000);

beforeEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
  setLogLevel("warn");
});

describe("server-only callable abuse controls", () => {
  test("clients cannot read or mutate admission and anomaly records", async () => {
    await seedUser("admin1", ["admin"]);
    await seedDoc("callable_abuse_controls/example", {
      schemaVersion: 1,
      callableName: "mutateUserAuthority",
      principalHash: "a".repeat(64),
    });
    const db = dbAs("admin1");
    const ref = doc(db, "callable_abuse_controls/example");

    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, {schemaVersion: 1}));
    await assertFails(updateDoc(ref, {blockedRequestCount: 0}));
    await assertFails(deleteDoc(ref));
  });
});

describe("global pull server clock custody", () => {
  test("clients cannot author or replace the stamp, and stamp-only removal fails", async () => {
    await seedUser("admin1", ["admin"]);
    const db = dbAs("admin1");
    const ref = doc(db, "abnormality_types/type1");

    await assertFails(
      setDoc(ref, {
        title: "Type 1",
        _globalPullServerUpdatedAt: serverTimestamp(),
      })
    );
    await assertSucceeds(setDoc(ref, {title: "Type 1"}));
    await assertFails(
      updateDoc(ref, {_globalPullServerUpdatedAt: null})
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "abnormality_types/type1"),
        {_globalPullServerUpdatedAt: Timestamp.now()}
      );
    });

    await assertSucceeds(updateDoc(ref, {title: "Type 1 revised"}));
    await assertFails(
      updateDoc(ref, {_globalPullServerUpdatedAt: serverTimestamp()})
    );
    await assertFails(
      updateDoc(ref, {_globalPullServerUpdatedAt: deleteField()})
    );
  });

  test("legacy substantive replacement may omit the stamp for server restamping", async () => {
    await seedUser("admin1", ["admin"]);
    await seedDoc("abnormality_types/type1", {
      title: "Type 1",
      _globalPullServerUpdatedAt: Timestamp.now(),
    });
    const db = dbAs("admin1");
    const ref = doc(db, "abnormality_types/type1");

    await assertSucceeds(setDoc(ref, {title: "Type 1 revised"}));
    const replaced = await getDoc(ref);
    expect(replaced.data()._globalPullServerUpdatedAt).toBeUndefined();
  });

  test("abnormality type tombstone requires an authoritative deletion time", async () => {
    await seedUser("admin1", ["admin"]);
    await seedDoc("abnormality_types/typeDelete", {
      title: "Duplicate type",
      isDeleted: false,
      version: 1,
    });
    const ref = doc(dbAs("admin1"), "abnormality_types/typeDelete");

    await assertFails(
      updateDoc(ref, {isDeleted: true, version: 2})
    );
    await assertFails(
      updateDoc(ref, {
        isDeleted: true,
        deletedAt: Timestamp.now(),
        version: 2,
      })
    );
    await assertSucceeds(
      updateDoc(ref, {
        isDeleted: true,
        deletedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });
});

describe("charge abnormality governed admin mutations", () => {
  function chargeAbnormalityPayload(uid, overrides = {}) {
    const now = new Date().toISOString();
    return {
      firestoreId: "abn1",
      sourceChargeNo: 12001,
      abnormalityTypeId: "TYPE_1",
      abnormalityTypeTitle: "Observed process condition",
      abnormalityTypeCode: "TYPE_1",
      category: "process",
      severity: "medium",
      affectedAssets: [{assetType: "base", assetNumber: 12}],
      component: null,
      observedReason: "Observed condition requiring review",
      description: null,
      possibleRootReasonCategory: "unknown",
      possibleRootReasonNotes: null,
      reannealingStatus: "notApplicable",
      reannealedToChargeNo: null,
      loggedAt: now,
      updatedAt: now,
      loggedByUid: uid,
      loggedByName: uid,
      updatedByUid: uid,
      updatedByName: uid,
      linkedTicketFirestoreId: null,
      linkedExecutionFirestoreId: null,
      version: 1,
      isDeleted: false,
      deletedAt: null,
      deletedByUid: null,
      deletedByName: null,
      deleteReason: null,
      ...overrides,
    };
  }

  test("approved operator can still create a valid charge abnormality", async () => {
    await seedUser("operator1", ["operations"]);
    const db = dbAs("operator1");

    await assertSucceeds(
      setDoc(
        doc(db, "charge_abnormalities/abn1"),
        chargeAbnormalityPayload("operator1")
      )
    );
  });

  test.each([
    [
      "partial document",
      (payload) => {
        delete payload.possibleRootReasonNotes;
        return payload;
      },
    ],
    [
      "unknown severity",
      (payload) => ({...payload, severity: "urgent"}),
    ],
    [
      "same-source completed RA",
      (payload) => ({
        ...payload,
        reannealingStatus: "completed",
        reannealedToChargeNo: payload.sourceChargeNo,
      }),
    ],
    [
      "unexpected field",
      (payload) => ({...payload, shadowState: "unguarded"}),
    ],
  ])("approved operator cannot create %s", async (_label, mutate) => {
    await seedUser("operator1", ["operations"]);
    const payload = mutate(chargeAbnormalityPayload("operator1"));

    await assertFails(
      setDoc(doc(dbAs("operator1"), "charge_abnormalities/abn1"), payload)
    );
  });

  test("Admin client cannot directly edit or soft-delete an abnormality", async () => {
    await seedUser("admin1", ["admin"]);
    await seedDoc(
      "charge_abnormalities/abn1",
      chargeAbnormalityPayload("operator1")
    );
    const ref = doc(dbAs("admin1"), "charge_abnormalities/abn1");

    await assertFails(
      updateDoc(ref, {
        observedReason: "Ungoverned correction",
        updatedByUid: "admin1",
        version: 2,
      })
    );
    await assertFails(
      updateDoc(ref, {
        isDeleted: true,
        deletedByUid: "admin1",
        version: 2,
      })
    );
  });

  test("mutation receipts and deterministic audits are server-only", async () => {
    await seedUser("admin1", ["admin"]);
    const db = dbAs("admin1");
    const receipt = doc(
      db,
      "charge_abnormality_mutation_receipts/request1"
    );

    await assertFails(getDoc(receipt));
    await assertFails(setDoc(receipt, {requestId: "request1"}));
    await assertFails(updateDoc(receipt, {resultVersion: 2}));
    await assertFails(deleteDoc(receipt));
    const notificationReceipt = doc(
      db,
      "notification_event_receipts/event1"
    );
    await assertFails(getDoc(notificationReceipt));
    await assertFails(setDoc(notificationReceipt, {status: "completed"}));
    await assertFails(updateDoc(notificationReceipt, {status: "suppressed"}));
    await assertFails(deleteDoc(notificationReceipt));
    await assertFails(
      setDoc(doc(db, "audit_logs/server_charge_abnormality_request1"), {
        entityType: "charge_abnormality",
        entityId: "abn1",
        action: "update",
        performedByUid: "admin1",
        timestamp: Timestamp.now(),
        severity: "high",
      })
    );
  });
});

describe("users", () => {
  test("pending user can create only self as unapproved operations", async () => {
    const db = dbAs("newUser", {
      email: "new@test.local",
      email_verified: true,
    });

    await assertSucceeds(
      setDoc(doc(db, "users/newUser"), {
        name: "New User",
        email: "new@test.local",
        roles: ["operations"],
        isApproved: false,
        createdAt: Timestamp.now(),
      })
    );
  });

  test("pending user cannot self-approve", async () => {
    const db = dbAs("newUser", {
      email: "new@test.local",
      email_verified: true,
    });

    await assertFails(
      setDoc(doc(db, "users/newUser"), {
        name: "New User",
        email: "new@test.local",
        roles: ["admin"],
        isApproved: true,
        createdAt: Timestamp.now(),
      })
    );
  });


  test("admin may correct profile fields without changing authority", async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("target1", ["operations"], false);
    const db = dbAs("admin1");

    await assertSucceeds(
      updateDoc(doc(db, "users/target1"), {
        name: "Corrected Target",
        email: "corrected@test.local",
      })
    );
  });

  test.each([
    ["approval", false, {isApproved: true}],
    ["revocation", true, {isApproved: false}],
    ["role replacement", false, {roles: ["admin"]}],
    ["combined authority", false, {isApproved: true, roles: ["admin"]}],
  ])("admin client cannot perform direct %s mutation", async (
    _label,
    initialApproval,
    patch,
  ) => {
    await seedUser("admin1", ["admin"]);
    await seedUser("target1", ["operations"], initialApproval);

    await assertFails(
      updateDoc(doc(dbAs("admin1"), "users/target1"), patch)
    );
  });

  test("admin client cannot create another user authority document", async () => {
    await seedUser("admin1", ["admin"]);

    await assertFails(
      setDoc(
        doc(dbAs("admin1"), "users/createdByAdmin"),
        userDoc("createdByAdmin", ["operations"], false)
      )
    );
  });

  test("admin cannot add ungoverned top-level user fields", async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("target1", ["operations"], false);
    const db = dbAs("admin1");

    await assertFails(
      updateDoc(doc(db, "users/target1"), {
        isApproved: true,
        shadowAuthority: "admin",
      })
    );
  });

  test("authority receipts and deterministic authority audits are server-only", async () => {
    await seedUser("admin1", ["admin"]);
    const db = dbAs("admin1");

    await assertFails(
      setDoc(doc(db, "user_authority_mutation_receipts/request1"), {
        requestId: "request1",
      })
    );
    await assertFails(
      getDoc(doc(db, "user_authority_mutation_receipts/request1"))
    );
    await assertFails(
      setDoc(doc(db, "audit_logs/server_authority_request1"), {
        entityType: "user",
        entityId: "target1",
        action: "update",
        performedByUid: "admin1",
        timestamp: Timestamp.now(),
        severity: "high",
      })
    );
  });
});

describe("server-written authority capsule", () => {
  beforeEach(async () => {
    await seedUser("authorityTarget", ["operations"]);
  });

  test("canonical authority remains independent of non-authority profile shape", async () => {
    await seedDoc("users/minimalAdmin", {
      isApproved: true,
      roles: ["admin"],
    });

    await assertSucceeds(
      getDoc(doc(dbAs("minimalAdmin"), "users/authorityTarget"))
    );
  });

  test.each([
    [
      "unknown role mixed with an allowed role",
      { isApproved: true, roles: ["admin", "unknownRole"] },
    ],
    [
      "non-string role mixed with an allowed role",
      { isApproved: true, roles: ["admin", 7] },
    ],
    ["empty role list", { isApproved: true, roles: [] }],
    [
      "oversized role list",
      { isApproved: true, roles: Array(11).fill("admin") },
    ],
    ["non-list roles", { isApproved: true, roles: "admin" }],
    ["non-boolean approval", { isApproved: "true", roles: ["admin"] }],
    ["missing approval", { roles: ["admin"] }],
  ])("rejects %s from a privileged writer", async (_label, authority) => {
    await seedDoc("users/malformedAdmin", authority);

    await assertFails(
      getDoc(doc(dbAs("malformedAdmin"), "users/authorityTarget"))
    );
  });
});

describe("maintenance_records", () => {
  beforeEach(async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("seniorMech", ["seniorMechanical"]);
    await seedUser("ops1", ["operations"]);
  });

  test("approved user can create maintenance record only with valid create payload", async () => {
    const db = dbAs("ops1");
    const now = new Date().toISOString();

    await assertSucceeds(
      setDoc(doc(db, "maintenance_records/ticket1"), {
        firestoreId: "ticket1",
        version: 1,
        assetType: "base",
        assetNumber: 1,
        maintenanceType: "breakdown",
        description: "Hydraulic clamp observation",
        routedTo: "mechanical",
        status: "open",
        isResolved: false,
        isCritical: true,
        loggedByUid: "ops1",
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      })
    );
  });

  test("senior can close but cannot mutate unrelated ticket evidence while closing", async () => {
    const createdAt = new Date(Date.now() - 60000).toISOString();
    const updatedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticket2", {
      firestoreId: "ticket2",
      version: 1,
      assetType: "base",
      assetNumber: 1,
      maintenanceType: "breakdown",
      description: "Original evidence",
      routedTo: "mechanical",
      status: "open",
      isResolved: false,
      isCritical: true,
      loggedByUid: "ops1",
      createdAt,
      updatedAt,
      isDeleted: false,
    });

    const db = dbAs("seniorMech");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticket2"), {
        isResolved: true,
        status: "closed",
        closedByUid: "seniorMech",
        closedAt: new Date().toISOString(),
        description: "Changed evidence while closing",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });

  test("senior can close maintenance ticket using mobile resolution fields", async () => {
    const createdAt = new Date(Date.now() - 60000).toISOString();
    const updatedAt = createdAt;
    const closedAt = new Date().toISOString();

    await seedDoc("maintenance_records/ticketCloseMobile", {
      firestoreId: "ticketCloseMobile",
      version: 1,
      assetType: "base",
      assetNumber: 1,
      maintenanceType: "breakdown",
      description: "Original evidence",
      routedTo: "mechanical",
      status: "open",
      isResolved: false,
      isCritical: true,
      loggedByUid: "ops1",
      createdAt,
      updatedAt,
      isDeleted: false,
    });

    const db = dbAs("seniorMech");

    await assertSucceeds(
      updateDoc(doc(db, "maintenance_records/ticketCloseMobile"), {
        isResolved: true,
        status: "resolved",
        endDate: closedAt,
        closedByUid: "seniorMech",
        closedByName: "Senior Mechanical",
        remarks: "Adjusted and verified.",
        downtimeHours: 1.5,
        teamsInvolved: ["mechanical"],
        actionsJson: "[]",
        updatedAt: closedAt,
        updatedByUid: "seniorMech",
        updatedByName: "Senior Mechanical",
        version: 2,
      })
    );
  });


  test("maintenance close requires resolved status and matching closer identity", async () => {
    const createdAt = new Date(Date.now() - 60000).toISOString();
    const closedAt = new Date().toISOString();

    await seedDoc("maintenance_records/ticketCloseInvariant", {
      firestoreId: "ticketCloseInvariant",
      version: 1,
      assetType: "base",
      assetNumber: 1,
      maintenanceType: "breakdown",
      description: "Original evidence",
      routedTo: "mechanical",
      status: "open",
      isResolved: false,
      isCritical: true,
      loggedByUid: "ops1",
      createdAt,
      updatedAt: createdAt,
      isDeleted: false,
    });

    const db = dbAs("seniorMech");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketCloseInvariant"), {
        isResolved: true,
        status: "open",
        endDate: closedAt,
        closedByUid: "seniorMech",
        closedByName: "Senior Mechanical",
        remarks: "Status mismatch should fail.",
        downtimeHours: 1.5,
        teamsInvolved: ["mechanical"],
        actionsJson: "[]",
        updatedAt: closedAt,
        updatedByUid: "seniorMech",
        updatedByName: "Senior Mechanical",
        version: 2,
      })
    );

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketCloseInvariant"), {
        isResolved: true,
        status: "resolved",
        endDate: closedAt,
        closedByUid: "ops1",
        closedByName: "Operations User",
        remarks: "Closer identity mismatch should fail.",
        downtimeHours: 1.5,
        teamsInvolved: ["mechanical"],
        actionsJson: "[]",
        updatedAt: closedAt,
        updatedByUid: "seniorMech",
        updatedByName: "Senior Mechanical",
        version: 2,
      })
    );
  });

  test("admin edit cannot mutate maintenance identity fields", async () => {
    const createdAt = new Date(Date.now() - 60000).toISOString();
    const updatedAt = createdAt;

    await seedDoc("maintenance_records/ticketAdmin", {
      firestoreId: "ticketAdmin",
      version: 1,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Original evidence",
      routedTo: "mechanical",
      status: "open",
      isResolved: false,
      isCritical: true,
      loggedByUid: "ops1",
      createdAt,
      updatedAt,
      isDeleted: false,
    });

    const db = dbAs("admin1");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketAdmin"), {
        assetNumber: 102,
        description: "Attempted identity rewrite",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });

  test("admin can soft-delete maintenance ticket only through delete fields", async () => {
    const createdAt = new Date(Date.now() - 60000).toISOString();
    const updatedAt = createdAt;

    await seedDoc("maintenance_records/ticketDelete", {
      firestoreId: "ticketDelete",
      version: 1,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Duplicate ticket",
      routedTo: "mechanical",
      status: "open",
      isResolved: false,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt,
      updatedAt,
      isDeleted: false,
    });

    const db = dbAs("admin1");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketDelete"), {
        isDeleted: true,
        deletedByUid: "admin1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketDelete"), {
        isDeleted: true,
        deletedAt: Timestamp.now(),
        deletedByUid: "admin1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );

    await assertSucceeds(
      updateDoc(doc(db, "maintenance_records/ticketDelete"), {
        isDeleted: true,
        deletedAt: new Date().toISOString(),
        deletedByUid: "admin1",
        deletedByName: "Admin",
        deleteReason: "duplicate",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });

  test("operations can reopen using mobile reopen fields and resolution history", async () => {
    const closedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticketReopenMobile", {
      firestoreId: "ticketReopenMobile",
      version: 2,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Closed ticket",
      routedTo: "mechanical",
      status: "resolved",
      isResolved: true,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt: new Date(Date.now() - 120000).toISOString(),
      updatedAt: closedAt,
      endDate: closedAt,
      closedByUid: "seniorMech",
      closedByName: "Senior Mechanical",
      remarks: "Resolved after inspection.",
      downtimeHours: 1.5,
      teamsInvolved: ["mechanical"],
      actionsJson: "[]",
      resolutionHistoryJson: "[]",
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertSucceeds(
      updateDoc(doc(db, "maintenance_records/ticketReopenMobile"), {
        isResolved: false,
        status: "open",
        endDate: null,
        closedByUid: null,
        closedByName: null,
        downtimeHours: null,
        teamsInvolved: [],
        actionsJson: "[]",
        remarks: "Issue recurred during operation.",
        resolutionHistoryJson: JSON.stringify([
          {
            resolvedByUid: "seniorMech",
            resolvedByName: "Senior Mechanical",
            resolvedAt: closedAt,
            actionsJson: "[]",
            remarks: "Resolved after inspection.",
            downtimeHours: 1.5,
            teamsInvolved: ["mechanical"],
          },
        ]),
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );
  });


  test("maintenance reopen requires open status and clears active close fields", async () => {
    const closedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticketReopenInvariant", {
      firestoreId: "ticketReopenInvariant",
      version: 2,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Closed ticket",
      routedTo: "mechanical",
      status: "resolved",
      isResolved: true,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt: new Date(Date.now() - 120000).toISOString(),
      updatedAt: closedAt,
      endDate: closedAt,
      closedByUid: "seniorMech",
      closedByName: "Senior Mechanical",
      remarks: "Resolved after inspection.",
      downtimeHours: 1.5,
      teamsInvolved: ["mechanical"],
      actionsJson: "[]",
      resolutionHistoryJson: "[]",
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketReopenInvariant"), {
        isResolved: false,
        status: "resolved",
        endDate: null,
        closedByUid: null,
        closedByName: null,
        downtimeHours: null,
        teamsInvolved: [],
        actionsJson: "[]",
        remarks: "Status mismatch should fail.",
        resolutionHistoryJson: "[]",
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketReopenInvariant"), {
        isResolved: false,
        status: "open",
        endDate: closedAt,
        closedByUid: "seniorMech",
        closedByName: "Senior Mechanical",
        downtimeHours: 1.5,
        teamsInvolved: [],
        actionsJson: "[]",
        remarks: "Uncleared close fields should fail.",
        resolutionHistoryJson: "[]",
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );
  });

  test("maintenance mobile reopen clears active work payload fields", async () => {
    const closedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticketReopenPayloadInvariant", {
      firestoreId: "ticketReopenPayloadInvariant",
      version: 2,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Closed ticket",
      routedTo: "mechanical",
      status: "resolved",
      isResolved: true,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt: new Date(Date.now() - 120000).toISOString(),
      updatedAt: closedAt,
      endDate: closedAt,
      closedByUid: "seniorMech",
      closedByName: "Senior Mechanical",
      remarks: "Resolved after inspection.",
      downtimeHours: 1.5,
      teamsInvolved: ["mechanical"],
      actionsJson: "[]",
      resolutionHistoryJson: "[]",
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketReopenPayloadInvariant"), {
        isResolved: false,
        status: "open",
        endDate: null,
        closedByUid: null,
        closedByName: null,
        downtimeHours: null,
        teamsInvolved: ["mechanical"],
        actionsJson: "[]",
        remarks: "Teams must be cleared on reopen.",
        resolutionHistoryJson: JSON.stringify([
          {
            resolvedByUid: "seniorMech",
            resolvedByName: "Senior Mechanical",
            resolvedAt: closedAt,
            actionsJson: "[]",
            remarks: "Resolved after inspection.",
            downtimeHours: 1.5,
            teamsInvolved: ["mechanical"],
          },
        ]),
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketReopenPayloadInvariant"), {
        isResolved: false,
        status: "open",
        endDate: null,
        closedByUid: null,
        closedByName: null,
        downtimeHours: null,
        teamsInvolved: [],
        actionsJson: JSON.stringify([{ action: "leftover action" }]),
        remarks: "Actions must be cleared on reopen.",
        resolutionHistoryJson: JSON.stringify([
          {
            resolvedByUid: "seniorMech",
            resolvedByName: "Senior Mechanical",
            resolvedAt: closedAt,
            actionsJson: "[]",
            remarks: "Resolved after inspection.",
            downtimeHours: 1.5,
            teamsInvolved: ["mechanical"],
          },
        ]),
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );
  });

  test("operations can reopen maintenance ticket without changing resolution evidence", async () => {
    const closedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticketReopen", {
      firestoreId: "ticketReopen",
      version: 2,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Closed ticket",
      routedTo: "mechanical",
      status: "closed",
      isResolved: true,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt: new Date(Date.now() - 120000).toISOString(),
      updatedAt: closedAt,
      closedByUid: "seniorMech",
      closedByName: "Senior Mechanical",
      closedAt,
      resolvedByUid: "seniorMech",
      resolvedByName: "Senior Mechanical",
      resolvedAt: closedAt,
      resolutionNote: "Resolved after inspection.",
      resolutionNotes: "Resolved after inspection.",
      resolutionDetails: "Clamp adjusted and verified.",
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertSucceeds(
      updateDoc(doc(db, "maintenance_records/ticketReopen"), {
        isResolved: false,
        status: "open",
        reopenedByUid: "ops1",
        reopenedByName: "Operations User",
        reopenedAt: new Date().toISOString(),
        reopenReason: "Issue recurred during operation.",
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );
  });

  test("legacy reopen cannot introduce mobile resolution payload fields", async () => {
    const closedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticketLegacyPayloadTamper", {
      firestoreId: "ticketLegacyPayloadTamper",
      version: 2,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Closed legacy ticket",
      routedTo: "mechanical",
      status: "closed",
      isResolved: true,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt: new Date(Date.now() - 120000).toISOString(),
      updatedAt: closedAt,
      closedByUid: "seniorMech",
      closedByName: "Senior Mechanical",
      closedAt,
      resolvedByUid: "seniorMech",
      resolvedByName: "Senior Mechanical",
      resolvedAt: closedAt,
      resolutionNote: "Resolved after inspection.",
      resolutionNotes: "Resolved after inspection.",
      resolutionDetails: "Clamp adjusted and verified.",
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketLegacyPayloadTamper"), {
        isResolved: false,
        status: "open",
        reopenedByUid: "ops1",
        reopenedByName: "Operations User",
        reopenedAt: new Date().toISOString(),
        reopenReason: "Issue recurred during operation.",
        teamsInvolved: [],
        actionsJson: "[]",
        resolutionHistoryJson: "[]",
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );
  });

  test("reopen cannot rewrite maintenance close or resolution fields", async () => {
    const closedAt = new Date(Date.now() - 60000).toISOString();

    await seedDoc("maintenance_records/ticketReopenTamper", {
      firestoreId: "ticketReopenTamper",
      version: 2,
      assetType: "base",
      assetNumber: 101,
      maintenanceType: "breakdown",
      description: "Closed ticket",
      routedTo: "mechanical",
      status: "closed",
      isResolved: true,
      isCritical: false,
      loggedByUid: "ops1",
      createdAt: new Date(Date.now() - 120000).toISOString(),
      updatedAt: closedAt,
      closedByUid: "seniorMech",
      closedByName: "Senior Mechanical",
      closedAt,
      resolvedByUid: "seniorMech",
      resolvedByName: "Senior Mechanical",
      resolvedAt: closedAt,
      resolutionNote: "Resolved after inspection.",
      resolutionNotes: "Resolved after inspection.",
      resolutionDetails: "Clamp adjusted and verified.",
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertFails(
      updateDoc(doc(db, "maintenance_records/ticketReopenTamper"), {
        isResolved: false,
        status: "open",
        reopenedByUid: "ops1",
        reopenedByName: "Operations User",
        reopenedAt: new Date().toISOString(),
        reopenReason: "Issue recurred during operation.",
        resolvedByUid: "ops1",
        resolutionDetails: "Tampered resolution details.",
        updatedAt: new Date().toISOString(),
        updatedByUid: "ops1",
        updatedByName: "Operations User",
        version: 3,
      })
    );
  });

});


describe("job_templates tombstone authority", () => {
  test("admin delete requires an authoritative deletion time", async () => {
    await seedUser("admin1", ["admin"]);
    const ref = doc(dbAs("admin1"), "job_templates/templateDelete");
    await assertSucceeds(
      setDoc(ref, {
        firestoreId: "templateDelete",
        jobName: "Legacy template",
        isDeleted: false,
        version: 1,
      })
    );

    await assertFails(
      updateDoc(ref, {isDeleted: true, version: 2})
    );
    await assertFails(
      updateDoc(ref, {
        isDeleted: true,
        deletedAt: Timestamp.now(),
        version: 2,
      })
    );
    await assertSucceeds(
      updateDoc(ref, {
        isDeleted: true,
        deletedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });
});

describe("template_packages", () => {
  beforeEach(async () => {
    await seedUser("si1", ["si"]);
  });

  test("SI retirement requires complete template package timeline fields", async () => {
    await seedDoc("template_packages/pkgEvidence", {
      firestoreId: "pkgEvidence",
      packageCode: "PKG-EVIDENCE",
      title: "Evidence package",
      lifecycleStatus: "active",
      latestVersionNumber: 1,
      createdByUid: "si1",
      updatedByUid: "si1",
      createdAt: new Date(1000).toISOString(),
      updatedAt: new Date(1000).toISOString(),
      version: 1,
      schemaVersion: 1,
      isDeleted: false,
    });

    const db = dbAs("si1");

    await assertFails(
      updateDoc(doc(db, "template_packages/pkgEvidence"), {
        lifecycleStatus: "retired",
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );

    await assertSucceeds(
      updateDoc(doc(db, "template_packages/pkgEvidence"), {
        lifecycleStatus: "retired",
        retiredAt: new Date().toISOString(),
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });
});

describe("template_versions", () => {
  beforeEach(async () => {
    await seedUser("si1", ["si"]);
    await seedUser("ops1", ["operations"]);
  });

  const draftVersion = {
    firestoreId: "ver1",
    packageFirestoreId: "pkg1",
    versionNumber: 1,
    status: "draft",
    jobTemplateSnapshotJson: "{\"name\":\"template\"}",
    moduleSnapshotsJson: "[{\"moduleCode\":\"M1\"}]",
    fieldDefinitionsJson: "[]",
    checklistJson: "[]",
    contentHash:
      "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    closureReviewConfirmed: true,
    closureReviewConfirmedByUid: "si1",
    closureReviewConfirmedAt: Timestamp.fromMillis(1000),
    closureCriticalModuleCount: 1,
    createdByUid: "si1",
    updatedByUid: "si1",
    createdAt: new Date(1000).toISOString(),
    updatedAt: new Date(1000).toISOString(),
    version: 1,
    schemaVersion: 1,
    isDeleted: false,
  };

  test("operations cannot create template version", async () => {
    const db = dbAs("ops1");

    await assertFails(
      setDoc(doc(db, "template_versions/verBad"), {
        ...draftVersion,
        firestoreId: "verBad",
        createdByUid: "ops1",
        updatedByUid: "ops1",
      })
    );
  });

  test("template versions and publication audits reject incomplete timelines", async () => {
    const db = dbAs("si1");

    await assertFails(
      setDoc(doc(db, "template_versions/verMissingUpdated"), {
        ...draftVersion,
        firestoreId: "verMissingUpdated",
        updatedAt: null,
      })
    );
    await assertFails(
      setDoc(doc(db, "template_versions/verDraftWithHistory"), {
        ...draftVersion,
        firestoreId: "verDraftWithHistory",
        publishedAt: Timestamp.now(),
      })
    );
    await assertFails(
      setDoc(doc(db, "template_versions/verBadClosureTime"), {
        ...draftVersion,
        firestoreId: "verBadClosureTime",
        closureReviewConfirmedAt: 42,
      })
    );
    await assertFails(
      setDoc(doc(db, "template_publish_audits/auditBadTimeline"), {
        firestoreId: "auditBadTimeline",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "ver1",
        action: "created",
        performedByUid: "si1",
        performedAt: 42,
        updatedAt: new Date().toISOString(),
        version: 1,
        isDeleted: false,
      })
    );
  });

  test("SI can publish draft only without mutating frozen JSON payload", async () => {
    await seedDoc("template_versions/ver1", draftVersion);

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(doc(db, "template_versions/ver1"), {
        status: "published",
        publishedByUid: "si1",
        publishedAt: Timestamp.now(),
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );

    await seedDoc("template_versions/ver2", {
      ...draftVersion,
      firestoreId: "ver2",
      status: "draft",
      version: 1,
    });

    await assertFails(
      updateDoc(doc(db, "template_versions/ver2"), {
        status: "published",
        moduleSnapshotsJson: "[{\"moduleCode\":\"MUTATED\"}]",
        publishedByUid: "si1",
        publishedAt: Timestamp.now(),
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("closure-critical template cannot publish without closure review confirmation", async () => {
    await seedDoc("template_versions/ver3", {
      ...draftVersion,
      firestoreId: "ver3",
      closureReviewConfirmed: false,
      closureReviewConfirmedByUid: null,
      closureReviewConfirmedAt: null,
      closureCriticalModuleCount: 2,
    });

    const db = dbAs("si1");

    await assertFails(
      updateDoc(doc(db, "template_versions/ver3"), {
        status: "published",
        publishedByUid: "si1",
        publishedAt: Timestamp.now(),
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });


  test("SI can retire a published template version without mutating frozen payload", async () => {
    await seedDoc("template_versions/verRetire", {
      ...draftVersion,
      firestoreId: "verRetire",
      status: "published",
      publishedByUid: "si1",
      publishedAt: Timestamp.fromMillis(2000),
      version: 2,
    });

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(doc(db, "template_versions/verRetire"), {
        status: "retired",
        retiredByUid: "si1",
        retiredAt: Timestamp.now(),
        retireReason: "Superseded by a newer governed version.",
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 3,
      })
    );

    await seedDoc("template_versions/verRetireBad", {
      ...draftVersion,
      firestoreId: "verRetireBad",
      status: "published",
      publishedByUid: "si1",
      publishedAt: Timestamp.fromMillis(2000),
      version: 2,
    });

    await assertFails(
      updateDoc(doc(db, "template_versions/verRetireBad"), {
        status: "retired",
        moduleSnapshotsJson: '[{"moduleCode":"MUTATED"}]',
        retiredByUid: "si1",
        retiredAt: Timestamp.now(),
        retireReason: "Trying to mutate frozen payload while retiring.",
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 3,
      })
    );
  });

  test("SI can archive a retired template version without mutating frozen payload", async () => {
    await seedDoc("template_versions/verArchive", {
      ...draftVersion,
      firestoreId: "verArchive",
      status: "retired",
      publishedByUid: "si1",
      publishedAt: Timestamp.fromMillis(2000),
      retiredByUid: "si1",
      retiredAt: Timestamp.fromMillis(3000),
      retireReason: "Superseded by a newer governed version.",
      version: 3,
    });

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(doc(db, "template_versions/verArchive"), {
        status: "archived",
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 4,
      })
    );

    await seedDoc("template_versions/verArchiveBad", {
      ...draftVersion,
      firestoreId: "verArchiveBad",
      status: "retired",
      publishedByUid: "si1",
      publishedAt: Timestamp.fromMillis(2000),
      retiredByUid: "si1",
      retiredAt: Timestamp.fromMillis(3000),
      retireReason: "Superseded by a newer governed version.",
      version: 3,
    });

    await assertFails(
      updateDoc(doc(db, "template_versions/verArchiveBad"), {
        status: "archived",
        checklistJson: '[{"field":"MUTATED"}]',
        updatedByUid: "si1",
        updatedAt: Timestamp.now(),
        version: 4,
      })
    );
  });
});


describe("template_version draft archive governance", () => {
  beforeEach(async () => {
    await seedUser("si1", ["si"]);
    await seedUser("si2", ["si"]);
    await seedUser("ops1", ["operations"]);
  });

  function activeDraft(overrides = {}) {
    return {
      firestoreId: "draftArchive",
      packageFirestoreId: "pkg1",
      versionNumber: 3,
      status: "draft",
      jobTemplateSnapshotJson: "{\"name\":\"template\"}",
      moduleSnapshotsJson: "[{\"moduleCode\":\"M1\"}]",
      fieldDefinitionsJson: "[]",
      checklistJson: "[]",
      contentHash: null,
      closureReviewConfirmed: false,
      closureReviewConfirmedByUid: null,
      closureReviewConfirmedByName: null,
      closureReviewConfirmedAt: null,
      closureCriticalModuleCount: 0,
      createdByUid: "si1",
      createdByName: "SI User",
      updatedByUid: "si1",
      updatedByName: "SI User",
      createdAt: new Date(1000).toISOString(),
      updatedAt: new Date(1000).toISOString(),
      version: 2,
      schemaVersion: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  test("SI can archive a draft and then write mandatory archive audit evidence", async () => {
    await seedDoc("template_versions/draftArchive", activeDraft());
    const db = dbAs("si1");
    const archivedHash =
      "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

    await assertSucceeds(
      updateDoc(doc(db, "template_versions/draftArchive"), {
        status: "archived",
        contentHash: archivedHash,
        updatedByUid: "si1",
        updatedByName: "SI User",
        updatedAt: new Date().toISOString(),
        version: 3,
      })
    );

    await assertSucceeds(
      setDoc(doc(db, "template_publish_audits/archiveAudit"), {
        firestoreId: "archiveAudit",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "draftArchive",
        action: "archived",
        performedByUid: "si1",
        performedByName: "SI User",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "Duplicate draft abandoned after review.",
        beforeHash: null,
        afterHash: archivedHash,
        payloadSnapshotJson: '{"status":"archived"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );
  });

  test("archive and restore audits must be written by the lifecycle actor", async () => {
    const lifecycleHash =
      "tg2-sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";

    await seedDoc(
      "template_versions/actorBoundArchive",
      activeDraft({
        firestoreId: "actorBoundArchive",
        status: "archived",
        contentHash: lifecycleHash,
        updatedByUid: "si1",
        updatedByName: "SI User",
        version: 3,
      })
    );

    const si2Db = dbAs("si2");

    await assertFails(
      setDoc(doc(si2Db, "template_publish_audits/archiveActorMismatch"), {
        firestoreId: "archiveActorMismatch",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "actorBoundArchive",
        action: "archived",
        performedByUid: "si2",
        performedByName: "Second SI",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "A different governor must not attest this archive transition.",
        beforeHash: null,
        afterHash: lifecycleHash,
        payloadSnapshotJson: '{"status":"archived"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );

    await seedDoc(
      "template_versions/actorBoundRestore",
      activeDraft({
        firestoreId: "actorBoundRestore",
        status: "draft",
        contentHash: lifecycleHash,
        updatedByUid: "si1",
        updatedByName: "SI User",
        version: 4,
      })
    );

    await assertFails(
      setDoc(doc(si2Db, "template_publish_audits/restoreActorMismatch"), {
        firestoreId: "restoreActorMismatch",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "actorBoundRestore",
        action: "restored",
        performedByUid: "si2",
        performedByName: "Second SI",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "A different governor must not attest this restore transition.",
        beforeHash: lifecycleHash,
        afterHash: lifecycleHash,
        payloadSnapshotJson: '{"status":"draft"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );
  });
  test("draft archive rejects operations user, payload mutation, and published source", async () => {
    await seedDoc("template_versions/draftArchive", activeDraft());
    const archivedHash =
      "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

    const opsDb = dbAs("ops1");
    await assertFails(
      updateDoc(doc(opsDb, "template_versions/draftArchive"), {
        status: "archived",
        contentHash: archivedHash,
        updatedByUid: "ops1",
        updatedAt: new Date().toISOString(),
        version: 3,
      })
    );

    const siDb = dbAs("si1");
    await assertFails(
      updateDoc(doc(siDb, "template_versions/draftArchive"), {
        status: "archived",
        contentHash: archivedHash,
        moduleSnapshotsJson: "[{\"moduleCode\":\"MUTATED\"}]",
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 3,
      })
    );

    await seedDoc(
      "template_versions/publishedArchiveAttempt",
      activeDraft({
        firestoreId: "publishedArchiveAttempt",
        status: "published",
        contentHash: archivedHash,
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
      })
    );
    await assertFails(
      updateDoc(doc(siDb, "template_versions/publishedArchiveAttempt"), {
        status: "archived",
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 3,
      })
    );
  });

  test("archive audit rejects short reason and direct archived creation remains denied", async () => {
    await seedDoc(
      "template_versions/draftArchive",
      activeDraft({
        status: "archived",
        contentHash:
          "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        version: 3,
      })
    );
    const db = dbAs("si1");

    await assertFails(
      setDoc(doc(db, "template_publish_audits/archiveAuditShort"), {
        firestoreId: "archiveAuditShort",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "draftArchive",
        action: "archived",
        performedByUid: "si1",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "short",
        afterHash:
          "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        payloadSnapshotJson: '{"status":"archived"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );

    await assertFails(
      setDoc(doc(db, "template_publish_audits/archiveAuditWrongHash"), {
        firestoreId: "archiveAuditWrongHash",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "draftArchive",
        action: "archived",
        performedByUid: "si1",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "Archive audit hash must match the archived version.",
        afterHash:
          "tg2-sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        payloadSnapshotJson: '{"status":"archived"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );

    await assertFails(
      setDoc(
        doc(db, "template_versions/directArchivedCreate"),
        activeDraft({
          firestoreId: "directArchivedCreate",
          status: "archived",
          contentHash:
            "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        })
      )
    );
  });

  test("SI can restore an archived draft as the same identity with restore audit", async () => {
    const archivedHash =
      "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    await seedDoc(
      "template_versions/draftRestore",
      activeDraft({
        firestoreId: "draftRestore",
        status: "archived",
        contentHash: archivedHash,
        version: 3,
      })
    );
    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(doc(db, "template_versions/draftRestore"), {
        status: "draft",
        contentHash: archivedHash,
        updatedByUid: "si1",
        updatedByName: "SI User",
        updatedAt: new Date().toISOString(),
        version: 4,
      })
    );

    await assertSucceeds(
      setDoc(doc(db, "template_publish_audits/restoreAudit"), {
        firestoreId: "restoreAudit",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "draftRestore",
        action: "restored",
        performedByUid: "si1",
        performedByName: "SI User",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "Archived draft restored after governance review.",
        beforeHash: archivedHash,
        afterHash: archivedHash,
        payloadSnapshotJson: '{"status":"draft"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );
  });

  test("restore rejects operations, published history, and invalid audit evidence", async () => {
    const archivedHash =
      "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    await seedDoc(
      "template_versions/opsRestore",
      activeDraft({
        firestoreId: "opsRestore",
        status: "archived",
        contentHash: archivedHash,
        version: 3,
      })
    );
    await assertFails(
      updateDoc(doc(dbAs("ops1"), "template_versions/opsRestore"), {
        status: "draft",
        updatedByUid: "ops1",
        updatedAt: new Date().toISOString(),
        version: 4,
      })
    );

    await seedDoc(
      "template_versions/publishedHistoryRestore",
      activeDraft({
        firestoreId: "publishedHistoryRestore",
        status: "archived",
        contentHash: archivedHash,
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        retiredByUid: "si1",
        retiredAt: new Date(3000).toISOString(),
        retireReason: "Superseded published history.",
        version: 4,
      })
    );
    const siDb = dbAs("si1");
    await assertFails(
      updateDoc(doc(siDb, "template_versions/publishedHistoryRestore"), {
        status: "draft",
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 5,
      })
    );

    await seedDoc(
      "template_versions/stillArchivedForAudit",
      activeDraft({
        firestoreId: "stillArchivedForAudit",
        status: "archived",
        contentHash: archivedHash,
        version: 3,
      })
    );
    await assertFails(
      setDoc(doc(siDb, "template_publish_audits/restoreBeforeState"), {
        firestoreId: "restoreBeforeState",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "stillArchivedForAudit",
        action: "restored",
        performedByUid: "si1",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "Restore audit cannot precede remote lifecycle state.",
        afterHash: archivedHash,
        payloadSnapshotJson: '{"status":"draft"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );

    await seedDoc(
      "template_versions/restoredForShortReason",
      activeDraft({
        firestoreId: "restoredForShortReason",
        status: "draft",
        contentHash: archivedHash,
        version: 4,
      })
    );
    await assertFails(
      setDoc(doc(siDb, "template_publish_audits/restoreShortReason"), {
        firestoreId: "restoreShortReason",
        packageFirestoreId: "pkg1",
        versionFirestoreId: "restoredForShortReason",
        action: "restored",
        performedByUid: "si1",
        performedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reason: "short",
        afterHash: archivedHash,
        payloadSnapshotJson: '{"status":"draft"}',
        version: 1,
        schemaVersion: 1,
        isDeleted: false,
      })
    );
  });
});

describe("job_executions", () => {
  beforeEach(async () => {
    await seedUser("ops1", ["operations"]);
    await seedUser("supervisor1", ["shiftSupervisor"]);
  });

  test("shift supervisor can create legacy job execution only with assignment identity", async () => {
    const db = dbAs("supervisor1");
    const now = new Date().toISOString();

    await assertSucceeds(
      setDoc(doc(db, "job_executions/jobCreate"), {
        firestoreId: "jobCreate",
        templateFirestoreId: "legacyTemplate1",
        templateName: "Legacy job",
        assetType: "base",
        assetNumber: 101,
        isCompleted: false,
        assignedByUid: "supervisor1",
        assignedByName: "Shift Supervisor",
        assignedAgencies: ["mechanical"],
        teamsInvolved: [],
        responsesJson: "[]",
        actionsJson: "[]",
        version: 1,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
      })
    );

    await assertFails(
      setDoc(doc(db, "job_executions/jobCreateBad"), {
        firestoreId: "jobCreateBad",
        templateFirestoreId: "ver1",
        assetType: "base",
        assetNumber: 101,
        isCompleted: false,
        assignedByUid: "someoneElse",
        createdAt: now,
        updatedAt: now,
        version: 1,
        isDeleted: false,
      })
    );
  });

  test("ordinary operations user cannot update job execution work fields", async () => {
    await seedDoc("job_executions/job1", {
      firestoreId: "job1",
      templateFirestoreId: "ver1",
      templatePackageId: "pkg1",
      templateVersionId: "ver1",
      templateVersionNumber: 1,
      templateContentHash:
        "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      assetType: "base",
      assetNumber: 1,
      assignedByUid: "supervisor1",
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      version: 1,
      isCompleted: false,
      isDeleted: false,
    });

    const db = dbAs("ops1");

    await assertFails(
      updateDoc(doc(db, "job_executions/job1"), {
        remarks: "Changed by operations",
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("shift supervisor cannot directly complete job execution; completion is Cloud Function only", async () => {
    await seedDoc("job_executions/job2", {
      firestoreId: "job2",
      templateFirestoreId: "ver1",
      templatePackageId: "pkg1",
      templateVersionId: "ver1",
      templateVersionNumber: 1,
      templateContentHash:
        "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      assetType: "base",
      assetNumber: 1,
      assignedByUid: "supervisor1",
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      version: 1,
      isCompleted: false,
      isDeleted: false,
    });

    const db = dbAs("supervisor1");

    await assertFails(
      updateDoc(doc(db, "job_executions/job2"), {
        isCompleted: true,
        completedByUid: "supervisor1",
        completedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("completion cannot mutate assignment identity", async () => {
    await seedDoc("job_executions/jobIdentity", {
      firestoreId: "jobIdentity",
      templateFirestoreId: "ver1",
      templatePackageId: "pkg1",
      templateVersionId: "ver1",
      templateVersionNumber: 1,
      templateContentHash:
        "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      assetType: "base",
      assetNumber: 1,
      assignedByUid: "supervisor1",
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      version: 1,
      isCompleted: false,
      isDeleted: false,
    });

    const db = dbAs("supervisor1");

    await assertFails(
      updateDoc(doc(db, "job_executions/jobIdentity"), {
        isCompleted: true,
        assignedByUid: "ops1",
        completedByUid: "supervisor1",
        completedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });
});

describe("job_modules", () => {
  beforeEach(async () => {
    await seedUser("seniorMech", ["seniorMechanical"]);
    await seedUser("supervisor1", ["shiftSupervisor"]);
    await seedUser("ops1", ["operations"]);
    await seedDoc("job_executions/modExec", {
      firestoreId: "modExec",
      isCompleted: false,
      isDeleted: false,
    });
  });

  const moduleBase = {
    firestoreId: "mod1",
    jobExecutionFirestoreId: "modExec",
    moduleTitle: "Base fan inspection",
    assetType: "base",
    assetNumber: 1,
    status: "draftSaved",
    isOpenForWork: true,
    discipline: "mechanical",
    safetyClass: "normal",
    requiredForClosure: false,
    addedDuringExecution: false,
    moduleSnapshotJson: "{}",
    fieldDefinitionsJson: "[]",
    createdByUid: "supervisor1",
    updatedByUid: "supervisor1",
    createdAt: new Date(1000).toISOString(),
    updatedAt: new Date(1000).toISOString(),
    version: 1,
    isDeleted: false,
  };

  test("matching senior discipline can submit own discipline module", async () => {
    await seedDoc("job_modules/mod1", moduleBase);

    const db = dbAs("seniorMech");

    await assertSucceeds(
      updateDoc(doc(db, "job_modules/mod1"), {
        status: "submitted",
        isOpenForWork: false,
        submittedByUid: "seniorMech",
        submittedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("operations cannot submit planned maintenance module", async () => {
    await seedDoc("job_modules/mod2", {
      ...moduleBase,
      firestoreId: "mod2",
    });

    const db = dbAs("ops1");

    await assertFails(
      updateDoc(doc(db, "job_modules/mod2"), {
        status: "submitted",
        isOpenForWork: false,
        submittedByUid: "ops1",
        submittedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("same-version module update is rejected", async () => {
    await seedDoc("job_modules/mod3", {
      ...moduleBase,
      firestoreId: "mod3",
    });

    const db = dbAs("seniorMech");

    await assertFails(
      updateDoc(doc(db, "job_modules/mod3"), {
        draftNote: "same version edit",
        updatedByUid: "seniorMech",
        updatedAt: Timestamp.now(),
        version: 1,
      })
    );
  });
});

describe("job_diary_entries", () => {
  beforeEach(async () => {
    await seedUser("seniorMech", ["seniorMechanical"]);
    await seedUser("ops1", ["operations"]);
  });

  test("creator can update diary only with version advance", async () => {
    await seedDoc("job_diary_entries/diary1", {
      firestoreId: "diary1",
      note: "Initial note",
      createdByUid: "seniorMech",
      updatedByUid: "seniorMech",
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      version: 1,
      isDeleted: false,
    });

    const db = dbAs("seniorMech");

    await assertFails(
      updateDoc(doc(db, "job_diary_entries/diary1"), {
        note: "Same version overwrite",
        updatedByUid: "seniorMech",
        updatedAt: Timestamp.now(),
        version: 1,
      })
    );

    await assertSucceeds(
      updateDoc(doc(db, "job_diary_entries/diary1"), {
        note: "Version advanced",
        updatedByUid: "seniorMech",
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("creator cannot relink diary entry while editing note", async () => {
    await seedDoc("job_diary_entries/diaryRelink", {
      firestoreId: "diaryRelink",
      note: "Initial note",
      jobExecutionFirestoreId: "executionA",
      templateFirestoreId: "templateA",
      createdByUid: "seniorMech",
      updatedByUid: "seniorMech",
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      version: 1,
      isDeleted: false,
    });

    const db = dbAs("seniorMech");

    await assertFails(
      updateDoc(doc(db, "job_diary_entries/diaryRelink"), {
        note: "Relink attempt",
        jobExecutionFirestoreId: "executionB",
        updatedByUid: "seniorMech",
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

});

describe("directives", () => {
  beforeEach(async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("supervisor1", ["shiftSupervisor"]);
    await seedUser("ops1", ["operations"]);
    await seedUser("seniorMech", ["seniorMechanical"]);
  });

  const directiveBase = {
    firestoreId: "dir1",
    title: "Check furnace purge status",
    description: "Verify purge permissive before restart.",
    status: "open",
    directedTo: "operations",
    createdByUid: "supervisor1",
    issuedByUid: "supervisor1",
    createdAt: new Date(1000).toISOString(),
    updatedAt: new Date(1000).toISOString(),
    acknowledgedByUid: null,
    acknowledgedAt: null,
    closedByUid: null,
    closedAt: null,
    version: 1,
    isDeleted: false,
  };

  test("shift supervisor can create directive targeting operations", async () => {
    const db = dbAs("supervisor1");

    await assertSucceeds(setDoc(doc(db, "directives/dir1"), directiveBase));
  });


  test("directive create requires firestoreId field", async () => {
    const db = dbAs("supervisor1");
    const { firestoreId, ...withoutFirestoreId } = directiveBase;

    await assertFails(
      setDoc(doc(db, "directives/dirMissingFirestoreId"), {
        ...withoutFirestoreId,
      })
    );
  });

  test("directive create requires firestoreId to match document id", async () => {
    const db = dbAs("supervisor1");

    await assertFails(
      setDoc(doc(db, "directives/dirMismatch"), {
        ...directiveBase,
        firestoreId: "differentDirectiveId",
      })
    );
  });

  test("senior discipline user cannot create directive", async () => {
    const db = dbAs("seniorMech");

    await assertFails(
      setDoc(doc(db, "directives/dirBad"), {
        ...directiveBase,
        firestoreId: "dirBad",
        createdByUid: "seniorMech",
        issuedByUid: "seniorMech",
      })
    );
  });

  test("target role user can acknowledge directive", async () => {
    await seedDoc("directives/dirAck", {
      ...directiveBase,
      firestoreId: "dirAck",
    });

    const db = dbAs("ops1");

    await assertSucceeds(
      updateDoc(doc(db, "directives/dirAck"), {
        status: "acknowledged",
        acknowledgedByUid: "ops1",
        acknowledgedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("issuer can close own open directive", async () => {
    await seedDoc("directives/dirClose", {
      ...directiveBase,
      firestoreId: "dirClose",
    });

    const db = dbAs("supervisor1");

    await assertSucceeds(
      updateDoc(doc(db, "directives/dirClose"), {
        status: "closed",
        closedByUid: "supervisor1",
        closedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        version: 2,
      })
    );
  });

  test("admin directive tombstone requires an authoritative deletion time", async () => {
    await seedDoc("directives/dirDelete", {
      ...directiveBase,
      firestoreId: "dirDelete",
    });
    const ref = doc(dbAs("admin1"), "directives/dirDelete");

    await assertFails(
      updateDoc(ref, {
        isDeleted: true,
        deletedByUid: "admin1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
    await assertFails(
      updateDoc(ref, {
        isDeleted: true,
        deletedAt: Timestamp.now(),
        deletedByUid: "admin1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
    await assertSucceeds(
      updateDoc(ref, {
        isDeleted: true,
        deletedAt: new Date().toISOString(),
        deletedByUid: "admin1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });
});


describe("knowledge_base", () => {
  beforeEach(async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("si1", ["si"]);
    await seedUser("ops1", ["operations"]);
  });

  function knowledgeRow(overrides = {}) {
    return {
      rowCode: "KB-001",
      schemaVersion: 1,
      taskText: "Inspect hydraulic clamp pressure permissive before furnace cycle.",
      moduleCandidateCode: "KB-MOD-001",
      ownerDisciplines: ["mechanical", "instrumentation"],
      safetyClasses: ["hydraulic", "interlock"],
      procedureRefs: ["SOP-BAF-CLAMP"],
      partRefs: [],
      deviceTags: ["PSL13"],
      targetRefs: ["base:101"],
      suggestedFields: ["Pressure switch state", "Observation"],
      composerReadiness: "readyPreset",
      confidence: "confirmedManual",
      lifecycleStatus: "active",
      matrixVersion: "v1",
      changeSummary: "Initial governed knowledge row seed.",
      updatedByUid: "admin1",
      updatedAt: serverTimestamp(),
      version: 1,
      createdByUid: "admin1",
      createdAt: serverTimestamp(),
      isDeleted: false,
      ...overrides,
    };
  }

  test("template governor can create knowledge row using server timestamps", async () => {
    const db = dbAs("admin1");

    await assertSucceeds(
      setDoc(doc(db, "knowledge_base/KB-001"), knowledgeRow())
    );
  });

  test("approved non-governor cannot create knowledge row", async () => {
    const db = dbAs("ops1");

    await assertFails(
      setDoc(
        doc(db, "knowledge_base/KB-001"),
        knowledgeRow({
          updatedByUid: "ops1",
          createdByUid: "ops1",
        })
      )
    );
  });

  test("knowledge row create requires rowCode to match document id", async () => {
    const db = dbAs("admin1");

    await assertFails(
      setDoc(
        doc(db, "knowledge_base/KB-001"),
        knowledgeRow({ rowCode: "DIFFERENT-ID" })
      )
    );
  });

  test("knowledge row create requires server timestamps", async () => {
    const db = dbAs("admin1");

    await assertFails(
      setDoc(
        doc(db, "knowledge_base/KB-001"),
        knowledgeRow({
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        })
      )
    );
  });

  test("template governor can update knowledge row with version advance and server timestamp", async () => {
    await seedDoc("knowledge_base/KB-001", {
      ...knowledgeRow({
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60000)),
        updatedAt: Timestamp.fromDate(new Date(Date.now() - 60000)),
      }),
    });

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(doc(db, "knowledge_base/KB-001"), {
        taskText: "Inspect hydraulic clamp pressure permissive and record switch evidence.",
        changeSummary: "SI revised task wording for better closure evidence.",
        updatedByUid: "si1",
        updatedAt: serverTimestamp(),
        version: 2,
      })
    );
  });

  test("legacy knowledge replacement can omit a prior server stamp", async () => {
    const createdAt = Timestamp.fromDate(new Date(Date.now() - 60000));
    await seedDoc("knowledge_base/KB-001", {
      ...knowledgeRow({
        createdAt,
        updatedAt: createdAt,
      }),
      _globalPullServerUpdatedAt: Timestamp.now(),
    });

    const db = dbAs("admin1");
    await assertSucceeds(
      setDoc(
        doc(db, "knowledge_base/KB-001"),
        knowledgeRow({
          createdAt,
          updatedAt: serverTimestamp(),
          version: 2,
          changeSummary:
            "Restored the governed row through the legacy replacement path.",
        })
      )
    );
  });

  test("knowledge row update cannot mutate identity or created fields", async () => {
    await seedDoc("knowledge_base/KB-001", {
      ...knowledgeRow({
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60000)),
        updatedAt: Timestamp.fromDate(new Date(Date.now() - 60000)),
      }),
    });

    const db = dbAs("si1");

    await assertFails(
      updateDoc(doc(db, "knowledge_base/KB-001"), {
        rowCode: "KB-002",
        createdByUid: "si1",
        changeSummary: "Attempted identity rewrite should be denied.",
        updatedByUid: "si1",
        updatedAt: serverTimestamp(),
        version: 2,
      })
    );
  });
});

describe("audit_logs", () => {
  beforeEach(async () => {
    await seedUser("ops1", ["operations"]);
    await seedUser("admin1", ["admin"]);
  });

  test("Admin can read and list shared audit events", async () => {
    await seedDoc("audit_logs/sharedAudit", auditEventPayload());
    const db = dbAs("admin1");

    await assertSucceeds(getDoc(doc(db, "audit_logs/sharedAudit")));
    await assertSucceeds(getDocs(collection(db, "audit_logs")));
  });

  test("audit visibility rejects non-Admin and malformed authority", async () => {
    await seedDoc("audit_logs/sharedAudit", auditEventPayload());
    await seedUser("unapprovedAdmin", ["admin"], false);
    await seedDoc("users/malformedAdmin", {
      isApproved: true,
      roles: ["admin", "unknownRole"],
    });

    for (const uid of [
      "ops1",
      "unapprovedAdmin",
      "malformedAdmin",
      "missingProfile",
    ]) {
      const db = dbAs(uid);
      await assertFails(getDoc(doc(db, "audit_logs/sharedAudit")));
      await assertFails(getDocs(collection(db, "audit_logs")));
    }

    const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(unauthenticatedDb, "audit_logs/sharedAudit"))
    );
    await assertFails(getDocs(collection(unauthenticatedDb, "audit_logs")));
  });

  test("revocation denies the next audit read on the existing session", async () => {
    await seedUser("revokedAdmin", ["admin"]);
    await seedDoc("audit_logs/sharedAudit", auditEventPayload());
    const db = dbAs("revokedAdmin");

    await assertSucceeds(getDoc(doc(db, "audit_logs/sharedAudit")));
    await seedUser("revokedAdmin", ["admin"], false);
    await assertFails(getDoc(doc(db, "audit_logs/sharedAudit")));
    await assertFails(getDocs(collection(db, "audit_logs")));
  });

  test("approved user can create well-formed audit event for self", async () => {
    const db = dbAs("ops1");

    await assertSucceeds(
      setDoc(doc(db, "audit_logs/audit1"), {
        entityType: "maintenance",
        entityId: "ticket1",
        action: "update",
        performedByUid: "ops1",
        performedByName: "Operations User",
        timestamp: Timestamp.now(),
        severity: "low",
        summary: "Updated ticket",
        beforeJson: "{}",
        afterJson: "{}",
      })
    );
  });

  test("approved user cannot spoof audit actor or write malformed audit", async () => {
    const db = dbAs("ops1");

    await assertFails(
      setDoc(doc(db, "audit_logs/auditSpoof"), {
        entityType: "maintenance",
        entityId: "ticket1",
        action: "update",
        performedByUid: "admin1",
        timestamp: Timestamp.now(),
        severity: "low",
      })
    );

    await assertFails(
      setDoc(doc(db, "audit_logs/auditMalformed"), {
        entityType: "maintenance",
        action: "update",
        performedByUid: "ops1",
        timestamp: "not-a-timestamp",
        severity: "extreme",
      })
    );
  });

  test("admin can create governed knowledge seed audit shape", async () => {
    const db = dbAs("admin1");

    await assertSucceeds(
      setDoc(doc(db, "audit_logs/knowledgeSeed"), {
        type: "knowledge_base_seed",
        action: "seed_baseline",
        performedByUid: "admin1",
        performedByName: "Admin",
        performedAt: Timestamp.now(),
        details: "Seeded governed knowledge baseline.",
        matrixVersion: "v1",
        rowCount: 100,
        version: 1,
        isDeleted: false,
      })
    );
  });
});

describe("charges", () => {
  beforeEach(async () => {
    await seedUser("ops1", ["operations"]);
  });

  test("approved user can read but cannot create base Charge", async () => {
    await seedDoc("charges/charge1", {
      chargeNo: "C001",
      isSynced: true,
    });

    const db = dbAs("ops1");

    await assertSucceeds(getDoc(doc(db, "charges/charge1")));

    await assertFails(
      setDoc(doc(db, "charges/charge2"), {
        chargeNo: "C002",
        isSynced: true,
      })
    );
  });
});
describe("module_registry", () => {
  beforeEach(async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("si1", ["si"]);
    await seedUser("supervisor1", ["shiftSupervisor"]);
    await seedUser("ops1", ["operations"]);
  });

  function registryFamily(overrides = {}) {
    return {
      registryModuleId: "baf.module.base_fan_vibration",
      moduleCode: "BASE-FAN-VIB",
      canonicalTitle: "Base fan vibration check",
      status: "active",
      discipline: "shared",
      ownerDisciplines: ["mechanical", "instrumentation"],
      assetType: "base",
      functionalSection: "Base fan",
      componentGroup: "Fan vibration",
      targetRefs: ["base:101"],
      deviceTagRefs: ["VT-BASE-FAN"],
      safetyClasses: ["rotating", "hmi"],
      requiredForClosure: true,
      latestPublishedRevisionNumber: 0,
      latestPublishedRevisionId: null,
      latestPublishedContentHash: null,
      createdByUid: "si1",
      createdByName: "SI User",
      createdAt: new Date(1000).toISOString(),
      updatedByUid: "si1",
      updatedByName: "SI User",
      updatedAt: new Date(1000).toISOString(),
      retiredByUid: null,
      retiredByName: null,
      retiredAt: null,
      retireReason: null,
      version: 1,
      schemaVersion: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  function registryRevision(overrides = {}) {
    return {
      registryModuleId: "baf.module.base_fan_vibration",
      revisionId: "draft1",
      revisionNumber: 0,
      revisionStatus: "draft",
      moduleSnapshotJson: '{"moduleCode":"BASE-FAN-VIB","moduleTitle":"Base fan vibration check"}',
      fieldDefinitionsJson: "[]",
      checklistJson: "[]",
      contentHash:
        "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      lineageJson: '{"sourceType":"manual"}',
      createdByUid: "si1",
      createdByName: "SI User",
      createdAt: new Date(1000).toISOString(),
      updatedByUid: "si1",
      updatedByName: "SI User",
      updatedAt: new Date(1000).toISOString(),
      publishedByUid: null,
      publishedByName: null,
      publishedAt: null,
      retiredByUid: null,
      retiredByName: null,
      retiredAt: null,
      retireReason: null,
      version: 1,
      schemaVersion: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  function registryAudit(overrides = {}) {
    return {
      firestoreId: "audit1",
      registryModuleId: "baf.module.base_fan_vibration",
      revisionId: "draft1",
      revisionNumber: 0,
      action: "draftCreated",
      performedByUid: "si1",
      performedByName: "SI User",
      performedAt: new Date().toISOString(),
      reasonNotes: "Created registry draft from manual module.",
      beforeHash: null,
      afterHash:
        "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      lineageSummaryJson: '{"sourceType":"manual"}',
      version: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  test("SI can create registry family, draft revision, and audit", async () => {
    const db = dbAs("si1");

    await assertSucceeds(
      setDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration"),
        registryFamily()
      )
    );

    await assertSucceeds(
      setDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/draft1"),
        registryRevision()
      )
    );

    await assertSucceeds(
      setDoc(doc(db, "module_registry_audits/audit1"), registryAudit())
    );
  });

  test("registry family, revision, and audit timelines fail closed", async () => {
    const db = dbAs("si1");

    await assertFails(
      setDoc(
        doc(db, "module_registry/baf.module.missing_time"),
        registryFamily({
          registryModuleId: "baf.module.missing_time",
          updatedAt: null,
        })
      )
    );
    await assertFails(
      setDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/draftHistory"),
        registryRevision({
          revisionId: "draftHistory",
          publishedAt: new Date().toISOString(),
        })
      )
    );
    await assertFails(
      setDoc(
        doc(db, "module_registry_audits/auditBadTimeline"),
        registryAudit({
          firestoreId: "auditBadTimeline",
          performedAt: 42,
        })
      )
    );
  });

  test("approved user can list active registry families", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );

    const db = dbAs("ops1");
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, "module_registry"),
          where("status", "==", "active")
        )
      )
    );

    expect(snap.size).toBe(1);
  });

  test("supervisor cannot create registry family or draft", async () => {
    const db = dbAs("supervisor1");

    await assertFails(
      setDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration"),
        registryFamily({ createdByUid: "supervisor1", updatedByUid: "supervisor1" })
      )
    );

    await assertFails(
      setDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/draft1"),
        registryRevision({ createdByUid: "supervisor1", updatedByUid: "supervisor1" })
      )
    );
  });

  test("approved user can read published registry revisions through scoped family revisions query", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/rev1",
      registryRevision({
        revisionId: "rev1",
        revisionNumber: 1,
        revisionStatus: "published",
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        version: 2,
      })
    );

    const db = dbAs("ops1");
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, "module_registry/baf.module.base_fan_vibration/revisions"),
          where("revisionStatus", "==", "published")
        )
      )
    );

    expect(snap.size).toBe(1);
  });

  test("SI can publish draft revision atomically but cannot mutate frozen payload", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft1",
      registryRevision()
    );

    const db = dbAs("si1");
    const familyRef = doc(db, "module_registry/baf.module.base_fan_vibration");
    const draft1Ref = doc(
      db,
      "module_registry/baf.module.base_fan_vibration/revisions/draft1"
    );
    const firstHash =
      "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const publishBatch = writeBatch(db);
    publishBatch.update(familyRef, {
      canonicalTitle: "Base fan vibration check rev 1",
      latestPublishedRevisionNumber: 1,
      latestPublishedRevisionId: "draft1",
      latestPublishedContentHash: firstHash,
      updatedByUid: "si1",
      updatedAt: new Date().toISOString(),
      version: 2,
    });
    publishBatch.update(draft1Ref, {
      revisionStatus: "published",
      revisionNumber: 1,
      publishedByUid: "si1",
      publishedAt: new Date().toISOString(),
      updatedByUid: "si1",
      updatedAt: new Date().toISOString(),
      version: 2,
    });
    await assertSucceeds(publishBatch.commit());

    const secondHash =
      "mrg1-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft2",
      registryRevision({ revisionId: "draft2", contentHash: secondHash })
    );

    const badBatch = writeBatch(db);
    badBatch.update(familyRef, {
      canonicalTitle: "Mutated draft should not publish",
      latestPublishedRevisionNumber: 2,
      latestPublishedRevisionId: "draft2",
      latestPublishedContentHash: secondHash,
      updatedByUid: "si1",
      updatedAt: new Date().toISOString(),
      version: 3,
    });
    badBatch.update(
      doc(
        db,
        "module_registry/baf.module.base_fan_vibration/revisions/draft2"
      ),
      {
        revisionStatus: "published",
        revisionNumber: 2,
        moduleSnapshotJson: '{"moduleCode":"MUTATED"}',
        publishedByUid: "si1",
        publishedAt: new Date().toISOString(),
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      }
    );
    await assertFails(badBatch.commit());
  });

  test("legacy family cannot publish again until latest pointers are bootstrapped", async () => {
    const firstHash =
      "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const secondHash =
      "mrg1-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily({
        latestPublishedRevisionNumber: 1,
        latestPublishedRevisionId: null,
        latestPublishedContentHash: null,
        version: 2,
      })
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/rev1",
      registryRevision({
        revisionId: "rev1",
        revisionNumber: 1,
        revisionStatus: "published",
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        version: 2,
      })
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft2",
      registryRevision({ revisionId: "draft2", contentHash: secondHash })
    );

    const db = dbAs("si1");
    const batch = writeBatch(db);
    batch.update(doc(db, "module_registry/baf.module.base_fan_vibration"), {
      latestPublishedRevisionNumber: 2,
      latestPublishedRevisionId: "draft2",
      latestPublishedContentHash: secondHash,
      updatedByUid: "si1",
      updatedAt: new Date().toISOString(),
      version: 3,
    });
    batch.update(
      doc(
        db,
        "module_registry/baf.module.base_fan_vibration/revisions/draft2"
      ),
      {
        revisionStatus: "published",
        revisionNumber: 2,
        publishedByUid: "si1",
        publishedAt: new Date().toISOString(),
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      }
    );
    await assertFails(batch.commit());
  });

  test("legacy latest-published pointers can only bootstrap from matching history", async () => {
    const firstHash =
      "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily({
        latestPublishedRevisionNumber: 1,
        latestPublishedRevisionId: null,
        latestPublishedContentHash: null,
        version: 2,
      })
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/rev1",
      registryRevision({
        revisionId: "rev1",
        revisionNumber: 1,
        revisionStatus: "published",
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        version: 2,
      })
    );

    const db = dbAs("si1");
    const familyRef = doc(db, "module_registry/baf.module.base_fan_vibration");
    await assertSucceeds(
      updateDoc(familyRef, {
        latestPublishedRevisionId: "rev1",
        latestPublishedContentHash: firstHash,
        updatedByUid: "si1",
        updatedByName: "SI User",
        updatedAt: new Date().toISOString(),
        version: 3,
      })
    );

    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft2",
      registryRevision({ revisionId: "draft2", contentHash: firstHash })
    );
    const noOpBatch = writeBatch(db);
    noOpBatch.update(familyRef, {
      latestPublishedRevisionNumber: 2,
      latestPublishedRevisionId: "draft2",
      latestPublishedContentHash: firstHash,
      updatedByUid: "si1",
      updatedAt: new Date().toISOString(),
      version: 4,
    });
    noOpBatch.update(
      doc(
        db,
        "module_registry/baf.module.base_fan_vibration/revisions/draft2"
      ),
      {
        revisionStatus: "published",
        revisionNumber: 2,
        publishedByUid: "si1",
        publishedAt: new Date().toISOString(),
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      }
    );
    await assertFails(noOpBatch.commit());
  });

  test("legacy pointer bootstrap rejects wrong hash and non-governor", async () => {
    const firstHash =
      "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily({
        latestPublishedRevisionNumber: 1,
        latestPublishedRevisionId: null,
        latestPublishedContentHash: null,
        version: 2,
      })
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/rev1",
      registryRevision({
        revisionId: "rev1",
        revisionNumber: 1,
        revisionStatus: "retired",
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        retiredByUid: "si1",
        retiredAt: new Date(3000).toISOString(),
        retireReason: "Superseded historical revision.",
        version: 3,
      })
    );

    await assertFails(
      updateDoc(
        doc(dbAs("si1"), "module_registry/baf.module.base_fan_vibration"),
        {
          latestPublishedRevisionId: "rev1",
          latestPublishedContentHash:
            "mrg1-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          updatedByUid: "si1",
          updatedAt: new Date().toISOString(),
          version: 3,
        }
      )
    );

    await assertFails(
      updateDoc(
        doc(dbAs("ops1"), "module_registry/baf.module.base_fan_vibration"),
        {
          latestPublishedRevisionId: "rev1",
          latestPublishedContentHash: firstHash,
          updatedByUid: "ops1",
          updatedAt: new Date().toISOString(),
          version: 3,
        }
      )
    );
  });

  test("identical registry content hash cannot advance published revision history", async () => {
    const firstHash =
      "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily({
        latestPublishedRevisionNumber: 1,
        latestPublishedRevisionId: "rev1",
        latestPublishedContentHash: firstHash,
        version: 2,
      })
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/rev1",
      registryRevision({
        revisionId: "rev1",
        revisionNumber: 1,
        revisionStatus: "published",
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        version: 2,
      })
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft2",
      registryRevision({ revisionId: "draft2", contentHash: firstHash })
    );

    const db = dbAs("si1");
    const noOpBatch = writeBatch(db);
    noOpBatch.update(
      doc(db, "module_registry/baf.module.base_fan_vibration"),
      {
        latestPublishedRevisionNumber: 2,
        latestPublishedRevisionId: "draft2",
        latestPublishedContentHash: firstHash,
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 3,
      }
    );
    noOpBatch.update(
      doc(
        db,
        "module_registry/baf.module.base_fan_vibration/revisions/draft2"
      ),
      {
        revisionStatus: "published",
        revisionNumber: 2,
        publishedByUid: "si1",
        publishedAt: new Date().toISOString(),
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      }
    );

    await assertFails(noOpBatch.commit());
  });

  test("SI can retire published revision and hard delete is denied", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/rev1",
      registryRevision({
        revisionId: "rev1",
        revisionNumber: 1,
        revisionStatus: "published",
        publishedByUid: "si1",
        publishedAt: new Date(2000).toISOString(),
        version: 2,
      })
    );

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/rev1"),
        {
          revisionStatus: "retired",
          retiredByUid: "si1",
          retiredAt: new Date().toISOString(),
          retireReason: "Superseded by a safer governed module revision.",
          updatedByUid: "si1",
          updatedAt: new Date().toISOString(),
          version: 3,
        }
      )
    );

    await assertFails(
      deleteDoc(doc(db, "module_registry/baf.module.base_fan_vibration/revisions/rev1"))
    );
  });

  test("SI can refresh registry family metadata only with the matching published revision", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft1",
      registryRevision()
    );

    const db = dbAs("si1");
    const hash =
      "mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const batch = writeBatch(db);
    batch.update(doc(db, "module_registry/baf.module.base_fan_vibration"), {
      canonicalTitle: "Base fan vibration check rev 1",
      latestPublishedRevisionNumber: 1,
      latestPublishedRevisionId: "draft1",
      latestPublishedContentHash: hash,
      updatedByUid: "si1",
      updatedAt: new Date().toISOString(),
      version: 2,
    });
    batch.update(
      doc(
        db,
        "module_registry/baf.module.base_fan_vibration/revisions/draft1"
      ),
      {
        revisionStatus: "published",
        revisionNumber: 1,
        publishedByUid: "si1",
        publishedAt: new Date().toISOString(),
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      }
    );

    await assertSucceeds(batch.commit());
  });

  test("registry draft family metadata drift is denied without a publish revision advance", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );

    const db = dbAs("si1");

    await assertFails(
      updateDoc(doc(db, "module_registry/baf.module.base_fan_vibration"), {
        canonicalTitle: "Unpublished draft title should not become canonical",
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
  });

  test("registry family and revision updates reject version jumps", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft1",
      registryRevision()
    );

    const db = dbAs("si1");

    await assertFails(
      updateDoc(doc(db, "module_registry/baf.module.base_fan_vibration"), {
        canonicalTitle: "Jumped family version",
        latestPublishedRevisionNumber: 1,
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 10,
      })
    );

    await assertFails(
      updateDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/draft1"),
        {
          updatedByUid: "si1",
          updatedAt: new Date().toISOString(),
          version: 10,
        }
      )
    );
  });

  test("registry create rejects unknown fields", async () => {
    const db = dbAs("si1");

    await assertFails(
      setDoc(doc(db, "module_registry/baf.module.base_fan_vibration"), {
        ...registryFamily(),
        unexpectedField: true,
      })
    );
  });
});

describe("P-02 pending-user Firebase token identity binding", () => {
  test("verified matching token email may create the pending self profile", async () => {
    const db = dbAs("newUser", {
      email: "new@test.local",
      email_verified: true,
    });

    await assertSucceeds(
      setDoc(
        doc(db, "users/newUser"),
        pendingUserPayload("new@test.local")
      )
    );
  });

  test("mismatched client-asserted email is rejected", async () => {
    const db = dbAs("newUser", {
      email: "token@test.local",
      email_verified: true,
    });

    await assertFails(
      setDoc(
        doc(db, "users/newUser"),
        pendingUserPayload("spoofed@test.local")
      )
    );
  });

  test("missing token email is rejected", async () => {
    const db = dbAs("newUser", { email_verified: true });

    await assertFails(
      setDoc(
        doc(db, "users/newUser"),
        pendingUserPayload("new@test.local")
      )
    );
  });

  test("unverified token email is rejected", async () => {
    const db = dbAs("newUser", {
      email: "new@test.local",
      email_verified: false,
    });

    await assertFails(
      setDoc(
        doc(db, "users/newUser"),
        pendingUserPayload("new@test.local")
      )
    );
  });

  test("verified user may correct a legacy pending email to the token email", async () => {
    await seedDoc(
      "users/legacyUser",
      pendingUserPayload("legacy-client-asserted@test.local")
    );

    const db = dbAs("legacyUser", {
      email: "canonical@test.local",
      email_verified: true,
    });

    await assertSucceeds(
      updateDoc(doc(db, "users/legacyUser"), {
        email: "canonical@test.local",
      })
    );
  });

  test("self update cannot replace email with a value different from the token", async () => {
    await seedDoc(
      "users/existingUser",
      pendingUserPayload("existing@test.local")
    );

    const db = dbAs("existingUser", {
      email: "existing@test.local",
      email_verified: true,
    });

    await assertFails(
      updateDoc(doc(db, "users/existingUser"), {
        email: "spoofed@test.local",
      })
    );
  });

  test("admin correction path remains available and is not bound to admin email", async () => {
    await seedUser("admin1", ["admin"]);
    await seedDoc(
      "users/pending1",
      pendingUserPayload("incorrect@test.local")
    );

    const adminDb = dbAs("admin1", {
      email: "admin@test.local",
      email_verified: true,
    });

    await assertSucceeds(
      updateDoc(doc(adminDb, "users/pending1"), {
        email: "corrected@test.local",
      })
    );
  });
});

describe("R-04 private notification installation registry", () => {
  const installationId = "55cf69a1-8a5d-4c80-a5af-7d1c2a744207";

  test("owner may create, refresh, and delete an exact installation record", async () => {
    await seedUser("owner1", ["operations"]);
    const ref = doc(
      dbAs("owner1"),
      `users/owner1/notification_installations/${installationId}`
    );

    await assertSucceeds(setDoc(ref, notificationInstallationPayload()));
    await assertSucceeds(
      updateDoc(ref, {
        token: "refreshed-token",
        updatedAt: serverTimestamp(),
      })
    );
    await assertSucceeds(deleteDoc(ref));
  });

  test("installation tokens cannot be read by the owner or another user", async () => {
    await seedUser("owner1", ["operations"]);
    await seedUser("other1", ["operations"]);
    await seedDoc(
      `users/owner1/notification_installations/${installationId}`,
      {
        schemaVersion: 1,
        token: "private-token",
        platform: "android",
        updatedAt: Timestamp.now(),
      }
    );

    await assertFails(
      getDoc(
        doc(
          dbAs("owner1"),
          `users/owner1/notification_installations/${installationId}`
        )
      )
    );
    await assertFails(
      getDoc(
        doc(
          dbAs("other1"),
          `users/owner1/notification_installations/${installationId}`
        )
      )
    );
  });

  test("one user cannot create or delete another user's installation", async () => {
    await seedUser("owner1", ["operations"]);
    await seedUser("other1", ["operations"]);
    const ref = doc(
      dbAs("other1"),
      `users/owner1/notification_installations/${installationId}`
    );

    await assertFails(setDoc(ref, notificationInstallationPayload()));
    await seedDoc(
      `users/owner1/notification_installations/${installationId}`,
      {
        schemaVersion: 1,
        token: "private-token",
        platform: "android",
        updatedAt: Timestamp.now(),
      }
    );
    await assertFails(deleteDoc(ref));
  });

  test("malformed IDs and document shapes fail closed", async () => {
    await seedUser("owner1", ["operations"]);
    const db = dbAs("owner1");
    const validRef = doc(
      db,
      `users/owner1/notification_installations/${installationId}`
    );

    await assertFails(
      setDoc(
        doc(db, "users/owner1/notification_installations/not-a-uuid"),
        notificationInstallationPayload()
      )
    );
    await assertFails(
      setDoc(validRef, notificationInstallationPayload({ schemaVersion: 2 }))
    );
    await assertFails(
      setDoc(validRef, notificationInstallationPayload({ platform: "other" }))
    );
    await assertFails(
      setDoc(
        validRef,
        notificationInstallationPayload({ unexpectedField: true })
      )
    );
    await assertFails(
      setDoc(
        validRef,
        notificationInstallationPayload({ updatedAt: Timestamp.now() })
      )
    );
  });

  test("missing or malformed parent profiles cannot register installations", async () => {
    const missingRef = doc(
      dbAs("missing1"),
      `users/missing1/notification_installations/${installationId}`
    );
    await assertFails(
      setDoc(missingRef, notificationInstallationPayload())
    );

    await seedDoc("users/malformed1", {
      roles: ["operations"],
      isApproved: true,
    });
    const malformedRef = doc(
      dbAs("malformed1"),
      `users/malformed1/notification_installations/${installationId}`
    );
    await assertFails(
      setDoc(malformedRef, notificationInstallationPayload())
    );
  });
});

describe("governed dynamic asset hierarchy", () => {
  beforeEach(async () => {
    await seedUser("admin1", ["admin"]);
    await seedUser("ops1", ["operations"]);
  });

  test("approved users read definitions, physical assets and a point tag claim", async () => {
    await seedDoc("asset_classes/class-1", assetClassPayload({
      id: "class-1",
      mutationId: "server-mutation",
    }));
    await seedDoc("asset_hierarchy_nodes/root", hierarchyNodePayload({
      id: "root",
      classId: "class-1",
      mutationId: "server-mutation",
    }));
    await seedDoc("asset_tag_claims/tag-hash", {
      schemaVersion: 2,
      ownerType: "installed_component",
      normalizedTag: "PT101",
      componentInstanceId: "component-1",
    });
    await seedDoc("asset_instances/asset-1", {assetInstanceId: "asset-1"});
    await seedDoc("asset_component_instances/component-1", {
      componentInstanceId: "component-1",
    });

    const opsDb = dbAs("ops1");
    await assertSucceeds(getDoc(doc(opsDb, "asset_classes/class-1")));
    await assertSucceeds(getDoc(doc(opsDb, "asset_hierarchy_nodes/root")));
    await assertSucceeds(getDoc(doc(opsDb, "asset_instances/asset-1")));
    await assertSucceeds(
      getDoc(doc(opsDb, "asset_component_instances/component-1"))
    );
    await assertSucceeds(getDoc(doc(opsDb, "asset_tag_claims/tag-hash")));
    await assertFails(getDocs(collection(opsDb, "asset_tag_claims")));
  });

  test("all client hierarchy mutations fail, including for Admin", async () => {
    const adminDb = dbAs("admin1");
    const writes = [
      setDoc(doc(adminDb, "asset_classes/class-1"), assetClassPayload({
        id: "class-1",
        mutationId: "client-mutation",
      })),
      setDoc(doc(adminDb, "asset_hierarchy_nodes/root"), hierarchyNodePayload({
        id: "root",
        classId: "class-1",
        mutationId: "client-mutation",
      })),
      setDoc(doc(adminDb, "asset_class_codes/furnace"), {assetClassId: "class-1"}),
      setDoc(doc(adminDb, "asset_instances/asset-1"), {assetInstanceId: "asset-1"}),
      setDoc(doc(adminDb, "asset_instance_numbers/number-1"), {assetInstanceId: "asset-1"}),
      setDoc(doc(adminDb, "asset_component_instances/component-1"), {
        componentInstanceId: "component-1",
      }),
      setDoc(doc(adminDb, "asset_tag_claims/tag-hash"), {nodeId: "root"}),
      setDoc(doc(adminDb, "asset_hierarchy_audits/audit-1"), {auditId: "audit-1"}),
      setDoc(doc(adminDb, "asset_hierarchy_mutation_receipts/request-1"), {
        requestId: "request-1",
      }),
    ];
    for (const write of writes) await assertFails(write);
  });

  test("hierarchy audits remain Admin-only and immutable", async () => {
    await seedDoc("asset_hierarchy_audits/audit-1", {auditId: "audit-1"});
    await assertSucceeds(
      getDoc(doc(dbAs("admin1"), "asset_hierarchy_audits/audit-1"))
    );
    await assertFails(
      getDoc(doc(dbAs("ops1"), "asset_hierarchy_audits/audit-1"))
    );
    await assertFails(
      deleteDoc(doc(dbAs("admin1"), "asset_hierarchy_audits/audit-1"))
    );
  });
});
