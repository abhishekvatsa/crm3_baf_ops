const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const at = (value) => new Date(value);

const persistedTimestamp = (value) => {
  const millis = Date.parse(value);
  return {
    _seconds: Math.floor(millis / 1000),
    _nanoseconds: (millis % 1000) * 1000000,
  };
};

const seedActor = (store, uid, roles) => {
  store.seed(`users/${uid}`, {isApproved: true, roles, name: uid});
  return {uid, name: uid};
};

const assetReference = ({
  classId,
  code,
  className,
  assetId,
  assetNumber,
  assetName,
  innerCoverAssociation = null,
}) => JSON.stringify({
  schemaVersion: 3,
  scope: 'physicalAsset',
  assetClassId: classId,
  assetClassCode: code,
  assetClassName: className,
  nodeId: assetId,
  nodeVersion: 1,
  nodeName: assetName,
  assetInstanceId: assetId,
  assetInstanceVersion: 1,
  assetNumber,
  assetInstanceName: assetName,
  componentInstanceId: null,
  componentInstanceVersion: null,
  componentTag: null,
  hierarchyPath: [className, assetName],
  ownershipStatus: 'unassigned',
  ownerDiscipline: null,
  accountableRoleKeys: [],
  innerCoverAssociation,
});

const linkedInnerCoverReference = () => ({
  baseAssetInstanceId: 'base-117',
  baseAssetNumber: 117,
  positionState: 'linked',
  innerCoverId: 'inner-gr26',
  innerCoverSerialNumber: 'GR26',
  linkageId: 'link-gr26-base-117',
  assignmentVersion: 3,
  linkedAt: '2026-08-01T04:00:00.000Z',
  eventAt: '2026-08-20T04:00:00.000Z',
  confirmedAt: '2026-08-20T04:04:00.000Z',
  confirmedByUid: 'operations-1',
  confirmedByName: 'operations-1',
});

const seedAssets = (store) => {
  store.seed('asset_classes/base-class', {
    schemaVersion: 1,
    assetClassId: 'base-class',
    code: 'BASE',
    name: 'Base',
    legacyAssetTypeKey: 'base',
    status: 'active',
  });
  store.seed('asset_classes/furnace-class', {
    schemaVersion: 1,
    assetClassId: 'furnace-class',
    code: 'FURNACE',
    name: 'Furnace',
    legacyAssetTypeKey: 'furnace',
    status: 'active',
  });
  store.seed('asset_instances/base-117', {
    schemaVersion: 1,
    assetInstanceId: 'base-117',
    assetClassId: 'base-class',
    assetClassCode: 'BASE',
    assetClassName: 'Base',
    assetNumber: 117,
    name: 'Base 117',
    status: 'active',
    version: 1,
    ownershipStatus: 'unassigned',
    ownerDiscipline: null,
    accountableRoleKeys: [],
  });
  store.seed('asset_instances/furnace-12', {
    schemaVersion: 1,
    assetInstanceId: 'furnace-12',
    assetClassId: 'furnace-class',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 12,
    name: 'Furnace 12',
    status: 'active',
    version: 1,
    ownershipStatus: 'unassigned',
    ownerDiscipline: null,
    accountableRoleKeys: [],
  });
  store.seed('base_inner_cover_assignments/base-117', {
    schemaVersion: 1,
    baseAssetInstanceId: 'base-117',
    baseAssetClassId: 'base-class',
    baseAssetNumber: 117,
    innerCoverId: 'inner-gr26',
    innerCoverSerialNumber: 'GR26',
    linkageId: 'link-gr26-base-117',
    linkedAt: '2026-08-01T04:00:00.000Z',
    version: 3,
  });
  store.seed('inner_cover_profiles/inner-gr26', {
    schemaVersion: 1,
    innerCoverId: 'inner-gr26',
    serialNumber: 'GR26',
    lifecycleState: 'installed',
    currentBaseAssetInstanceId: 'base-117',
    currentBaseAssetNumber: 117,
    currentLinkageId: 'link-gr26-base-117',
  });
};

const createCommand = (ticketId = 'stuckup-case-1') => ({
  commandId: `createMaintenanceTicket_${ticketId}`,
  commandType: 'createMaintenanceTicket',
  aggregateId: ticketId,
  expectedVersion: 0,
  payload: {
    ticket: {
      schemaVersion: 1,
      version: 1,
      assetType: 'furnace',
      assetNumber: 12,
      component: 'Furnace / Inner Cover interface',
      subsystem: 'Furnace positioning and sealing',
      tag: null,
      hierarchyPath: ['Furnace', 'Furnace positioning and sealing'],
      assetHierarchyRefJson: assetReference({
        classId: 'furnace-class',
        code: 'FURNACE',
        className: 'Furnace',
        assetId: 'furnace-12',
        assetNumber: 12,
        assetName: 'Furnace 12',
      }),
      maintenanceType: 'breakdown',
      classification: 'furnaceStuckup',
      description: 'Furnace remains stuck on the Base during post-annealing removal.',
      routedTo: 'mechanical',
      otherDepartment: null,
      isCritical: true,
      startDate: '2026-08-20T04:00:00.000Z',
      chargeNoAtEvent: 12345,
      qualityIntentSchemaVersion: 1,
      qualityImpactAssessment: 'notSuspected',
      qualityWarningReason: null,
      furnaceStuckupSchemaVersion: 1,
      stuckupBaseNumber: 117,
      stuckupBaseAssetRefJson: assetReference({
        classId: 'base-class',
        code: 'BASE',
        className: 'Base',
        assetId: 'base-117',
        assetNumber: 117,
        assetName: 'Base 117',
        innerCoverAssociation: linkedInnerCoverReference(),
      }),
      stuckupSuspectedCause: 'innerCoverBulging',
      stuckupOperatingContext: 'postAnnealingRemoval',
    },
  },
});

describe('Furnace stuck-up governed lifecycle', () => {
  test.each(['operations', 'admin', 'si', 'contractSupervisor', 'shiftSupervisor'])(
    '%s confirms physical removal without closing maintenance or adjudicating cause',
    async (role) => {
      const store = new MemoryWorkflowStore();
      seedAssets(store);
      const operations = seedActor(store, 'operations-1', ['operations']);
      const actor = seedActor(store, 'removal-witness', [role]);
      const service = new MaintenanceWorkflowCommandService(store);
      await service.execute(createCommand(), {
        actor: operations,
        serverNow: at('2026-08-20T04:05:00Z'),
      });
      for (const [assetId, condition] of [['base-117', 'down'], ['furnace-12', 'unfit']]) {
        store.seed(`asset_operational_conditions/${assetId}`, {
          schemaVersion: 1,
          assetInstanceId: assetId,
          condition,
          active: true,
          reason: 'Separate plant-condition declaration pending maintenance.',
          version: 1,
        });
      }
      const unrelatedPaths = [
        'maintenance_tickets/stuckup-case-1',
        'base_inner_cover_assignments/base-117',
        'inner_cover_profiles/inner-gr26',
        'asset_operational_conditions/base-117',
        'asset_operational_conditions/furnace-12',
      ];
      const before = unrelatedPaths.map((path) => store.read(path));
      const release = {
        commandId: 'operations-removal',
        commandType: 'releaseFurnaceStuckup',
        aggregateId: 'stuckup-case-1',
        expectedVersion: 1,
        payload: {releaseNotes: 'Furnace lifted clear of Base 117.'},
      };
      const receipt = await service.execute(release, {
        actor: {...actor, name: 'Untrusted caller name'},
        serverNow: at('2026-08-20T05:00:00Z'),
      });
      expect(receipt).toMatchObject({
        resultKey: 'furnace-stuckup-released',
        aggregateVersion: 2,
      });
      expect(store.read('furnace_stuckup_cases/stuckup-case-1')).toMatchObject({
        obstructionStatus: 'released',
        adjudicationStatus: 'pending',
        confirmedCause: null,
        releasedByUid: actor.uid,
        releasedByName: actor.name,
        releasedAt: '2026-08-20T05:00:00.000Z',
        releaseNotes: release.payload.releaseNotes,
        version: 2,
      });
      for (const assetId of ['base-117', 'furnace-12']) {
        expect(store.read(`asset_availability_current/${assetId}`)).toMatchObject({
          availabilityState: 'clear',
          activeConstraintId: null,
          updatedByUid: actor.uid,
        });
        expect(store.read(
          `asset_availability_constraints/stuckup-case-1_${assetId}`,
        )).toMatchObject({
          status: 'released',
          releasedAt: '2026-08-20T05:00:00.000Z',
          releasedByUid: actor.uid,
        });
      }
      expect(unrelatedPaths.map((path) => store.read(path))).toEqual(before);
      expect(store.read('asset_condition_declarations/inner_cover_bulged_inner-gr26'))
        .toBeNull();
      expect(store.read(`audit_logs/${receipt.result.auditId}`)).toMatchObject({
        performedByUid: actor.uid,
        performedByName: actor.name,
        timestamp: '2026-08-20T05:00:00.000Z',
        operation: 'releaseFurnaceStuckup',
      });
      const after = store.entries();
      await expect(service.execute(release, {
        actor,
        serverNow: at('2026-08-20T05:01:00Z'),
      })).resolves.toEqual(receipt);
      expect(store.entries()).toEqual(after);
      await expect(service.execute({...release, commandId: 'stale-second-removal'}, {
        actor,
        serverNow: at('2026-08-20T05:02:00Z'),
      })).rejects.toMatchObject({code: 'workflow-version-conflict'});
      expect(store.entries()).toEqual(after);

      store.seed(`users/${actor.uid}`, {name: actor.name, roles: [role], isApproved: false});
      const revoked = store.entries();
      await expect(service.execute(release, {
        actor,
        serverNow: at('2026-08-20T05:03:00Z'),
      })).rejects.toMatchObject({code: 'permission-denied'});
      expect(store.entries()).toEqual(revoked);
    },
  );

  test.each([
    ['seniorMechanical', true],
    ['seniorElectrical', true],
    ['seniorInstrumentation', true],
    ['seniorRefractory', true],
    ['refractory', true],
    ['operations', false],
  ])('%s approval=%s cannot bypass removal authority', async (role, isApproved) => {
    const store = new MemoryWorkflowStore();
    seedAssets(store);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(createCommand(), {
      actor: operations,
      serverNow: at('2026-08-20T04:05:00Z'),
    });
    const actor = seedActor(store, 'restricted-witness', [role]);
    store.seed(`users/${actor.uid}`, {name: actor.name, roles: [role], isApproved});
    const before = store.entries();
    await expect(service.execute({
      commandId: 'unauthorized-removal',
      commandType: 'releaseFurnaceStuckup',
      aggregateId: 'stuckup-case-1',
      expectedVersion: 1,
      payload: {releaseNotes: 'Furnace lifted clear.'},
    }, {
      actor,
      serverNow: at('2026-08-20T05:00:00Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.entries()).toEqual(before);
  });

  test('creates, releases and adjudicates distinct incident and condition evidence', async () => {
    const store = new MemoryWorkflowStore();
    seedAssets(store);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const supervisor = seedActor(store, 'supervisor-1', ['contractSupervisor']);
    const si = seedActor(store, 'si-1', ['si']);
    const service = new MaintenanceWorkflowCommandService(store);
    const create = createCommand();

    const created = await service.execute(create, {
      actor: operations,
      serverNow: at('2026-08-20T04:05:00Z'),
    });
    expect(created.result).toMatchObject({
      ticketId: 'stuckup-case-1',
      stuckupCaseId: 'stuckup-case-1',
    });
    expect(store.read('furnace_stuckup_cases/stuckup-case-1')).toMatchObject({
      obstructionStatus: 'active',
      adjudicationStatus: 'pending',
      baseAssetNumber: 117,
      furnaceAssetNumber: 12,
      innerCoverId: 'inner-gr26',
      innerCoverSerialNumber: 'GR26',
      suspectedCause: 'innerCoverBulging',
      version: 1,
    });
    expect(store.read('asset_availability_current/base-117')).toMatchObject({
      availabilityState: 'temporarilyBlocked',
      linkedCaseId: 'stuckup-case-1',
    });
    expect(store.read('asset_availability_current/furnace-12')).toMatchObject({
      availabilityState: 'temporarilyBlocked',
      linkedCaseId: 'stuckup-case-1',
    });
    await expect(service.execute(create, {
      actor: operations,
      serverNow: at('2026-08-20T04:06:00Z'),
    })).resolves.toEqual(created);
    expect(store.read('asset_condition_declarations/inner_cover_bulged_inner-gr26'))
      .toBeNull();

    const released = await service.execute({
      commandId: 'release-stuckup-1',
      commandType: 'releaseFurnaceStuckup',
      aggregateId: 'stuckup-case-1',
      expectedVersion: 1,
      payload: {releaseNotes: 'Furnace lifted clear and the physical obstruction ended.'},
    }, {
      actor: supervisor,
      serverNow: at('2026-08-20T05:00:00Z'),
    });
    expect(released.resultKey).toBe('furnace-stuckup-released');
    expect(store.read('asset_availability_current/base-117')).toMatchObject({
      availabilityState: 'clear',
      activeConstraintId: null,
    });
    expect(store.read('asset_availability_current/furnace-12')).toMatchObject({
      availabilityState: 'clear',
      activeConstraintId: null,
    });

    const adjudicated = await service.execute({
      commandId: 'adjudicate-stuckup-1',
      commandType: 'adjudicateFurnaceStuckup',
      aggregateId: 'stuckup-case-1',
      expectedVersion: 2,
      payload: {
        confirmedCause: 'innerCoverBulging',
        adjudicationNotes: 'SI confirmed visible Inner Cover bulging after safe separation.',
      },
    }, {
      actor: si,
      serverNow: at('2026-08-20T06:00:00Z'),
    });
    expect(adjudicated.resultKey).toBe('furnace-stuckup-adjudicated');
    expect(store.read('furnace_stuckup_cases/stuckup-case-1')).toMatchObject({
      obstructionStatus: 'released',
      adjudicationStatus: 'confirmed',
      confirmedCause: 'innerCoverBulging',
      version: 3,
    });
    expect(store.read('asset_condition_declarations/inner_cover_bulged_inner-gr26'))
      .toMatchObject({
        conditionType: 'innerCoverBulged',
        assetSerialNumber: 'GR26',
        state: 'confirmed',
        evidenceCount: 1,
        version: 1,
      });
    expect(store.read(
      'asset_condition_evidence/inner_cover_bulged_inner-gr26_stuckup-case-1',
    )).toMatchObject({
      caseId: 'stuckup-case-1',
      evidenceType: 'confirmedFurnaceStuckupCause',
    });

    const declarationPath =
      'asset_condition_declarations/inner_cover_bulged_inner-gr26';
    const declaration = store.read(declarationPath);
    store.seed(declarationPath, {
      ...declaration,
      firstConfirmedAt: persistedTimestamp(declaration.firstConfirmedAt),
      latestEvidenceAt: persistedTimestamp(declaration.latestEvidenceAt),
      updatedAt: persistedTimestamp(declaration.updatedAt),
    });
    await service.execute(createCommand('stuckup-case-2'), {
      actor: operations,
      serverNow: at('2026-08-20T07:00:00Z'),
    });
    await service.execute({
      commandId: 'release-stuckup-2',
      commandType: 'releaseFurnaceStuckup',
      aggregateId: 'stuckup-case-2',
      expectedVersion: 1,
      payload: {releaseNotes: 'The second obstruction was safely released.'},
    }, {
      actor: supervisor,
      serverNow: at('2026-08-20T07:15:00Z'),
    });
    await service.execute({
      commandId: 'adjudicate-stuckup-2',
      commandType: 'adjudicateFurnaceStuckup',
      aggregateId: 'stuckup-case-2',
      expectedVersion: 2,
      payload: {
        confirmedCause: 'innerCoverBulging',
        adjudicationNotes: 'SI confirmed recurring bulging after safe release.',
      },
    }, {
      actor: si,
      serverNow: at('2026-08-20T07:30:00Z'),
    });
    expect(store.read(declarationPath)).toMatchObject({
      evidenceCount: 2,
      version: 2,
      firstConfirmedAt: '2026-08-20T06:00:00.000Z',
      latestCaseId: 'stuckup-case-2',
    });
  });

  test('ordinary Operations authority cannot adjudicate a suspected cause', async () => {
    const store = new MemoryWorkflowStore();
    seedAssets(store);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    await service.execute(createCommand(), {
      actor: operations,
      serverNow: at('2026-08-20T04:05:00Z'),
    });

    await expect(service.execute({
      commandId: 'unauthorized-adjudication',
      commandType: 'adjudicateFurnaceStuckup',
      aggregateId: 'stuckup-case-1',
      expectedVersion: 1,
      payload: {
        confirmedCause: 'innerCoverBulging',
        adjudicationNotes: 'An observer suspicion must not become a declaration.',
      },
    }, {
      actor: operations,
      serverNow: at('2026-08-20T04:10:00Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.read('asset_condition_declarations/inner_cover_bulged_inner-gr26'))
      .toBeNull();
  });

  test('rejects when the confirmed Inner Cover pairing changed before submit', async () => {
    const store = new MemoryWorkflowStore();
    seedAssets(store);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    const command = createCommand('stale-pairing');

    store.seed('base_inner_cover_assignments/base-117', {
      schemaVersion: 1,
      baseAssetInstanceId: 'base-117',
      baseAssetClassId: 'base-class',
      baseAssetNumber: 117,
      innerCoverId: 'inner-gr27',
      innerCoverSerialNumber: 'GR27',
      linkageId: 'link-gr27-base-117',
      linkedAt: '2026-08-20T03:59:00.000Z',
      version: 4,
    });
    store.seed('inner_cover_profiles/inner-gr27', {
      schemaVersion: 1,
      innerCoverId: 'inner-gr27',
      serialNumber: 'GR27',
      lifecycleState: 'installed',
      currentBaseAssetInstanceId: 'base-117',
      currentBaseAssetNumber: 117,
      currentLinkageId: 'link-gr27-base-117',
    });

    await expect(service.execute(command, {
      actor: operations,
      serverNow: at('2026-08-20T04:05:00Z'),
    })).rejects.toMatchObject({
      code: 'aborted',
      details: {reasonCode: 'furnace-stuckup-inner-cover-confirmation-stale'},
    });
    expect(store.read('maintenance_tickets/stale-pairing')).toBeNull();
    expect(store.read('furnace_stuckup_cases/stale-pairing')).toBeNull();
  });

  test('rejects an issue that predates the current Inner Cover assignment', async () => {
    const store = new MemoryWorkflowStore();
    seedAssets(store);
    const operations = seedActor(store, 'operations-1', ['operations']);
    const service = new MaintenanceWorkflowCommandService(store);
    store.seed('base_inner_cover_assignments/base-117', {
      ...store.read('base_inner_cover_assignments/base-117'),
      linkedAt: '2026-08-20T04:02:00.000Z',
    });

    await expect(service.execute(createCommand('pre-linkage-issue'), {
      actor: operations,
      serverNow: at('2026-08-20T04:05:00Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {
        reasonCode: 'maintenance-ticket-inner-cover-linkage-after-event',
      },
    });
    expect(store.read('maintenance_tickets/pre-linkage-issue')).toBeNull();
    expect(store.read('furnace_stuckup_cases/pre-linkage-issue')).toBeNull();
  });
});

const replayWithoutWrites = async (store, service, command, actor, receipt) => {
  const before = store.entries();
  const transact = store.runTransaction.bind(store);
  const spy = jest.spyOn(store, 'runTransaction').mockImplementation((work) => transact((tx) => {
    const write = () => { throw new Error('Replay must not stage any write'); };
    return work({get: tx.get.bind(tx), query: tx.query.bind(tx), create: write, update: write, set: write, delete: write});
  }));
  try {
    await expect(service.execute(command, {actor, serverNow: at('2026-09-12T12:00:00.000Z')}))
      .resolves.toEqual(receipt);
  } finally { spy.mockRestore(); }
  expect(store.entries()).toEqual(before);
};

const timestampMaps = (value, key = '') => {
  if (typeof value === 'string' && (key === 'timestamp' || key.endsWith('At')) &&
      /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value) && key !== 'appliedAt') {
    return persistedTimestamp(value);
  }
  if (Array.isArray(value)) return value.map((item) => timestampMaps(item));
  if (value != null && typeof value === 'object') return Object.fromEntries(
    Object.entries(value).map(([child, item]) => [child, timestampMaps(item, child)]),
  );
  return value;
};

class TimestampWorkflowStore extends MemoryWorkflowStore {
  runTransaction(work) {
    return super.runTransaction((tx) => work({
      get: tx.get.bind(tx), query: tx.query.bind(tx), delete: tx.delete.bind(tx),
      create: (path, data) => tx.create(path, timestampMaps(data)),
      update: (path, data) => tx.update(path, timestampMaps(data)),
      set: (path, data, merge) => tx.set(path, timestampMaps(data), merge),
    }));
  }
}

const modernStuckupJourney = async (adjudicateFirst, timestamps = false) => {
  const store = timestamps ? new TimestampWorkflowStore() : new MemoryWorkflowStore();
  seedAssets(store);
  const operations = seedActor(store, 'operations-1', ['operations']);
  const si = seedActor(store, 'si-1', ['si']);
  const service = new MaintenanceWorkflowCommandService(store);
  await service.execute(createCommand(), {actor: operations, serverNow: at('2026-08-20T04:05:00Z')});
  const commands = [
    {commandId: 'modern-release', commandType: 'releaseFurnaceStuckup', aggregateId: 'stuckup-case-1', expectedVersion: 1, payload: {releaseNotes: 'Furnace safely separated.'}},
    {commandId: 'modern-adjudicate', commandType: 'adjudicateFurnaceStuckup', aggregateId: 'stuckup-case-1', expectedVersion: 2, payload: {confirmedCause: 'innerCoverBulging', adjudicationNotes: 'SI confirmed bulging after examination.'}},
  ];
  if (adjudicateFirst) commands.reverse();
  commands.forEach((command, i) => { command.expectedVersion = i + 1; });
  const actors = commands.map((command) => command.commandType === 'releaseFurnaceStuckup' ? operations : si);
  const receipts = [];
  for (let i = 0; i < commands.length; i++) receipts.push(await service.execute(commands[i], {
    actor: actors[i], serverNow: at(`2026-08-20T0${5 + i}:00:00.000Z`),
  }));
  return {store, service, commands, actors, receipts, operations, si};
};

describe('Historical stuck-up acceptance after later business progress', () => {
  test.each([false, true])('new commands replay after both lifecycle operations (adjudicate first=%s)', async (adjudicateFirst) => {
    const journey = await modernStuckupJourney(adjudicateFirst);
    const {store, service, commands, actors, receipts, operations, si} = journey;
    // A later incident changes the mutable availability and condition-declaration tips.
    await service.execute(createCommand('later-case'), {actor: operations, serverNow: at('2026-08-20T07:00:00Z')});
    await service.execute({commandId: 'later-adjudication', commandType: 'adjudicateFurnaceStuckup',
      aggregateId: 'later-case', expectedVersion: 1, payload: {confirmedCause: 'combinedCondition', adjudicationNotes: 'Another inspected incident.'}},
    {actor: si, serverNow: at('2026-08-20T08:00:00Z')});
    expect(store.read('asset_availability_current/base-117').availabilityState).toBe('temporarilyBlocked');
    expect(store.read('asset_condition_declarations/inner_cover_bulged_inner-gr26').evidenceCount).toBe(2);
    for (let i = 0; i < commands.length; i++) await replayWithoutWrites(store, service, commands[i], actors[i], receipts[i]);
  });

  test.each([false, true])('stored Timestamp forms preserve exact audit proof (adjudicate first=%s)', async (adjudicateFirst) => {
    const {store, service, commands, actors, receipts} = await modernStuckupJourney(adjudicateFirst, true);
    for (let i = 0; i < commands.length; i++) await replayWithoutWrites(store, service, commands[i], actors[i], receipts[i]);
    const path = `audit_logs/${receipts[0].result.auditId}`;
    const audit = store.read(path);
    store.seed(path, {...audit, timestamp: {...audit.timestamp, _nanoseconds: audit.timestamp._nanoseconds + 1}});
    const before = store.entries();
    await expect(service.execute(commands[0], {actor: actors[0], serverNow: at('2026-09-12T12:00:00Z')}))
      .rejects.toMatchObject({details: {reasonCode: 'furnace-stuckup-replay-evidence-invalid'}});
    expect(store.entries()).toEqual(before);
  });

  test.each(require('./fixtures/furnaceStuckupLegacyReplay.json').scenarios.map((scenario) => [scenario.order, scenario]))(
    'actual pre-fix receipts remain write-free after %s', async (_, scenario) => {
      const store = new MemoryWorkflowStore();
      for (const [path, data] of scenario.documents) store.seed(path, data);
      const service = new MaintenanceWorkflowCommandService(store);
      for (let i = 0; i < scenario.commands.length; i++) await replayWithoutWrites(store, service, scenario.commands[i], scenario.actors[i], scenario.receipts[i]);
    },
  );

  const corruptions = [
    ['audit absent', async (s, c, r) => s.runTransaction((tx) => tx.delete(`audit_logs/${r.result.auditId}`))],
    ['audit actor', (s, c, r) => { const p = `audit_logs/${r.result.auditId}`; s.seed(p, {...s.read(p), performedByUid: 'another-actor'}); }],
    ['audit outcome', (s, c, r) => { const p = `audit_logs/${r.result.auditId}`; const a = s.read(p); s.seed(p, {...a, afterJson: JSON.stringify({...JSON.parse(a.afterJson), releaseNotes: 'Different physical action'})}); }],
    ['audit original version', (s, c, r) => { const p = `audit_logs/${r.result.auditId}`; const a = s.read(p); s.seed(p, {...a, beforeJson: JSON.stringify({...JSON.parse(a.beforeJson), version: 9})}); }],
    ['audit time', (s, c, r) => { const p = `audit_logs/${r.result.auditId}`; s.seed(p, {...s.read(p), timestamp: '2026-08-20T05:01:00.000Z'}); }],
    ['receipt time', (s, c) => { const p = `maintenance_workflow_command_receipts/${c.commandId}`; s.seed(p, {...s.read(p), appliedAt: '2026-08-20T05:01:00.000Z'}); }],
    ['receipt case', (s, c) => { const p = `maintenance_workflow_command_receipts/${c.commandId}`; const r = s.read(p); s.seed(p, {...r, result: {...r.result, caseId: 'another-case'}}); }],
    ['receipt result kind', (s, c) => { const p = `maintenance_workflow_command_receipts/${c.commandId}`; s.seed(p, {...s.read(p), resultKey: 'furnace-stuckup-adjudicated'}); }],
    ['current case replaced', (s, c) => { const p = `furnace_stuckup_cases/${c.aggregateId}`; s.seed(p, {...s.read(p), baseAssetInstanceId: 'another-base'}); }],
    ['current case rolled back', (s, c) => { const p = `furnace_stuckup_cases/${c.aggregateId}`; s.seed(p, {...s.read(p), version: 1}); }],
    ['release constraint absent', async (s, c) => s.runTransaction((tx) => tx.delete(`asset_availability_constraints/${c.aggregateId}_base-117`))],
    ['release constraint actor', (s, c) => { const p = `asset_availability_constraints/${c.aggregateId}_base-117`; s.seed(p, {...s.read(p), releasedByUid: 'another-actor'}); }],
  ];
  test.each(corruptions.flatMap(([name, mutate]) => [ ['legacy', name, mutate], ['modern', name, mutate] ]))(
    '%s replay rejects %s without writes', async (kind, _, mutate) => {
      let store, service, commands, actors, receipts;
      if (kind === 'modern') ({store, service, commands, actors, receipts} = await modernStuckupJourney(false));
      else {
        const scenario = require('./fixtures/furnaceStuckupLegacyReplay.json').scenarios[0];
        ({commands, actors, receipts} = scenario); store = new MemoryWorkflowStore();
        for (const [path, data] of scenario.documents) store.seed(path, data);
        service = new MaintenanceWorkflowCommandService(store);
      }
      await mutate(store, commands[0], receipts[0]);
      const before = store.entries();
      await expect(service.execute(commands[0], {actor: actors[0], serverNow: at('2026-09-12T12:00:00Z')}))
        .rejects.toMatchObject({details: {reasonCode: 'furnace-stuckup-replay-evidence-invalid'}});
      expect(store.entries()).toEqual(before);
    },
  );

  test.each(['fingerprint', 'audit-schema', 'receipt-schema', 'condition-evidence', 'actor', 'payload', 'revoked'])(
    'modern adjudication proof rejects %s', async (kind) => {
      const {store, service, commands, actors, receipts} = await modernStuckupJourney(true);
      const command = structuredClone(commands[0]);
      const receiptPath = `maintenance_workflow_command_receipts/${command.commandId}`;
      const auditPath = `audit_logs/${receipts[0].result.auditId}`;
      let actor = actors[0];
      if (kind === 'fingerprint') { const receipt = store.read(receiptPath); delete receipt.result.auditFingerprint; store.seed(receiptPath, receipt); }
      if (kind === 'audit-schema') { const audit = store.read(auditPath); audit.schemaVersion = 1; delete audit.commandFingerprint; store.seed(auditPath, audit); }
      if (kind === 'receipt-schema') { const receipt = store.read(receiptPath); delete receipt.result.auditSchemaVersion; store.seed(receiptPath, receipt); }
      if (kind === 'condition-evidence') await store.runTransaction((tx) => tx.delete(`asset_condition_evidence/${receipts[0].result.evidenceId}`));
      if (kind === 'actor') actor = seedActor(store, 'other-si', ['si']);
      if (kind === 'payload') command.payload.adjudicationNotes = 'Changed request intent';
      if (kind === 'revoked') store.seed(`users/${actor.uid}`, {name: actor.name, isApproved: true, roles: ['operations']});
      const before = store.entries();
      await expect(service.execute(command, {actor, serverNow: at('2026-09-12T12:00:00Z')})).rejects.toBeDefined();
      expect(store.entries()).toEqual(before);
    },
  );
});

describe('Legacy stuck-up evidence is not guessed or downgraded', () => {
  test.each(['missing', 'wrong cause', 'wrong original time'])('legacy adjudication rejects %s condition evidence', async (corruption) => {
    const scenario = require('./fixtures/furnaceStuckupLegacyReplay.json').scenarios[1];
    const store = new MemoryWorkflowStore();
    for (const [path, data] of scenario.documents) store.seed(path, data);
    const path = `asset_condition_evidence/${scenario.receipts[0].result.evidenceId}`;
    if (corruption === 'missing') await store.runTransaction((tx) => tx.delete(path));
    else store.seed(path, {...store.read(path), ...(corruption === 'wrong cause' ?
      {confirmedCause: 'other'} : {confirmedAt: '2026-08-20T05:01:00.000Z'})});
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(scenario.commands[0], {
      actor: scenario.actors[0], serverNow: at('2026-09-12T12:00:00Z'),
    })).rejects.toMatchObject({details: {reasonCode: 'furnace-stuckup-replay-evidence-invalid'}});
    expect(store.entries()).toEqual(before);
  });

  test('the unsupported legacy workflow receipt still requires reconciliation', async () => {
    const scenario = require('./fixtures/furnaceStuckupLegacyReplay.json').scenarios[0];
    const store = new MemoryWorkflowStore();
    for (const [path, data] of scenario.documents) store.seed(path, data);
    const path = `maintenance_workflow_command_receipts/${scenario.commands[0].commandId}`;
    store.seed(path, {...store.read(path), receiptSchemaVersion: 1, payloadHash: '0123456789abcdef'});
    const before = store.entries();
    await expect(new MaintenanceWorkflowCommandService(store).execute(scenario.commands[0], {
      actor: scenario.actors[0], serverNow: at('2026-09-12T12:00:00Z'),
    })).rejects.toMatchObject({details: {reasonCode: 'legacy-workflow-receipt-reconciliation-required'}});
    expect(store.entries()).toEqual(before);
  });
});
