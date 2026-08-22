const {
  mutateInnerCoverLifecycleWithDb,
  parseInnerCoverLifecycleMutationRequest,
} = require('../lib/innerCoverLifecycleMutation');

function clone(value) {
  return value == null ? value : structuredClone(value);
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {exists: value != null, id, data: () => clone(value)};
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {
      id,
      path,
      async get() { return snapshot(path, id); },
    };
  }

  return {
    store,
    writes,
    db: {
      collection(name) {
        return {doc(id) { return ref(name, id); }};
      },
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(documentRef) {
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({kind: 'set', path: documentRef.path, data: clone(data)});
          },
          delete(documentRef) {
            staged.push({kind: 'delete', path: documentRef.path});
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          if (write.kind === 'delete') store.delete(write.path);
          else store.set(write.path, clone(write.data));
          writes.push(write);
        }
        return result;
      },
    },
  };
}

const IDS = {
  innerClass: '11111111-1111-4111-8111-111111111111',
  baseClass: '22222222-2222-4222-8222-222222222222',
  cover: '33333333-3333-4333-8333-333333333333',
  cover2: '44444444-4444-4444-8444-444444444444',
  base: '55555555-5555-4555-8555-555555555555',
  base2: '66666666-6666-4666-8666-666666666666',
  register: '77777777-7777-4777-8777-777777777777',
  accept: '88888888-8888-4888-8888-888888888888',
  link: '99999999-9999-4999-8999-999999999999',
  delink: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  replace: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  donorSection: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
};

function assetClass(id, key, name) {
  return {
    schemaVersion: 1,
    assetClassId: id,
    code: key === 'base' ? 'BASE' : 'INNER_COVER',
    name,
    legacyAssetTypeKey: key,
    status: 'active',
    version: 1,
  };
}

function base(id, number) {
  return {
    schemaVersion: 1,
    assetInstanceId: id,
    assetClassId: IDS.baseClass,
    assetClassCode: 'BASE',
    assetClassName: 'Base',
    assetNumber: number,
    name: `Base ${number}`,
    status: 'active',
    serviceState: 'inService',
    version: 1,
  };
}

function seed() {
  return {
    'users/admin-1': {
      isApproved: true,
      roles: ['admin'],
      name: 'Admin One',
    },
    [`asset_classes/${IDS.innerClass}`]: assetClass(
      IDS.innerClass,
      'innerCover',
      'Inner Cover',
    ),
    [`asset_classes/${IDS.baseClass}`]: assetClass(
      IDS.baseClass,
      'base',
      'Base',
    ),
    [`asset_instances/${IDS.base}`]: base(IDS.base, 201),
    [`asset_instances/${IDS.base2}`]: base(IDS.base2, 202),
  };
}

function registerRequest(overrides = {}) {
  return {
    requestId: IDS.register,
    operation: 'REGISTER_INNER_COVER',
    innerCoverId: IDS.cover,
    innerCoverAssetClassId: IDS.innerClass,
    reason: 'Register a purchased Inner Cover into governed custody.',
    registrationDraft: {
      serialNumber: 'GR26',
      sourceType: 'purchased',
      originClassification: 'documentedPurchase',
      supplierOrFabricator: 'Approved supplier',
      receivedOrCompletedOn: '2026-08-01T00:00:00.000Z',
      incorporatedOn: '2026-08-01T12:00:00.000Z',
      drawingReference: 'IC-001',
      materialGrade: 'SS 321',
      notes: null,
      fabricationSections: [],
    },
    ...overrides,
  };
}

function acceptRequest(innerCoverId = IDS.cover, expectedVersion = 1) {
  return {
    requestId: IDS.accept,
    operation: 'ACCEPT_INNER_COVER',
    innerCoverId,
    expectedVersion,
    reason: 'Inspection and leak-test evidence are acceptable for service.',
    acceptanceDraft: {
      inspectedOn: '2026-08-02T00:00:00.000Z',
      acceptanceReference: 'ACC-26',
      leakTestReference: 'LT-26',
      ndtReference: null,
      notes: 'Accepted after dimensional and leak inspection.',
    },
  };
}

function linkRequest(innerCoverId = IDS.cover, expectedVersion = 2) {
  return {
    requestId: IDS.link,
    operation: 'LINK_INNER_COVER',
    innerCoverId,
    expectedVersion,
    targetBaseAssetInstanceId: IDS.base,
    reason: 'Install the accepted Inner Cover on Base 201 for operation.',
  };
}

function profile(id, serial, state, version, overrides = {}) {
  const accepted = ['available', 'reserved', 'installed'].includes(state);
  return {
    schemaVersion: 1,
    innerCoverId: id,
    assetClassId: IDS.innerClass,
    assetClassCode: 'INNER_COVER',
    assetClassName: 'Inner Cover',
    serialNumber: serial,
    normalizedSerialNumber: serial,
    sourceType: 'legacyExisting',
    lifecycleState: state,
    traceabilityGrade: 'T0',
    acceptanceReference: accepted ? `ACC-${serial}` : null,
    acceptedAt: accepted ? new Date('2026-08-02T00:00:00.000Z') : null,
    acceptedByUid: accepted ? 'admin-1' : null,
    acceptedByName: accepted ? 'Admin One' : null,
    currentBaseAssetInstanceId: null,
    currentBaseAssetNumber: null,
    currentBaseAssetName: null,
    currentLinkageId: null,
    version,
    lastMutationId: 'prior',
    ...overrides,
  };
}

async function invoke(memory, request) {
  return mutateInnerCoverLifecycleWithDb({
    db: memory.db,
    authUid: 'admin-1',
    data: request,
    now: () => new Date('2026-08-15T12:00:00.000Z'),
    timestampFromDate: (date) => date,
  });
}

describe('Inner Cover lifecycle mutation', () => {
  test('parser requires the complete operation-specific request shape', () => {
    expect(parseInnerCoverLifecycleMutationRequest(registerRequest()))
      .toMatchObject({innerCoverId: IDS.cover, operation: 'REGISTER_INNER_COVER'});
    expect(() => parseInnerCoverLifecycleMutationRequest({
      ...registerRequest(),
      expectedVersion: 1,
    })).toThrow('expectedVersion');
    expect(() => parseInnerCoverLifecycleMutationRequest({
      ...registerRequest(),
      surprise: true,
    })).toThrow('request.surprise is unsupported');
  });

  test('availability requires governed acceptance and future evidence is rejected', async () => {
    const memory = fakeDb(seed());
    await invoke(memory, registerRequest());
    await expect(invoke(memory, {
      requestId: '15151515-1515-4151-8151-151515151515',
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 1,
      targetState: 'available',
      reason: 'Attempt to bypass the governed acceptance command.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inner-cover-state-transition-invalid'},
    });
    await expect(invoke(memory, {
      ...acceptRequest(),
      requestId: '16161616-1616-4161-8161-161616161616',
      acceptanceDraft: {
        ...acceptRequest().acceptanceDraft,
        inspectedOn: '2026-08-16T00:00:00.000Z',
      },
    })).rejects.toThrow('cannot be in the future');
    await expect(invoke(fakeDb(seed()), {
      ...registerRequest(),
      requestId: '17171717-1717-4171-8171-171717171717',
      registrationDraft: {
        ...registerRequest().registrationDraft,
        receivedOrCompletedOn: '2026-08-16T00:00:00.000Z',
      },
    })).rejects.toThrow('cannot be in the future');
    await expect(invoke(fakeDb(seed()), {
      ...registerRequest(),
      requestId: '18181818-1818-4181-8181-181818181818',
      registrationDraft: {
        ...registerRequest().registrationDraft,
        incorporatedOn: '2026-08-16T00:00:00.000Z',
      },
    })).rejects.toThrow('cannot be in the future');
  });

  test('owner-declared new origin remains limited-trace rather than T3', async () => {
    const memory = fakeDb(seed());
    await invoke(memory, {
      ...registerRequest(),
      registrationDraft: {
        ...registerRequest().registrationDraft,
        serialNumber: 'N16',
        sourceType: 'legacyExisting',
        originClassification: 'ownerDeclaredNew',
        supplierOrFabricator: null,
        receivedOrCompletedOn: null,
      },
    });
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({
        serialNumber: 'N16',
        sourceType: 'legacyExisting',
        originClassification: 'ownerDeclaredNew',
        traceabilityGrade: 'T1',
        incorporatedOn: new Date('2026-08-01T12:00:00.000Z'),
      });
  });

  test('registers, accepts, links and delinks with exact history', async () => {
    const memory = fakeDb(seed());
    const registered = await invoke(memory, registerRequest());
    const accepted = await invoke(memory, acceptRequest());
    const linked = await invoke(memory, linkRequest());
    const linkageId = `link_${IDS.link}`;
    const delinked = await invoke(memory, {
      requestId: IDS.delink,
      operation: 'DELINK_INNER_COVER',
      innerCoverId: IDS.cover,
      expectedVersion: 3,
      sourceBaseAssetInstanceId: IDS.base,
      expectedSourceAssignmentVersion: 1,
      targetState: 'awaitingInspection',
      reason: 'Remove the Inner Cover for post-service inspection.',
    });

    expect(registered).toMatchObject({version: 1, idempotentReplay: false});
    expect(accepted).toMatchObject({version: 2});
    expect(linked).toMatchObject({version: 3});
    expect(delinked).toMatchObject({version: 4});
    expect(memory.store.has(`base_inner_cover_assignments/${IDS.base}`))
      .toBe(false);
    expect(memory.store.get(`inner_cover_linkages/${linkageId}`))
      .toMatchObject({active: false, removalAction: 'DELINK_INNER_COVER'});
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({
        lifecycleState: 'awaitingInspection',
        currentBaseAssetInstanceId: null,
        version: 4,
      });
  });

  test('exact replay is write-free and a reused request ID is rejected', async () => {
    const memory = fakeDb(seed());
    const first = await invoke(memory, registerRequest());
    const writeCount = memory.writes.length;
    const replay = await invoke(memory, registerRequest());
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect(memory.writes).toHaveLength(writeCount);
    await expect(invoke(memory, registerRequest({
      registrationDraft: {
        ...registerRequest().registrationDraft,
        serialNumber: 'GR27',
      },
    }))).rejects.toMatchObject({
      code: 'already-exists',
      details: {reasonCode: 'inner-cover-request-id-reused'},
    });
  });

  test('serial claims reject duplicate physical identity', async () => {
    const memory = fakeDb(seed());
    await invoke(memory, registerRequest());
    await expect(invoke(memory, registerRequest({
      requestId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      innerCoverId: IDS.cover2,
      registrationDraft: {
        ...registerRequest().registrationDraft,
        serialNumber: 'GR-26',
      },
    }))).rejects.toMatchObject({
      code: 'already-exists',
      details: {reasonCode: 'inner-cover-serial-collision'},
    });
  });

  test('partially populated current projection fails closed', async () => {
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'available',
        2,
        {currentBaseAssetInstanceId: IDS.base},
      ),
    });
    await expect(invoke(memory, linkRequest())).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inner-cover-projection-incomplete'},
    });
    expect(memory.writes).toHaveLength(0);
  });

  test('atomic replacement returns the displaced cover to the pool', async () => {
    const linkageId = 'link-existing';
    const installed = profile(IDS.cover2, 'GR27', 'installed', 4, {
      currentBaseAssetInstanceId: IDS.base,
      currentBaseAssetNumber: 201,
      currentBaseAssetName: 'Base 201',
      currentLinkageId: linkageId,
    });
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'available',
        2,
      ),
      [`inner_cover_profiles/${IDS.cover2}`]: installed,
      [`base_inner_cover_assignments/${IDS.base}`]: {
        schemaVersion: 1,
        baseAssetInstanceId: IDS.base,
        baseAssetClassId: IDS.baseClass,
        baseAssetNumber: 201,
        baseAssetName: 'Base 201',
        innerCoverId: IDS.cover2,
        innerCoverSerialNumber: 'GR27',
        linkageId,
        version: 3,
      },
      [`inner_cover_linkages/${linkageId}`]: {
        schemaVersion: 1,
        linkageId,
        baseAssetInstanceId: IDS.base,
        innerCoverId: IDS.cover2,
        innerCoverSerialNumber: 'GR27',
        active: true,
        removedAt: null,
        version: 1,
      },
    });

    const result = await invoke(memory, {
      requestId: IDS.replace,
      operation: 'REPLACE_INNER_COVER',
      innerCoverId: IDS.cover,
      expectedVersion: 2,
      targetBaseAssetInstanceId: IDS.base,
      expectedTargetAssignmentVersion: 3,
      displacedInnerCoverId: IDS.cover2,
      expectedDisplacedVersion: 4,
      targetState: 'awaitingInspection',
      reason: 'Replace the suspect cover and return it for inspection.',
    });

    expect(result).toMatchObject({version: 3, secondaryVersion: 5});
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({lifecycleState: 'installed', currentBaseAssetNumber: 201});
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover2}`))
      .toMatchObject({
        lifecycleState: 'awaitingInspection',
        currentBaseAssetInstanceId: null,
      });
    expect(memory.store.get(`base_inner_cover_assignments/${IDS.base}`))
      .toMatchObject({innerCoverId: IDS.cover, version: 4});
  });

  test('known donor part can be allocated only once', async () => {
    const donorId = IDS.cover2;
    const donor = profile(
      donorId,
      'GR20',
      'retiredForSalvage',
      6,
    );
    const fabricated = {
      ...registerRequest(),
      registrationDraft: {
        ...registerRequest().registrationDraft,
        sourceType: 'fabricated',
        originClassification: 'documentedFabrication',
        serialNumber: 'GR30',
        fabricationSections: [
          {
            sectionId: IDS.donorSection,
            sectionType: 'lowerAssembly',
            materialSource: 'reusedKnownDonor',
            donorInnerCoverId: donorId,
            donorSectionKey: 'lower-01',
            donorExpectedVersion: 6,
            lengthMm: 1200,
            cutCount: 1,
            notes: null,
          },
          {
            sectionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            sectionType: 'flatVertical',
            materialSource: 'newPurchased',
            donorInnerCoverId: null,
            donorSectionKey: null,
            donorExpectedVersion: null,
            lengthMm: 2200,
            cutCount: 1,
            notes: null,
          },
          {
            sectionId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            sectionType: 'corrugatedShell',
            materialSource: 'newFabricated',
            donorInnerCoverId: null,
            donorSectionKey: null,
            donorExpectedVersion: null,
            lengthMm: 4400,
            cutCount: 2,
            notes: null,
          },
          {
            sectionId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
            sectionType: 'topCover',
            materialSource: 'newFabricated',
            donorInnerCoverId: null,
            donorSectionKey: null,
            donorExpectedVersion: null,
            lengthMm: null,
            cutCount: 1,
            notes: null,
          },
        ],
      },
    };
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${donorId}`]: donor,
    });
    await invoke(memory, fabricated);
    expect(memory.store.get(`inner_cover_profiles/${donorId}`))
      .toMatchObject({lifecycleState: 'partiallyDismantled', version: 7});
    const audit = memory.store.get(
      `inner_cover_lifecycle_audits/inner_cover_${fabricated.requestId}`,
    );
    const relatedChanges = JSON.parse(audit.relatedEntityChangesJson);
    expect(relatedChanges).toEqual([
      expect.objectContaining({
        entityType: 'inner_cover_donor',
        entityId: donorId,
        before: expect.objectContaining({
          lifecycleState: 'retiredForSalvage',
          version: 6,
        }),
        after: expect.objectContaining({
          lifecycleState: 'partiallyDismantled',
          version: 7,
        }),
      }),
    ]);

    const second = {
      ...fabricated,
      requestId: '12121212-1212-4121-8121-121212121212',
      innerCoverId: '13131313-1313-4131-8131-131313131313',
      registrationDraft: {
        ...fabricated.registrationDraft,
        serialNumber: 'GR31',
        fabricationSections: fabricated.registrationDraft.fabricationSections
          .map((section) => ({
            ...section,
            sectionId: section.sectionType === 'lowerAssembly' ?
              '14141414-1414-4141-8141-141414141414' : section.sectionId,
            donorExpectedVersion: section.sectionType === 'lowerAssembly' ?
              7 : section.donorExpectedVersion,
          })),
      },
    };
    await expect(invoke(memory, second)).rejects.toMatchObject({
      code: 'already-exists',
      details: {reasonCode: 'inner-cover-donor-part-already-consumed'},
    });
  });
});
