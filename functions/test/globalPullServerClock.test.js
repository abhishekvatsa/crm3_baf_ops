const {
  GLOBAL_PULL_COLLECTIONS,
  GLOBAL_PULL_PROTOCOL_FINGERPRINT,
  GLOBAL_PULL_PROTOCOL_VERSION,
  GLOBAL_PULL_SERVER_UPDATED_AT_FIELD,
  GLOBAL_PULL_WRITER_VERSION,
  applyGlobalPullServerClock,
  beginGlobalPullRunWithDb,
  shouldStampGlobalPullWrite,
} = require("../lib/globalPullServerClock");

const activatedAt = new Date("2026-07-27T18:00:00.000Z");
const serverAnchor = new Date("2026-07-27T18:05:00.000Z");

function timestamp(date) {
  return {toDate: () => new Date(date.getTime())};
}

function snapshot(data, writes) {
  return {
    exists: data != null,
    data: () => data,
    ref: {
      set: async (value, options) => {
        writes.push({value, options});
      },
    },
  };
}

function authorityDb({approved = true, contractOverrides = {}} = {}) {
  const actor = {
    isApproved: approved,
    roles: ["operations"],
  };
  const contract = {
    state: "ACTIVE",
    protocolVersion: GLOBAL_PULL_PROTOCOL_VERSION,
    protocolFingerprint: GLOBAL_PULL_PROTOCOL_FINGERPRINT,
    writerVersion: GLOBAL_PULL_WRITER_VERSION,
    serverStampField: GLOBAL_PULL_SERVER_UPDATED_AT_FIELD,
    collections: GLOBAL_PULL_COLLECTIONS,
    activatedAt: timestamp(activatedAt),
    sourceCommit: "a".repeat(40),
    backfillReceiptSha256: "b".repeat(64),
    ...contractOverrides,
  };
  return {
    doc: (path) => ({
      get: async () => {
        if (path === "users/operator-a") {
          return {exists: true, data: () => actor};
        }
        if (path === "runtime_contracts/global_pull_v1") {
          return {exists: true, data: () => contract};
        }
        return {exists: false, data: () => undefined};
      },
    }),
  };
}

describe("global pull server authority", () => {
  test("returns an approved actor digest and authoritative bounded-run clock", async () => {
    const result = await beginGlobalPullRunWithDb({
      db: authorityDb(),
      authUid: "operator-a",
      serverNow: () => serverAnchor,
    });

    expect(result).toEqual({
      actorUid: "operator-a",
      authorityDigest:
        "auth1-sha256:0ee99aa12c081365ef07b5b3d3f8c7c66d55ae92dd7db646be6366352098f22b",
      protocolVersion: GLOBAL_PULL_PROTOCOL_VERSION,
      protocolFingerprint: GLOBAL_PULL_PROTOCOL_FINGERPRINT,
      writerVersion: GLOBAL_PULL_WRITER_VERSION,
      serverStampField: GLOBAL_PULL_SERVER_UPDATED_AT_FIELD,
      collections: GLOBAL_PULL_COLLECTIONS,
      activatedAt: activatedAt.toISOString(),
      serverAnchor: serverAnchor.toISOString(),
    });
  });

  test("rejects unauthenticated, unapproved, and inactive runs", async () => {
    await expect(
      beginGlobalPullRunWithDb({
        db: authorityDb(),
        authUid: null,
        serverNow: () => serverAnchor,
      }),
    ).rejects.toMatchObject({reason: "actor-unauthenticated"});

    await expect(
      beginGlobalPullRunWithDb({
        db: authorityDb({approved: false}),
        authUid: "operator-a",
        serverNow: () => serverAnchor,
      }),
    ).rejects.toMatchObject({reason: "actor-not-approved"});

    await expect(
      beginGlobalPullRunWithDb({
        db: authorityDb({contractOverrides: {state: "PREPARED"}}),
        authUid: "operator-a",
        serverNow: () => serverAnchor,
      }),
    ).rejects.toMatchObject({reason: "contract-incompatible"});
  });

  test("rejects a partial or reordered collection contract", async () => {
    await expect(
      beginGlobalPullRunWithDb({
        db: authorityDb({
          contractOverrides: {
            collections: GLOBAL_PULL_COLLECTIONS.slice(1),
          },
        }),
        authUid: "operator-a",
        serverNow: () => serverAnchor,
      }),
    ).rejects.toMatchObject({reason: "contract-collection-set-mismatch"});
  });
});

describe("global pull server stamp", () => {
  test("detects real writes but not the trigger's own stamp-only update", () => {
    const stamp = timestamp(serverAnchor);
    expect(
      shouldStampGlobalPullWrite(
        {updatedAt: "old", [GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: stamp},
        {updatedAt: "new", [GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: stamp},
      ),
    ).toBe(true);
    expect(
      shouldStampGlobalPullWrite(
        {updatedAt: "same"},
        {updatedAt: "same", [GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: stamp},
      ),
    ).toBe(false);
  });

  test("stamps an allowlisted create and ignores unrelated collections", async () => {
    const writes = [];
    const action = await applyGlobalPullServerClock({
      collectionId: "maintenance_records",
      change: {
        before: snapshot(undefined, writes),
        after: snapshot({updatedAt: "client-time"}, writes),
      },
      serverTimestamp: () => "SERVER_TIME",
    });
    expect(action).toBe("stamped");
    expect(writes).toEqual([
      {
        value: {[GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: "SERVER_TIME"},
        options: {merge: true},
      },
    ]);

    const ignored = await applyGlobalPullServerClock({
      collectionId: "users",
      change: {
        before: snapshot(undefined, writes),
        after: snapshot({isApproved: true}, writes),
      },
      serverTimestamp: () => "SERVER_TIME",
    });
    expect(ignored).toBe("ignored-collection");
    expect(writes).toHaveLength(1);
  });

  test("converts a hard delete into a stamped soft tombstone", async () => {
    const writes = [];
    const action = await applyGlobalPullServerClock({
      collectionId: "directives",
      change: {
        before: snapshot(
          {
            firestoreId: "directive-1",
            isDeleted: false,
            updatedAt: "client-time",
          },
          writes,
        ),
        after: snapshot(undefined, writes),
      },
      serverTimestamp: () => "SERVER_TIME",
    });

    expect(action).toBe("restored-tombstone");
    expect(writes).toEqual([
      {
        value: {
          firestoreId: "directive-1",
          isDeleted: true,
          updatedAt: "client-time",
          deletedAt: "SERVER_TIME",
          [GLOBAL_PULL_SERVER_UPDATED_AT_FIELD]: "SERVER_TIME",
        },
        options: {merge: false},
      },
    ]);
  });
});
