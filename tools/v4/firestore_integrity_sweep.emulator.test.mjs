import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../..',
);
const PROJECT_ID = 'demo-gate1b';
const ADMIN_UID = 'gate1b-emulator-admin';
const HMAC_KEY = 'gate-1b-emulator-key-with-at-least-32-bytes';

const require = createRequire(import.meta.url);
const admin = require(path.join(ROOT, 'functions/node_modules/firebase-admin'));

function requireEmulators() {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'FIRESTORE_EMULATOR_HOST is required.',
  );
  assert.ok(
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
    'FIREBASE_AUTH_EMULATOR_HOST is required.',
  );
}

test('actual CLI joins Firestore and Auth into a privacy-safe pass', async () => {
  requireEmulators();
  const app = admin.initializeApp(
    {projectId: PROJECT_ID},
    `gate1b-emulator-test-${process.pid}`,
  );
  const output = path.join(
    os.tmpdir(),
    `crm3_gate1b_emulator_${process.pid}_${Date.now()}.json`,
  );

  try {
    await app.auth().createUser({
      uid: ADMIN_UID,
      email: 'gate1b-emulator-admin@example.invalid',
      displayName: 'Gate 1B Emulator Admin',
      disabled: false,
    });
    await app.firestore().collection('users').doc(ADMIN_UID).set({
      name: 'Gate 1B Emulator Admin',
      email: 'gate1b-emulator-admin@example.invalid',
      roles: ['admin'],
      isApproved: true,
      photoUrl: null,
      fcmToken: null,
      createdAt: admin.firestore.Timestamp.fromDate(
        new Date('2026-07-26T00:00:00Z'),
      ),
    });

    const execution = spawnSync(
      process.execPath,
      [
        path.join(ROOT, 'tools/v4/firestore_integrity_sweep.mjs'),
        '--project',
        PROJECT_ID,
        '--output',
        output,
      ],
      {
        cwd: ROOT,
        encoding: 'utf8',
        env: {
          ...process.env,
          CRM3_GATE1B_HMAC_KEY: HMAC_KEY,
        },
      },
    );
    assert.equal(
      execution.status,
      0,
      `stdout=${execution.stdout}\nstderr=${execution.stderr}`,
    );

    const reportText = fs.readFileSync(output, 'utf8');
    const report = JSON.parse(reportText);
    assert.equal(
      report.decision,
      'PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY',
    );
    assert.equal(report.readOnly, true);
    assert.equal(report.cloudMutationCapability, 'NONE');
    assert.equal(report.coverage.firestoreUserCount, 1);
    assert.equal(report.coverage.firebaseAuthUserCount, 1);
    assert.equal(report.summary.enabledApprovedAdminCount, 1);
    assert.equal(report.summary.blockingFindingCount, 0);
    assert.equal(report.subjects.length, 1);
    assert.match(
      report.subjects[0].subjectPseudonym,
      /^hmac256:[0-9a-f]{64}$/,
    );
    assert.equal(reportText.includes(ADMIN_UID), false);
    assert.equal(reportText.includes('example.invalid'), false);
    assert.equal(reportText.includes(HMAC_KEY), false);
    assert.ok(fs.existsSync(`${output}.sha256`));
  } finally {
    for (const file of [output, `${output}.sha256`]) {
      if (fs.existsSync(file)) fs.unlinkSync(file);
    }
    await app.delete();
  }
});
