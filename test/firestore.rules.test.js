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
  setLogLevel,
} = require("firebase/firestore");

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

function dbAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
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
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
  setLogLevel("warn");
});

describe("users", () => {
  test("pending user can create only self as unapproved operations", async () => {
    const db = dbAs("newUser");

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
    const db = dbAs("newUser");

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


describe("template_packages", () => {
  beforeEach(async () => {
    await seedUser("si1", ["si"]);
  });

  test("SI can update template package lifecycle fields", async () => {
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

    await assertSucceeds(
      updateDoc(doc(db, "template_packages/pkgEvidence"), {
        lifecycleStatus: "retired",
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

describe("job_executions", () => {
  beforeEach(async () => {
    await seedUser("ops1", ["operations"]);
    await seedUser("supervisor1", ["shiftSupervisor"]);
  });

  test("shift supervisor can create job execution only with assignment identity", async () => {
    const db = dbAs("supervisor1");
    const now = new Date().toISOString();

    await assertSucceeds(
      setDoc(doc(db, "job_executions/jobCreate"), {
        firestoreId: "jobCreate",
        templateFirestoreId: "ver1",
        templateName: "Governed job",
        templatePackageId: "pkg1",
        templateVersionId: "ver1",
        templateVersionNumber: 1,
        templateContentHash:
          "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
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
  });

  const moduleBase = {
    firestoreId: "mod1",
    moduleTitle: "Base fan inspection",
    assetType: "base",
    assetNumber: 1,
    status: "draftSaved",
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

  test("SI can publish draft revision but cannot mutate frozen payload while publishing", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft1",
      registryRevision()
    );

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/draft1"),
        {
          revisionStatus: "published",
          revisionNumber: 1,
          publishedByUid: "si1",
          publishedAt: new Date().toISOString(),
          updatedByUid: "si1",
          updatedAt: new Date().toISOString(),
          version: 2,
        }
      )
    );

    await seedDoc(
      "module_registry/baf.module.base_fan_vibration/revisions/draft2",
      registryRevision({ revisionId: "draft2" })
    );

    await assertFails(
      updateDoc(
        doc(db, "module_registry/baf.module.base_fan_vibration/revisions/draft2"),
        {
          revisionStatus: "published",
          revisionNumber: 1,
          moduleSnapshotJson: '{"moduleCode":"MUTATED"}',
          publishedByUid: "si1",
          publishedAt: new Date().toISOString(),
          updatedByUid: "si1",
          updatedAt: new Date().toISOString(),
          version: 2,
        }
      )
    );
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

  test("SI can refresh registry family metadata only as a publish-style revision advance", async () => {
    await seedDoc(
      "module_registry/baf.module.base_fan_vibration",
      registryFamily()
    );

    const db = dbAs("si1");

    await assertSucceeds(
      updateDoc(doc(db, "module_registry/baf.module.base_fan_vibration"), {
        canonicalTitle: "Base fan vibration check rev 1",
        latestPublishedRevisionNumber: 1,
        updatedByUid: "si1",
        updatedAt: new Date().toISOString(),
        version: 2,
      })
    );
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
