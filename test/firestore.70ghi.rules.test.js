const fs = require("fs");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
  Timestamp,
  setLogLevel,
} = require("firebase/firestore");

let testEnv;

const PROJECT_ID = "crm3-baf-ops-70ghi-rules";

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
      userDoc(uid, roles, isApproved),
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
}, 120000);

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedUser("admin1", ["admin"]);
  await seedUser("si1", ["si"]);
  await seedUser("supervisor1", ["shiftSupervisor"]);
  await seedUser("ops1", ["operations"]);
  await seedUser("pending1", ["operations"], false);
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
  setLogLevel("warn");
});

describe("70GHI governance audit read parity", () => {
  beforeEach(async () => {
    await seedDoc("template_publish_audits/pubAudit1", {
      firestoreId: "pubAudit1",
      packageFirestoreId: "pkg1",
      versionFirestoreId: "ver1",
      action: "published",
      performedByUid: "si1",
      performedAt: new Date(1000).toISOString(),
      updatedAt: new Date(1000).toISOString(),
      afterHash:
        "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      version: 1,
      isDeleted: false,
    });
    await seedDoc("module_registry_audits/registryAudit1", {
      firestoreId: "registryAudit1",
      registryModuleId: "registry1",
      action: "draftCreated",
      performedByUid: "si1",
      performedAt: new Date(1000).toISOString(),
      version: 1,
      isDeleted: false,
    });
  });

  test("approved operations user can read template publication evidence required by global pull", async () => {
    await assertSucceeds(
      getDoc(doc(dbAs("ops1"), "template_publish_audits/pubAudit1")),
    );
  });

  test("approved operations user can run the paginated global-pull audit query", async () => {
    const auditsQuery = query(
      collection(dbAs("ops1"), "template_publish_audits"),
      where("updatedAt", ">", new Date(0).toISOString()),
      orderBy("updatedAt"),
      limit(500),
    );
    const snapshot = await assertSucceeds(getDocs(auditsQuery));
    expect(snapshot.docs.map((entry) => entry.id)).toContain("pubAudit1");
  });

  test("SI can read both template and registry governance audits", async () => {
    await assertSucceeds(
      getDoc(doc(dbAs("si1"), "template_publish_audits/pubAudit1")),
    );
    await assertSucceeds(
      getDoc(doc(dbAs("si1"), "module_registry_audits/registryAudit1")),
    );
  });

  test("ordinary approved user cannot read registry governance audit details", async () => {
    await assertFails(
      getDoc(doc(dbAs("ops1"), "module_registry_audits/registryAudit1")),
    );
  });

  test("unapproved user cannot read template publication audits", async () => {
    await assertFails(
      getDoc(doc(dbAs("pending1"), "template_publish_audits/pubAudit1")),
    );
  });
});

describe("70GHI direct governed assignment denial", () => {
  test("shift supervisor cannot directly create governed JobExecution", async () => {
    const now = new Date().toISOString();
    await assertFails(
      setDoc(doc(dbAs("supervisor1"), "job_executions/governedDirect"), {
        firestoreId: "governedDirect",
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
      }),
    );
  });

  test("governed TemplateVersion cannot be disguised as legacy direct execution", async () => {
    await seedDoc("template_versions/ver1", {
      firestoreId: "ver1",
      packageFirestoreId: "pkg1",
      versionNumber: 1,
      status: "published",
      isDeleted: false,
    });
    const now = new Date().toISOString();
    await assertFails(
      setDoc(doc(dbAs("supervisor1"), "job_executions/disguisedGoverned"), {
        firestoreId: "disguisedGoverned",
        templateFirestoreId: "ver1",
        templateName: "Disguised governed job",
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
      }),
    );
  });

  test("shift supervisor retains direct legacy JobExecution create", async () => {
    const now = new Date().toISOString();
    await assertSucceeds(
      setDoc(doc(dbAs("supervisor1"), "job_executions/legacyDirect"), {
        firestoreId: "legacyDirect",
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
      }),
    );
  });

  function modulePayload(overrides = {}) {
    const now = new Date().toISOString();
    return {
      firestoreId: "moduleDirect",
      jobExecutionFirestoreId: "job1",
      templateFirestoreId: "ver1",
      templateName: "Governed job",
      templatePackageId: "pkg1",
      templateVersionId: "ver1",
      templateModuleId: "tm1",
      moduleCode: "M-01",
      moduleTitle: "Inspect base fan",
      moduleSnapshotJson: "{}",
      fieldDefinitionsJson: "[]",
      assetType: "base",
      assetNumber: 101,
      status: "notStarted",
      discipline: "mechanical",
      safetyClass: "normal",
      isRequired: true,
      requiredForClosure: false,
      addedDuringExecution: false,
      displayOrder: 0,
      responsesJson: "[]",
      actionsJson: "[]",
      requiresFollowUp: false,
      createdByUid: "supervisor1",
      updatedByUid: "supervisor1",
      createdAt: now,
      updatedAt: now,
      version: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  test("shift supervisor cannot directly create initial governed frozen module", async () => {
    await assertFails(
      setDoc(
        doc(dbAs("supervisor1"), "job_modules/moduleDirect"),
        modulePayload(),
      ),
    );
  });

  test("initial governed module cannot be disguised by omitting governance fields", async () => {
    await seedDoc("template_versions/ver1", {
      firestoreId: "ver1",
      packageFirestoreId: "pkg1",
      versionNumber: 1,
      status: "published",
      isDeleted: false,
    });
    await assertFails(
      setDoc(
        doc(dbAs("supervisor1"), "job_modules/moduleDisguised"),
        modulePayload({
          firestoreId: "moduleDisguised",
          templatePackageId: null,
          templateVersionId: null,
          templateFirestoreId: "ver1",
        }),
      ),
    );
  });

  test("direct runtime-added module path is denied and must use the population callable", async () => {
    await assertFails(
      setDoc(
        doc(dbAs("supervisor1"), "job_modules/moduleRuntime"),
        modulePayload({
          firestoreId: "moduleRuntime",
          addedDuringExecution: true,
        }),
      ),
    );
  });

  test("client cannot read or write server idempotency receipts", async () => {
    await seedDoc(
      "published_template_assignment_requests/request1",
      {
        firestoreId: "request1",
        actorUid: "supervisor1",
        payloadFingerprint: "abc",
      },
    );
    await assertFails(
      getDoc(
        doc(
          dbAs("supervisor1"),
          "published_template_assignment_requests/request1",
        ),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          dbAs("supervisor1"),
          "published_template_assignment_requests/request2",
        ),
        {
          firestoreId: "request2",
          actorUid: "supervisor1",
          payloadFingerprint: "abc",
        },
      ),
    );
  });
});

describe("70GHI package/version/audit coupling", () => {
  const contentHash =
    "tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

  function packageData(overrides = {}) {
    return {
      firestoreId: "pkg1",
      packageCode: "PKG-1",
      title: "Governed package",
      lifecycleStatus: "active",
      activeVersionFirestoreId: null,
      latestVersionNumber: 0,
      createdByUid: "si1",
      updatedByUid: "si1",
      createdAt: new Date(1000).toISOString(),
      updatedAt: new Date(1000).toISOString(),
      version: 1,
      schemaVersion: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  function versionData(overrides = {}) {
    return {
      firestoreId: "ver1",
      packageFirestoreId: "pkg1",
      versionNumber: 1,
      status: "published",
      jobTemplateSnapshotJson: '{"jobName":"Governed job"}',
      moduleSnapshotsJson:
        '[{"moduleCode":"M-01","moduleTitle":"Inspect base fan"}]',
      fieldDefinitionsJson: "[]",
      checklistJson: "[]",
      contentHash,
      closureReviewConfirmed: false,
      closureCriticalModuleCount: 0,
      createdByUid: "si1",
      updatedByUid: "si1",
      publishedByUid: "si1",
      createdAt: new Date(1000).toISOString(),
      updatedAt: new Date(2000).toISOString(),
      publishedAt: new Date(2000).toISOString(),
      version: 2,
      schemaVersion: 1,
      isDeleted: false,
      ...overrides,
    };
  }

  beforeEach(async () => {
    await seedDoc("template_packages/pkg1", packageData());
  });

  test("package active pointer may advance only to its published version and matching number", async () => {
    await seedDoc("template_versions/ver1", versionData());
    await assertSucceeds(
      updateDoc(doc(dbAs("si1"), "template_packages/pkg1"), {
        activeVersionFirestoreId: "ver1",
        latestVersionNumber: 1,
        updatedByUid: "si1",
        updatedAt: new Date(3000).toISOString(),
        version: 2,
      }),
    );
  });

  test("package active pointer rejects draft or foreign version", async () => {
    await seedDoc(
      "template_versions/draft1",
      versionData({
        firestoreId: "draft1",
        status: "draft",
      }),
    );
    await assertFails(
      updateDoc(doc(dbAs("si1"), "template_packages/pkg1"), {
        activeVersionFirestoreId: "draft1",
        latestVersionNumber: 1,
        updatedByUid: "si1",
        updatedAt: new Date(3000).toISOString(),
        version: 2,
      }),
    );

    await seedDoc(
      "template_versions/foreign1",
      versionData({
        firestoreId: "foreign1",
        packageFirestoreId: "pkg2",
      }),
    );
    await assertFails(
      updateDoc(doc(dbAs("si1"), "template_packages/pkg1"), {
        activeVersionFirestoreId: "foreign1",
        latestVersionNumber: 1,
        updatedByUid: "si1",
        updatedAt: new Date(3000).toISOString(),
        version: 2,
      }),
    );
  });

  test("published audit must match active package, canonical hash, and publishing actor", async () => {
    await seedDoc("template_versions/ver1", versionData());
    await seedDoc(
      "template_packages/pkg1",
      packageData({
        activeVersionFirestoreId: "ver1",
        latestVersionNumber: 1,
        version: 2,
      }),
    );

    const validAudit = {
      firestoreId: "pubAudit",
      packageFirestoreId: "pkg1",
      versionFirestoreId: "ver1",
      action: "published",
      performedByUid: "si1",
      performedByName: "SI User",
      performedAt: new Date(3000).toISOString(),
      updatedAt: new Date(3000).toISOString(),
      beforeHash: null,
      afterHash: contentHash,
      payloadSnapshotJson: "{}",
      version: 1,
      schemaVersion: 1,
      isDeleted: false,
    };

    await assertSucceeds(
      setDoc(
        doc(dbAs("si1"), "template_publish_audits/pubAudit"),
        validAudit,
      ),
    );

    await assertFails(
      setDoc(
        doc(dbAs("si1"), "template_publish_audits/pubAuditWrongHash"),
        {
          ...validAudit,
          firestoreId: "pubAuditWrongHash",
          afterHash:
            "tg2-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        },
      ),
    );

    await assertFails(
      setDoc(
        doc(dbAs("admin1"), "template_publish_audits/pubAuditWrongActor"),
        {
          ...validAudit,
          firestoreId: "pubAuditWrongActor",
          performedByUid: "admin1",
        },
      ),
    );
  });
});
