const {
  AssignmentValidationError,
  assignmentRequestPayloadFingerprint,
  assignPublishedTemplateVersionWithDb,
  computeTemplateVersionContentHash,
  parsePublishedTemplateAssignmentRequest,
} = require("../lib/publishedTemplateAssignment");

const REQUEST_ID = "11111111-1111-4111-8111-111111111111";

function versionFixture(overrides = {}) {
  const jobTemplateSnapshotJson =
    '{"jobName":"Base PM","composer":{"closureReviewConfirmed":true,"closureReviewConfirmedByUid":"si1","closureReviewConfirmedByName":"SI User","closureReviewConfirmedAt":"2026-06-19T10:00:00.000Z"},"closureCriticalCount":1}';
  const moduleSnapshotsJson =
    '[{"moduleCode":"M-01","moduleTitle":"Inspect fan","requiredForClosure":true,"discipline":"mechanical"}]';
  const fieldDefinitionsJson =
    '[{"key":"vibration","label":"Vibration","moduleCode":"M-01","type":"number","isRequired":true}]';
  return {
    firestoreId: "ver1",
    packageFirestoreId: "pkg1",
    versionNumber: 1,
    versionLabel: "v1",
    status: "published",
    contentHash:
      "tg2-sha256:10c47efd30febb9c3938de06ae8ceb5089fa5d73c688041df5fdbc5710554ac9",
    jobTemplateSnapshotJson,
    moduleSnapshotsJson,
    fieldDefinitionsJson,
    checklistJson: "[]",
    closureReviewConfirmed: true,
    closureCriticalModuleCount: 1,
    closureReviewConfirmedByUid: "si1",
    closureReviewConfirmedByName: "SI User",
    closureReviewConfirmedAt: "2026-06-19T10:00:00.000Z",
    publishedByUid: "si1",
    publishedByName: "SI User",
    publishedAt: "2026-06-19T10:05:00.000Z",
    targetRefs: [],
    deviceTagRefs: [],
    safetyClass: null,
    safetyGatePolicyJson: null,
    procedureRefs: [],
    operationalStatePreconditions: [],
    schemaVersion: 1,
    isDeleted: false,
    ...overrides,
  };
}

function requestFixture(overrides = {}) {
  return {
    requestId: REQUEST_ID,
    packageId: "pkg1",
    versionId: "ver1",
    expectedVersionNumber: 1,
    expectedContentHash: versionFixture().contentHash,
    assetType: "base",
    assetNumber: 101,
    chargeNoAtEvent: 12345,
    remarks: "Inspect during planned window.",
    ...overrides,
  };
}

function packageFixture(overrides = {}) {
  return {
    firestoreId: "pkg1",
    packageCode: "BAF-BASE-PM",
    title: "Base preventive maintenance",
    disciplineScope: "mechanical",
    lifecycleStatus: "active",
    activeVersionFirestoreId: "ver1",
    latestVersionNumber: 1,
    isDeleted: false,
    ...overrides,
  };
}

function auditFixture(overrides = {}) {
  return {
    firestoreId: "audit1",
    packageFirestoreId: "pkg1",
    versionFirestoreId: "ver1",
    action: "published",
    performedByUid: "si1",
    performedAt: "2026-06-19T10:05:01.000Z",
    afterHash: versionFixture().contentHash,
    isDeleted: false,
    ...overrides,
  };
}

function workflowFixture(overrides = {}) {
  return {
    firestoreId: "workflow1",
    jobExecutionId: "workflow1",
    assetTypeKey: "base",
    assetNumber: 101,
    status: "pendingLaneClassification",
    activeRedWork: false,
    awaitingPreparation: false,
    cancelled: false,
    ...overrides,
  };
}

function fakeAssignmentDb({
  user = {
    isApproved: true,
    roles: ["shiftSupervisor"],
    name: "Shift Supervisor",
  },
  packageData = packageFixture(),
  versionData = versionFixture(),
  audits = [auditFixture()],
  equipmentData = null,
  workflows = [],
} = {}) {
  const store = new Map();
  const writes = [];
  const queuedTransactionFailures = [];
  let transactionAttempts = 0;
  let idCounter = 0;

  function seed(path, data) {
    store.set(path, structuredClone(data));
  }
  if (user != null) seed("users/supervisor1", user);
  if (packageData != null) seed("template_packages/pkg1", packageData);
  if (versionData != null) seed("template_versions/ver1", versionData);
  audits.forEach((audit, index) =>
    seed(
      `template_publish_audits/${audit.firestoreId ?? `audit${index + 1}`}`,
      audit,
    ),
  );
  if (equipmentData != null) {
    seed("equipment_status/base_101", equipmentData);
  }
  workflows.forEach((workflow, index) => {
    const id = workflow.firestoreId ?? `workflow${index + 1}`;
    seed(`maintenance_workflows/${id}`, workflow);
  });

  function docRef(collectionName, id) {
    const resolvedId = id ?? `${collectionName.replaceAll("_", "")}_${++idCounter}`;
    return {
      id: resolvedId,
      path: `${collectionName}/${resolvedId}`,
    };
  }

  function querySnapshot(refOrQuery) {
    const prefix = `${refOrQuery.collectionName}/`;
    const docs = [];
    for (const [path, data] of store.entries()) {
      if (!path.startsWith(prefix)) continue;
      const matches = refOrQuery.clauses.every(
        ([field, op, value]) => op === "==" && data[field] === value,
      );
      if (!matches) continue;
      docs.push({
        exists: true,
        id: path.slice(prefix.length),
        data: () => structuredClone(data),
      });
    }
    return {docs};
  }

  function queryRef(collectionName, clauses) {
    const query = {
      kind: "query",
      collectionName,
      clauses,
      where(field, op, value) {
        return queryRef(collectionName, [...clauses, [field, op, value]]);
      },
      async get() {
        return querySnapshot(query);
      },
    };
    return query;
  }

  const db = {
    collection(name) {
      return {
        doc(id) {
          return docRef(name, id);
        },
        where(field, op, value) {
          return queryRef(name, [[field, op, value]]);
        },
      };
    },
    async runTransaction(fn) {
      transactionAttempts += 1;
      if (queuedTransactionFailures.length > 0) {
        throw queuedTransactionFailures.shift();
      }
      const staged = [];
      const transaction = {
        async get(refOrQuery) {
          if (refOrQuery.kind === "query") {
            return querySnapshot(refOrQuery);
          }
          const data = store.get(refOrQuery.path);
          return {
            exists: data != null,
            id: refOrQuery.id,
            data: () => (data == null ? undefined : structuredClone(data)),
          };
        },
        set(ref, data) {
          staged.push({path: ref.path, data: structuredClone(data)});
        },
      };
      const result = await fn(transaction);
      for (const write of staged) {
        store.set(write.path, write.data);
        writes.push(write);
      }
      return result;
    },
  };

  return {
    db,
    store,
    writes,
    failNextTransaction(error) {
      queuedTransactionFailures.push(error);
    },
    get transactionAttempts() {
      return transactionAttempts;
    },
  };
}

function closedTransactionError() {
  const error = new Error("3 INVALID_ARGUMENT: Transaction is invalid or closed.");
  error.code = 3;
  error.details = "Transaction is invalid or closed.";
  return error;
}

describe("published TemplateVersion server assignment", () => {
  test("matches the Dart tg2 canonical hash fixture", () => {
    expect(computeTemplateVersionContentHash(versionFixture())).toBe(
      "tg2-sha256:10c47efd30febb9c3938de06ae8ceb5089fa5d73c688041df5fdbc5710554ac9",
    );
  });

  test("request payload fingerprint excludes requestId and matches canonical meaning", () => {
    const parsed = parsePublishedTemplateAssignmentRequest(requestFixture());
    const direct = assignmentRequestPayloadFingerprint({
      packageId: "pkg1",
      versionId: "ver1",
      expectedVersionNumber: 1,
      expectedContentHash: versionFixture().contentHash,
      assetType: "base",
      assetNumber: 101,
      chargeNoAtEvent: 12345,
      remarks: "Inspect during planned window.",
    });
    expect(parsed.payloadFingerprint).toBe(direct);
    const changedId = parsePublishedTemplateAssignmentRequest(
      requestFixture({
        requestId: "22222222-2222-4222-8222-222222222222",
      }),
    );
    expect(changedId.payloadFingerprint).toBe(direct);
  });

  test("creates canonical execution, frozen module, and idempotency receipt atomically", async () => {
    const {db, store, writes} = fakeAssignmentDb();
    const result = await assignPublishedTemplateVersionWithDb({
      db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });

    expect(result.ok).toBe(true);
    expect(result.idempotentReplay).toBe(false);
    expect(result.publicationAuditId).toBe("audit1");
    expect(result.execution.templatePackageId).toBe("pkg1");
    expect(result.execution.templateVersionId).toBe("ver1");
    expect(result.execution.templateContentHash).toBe(
      versionFixture().contentHash,
    );
    expect(result.execution.assignedByUid).toBe("supervisor1");
    expect(result.execution.modulePopulationVersion).toBe(1);
    expect(result.execution.modulePopulationSchemaVersion).toBe(1);
    expect(result.execution.modulePopulationLastModuleId).toBe(
      result.modules[0].firestoreId,
    );
    expect(result.modules).toHaveLength(1);
    expect(result.modules[0].jobExecutionFirestoreId).toBe(
      result.executionId,
    );
    expect(result.modules[0].moduleCode).toBe("M-01");
    expect(result.modules[0].fieldDefinitionsJson).toContain("vibration");
    expect(result.modules[0].addedDuringExecution).toBe(false);
    expect(
      store.has(`job_executions/${result.executionId}`),
    ).toBe(true);
    expect(
      store.has(`job_modules/${result.modules[0].firestoreId}`),
    ).toBe(true);
    expect(
      store.has(
        `published_template_assignment_requests/${REQUEST_ID}`,
      ),
    ).toBe(true);
    expect(
      store.has(`maintenance_workflows/${result.executionId}`),
    ).toBe(true);
    expect(
      store.has("equipment_status/base_101"),
    ).toBe(true);
    expect(
      store.get(`maintenance_workflows/${result.executionId}`),
    ).toMatchObject({
      jobExecutionId: result.executionId,
      status: "pendingLaneClassification",
      workflowSchemaVersion: 1,
      laneSetVersion: 0,
    });
    expect(
      store.get("equipment_status/base_101"),
    ).toMatchObject({
      assetTypeKey: "base",
      assetNumber: 101,
      state: "underMaintenance",
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
    expect(writes).toHaveLength(5);
  });

  test("serializes assignment through an existing governed equipment projection", async () => {
    const {db, store} = fakeAssignmentDb({
      workflows: [
        workflowFixture({firestoreId: "workflow1"}),
        workflowFixture({firestoreId: "workflow2"}),
      ],
      equipmentData: {
        assetTypeKey: "base",
        assetNumber: 101,
        state: "underMaintenance",
        activeNonRedMaintenanceCount: 2,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 7,
      },
    });

    await assignPublishedTemplateVersionWithDb({
      db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });

    expect(store.get("equipment_status/base_101")).toMatchObject({
      previousState: "underMaintenance",
      state: "underMaintenance",
      activeNonRedMaintenanceCount: 3,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 8,
    });
  });

  test("reconstructs a missing projection from current workflow facts", async () => {
    const fixture = fakeAssignmentDb({
      workflows: [workflowFixture()],
    });

    await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });

    expect(fixture.store.get("equipment_status/base_101")).toMatchObject({
      state: "underMaintenance",
      activeNonRedMaintenanceCount: 2,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 1,
    });
  });

  test("upgrades a legacy projection whose state matches workflow facts", async () => {
    const fixture = fakeAssignmentDb({
      workflows: [workflowFixture()],
      equipmentData: {
        state: "underMaintenance",
        version: 4,
      },
    });

    await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });

    expect(fixture.store.get("equipment_status/base_101")).toMatchObject({
      assetTypeKey: "base",
      assetNumber: 101,
      state: "underMaintenance",
      activeNonRedMaintenanceCount: 2,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 5,
    });
  });

  test("re-reads workflow facts after a projection race before transaction start", async () => {
    const fixture = fakeAssignmentDb();
    let hookCalls = 0;

    await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
      beforeAssignmentTransactionForTest: async () => {
        hookCalls += 1;
        fixture.store.set(
          "maintenance_workflows/racing_workflow",
          workflowFixture({firestoreId: "racing_workflow"}),
        );
        fixture.store.set("equipment_status/base_101", {
          assetTypeKey: "base",
          assetNumber: 101,
          state: "underMaintenance",
          activeNonRedMaintenanceCount: 1,
          activeRedWorkCount: 0,
          awaitingPreparationCount: 0,
          version: 1,
        });
      },
    });

    expect(hookCalls).toBe(1);
    expect(fixture.store.get("equipment_status/base_101")).toMatchObject({
      activeNonRedMaintenanceCount: 2,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 2,
    });
  });

  test("persistent workflow/projection mismatch exhausts bounded reconciliation without writes", async () => {
    const fixture = fakeAssignmentDb({
      workflows: [workflowFixture()],
      equipmentData: {
        assetTypeKey: "base",
        assetNumber: 101,
        state: "underMaintenance",
        activeNonRedMaintenanceCount: 2,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 2,
      },
    });

    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {
        reasonCode: "equipment-projection-reconciliation-exhausted",
        maximumAttempts: 5,
      },
    });
    expect(fixture.writes).toHaveLength(0);
    expect(
      [...fixture.store.keys()].some((path) =>
        path.startsWith("job_executions/") ||
        path.startsWith("published_template_assignment_requests/"),
      ),
    ).toBe(false);
  });

  test.each([
    [
      "invalid counter",
      {
        assetTypeKey: "base",
        assetNumber: 101,
        state: "underMaintenance",
        activeNonRedMaintenanceCount: -1,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 1,
      },
      "equipment-projection-counter-invalid",
    ],
    [
      "identity mismatch",
      {
        assetTypeKey: "furnace",
        assetNumber: 1,
        state: "underMaintenance",
        activeNonRedMaintenanceCount: 1,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 1,
      },
      "equipment-projection-identity-mismatch",
    ],
    [
      "state mismatch",
      {
        assetTypeKey: "base",
        assetNumber: 101,
        state: "inService",
        activeNonRedMaintenanceCount: 1,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 1,
      },
      "equipment-projection-state-mismatch",
    ],
  ])("%s projection rejects without writes", async (_label, equipmentData, reasonCode) => {
    const fixture = fakeAssignmentDb({
      equipmentData,
      workflows: [workflowFixture()],
    });

    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode},
    });
    expect(fixture.writes).toHaveLength(0);
    expect(fixture.store.get("maintenance_workflows/workflow1")).toEqual(
      workflowFixture(),
    );
    expect(
      [...fixture.store.keys()].some((path) =>
        path.startsWith("job_executions/") ||
        path.startsWith("job_modules/") ||
        path.startsWith("published_template_assignment_requests/"),
      ),
    ).toBe(false);
  });

  test("pre-transaction test hook executes before any transaction write", async () => {
    const fixture = fakeAssignmentDb();
    let hookCalls = 0;

    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture(),
        beforeAssignmentTransactionForTest: async () => {
          hookCalls += 1;
          throw new Error("forced-before-transaction");
        },
      }),
    ).rejects.toThrow("forced-before-transaction");

    expect(hookCalls).toBe(1);
    expect(fixture.writes).toHaveLength(0);
  });

  test("safe retry returns the same execution and modules without duplicate writes", async () => {
    const {db, writes} = fakeAssignmentDb();
    const first = await assignPublishedTemplateVersionWithDb({
      db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });
    const writeCount = writes.length;

    const replay = await assignPublishedTemplateVersionWithDb({
      db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T12:00:00.000Z"),
    });

    expect(replay.idempotentReplay).toBe(true);
    expect(replay.executionId).toBe(first.executionId);
    expect(replay.modules.map((module) => module.firestoreId)).toEqual(
      first.modules.map((module) => module.firestoreId),
    );
    expect(writes).toHaveLength(writeCount);
  });

  test("same request ID with changed assignment meaning is rejected without writes", async () => {
    const {db, writes} = fakeAssignmentDb();
    await assignPublishedTemplateVersionWithDb({
      db,
      authUid: "supervisor1",
      data: requestFixture(),
    });
    const writeCount = writes.length;

    await expect(
      assignPublishedTemplateVersionWithDb({
        db,
        authUid: "supervisor1",
        data: requestFixture({assetNumber: 102}),
      }),
    ).rejects.toMatchObject({
      code: "already-exists",
      details: {reasonCode: "request-payload-mismatch"},
    });
    expect(writes).toHaveLength(writeCount);
  });

  test("rejects unauthorized and unapproved users before writes", async () => {
    const {db, writes} = fakeAssignmentDb({
      user: {isApproved: true, roles: ["operations"], name: "Operations"},
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({code: "permission-denied"});
    expect(writes).toHaveLength(0);
  });

  test("rejects historical, unpublished, or hash-divergent governance without partial writes", async () => {
    for (const scenario of [
      {
        packageData: packageFixture({activeVersionFirestoreId: "ver2"}),
        expectedCode: "failed-precondition",
        reasonCode: "version-not-active",
      },
      {
        versionData: versionFixture({status: "draft"}),
        expectedCode: "failed-precondition",
        reasonCode: "version-not-published",
      },
      {
        versionData: versionFixture({
          moduleSnapshotsJson:
            '[{"moduleCode":"M-CHANGED","moduleTitle":"Changed"}]',
        }),
        expectedCode: "failed-precondition",
        reasonCode: "version-hash-mismatch",
      },
    ]) {
      const {db, writes} = fakeAssignmentDb(scenario);
      await expect(
        assignPublishedTemplateVersionWithDb({
          db,
          authUid: "supervisor1",
          data: requestFixture(),
        }),
      ).rejects.toMatchObject({
        code: scenario.expectedCode,
        details: {reasonCode: scenario.reasonCode},
      });
      expect(writes).toHaveLength(0);
    }
  });

  test("rejects missing publication audit and duplicate module codes without partial writes", async () => {
    const missingAudit = fakeAssignmentDb({audits: []});
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: missingAudit.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({
      code: "not-found",
      details: {reasonCode: "publication-audit-missing"},
    });
    expect(missingAudit.writes).toHaveLength(0);

    const duplicateVersion = versionFixture({
      moduleSnapshotsJson:
        '[{"moduleCode":"M-01","moduleTitle":"One"},{"moduleCode":"m01","moduleTitle":"Two"}]',
      fieldDefinitionsJson: "[]",
    });
    duplicateVersion.contentHash = computeTemplateVersionContentHash(
      duplicateVersion,
    );
    const duplicateDb = fakeAssignmentDb({
      versionData: duplicateVersion,
      audits: [
        auditFixture({afterHash: duplicateVersion.contentHash}),
      ],
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: duplicateDb.db,
        authUid: "supervisor1",
        data: requestFixture({
          expectedContentHash: duplicateVersion.contentHash,
        }),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode: "duplicate-module-code"},
    });
    expect(duplicateDb.writes).toHaveLength(0);
  });

  test("rejects inactive package, mismatched package/version, and missing publish actor without writes", async () => {
    const scenarios = [
      {
        packageData: packageFixture({lifecycleStatus: "retired"}),
        reasonCode: "package-not-active",
      },
      {
        packageData: packageFixture({latestVersionNumber: 2}),
        reasonCode: "package-version-number-mismatch",
      },
      {
        versionData: versionFixture({packageFirestoreId: "pkg2"}),
        reasonCode: "version-package-mismatch",
      },
      {
        versionData: versionFixture({publishedByUid: null}),
        reasonCode: "published-actor-missing",
      },
    ];

    for (const scenario of scenarios) {
      const fixture = fakeAssignmentDb(scenario);
      await expect(
        assignPublishedTemplateVersionWithDb({
          db: fixture.db,
          authUid: "supervisor1",
          data: requestFixture(),
        }),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {reasonCode: scenario.reasonCode},
      });
      expect(fixture.writes).toHaveLength(0);
    }
  });

  test("rejects malformed snapshots, duplicate field keys, and oversized module sets without writes", async () => {
    const malformedVersion = versionFixture({
      moduleSnapshotsJson: "not-json",
    });
    const malformedDb = fakeAssignmentDb({
      versionData: malformedVersion,
      audits: [auditFixture({afterHash: malformedVersion.contentHash})],
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: malformedDb.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode: "invalid-snapshot-json"},
    });
    expect(malformedDb.writes).toHaveLength(0);

    const duplicateFieldVersion = versionFixture({
      fieldDefinitionsJson: JSON.stringify([
        {moduleCode: "M-01", key: "vibration", label: "Vibration A"},
        {moduleCode: "M-01", key: "VIBRATION", label: "Vibration B"},
      ]),
    });
    duplicateFieldVersion.contentHash = computeTemplateVersionContentHash(
      duplicateFieldVersion,
    );
    const duplicateFieldDb = fakeAssignmentDb({
      versionData: duplicateFieldVersion,
      audits: [auditFixture({afterHash: duplicateFieldVersion.contentHash})],
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: duplicateFieldDb.db,
        authUid: "supervisor1",
        data: requestFixture({
          expectedContentHash: duplicateFieldVersion.contentHash,
        }),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode: "duplicate-field-key"},
    });
    expect(duplicateFieldDb.writes).toHaveLength(0);

    const modules = Array.from({length: 101}, (_, index) => ({
      moduleCode: `M-${String(index + 1).padStart(3, "0")}`,
      moduleTitle: `Module ${index + 1}`,
    }));
    const oversizedVersion = versionFixture({
      moduleSnapshotsJson: JSON.stringify(modules),
      fieldDefinitionsJson: "[]",
    });
    oversizedVersion.contentHash = computeTemplateVersionContentHash(
      oversizedVersion,
    );
    const oversizedDb = fakeAssignmentDb({
      versionData: oversizedVersion,
      audits: [auditFixture({afterHash: oversizedVersion.contentHash})],
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: oversizedDb.db,
        authUid: "supervisor1",
        data: requestFixture({
          expectedContentHash: oversizedVersion.contentHash,
        }),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode: "too-many-modules"},
    });
    expect(oversizedDb.writes).toHaveLength(0);
  });

  test("forced failure before multi-module writes leaves no execution, child, or receipt residue", async () => {
    const multiVersion = versionFixture({
      moduleSnapshotsJson: JSON.stringify([
        {moduleCode: "M-01", moduleTitle: "Inspect fan", requiredForClosure: true, discipline: "mechanical"},
        {moduleCode: "M-02", moduleTitle: "Inspect base seal", requiredForClosure: false, discipline: "mechanical"},
      ]),
      fieldDefinitionsJson: JSON.stringify([
        {key: "vibration", label: "Vibration", moduleCode: "M-01", type: "number", isRequired: true},
        {key: "seal", label: "Seal", moduleCode: "M-02", type: "text", isRequired: false},
      ]),
    });
    multiVersion.contentHash = computeTemplateVersionContentHash(multiVersion);
    const fixture = fakeAssignmentDb({
      versionData: multiVersion,
      audits: [auditFixture({afterHash: multiVersion.contentHash})],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({expectedContentHash: multiVersion.contentHash}),
      beforeAssignmentWritesForTest: async () => {
        throw new Error("forced-multi-module-failure");
      },
    })).rejects.toThrow("forced-multi-module-failure");

    expect(fixture.writes).toHaveLength(0);
    expect([...fixture.store.keys()].some((path) => path.startsWith("job_executions/"))).toBe(false);
    expect([...fixture.store.keys()].some((path) => path.startsWith("job_modules/"))).toBe(false);
    expect([...fixture.store.keys()].some((path) => path.startsWith("published_template_assignment_requests/"))).toBe(false);
  });

  test("idempotency receipt cannot be replayed by another actor or after evidence loss", async () => {
    const fixture = fakeAssignmentDb();
    const first = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });
    const receiptPath = `published_template_assignment_requests/${REQUEST_ID}`;
    const receipt = fixture.store.get(receiptPath);
    fixture.store.set(receiptPath, {...receipt, actorUid: "other-user"});
    const writeCount = fixture.writes.length;

    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({
      code: "already-exists",
      details: {reasonCode: "request-owner-mismatch"},
    });
    expect(fixture.writes).toHaveLength(writeCount);

    fixture.store.set(receiptPath, {
      ...receipt,
      actorUid: "supervisor1",
      moduleIds: [],
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({
      code: "data-loss",
      details: {reasonCode: "request-evidence-incomplete"},
    });
    expect(fixture.writes).toHaveLength(writeCount);
    expect(first.executionId).toBeTruthy();
  });


  test("retries only the exact invalid-or-closed transaction transient and replays idempotently", async () => {
    const fixture = fakeAssignmentDb();
    const first = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });
    fixture.failNextTransaction(closedTransactionError());

    const replay = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });

    expect(replay).toMatchObject({
      ok: true,
      idempotentReplay: true,
      executionId: first.executionId,
    });
    expect(fixture.transactionAttempts).toBe(3);
    expect(fixture.store.size).toBeGreaterThan(0);
  });

  test("does not retry unrelated INVALID_ARGUMENT failures", async () => {
    const fixture = fakeAssignmentDb();
    const error = new Error("3 INVALID_ARGUMENT: malformed request");
    error.code = 3;
    error.details = "malformed request";
    fixture.failNextTransaction(error);

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    })).rejects.toBe(error);
    expect(fixture.transactionAttempts).toBe(1);
    expect(fixture.writes).toHaveLength(0);
  });

  test("fails closed after bounded invalid-or-closed transaction retries", async () => {
    const fixture = fakeAssignmentDb();
    for (let index = 0; index < 8; index += 1) {
      fixture.failNextTransaction(closedTransactionError());
    }

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    })).rejects.toMatchObject({
      code: "aborted",
      details: {
        reasonCode: "assignment-transaction-retry-exhausted",
        maximumAttempts: 8,
      },
    });
    expect(fixture.transactionAttempts).toBe(8);
    expect(fixture.writes).toHaveLength(0);
  });

  test("validates UUID and plant asset range before Firestore work", async () => {
    const {db, writes} = fakeAssignmentDb();
    await expect(
      assignPublishedTemplateVersionWithDb({
        db,
        authUid: "supervisor1",
        data: requestFixture({requestId: "not-a-uuid"}),
      }),
    ).rejects.toBeInstanceOf(AssignmentValidationError);
    await expect(
      assignPublishedTemplateVersionWithDb({
        db,
        authUid: "supervisor1",
        data: requestFixture({assetNumber: 999}),
      }),
    ).rejects.toMatchObject({
      code: "invalid-argument",
      details: {reasonCode: "invalid-asset-number"},
    });
    expect(writes).toHaveLength(0);
  });
});
