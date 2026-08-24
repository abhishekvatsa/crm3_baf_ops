const {
  AssignmentValidationError,
  assignmentRequestPayloadFingerprint,
  assignPublishedTemplateVersionWithDb,
  computeTemplateVersionContentHash,
  parsePublishedTemplateAssignmentRequest,
} = require("../lib/publishedTemplateAssignment");

const REQUEST_ID = "11111111-1111-4111-8111-111111111111";
const ANNEALING_CAR_ASSET_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

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

function rehashedVersion(overrides = {}) {
  const version = versionFixture({...overrides, contentHash: null});
  version.contentHash = computeTemplateVersionContentHash(version);
  return version;
}

function customJobSnapshot({
  includeHierarchy = true,
  hierarchyOverrides = {},
} = {}) {
  return JSON.stringify({
    jobName: "Annealing car PM",
    assetType: "governedCustom",
    ...(includeHierarchy ? {
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 2,
        scope: "definition",
        assetClassId: "annealing-car-class",
        assetClassCode: "ANNEALING_CAR",
        assetClassName: "Annealing car",
        nodeId: "car-body",
        nodeVersion: 1,
        nodeName: "Car body",
        assetInstanceId: null,
        assetInstanceVersion: null,
        assetNumber: null,
        assetInstanceName: null,
        componentInstanceId: null,
        componentInstanceVersion: null,
        componentTag: null,
        hierarchyPath: ["Car body"],
        ownershipStatus: "unassigned",
        ownerDiscipline: null,
        accountableRoleKeys: [],
        ...hierarchyOverrides,
      }),
    } : {}),
    composer: {
      closureReviewConfirmed: true,
      closureReviewConfirmedByUid: "si1",
      closureReviewConfirmedByName: "SI User",
      closureReviewConfirmedAt: "2026-06-19T10:00:00.000Z",
    },
    closureCriticalCount: 1,
  });
}

function legacyTypeJobSnapshot(assetType) {
  const snapshot = JSON.parse(versionFixture().jobTemplateSnapshotJson);
  snapshot.assetType = assetType;
  return JSON.stringify(snapshot);
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

function assetInstanceFixture(overrides = {}) {
  return {
    assetInstanceId: ANNEALING_CAR_ASSET_ID,
    assetClassId: "annealing-car-class",
    assetNumber: 3,
    name: "Annealing car 3",
    status: "active",
    isDeleted: false,
    version: 1,
    ...overrides,
  };
}

function assetClassFixture(overrides = {}) {
  return {
    assetClassId: "annealing-car-class",
    code: "ANNEALING_CAR",
    name: "Annealing car",
    legacyAssetTypeKey: null,
    status: "active",
    isDeleted: false,
    version: 1,
    ...overrides,
  };
}

function frozenBaseMaintenanceClass() {
  return {
    schemaVersion: 1,
    definitionId: 'maintenance-class-base',
    definitionVersion: 2,
    code: 'BASE_MAINTENANCE',
    title: 'Base Maintenance',
    assetTypeKeys: ['base'],
    assetClassIds: [],
    resetCounters: [
      {key: 'BASE_MAINTENANCE', label: 'Base maintenance', thresholdDays: 50},
    ],
    principalLaneKey: 'mech',
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
  assetClasses = [assetClassFixture()],
  assetInstances = [assetInstanceFixture()],
  innerCoverAssignments = [],
  innerCoverProfiles = [],
  maintenancePlans = [],
} = {}) {
  const store = new Map();
  const writes = [];
  const queuedTransactionFailures = [];
  let transactionAttempts = 0;
  let queryReads = 0;
  const directReadsByPath = new Map();
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
  assetClasses.forEach((assetClass, index) => {
    const id = assetClass.assetClassId ?? `asset-class-${index + 1}`;
    seed(`asset_classes/${id}`, assetClass);
  });
  assetInstances.forEach((asset, index) => {
    const id = asset.assetInstanceId ?? `asset${index + 1}`;
    seed(`asset_instances/${id}`, asset);
  });
  innerCoverAssignments.forEach((assignment, index) => {
    const id = assignment.baseAssetInstanceId ?? `base-${index + 1}`;
    seed(`base_inner_cover_assignments/${id}`, assignment);
  });
  innerCoverProfiles.forEach((profile, index) => {
    const id = profile.innerCoverId ?? `inner-cover-${index + 1}`;
    seed(`inner_cover_profiles/${id}`, profile);
  });
  maintenancePlans.forEach((plan, index) => {
    const id = plan.planId ?? `plan-${index + 1}`;
    seed(`maintenance_plans/${id}`, plan);
  });

  function docRef(collectionName, id) {
    const resolvedId = id ?? `${collectionName.replaceAll("_", "")}_${++idCounter}`;
    const path = `${collectionName}/${resolvedId}`;
    return {
      id: resolvedId,
      path,
      async get() {
        directReadsByPath.set(path, (directReadsByPath.get(path) ?? 0) + 1);
        const data = store.get(path);
        return {
          exists: data != null,
          id: resolvedId,
          data: () => (data == null ? undefined : structuredClone(data)),
        };
      },
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
        queryReads += 1;
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
    get queryReads() {
      return queryReads;
    },
    directReadCount(path) {
      return directReadsByPath.get(path) ?? 0;
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

  test("request identity is complete and participates in the fingerprint", () => {
    const parsed = parsePublishedTemplateAssignmentRequest(requestFixture({
      assetClassId: "base-class",
      assetInstanceId: "base-101",
    }));
    const direct = assignmentRequestPayloadFingerprint({
      packageId: "pkg1",
      versionId: "ver1",
      expectedVersionNumber: 1,
      expectedContentHash: versionFixture().contentHash,
      assetType: "base",
      assetNumber: 101,
      assetClassId: "base-class",
      assetInstanceId: "base-101",
      chargeNoAtEvent: 12345,
      remarks: "Inspect during planned window.",
    });
    expect(parsed.payloadFingerprint).toBe(direct);
    expect(
      parsePublishedTemplateAssignmentRequest(requestFixture({
        assetClassId: "base-class",
        assetInstanceId: "base-101-other",
      })).payloadFingerprint,
    ).not.toBe(direct);
    expect(() => parsePublishedTemplateAssignmentRequest(requestFixture({
      assetClassId: "base-class",
    }))).toThrow(expect.objectContaining({
      details: expect.objectContaining({
        reasonCode: "assignment-asset-identity-incomplete",
      }),
    }));
  });

  test("source plan identity is complete and participates in the fingerprint", () => {
    const parsed = parsePublishedTemplateAssignmentRequest(requestFixture({
      sourcePlanId: 'plan-base-101',
      sourcePlanExpectedVersion: 3,
    }));
    expect(parsed.payloadFingerprint).not.toBe(
      parsePublishedTemplateAssignmentRequest(requestFixture()).payloadFingerprint,
    );
    expect(() => parsePublishedTemplateAssignmentRequest(requestFixture({
      sourcePlanId: 'plan-base-101',
    }))).toThrow(expect.objectContaining({
      details: expect.objectContaining({
        reasonCode: 'assignment-source-plan-identity-incomplete',
      }),
    }));
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
    expect(result.execution.isCompleted).toBe(false);
    expect(result.execution.isCancelled).toBe(false);
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

  test("atomically releases a matching ready maintenance plan and replays once", async () => {
    const classification = frozenBaseMaintenanceClass();
    const versionData = rehashedVersion({
      metadataJson: JSON.stringify({maintenanceClassification: classification}),
    });
    const fixture = fakeAssignmentDb({
      versionData,
      audits: [auditFixture({afterHash: versionData.contentHash})],
      assetClasses: [assetClassFixture({
        assetClassId: 'base-class',
        code: 'BASE',
        name: 'Base',
        legacyAssetTypeKey: 'base',
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: 'base-101',
        assetClassId: 'base-class',
        assetNumber: 101,
        name: 'Base 101',
      })],
      maintenancePlans: [{
        schemaVersion: 2,
        planId: 'plan-base-101',
        version: 3,
        status: 'ready',
        assetIdentityKey: 'base-class:base-101',
        assetTypeKey: 'base',
        assetNumber: 101,
        assetClassId: 'base-class',
        assetInstanceId: 'base-101',
        assetInstanceVersion: 1,
        assetInstanceName: 'Base 101',
        maintenanceClassDefinitionId: classification.definitionId,
        maintenanceClassDefinitionVersion: classification.definitionVersion,
        maintenanceClass: classification,
        templatePackageId: null,
        templateVersionId: null,
        templateContentHash: null,
      }],
    });
    const request = requestFixture({
      expectedContentHash: versionData.contentHash,
      assetClassId: 'base-class',
      assetInstanceId: 'base-101',
      sourcePlanId: 'plan-base-101',
      sourcePlanExpectedVersion: 3,
    });

    const first = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: 'supervisor1',
      data: request,
      now: () => new Date('2026-06-19T11:00:00.000Z'),
    });
    expect(first.idempotentReplay).toBe(false);
    expect(first.execution).toMatchObject({
      sourceMaintenancePlanId: 'plan-base-101',
      sourceMaintenancePlanVersion: 3,
    });
    expect(fixture.store.get('maintenance_plans/plan-base-101')).toMatchObject({
      status: 'released',
      version: 4,
      releasedExecutionId: first.executionId,
    });
    expect(fixture.store.get(
      `maintenance_plan_audits/assignment_${REQUEST_ID}`,
    )).toMatchObject({
      operation: 'release-to-governed-assignment',
      planId: 'plan-base-101',
    });
    expect(fixture.writes).toHaveLength(7);

    const replay = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: 'supervisor1',
      data: request,
      now: () => new Date('2026-06-19T11:01:00.000Z'),
    });
    expect(replay).toMatchObject({
      idempotentReplay: true,
      executionId: first.executionId,
    });
    expect(fixture.writes).toHaveLength(7);
  });

  test("rejects release when the planned asset version is stale", async () => {
    const classification = frozenBaseMaintenanceClass();
    const versionData = rehashedVersion({
      metadataJson: JSON.stringify({maintenanceClassification: classification}),
    });
    const fixture = fakeAssignmentDb({
      versionData,
      audits: [auditFixture({afterHash: versionData.contentHash})],
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-101",
        assetClassId: "base-class",
        assetNumber: 101,
        name: "Base 101",
        version: 2,
      })],
      maintenancePlans: [{
        schemaVersion: 2,
        planId: "plan-base-101",
        version: 3,
        status: "ready",
        assetIdentityKey: "base-class:base-101",
        assetTypeKey: "base",
        assetNumber: 101,
        assetClassId: "base-class",
        assetInstanceId: "base-101",
        assetInstanceVersion: 1,
        assetInstanceName: "Base 101",
        maintenanceClassDefinitionId: classification.definitionId,
        maintenanceClassDefinitionVersion: classification.definitionVersion,
        maintenanceClass: classification,
        templatePackageId: null,
        templateVersionId: null,
        templateContentHash: null,
      }],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: versionData.contentHash,
        assetClassId: "base-class",
        assetInstanceId: "base-101",
        sourcePlanId: "plan-base-101",
        sourcePlanExpectedVersion: 3,
      }),
    })).rejects.toMatchObject({
      details: {reasonCode: "assignment-source-plan-mismatch"},
    });
    expect(fixture.writes).toHaveLength(0);
  });

  test("binds a legacy-type assignment to the selected governed physical asset", async () => {
    const fixture = fakeAssignmentDb({
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-101",
        assetClassId: "base-class",
        assetNumber: 101,
        name: "Base 101",
      })],
    });

    const result = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        assetClassId: "base-class",
        assetInstanceId: "base-101",
      }),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });

    expect(result.execution).toMatchObject({
      assetType: "base",
      assetNumber: 101,
      assetClassId: "base-class",
      assetInstanceId: "base-101",
    });
    expect(JSON.parse(result.execution.metadataJson).assignmentAssetIdentity)
      .toEqual({
        assetClassId: "base-class",
        assetInstanceId: "base-101",
        assetNumber: 101,
      });
    expect(
      fixture.store.get(`maintenance_workflows/${result.executionId}`),
    ).toMatchObject({
      assetClassId: "base-class",
      assetInstanceId: "base-101",
    });
    expect(fixture.store.get("equipment_status/base_101")).toMatchObject({
      assetClassId: "base-class",
      assetInstanceId: "base-101",
    });
  });

  test("upgrades a complete legacy projection to exact governed identity", async () => {
    const fixture = fakeAssignmentDb({
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-101",
        assetClassId: "base-class",
        assetNumber: 101,
        name: "Base 101",
      })],
      workflows: [workflowFixture()],
      equipmentData: {
        assetTypeKey: "base",
        assetNumber: 101,
        state: "underMaintenance",
        activeNonRedMaintenanceCount: 1,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 2,
      },
    });

    await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        assetClassId: "base-class",
        assetInstanceId: "base-101",
      }),
    });

    expect(fixture.store.get("equipment_status/base_101")).toMatchObject({
      assetClassId: "base-class",
      assetInstanceId: "base-101",
      activeNonRedMaintenanceCount: 2,
      version: 3,
    });
  });

  test("rejects a partially populated legacy projection during identity upgrade", async () => {
    const fixture = fakeAssignmentDb({
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-101",
        assetClassId: "base-class",
        assetNumber: 101,
        name: "Base 101",
      })],
      equipmentData: {
        assetTypeKey: "base",
        assetNumber: 101,
        assetClassId: "base-class",
        state: "inService",
        activeNonRedMaintenanceCount: 0,
        activeRedWorkCount: 0,
        awaitingPreparationCount: 0,
        version: 2,
      },
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        assetClassId: "base-class",
        assetInstanceId: "base-101",
      }),
    })).rejects.toMatchObject({
      details: expect.objectContaining({
        reasonCode: "equipment-projection-identity-mismatch",
      }),
    });
    expect(fixture.writes).toHaveLength(0);
  });

  test("rejects an exact assignment when the physical asset is not in the selected class", async () => {
    const fixture = fakeAssignmentDb({
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-101",
        assetClassId: "other-class",
        assetNumber: 101,
        name: "Wrong Base 101",
      })],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        assetClassId: "base-class",
        assetInstanceId: "base-101",
      }),
    })).rejects.toMatchObject({
      details: expect.objectContaining({
        reasonCode: "custom-asset-instance-invalid",
      }),
    });
    expect(fixture.writes).toHaveLength(0);
  });

  test("fails closed when a matching legacy asset class row is malformed", async () => {
    const fixture = fakeAssignmentDb({
      assetClasses: [
        assetClassFixture({
          assetClassId: "base-class",
          code: "BASE",
          name: "Base",
          legacyAssetTypeKey: "base",
        }),
        assetClassFixture({
          assetClassId: "malformed-base-class",
          code: "BASE_MALFORMED",
          name: "Malformed Base",
          legacyAssetTypeKey: "base",
          status: "unknown",
        }),
      ],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-101",
        assetClassId: "base-class",
        assetNumber: 101,
        name: "Base 101",
      })],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        assetClassId: "base-class",
        assetInstanceId: "base-101",
      }),
    })).rejects.toMatchObject({
      details: expect.objectContaining({
        reasonCode: "assignment-asset-class-invalid",
      }),
    });
    expect(fixture.writes).toHaveLength(0);
  });

  test("binds Inner Cover planned work to the selected Base position", async () => {
    const version = rehashedVersion({
      jobTemplateSnapshotJson: legacyTypeJobSnapshot("innerCover"),
    });
    const fixture = fakeAssignmentDb({
      versionData: version,
      audits: [auditFixture({afterHash: version.contentHash})],
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-201",
        assetClassId: "base-class",
        assetNumber: 201,
        name: "Base 201",
      })],
      innerCoverAssignments: [{
        schemaVersion: 1,
        baseAssetInstanceId: "base-201",
        baseAssetClassId: "base-class",
        baseAssetNumber: 201,
        baseAssetName: "Base 201",
        innerCoverId: "inner-cover-gr26",
        innerCoverSerialNumber: "GR26",
        linkageId: "linkage-gr26-base201",
        linkedAt: "2026-08-15T06:00:00.000Z",
        version: 3,
        updatedAt: "2026-08-15T06:00:00.000Z",
        lastMutationId: "mutation-gr26-base201",
      }],
      innerCoverProfiles: [{
        schemaVersion: 1,
        innerCoverId: "inner-cover-gr26",
        serialNumber: "GR26",
        lifecycleState: "installed",
        currentBaseAssetInstanceId: "base-201",
        currentBaseAssetNumber: 201,
        currentLinkageId: "linkage-gr26-base201",
      }],
    });

    const result = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: version.contentHash,
        assetType: "innerCover",
        assetNumber: 201,
        assetClassId: "base-class",
        assetInstanceId: "base-201",
      }),
    });

    expect(result.execution).toMatchObject({
      assetType: "innerCover",
      assetNumber: 201,
      assetClassId: "base-class",
      assetInstanceId: "base-201",
      metadataJson: expect.stringContaining(
        '"innerCoverSerialNumber":"GR26"',
      ),
    });
    expect(
      fixture.store.get(`maintenance_workflows/${result.executionId}`),
    ).toMatchObject({
      assetTypeKey: "innerCover",
      assetNumber: 201,
      assetClassId: "base-class",
      assetInstanceId: "base-201",
      innerCoverId: "inner-cover-gr26",
      innerCoverSerialNumber: "GR26",
      innerCoverLinkageId: "linkage-gr26-base201",
      innerCoverAssignmentVersion: 3,
    });
  });

  test("rejects an Inner Cover swap that races assignment", async () => {
    const version = rehashedVersion({
      jobTemplateSnapshotJson: legacyTypeJobSnapshot("innerCover"),
    });
    const assignment = {
      schemaVersion: 1,
      baseAssetInstanceId: "base-201",
      baseAssetClassId: "base-class",
      baseAssetNumber: 201,
      baseAssetName: "Base 201",
      innerCoverId: "inner-cover-gr26",
      innerCoverSerialNumber: "GR26",
      linkageId: "linkage-gr26-base201",
      linkedAt: "2026-08-15T06:00:00.000Z",
      version: 3,
      updatedAt: "2026-08-15T06:00:00.000Z",
      lastMutationId: "mutation-gr26-base201",
    };
    const fixture = fakeAssignmentDb({
      versionData: version,
      audits: [auditFixture({afterHash: version.contentHash})],
      assetClasses: [assetClassFixture({
        assetClassId: "base-class",
        code: "BASE",
        name: "Base",
        legacyAssetTypeKey: "base",
      })],
      assetInstances: [assetInstanceFixture({
        assetInstanceId: "base-201",
        assetClassId: "base-class",
        assetNumber: 201,
        name: "Base 201",
      })],
      innerCoverAssignments: [assignment],
      innerCoverProfiles: [{
        schemaVersion: 1,
        innerCoverId: "inner-cover-gr26",
        serialNumber: "GR26",
        lifecycleState: "installed",
        currentBaseAssetInstanceId: "base-201",
        currentBaseAssetNumber: 201,
        currentLinkageId: "linkage-gr26-base201",
      }],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: version.contentHash,
        assetType: "innerCover",
        assetNumber: 201,
        assetClassId: "base-class",
        assetInstanceId: "base-201",
      }),
      beforeAssignmentTransactionForTest: async () => {
        fixture.store.set("base_inner_cover_assignments/base-201", {
          ...assignment,
          innerCoverId: "inner-cover-gr27",
          innerCoverSerialNumber: "GR27",
          linkageId: "linkage-gr27-base201",
          version: 4,
        });
        fixture.store.set("inner_cover_profiles/inner-cover-gr27", {
          schemaVersion: 1,
          innerCoverId: "inner-cover-gr27",
          serialNumber: "GR27",
          lifecycleState: "installed",
          currentBaseAssetInstanceId: "base-201",
          currentBaseAssetNumber: 201,
          currentLinkageId: "linkage-gr27-base201",
        });
      },
    })).rejects.toMatchObject({
      details: expect.objectContaining({
        reasonCode: "inner-cover-assignment-changed",
      }),
    });
    expect(fixture.writes).toHaveLength(0);
  });

  test("binds governed custom assignment to its published hierarchy identity", async () => {
    const version = rehashedVersion({
      jobTemplateSnapshotJson: customJobSnapshot(),
    });
    const {db, store} = fakeAssignmentDb({
      versionData: version,
      audits: [auditFixture({afterHash: version.contentHash})],
    });

    const result = await assignPublishedTemplateVersionWithDb({
      db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: version.contentHash,
        assetType: "governedCustom",
        assetNumber: 3,
      }),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });

    const metadata = JSON.parse(result.execution.metadataJson);
    const snapshot = metadata.jobTemplateSnapshot;
    const hierarchy = JSON.parse(snapshot.assetHierarchyRefJson);
    expect(result.execution.assetType).toBe("governedCustom");
    expect(result.execution.assetNumber).toBe(3);
    expect(result.execution.assetClassId).toBe("annealing-car-class");
    expect(result.execution.assetInstanceId).toBe(ANNEALING_CAR_ASSET_ID);
    expect(hierarchy.assetClassId).toBe("annealing-car-class");
    expect(
      store.get(`maintenance_workflows/${result.executionId}`),
    ).toMatchObject({
      assetClassId: "annealing-car-class",
      assetInstanceId: ANNEALING_CAR_ASSET_ID,
    });
    expect(
      store.get(
        `equipment_status/governedCustom_annealing-car-class_${ANNEALING_CAR_ASSET_ID}`,
      ),
    ).toMatchObject({
      assetClassId: "annealing-car-class",
      assetInstanceId: ANNEALING_CAR_ASSET_ID,
      activeNonRedMaintenanceCount: 1,
    });
  });

  test("isolates governed custom projections when classes share an asset number", async () => {
    const otherAssetId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
    const version = rehashedVersion({
      jobTemplateSnapshotJson: customJobSnapshot(),
    });
    const fixture = fakeAssignmentDb({
      versionData: version,
      audits: [auditFixture({afterHash: version.contentHash})],
      assetInstances: [
        assetInstanceFixture(),
        assetInstanceFixture({
          assetInstanceId: otherAssetId,
          assetClassId: "transfer-car-class",
          name: "Transfer car 3",
        }),
      ],
      workflows: [workflowFixture({
        firestoreId: "other-class-workflow",
        assetTypeKey: "governedCustom",
        assetNumber: 3,
        assetClassId: "transfer-car-class",
        assetInstanceId: otherAssetId,
      })],
    });
    const otherProjectionPath =
      `equipment_status/governedCustom_transfer-car-class_${otherAssetId}`;
    fixture.store.set(otherProjectionPath, {
      assetTypeKey: "governedCustom",
      assetNumber: 3,
      assetClassId: "transfer-car-class",
      assetInstanceId: otherAssetId,
      state: "underMaintenance",
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 2,
    });

    const result = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: version.contentHash,
        assetType: "governedCustom",
        assetNumber: 3,
      }),
    });

    expect(
      fixture.store.get(
        `equipment_status/governedCustom_annealing-car-class_${ANNEALING_CAR_ASSET_ID}`,
      ),
    ).toMatchObject({
      activeNonRedMaintenanceCount: 1,
      assetClassId: "annealing-car-class",
      assetInstanceId: ANNEALING_CAR_ASSET_ID,
    });
    expect(fixture.store.get(otherProjectionPath)).toMatchObject({
      activeNonRedMaintenanceCount: 1,
      version: 2,
    });
    expect(
      fixture.store.get(`maintenance_workflows/${result.executionId}`),
    ).toMatchObject({
      assetClassId: "annealing-car-class",
      assetInstanceId: ANNEALING_CAR_ASSET_ID,
    });
  });

  test("fails closed on an unbound legacy custom workflow with the same number", async () => {
    const version = rehashedVersion({
      jobTemplateSnapshotJson: customJobSnapshot(),
    });
    const fixture = fakeAssignmentDb({
      versionData: version,
      audits: [auditFixture({afterHash: version.contentHash})],
      workflows: [workflowFixture({
        assetTypeKey: "governedCustom",
        assetNumber: 3,
      })],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: version.contentHash,
        assetType: "governedCustom",
        assetNumber: 3,
      }),
    })).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode: "custom-workflow-identity-incomplete"},
    });
    expect(fixture.writes).toHaveLength(0);
  });

  test("rejects custom assignment without hierarchy identity or with a mismatched snapshot type", async () => {
    const missingHierarchy = rehashedVersion({
      jobTemplateSnapshotJson: customJobSnapshot({includeHierarchy: false}),
    });
    const missingDb = fakeAssignmentDb({
      versionData: missingHierarchy,
      audits: [auditFixture({afterHash: missingHierarchy.contentHash})],
    });
    await expect(assignPublishedTemplateVersionWithDb({
      db: missingDb.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: missingHierarchy.contentHash,
        assetType: "governedCustom",
        assetNumber: 3,
      }),
    })).rejects.toMatchObject({
      details: {reasonCode: "custom-snapshot-hierarchy-reference-missing"},
    });
    expect(missingDb.writes).toHaveLength(0);

    const mismatched = rehashedVersion({
      jobTemplateSnapshotJson: customJobSnapshot(),
    });
    const mismatchDb = fakeAssignmentDb({
      versionData: mismatched,
      audits: [auditFixture({afterHash: mismatched.contentHash})],
    });
    await expect(assignPublishedTemplateVersionWithDb({
      db: mismatchDb.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: mismatched.contentHash,
        assetType: "base",
      }),
    })).rejects.toMatchObject({
      details: {reasonCode: "assignment-asset-type-mismatch"},
    });
    expect(mismatchDb.writes).toHaveLength(0);
  });

  test.each([
    ["missing schema-v2 scope", {scope: undefined}],
    ["missing ownership state", {ownershipStatus: undefined}],
    ["contradictory ownership", {
      ownershipStatus: "confirmed",
      ownerDiscipline: null,
      accountableRoleKeys: [],
    }],
    ["malformed accountable roles", {accountableRoleKeys: [4]}],
    ["incomplete installed identity", {
      scope: "installedComponent",
      ownershipStatus: "confirmed",
      ownerDiscipline: "mechanical",
      accountableRoleKeys: ["seniorMechanical"],
    }],
  ])("rejects custom hierarchy reference with %s", async (_, hierarchyOverrides) => {
    const version = rehashedVersion({
      jobTemplateSnapshotJson: customJobSnapshot({hierarchyOverrides}),
    });
    const fake = fakeAssignmentDb({
      versionData: version,
      audits: [auditFixture({afterHash: version.contentHash})],
    });

    await expect(assignPublishedTemplateVersionWithDb({
      db: fake.db,
      authUid: "supervisor1",
      data: requestFixture({
        expectedContentHash: version.contentHash,
        assetType: "governedCustom",
        assetNumber: 3,
      }),
    })).rejects.toMatchObject({
      details: {reasonCode: "custom-snapshot-hierarchy-reference-invalid"},
    });
    expect(fake.writes).toHaveLength(0);
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
    const fixture = fakeAssignmentDb();
    const receiptPath =
      `published_template_assignment_requests/${REQUEST_ID}`;
    const first = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });
    const writeCount = fixture.writes.length;
    const queryReadCount = fixture.queryReads;
    const transactionAttemptCount = fixture.transactionAttempts;
    const receiptReadCount = fixture.directReadCount(receiptPath);

    const replay = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T12:00:00.000Z"),
    });

    expect(replay.idempotentReplay).toBe(true);
    expect(replay.executionId).toBe(first.executionId);
    expect(replay.modules.map((module) => module.firestoreId)).toEqual(
      first.modules.map((module) => module.firestoreId),
    );
    expect(fixture.directReadCount(receiptPath)).toBe(receiptReadCount + 1);
    expect(fixture.queryReads).toBe(queryReadCount);
    expect(fixture.transactionAttempts).toBe(transactionAttemptCount + 1);
    expect(fixture.writes).toHaveLength(writeCount);
  });

  test("replay fails closed when assignment timestamp evidence is absent or corrupt", async () => {
    const fixture = fakeAssignmentDb();
    const first = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
      now: () => new Date("2026-06-19T11:00:00.000Z"),
    });
    const receiptPath =
      `published_template_assignment_requests/${REQUEST_ID}`;
    const executionPath = `job_executions/${first.executionId}`;
    const receipt = fixture.store.get(receiptPath);
    const execution = fixture.store.get(executionPath);

    fixture.store.set(receiptPath, {...receipt, assignedAt: null});
    fixture.store.set(executionPath, {...execution, createdAt: null});
    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    })).rejects.toMatchObject({
      code: "data-loss",
      details: {reasonCode: "request-assigned-at-missing"},
    });

    fixture.store.set(receiptPath, {...receipt, assignedAt: "not-a-date"});
    fixture.store.set(executionPath, execution);
    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    })).rejects.toMatchObject({
      code: "data-loss",
      details: {
        reasonCode: "request-assigned-at-invalid",
        source: "receipt",
      },
    });

    fixture.store.set(receiptPath, {
      ...receipt,
      assignedAt: "2026-06-19T11:00:01.000Z",
    });
    fixture.store.set(executionPath, execution);
    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    })).rejects.toMatchObject({
      code: "data-loss",
      details: {reasonCode: "request-assigned-at-mismatch"},
    });

    fixture.store.set(receiptPath, {...receipt, assignedAt: 20260619});
    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    })).rejects.toMatchObject({
      code: "data-loss",
      details: {
        reasonCode: "request-assigned-at-invalid",
        source: "receipt",
      },
    });
  });

  test("same request ID with changed assignment meaning is rejected without writes", async () => {
    const fixture = fakeAssignmentDb();
    await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });
    const writeCount = fixture.writes.length;
    const queryReadCount = fixture.queryReads;

    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture({assetNumber: 102}),
      }),
    ).rejects.toMatchObject({
      code: "already-exists",
      details: {reasonCode: "request-payload-mismatch"},
    });
    expect(fixture.queryReads).toBe(queryReadCount);
    expect(fixture.writes).toHaveLength(writeCount);
  });

  test("receipt created after an absent preflight replays without duplicate writes", async () => {
    const fixture = fakeAssignmentDb();
    let concurrentResult = null;

    const replay = await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
      beforeAssignmentTransactionForTest: async () => {
        concurrentResult = await assignPublishedTemplateVersionWithDb({
          db: fixture.db,
          authUid: "supervisor1",
          data: requestFixture(),
        });
      },
    });

    expect(concurrentResult).toMatchObject({
      ok: true,
      idempotentReplay: false,
    });
    expect(replay).toMatchObject({
      ok: true,
      idempotentReplay: true,
      executionId: concurrentResult.executionId,
    });
    expect(
      [...fixture.store.keys()].filter((path) =>
        path.startsWith("job_executions/"),
      ),
    ).toHaveLength(1);
    expect(
      [...fixture.store.keys()].filter((path) =>
        path.startsWith("job_modules/"),
      ),
    ).toHaveLength(1);
  });

  test("receipt observed during preflight fails closed if it disappears", async () => {
    const fixture = fakeAssignmentDb();
    const receiptPath =
      `published_template_assignment_requests/${REQUEST_ID}`;
    await assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
    });
    const queryReadCount = fixture.queryReads;
    const writeCount = fixture.writes.length;

    await expect(assignPublishedTemplateVersionWithDb({
      db: fixture.db,
      authUid: "supervisor1",
      data: requestFixture(),
      beforeAssignmentTransactionForTest: async () => {
        fixture.store.delete(receiptPath);
      },
    })).rejects.toMatchObject({
      code: "aborted",
      details: {reasonCode: "request-receipt-disappeared"},
    });

    expect(fixture.queryReads).toBe(queryReadCount);
    expect(fixture.writes).toHaveLength(writeCount);
    expect(
      [...fixture.store.keys()].filter((path) =>
        path.startsWith("job_executions/"),
      ),
    ).toHaveLength(1);
  });

  test("rejects unauthorized and unapproved users before writes", async () => {
    const fixture = fakeAssignmentDb({
      user: {isApproved: true, roles: ["operations"], name: "Operations"},
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: fixture.db,
        authUid: "supervisor1",
        data: requestFixture(),
      }),
    ).rejects.toMatchObject({code: "permission-denied"});
    expect(
      fixture.directReadCount(
        `published_template_assignment_requests/${REQUEST_ID}`,
      ),
    ).toBe(0);
    expect(fixture.queryReads).toBe(0);
    expect(fixture.transactionAttempts).toBe(0);
    expect(fixture.writes).toHaveLength(0);
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

    const invalidFieldTypeVersion = versionFixture({
      fieldDefinitionsJson: JSON.stringify([
        {
          moduleCode: "M-01",
          key: "vibration",
          label: "Vibration",
          type: "telepathy",
        },
      ]),
    });
    invalidFieldTypeVersion.contentHash = computeTemplateVersionContentHash(
      invalidFieldTypeVersion,
    );
    const invalidFieldTypeDb = fakeAssignmentDb({
      versionData: invalidFieldTypeVersion,
      audits: [auditFixture({afterHash: invalidFieldTypeVersion.contentHash})],
    });
    await expect(
      assignPublishedTemplateVersionWithDb({
        db: invalidFieldTypeDb.db,
        authUid: "supervisor1",
        data: requestFixture({
          expectedContentHash: invalidFieldTypeVersion.contentHash,
        }),
      }),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {reasonCode: "field-definition-payload-invalid"},
    });
    expect(invalidFieldTypeDb.writes).toHaveLength(0);

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
