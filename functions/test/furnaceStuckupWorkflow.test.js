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
