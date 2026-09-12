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

  test('retirement for salvage requires and retains bulge evidence', async () => {
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'available',
        2,
      ),
    });
    const request = {
      requestId: '19191919-1919-4191-8191-191919191919',
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 2,
      targetState: 'retiredForSalvage',
      reason: 'Retire the cover for controlled salvage after inspection.',
    };
    await expect(invoke(memory, request)).rejects.toThrow(
      'retirementCondition is required',
    );

    const result = await invoke(memory, {
      ...request,
      retirementCondition: 'bulged',
    });

    expect(result).toMatchObject({version: 3, idempotentReplay: false});
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({
        lifecycleState: 'retiredForSalvage',
        retirementCondition: 'bulged',
        version: 3,
      });
    const audit = memory.store.get(
      `inner_cover_lifecycle_audits/inner_cover_${request.requestId}`,
    );
    expect(JSON.parse(audit.afterJson)).toMatchObject({
      lifecycleState: 'retiredForSalvage',
      retirementCondition: 'bulged',
    });

    const returnRequestId = '20202020-2020-4020-8020-202020202020';
    const returned = await invoke(memory, {
      requestId: returnRequestId,
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 3,
      targetState: 'awaitingInspection',
      reason: 'Return the retired cover for a fresh governed fitness check.',
    });
    expect(returned).toMatchObject({version: 4, idempotentReplay: false});
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({
        lifecycleState: 'awaitingInspection',
        retirementCondition: 'bulged',
        returnedToInspectionByUid: 'admin-1',
        returnToInspectionReason:
          'Return the retired cover for a fresh governed fitness check.',
        version: 4,
      });

    await expect(invoke(memory, linkRequest(IDS.cover, 4)))
      .rejects.toMatchObject({
        code: 'failed-precondition',
        details: {reasonCode: 'inner-cover-not-available'},
      });
    await invoke(memory, acceptRequest(IDS.cover, 4));
    await invoke(memory, linkRequest(IDS.cover, 5));
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({
        lifecycleState: 'installed',
        retirementCondition: 'bulged',
        currentBaseAssetNumber: 201,
        version: 6,
      });
  });

  test('a dismantled salvage cover cannot return to inspection', async () => {
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'partiallyDismantled',
        5,
        {retirementCondition: 'bulged'},
      ),
    });

    await expect(invoke(memory, {
      requestId: '21212121-2121-4121-8121-212121212121',
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 5,
      targetState: 'awaitingInspection',
      reason: 'Attempt to restore a cover after donor dismantling.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inner-cover-state-transition-invalid'},
    });
  });

  test('legacy retirement can supply its missing condition during return', async () => {
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'retiredForSalvage',
        3,
      ),
    });

    const returned = await invoke(memory, {
      requestId: '22222222-3333-4222-8222-333333333333',
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 3,
      targetState: 'awaitingInspection',
      retirementCondition: 'notBulged',
      reason: 'Reconstruct the old retirement condition before inspection.',
    });

    expect(returned).toMatchObject({version: 4});
    expect(memory.store.get(`inner_cover_profiles/${IDS.cover}`))
      .toMatchObject({
        lifecycleState: 'awaitingInspection',
        retirementCondition: 'notBulged',
        version: 4,
      });
  });

  test('return cannot rewrite a retained retirement condition', async () => {
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'retiredForSalvage',
        3,
        {retirementCondition: 'bulged'},
      ),
    });

    await expect(invoke(memory, {
      requestId: '23232323-2323-4323-8323-232323232323',
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 3,
      targetState: 'awaitingInspection',
      retirementCondition: 'notBulged',
      reason: 'Attempt to contradict the retained retirement record.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'inner-cover-return-condition-mismatch'},
    });
  });

  test('ordinary inspection transition cannot inject retirement history', async () => {
    const memory = fakeDb({
      ...seed(),
      [`inner_cover_profiles/${IDS.cover}`]: profile(
        IDS.cover,
        'GR26',
        'underRepair',
        3,
      ),
    });

    await expect(invoke(memory, {
      requestId: '24242424-2424-4424-8424-242424242424',
      operation: 'SET_INNER_COVER_STATE',
      innerCoverId: IDS.cover,
      expectedVersion: 3,
      targetState: 'awaitingInspection',
      retirementCondition: 'notBulged',
      reason: 'Complete repair and send the cover for inspection.',
    })).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'inner-cover-return-condition-unexpected'},
    });
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

  test('the same donor part cannot be allocated twice in one request', async () => {
    // The neighbouring test is named for this invariant but allocates the
    // donor once, so it never exercised the guard. The guard read
    // `!donorClaimIds.add(claimId)`, and Set.add returns the Set rather than
    // whether the value was new, so it was false for a first allocation and a
    // repeat alike.
    //
    // Two distinct section ids can name the same donor cover and section key.
    // Within one request both persistent-claim reads see absence before either
    // write, so the in-request check is the only thing that catches it.
    const donorId = IDS.cover2;
    const donor = profile(donorId, 'GR20', 'retiredForSalvage', 6);
    const duplicateDonorSection = {
      sectionType: 'lowerAssembly',
      materialSource: 'reusedKnownDonor',
      donorInnerCoverId: donorId,
      donorSectionKey: 'lower-01',
      donorExpectedVersion: 6,
      lengthMm: 1200,
      cutCount: 1,
      notes: null,
    };
    const fabricated = {
      ...registerRequest(),
      registrationDraft: {
        ...registerRequest().registrationDraft,
        sourceType: 'fabricated',
        originClassification: 'documentedFabrication',
        serialNumber: 'GR31',
        // All four required section types stay present, so the rejection
        // cannot come from a missing-section check. Two of them name the same
        // donor cover and section key, which is what makes one claim id twice.
        fabricationSections: [
          {...duplicateDonorSection, sectionId: IDS.donorSection},
          {
            ...duplicateDonorSection,
            sectionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            sectionType: 'flatVertical',
            lengthMm: 2200,
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

    // Assert the specific refusal. `invalid-argument` alone is produced by
    // several other validations, so matching only the code would let this test
    // pass while the donor guard did nothing.
    await expect(invoke(memory, fabricated)).rejects.toMatchObject({
      code: 'invalid-argument',
      message: expect.stringContaining(
        'cannot allocate the same donor part more than once',
      ),
    });

    // Nothing was committed: the donor keeps its version and no new cover
    // profile was written for the fabricated serial.
    expect(memory.store.get(`inner_cover_profiles/${donorId}`))
      .toMatchObject({version: 6});
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
