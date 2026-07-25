const fs = require('fs');
const path = require('path');

const rules = fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8');

const functionBlock = (name, nextMarker) => {
  const start = rules.indexOf(`function ${name}`);
  expect(start).toBeGreaterThanOrEqual(0);
  const end = nextMarker == null ? rules.length : rules.indexOf(nextMarker, start);
  return rules.slice(start, end < 0 ? rules.length : end);
};

describe('user document schema perimeter', () => {
  test('all user writes consume one exact document-shape validator', () => {
    const shape = functionBlock('validUserDocumentShape', 'function isApprovedUser');
    expect(shape).toContain('data.keys().hasAll([');
    expect(shape).toContain('data.keys().hasOnly([');
    for (const field of [
      'name',
      'email',
      'photoUrl',
      'roles',
      'isApproved',
      'fcmToken',
      'createdAt',
    ]) {
      expect(shape).toContain(`'${field}'`);
    }
    expect(functionBlock('validPendingUserCreate', 'function validSelfUserUpdate'))
      .toContain('validUserDocumentShape(request.resource.data)');
    expect(functionBlock('validSelfUserUpdate', 'function validAdminUserProfileUpdate'))
      .toContain('validUserDocumentShape(request.resource.data)');
    expect(functionBlock('validAdminUserProfileUpdate', '// ─────────────────────────────────────────────'))
      .toContain('validUserDocumentShape(request.resource.data)');
  });

  test('client authority mutations are denied while profile corrections remain scoped', () => {
    const block = functionBlock(
      'validAdminUserProfileUpdate',
      '// ─────────────────────────────────────────────',
    );
    expect(block).toContain("affectedKeys().hasOnly([");
    for (const field of ['name', 'email', 'photoUrl', 'fcmToken']) {
      expect(block).toContain(`'${field}'`);
    }
    expect(block).toContain(
      "request.resource.data.get('roles', []) == resource.data.get('roles', [])",
    );
    expect(block).toContain(
      "request.resource.data.get('isApproved', null) == resource.data.get('isApproved', null)",
    );

    const usersMatch = rules.slice(
      rules.indexOf('match /users/{userId}'),
      rules.indexOf('match /knowledge_base/{docId}'),
    );
    expect(usersMatch).toContain('allow create: if validPendingUserCreate(userId);');
    expect(usersMatch).not.toContain('validAdminUserWrite');
  });

  test('server authority receipts and deterministic audits are client-inaccessible', () => {
    expect(rules).toContain('match /user_authority_mutation_receipts/{docId}');
    expect(rules).toContain("!docId.matches('^server_authority_.*')");
  });

  test('roles are restricted to the canonical vocabulary and non-empty list', () => {
    const block = functionBlock('validUserRoleList', 'function validOptionalUserString');
    expect(block).toContain('roles is list');
    expect(block).toContain('roles.size() > 0');
    expect(block).toContain('roles.size() <= 10');
    expect(block).toContain('roles.hasOnly([');
    for (const role of [
      'admin', 'si', 'contractSupervisor', 'shiftSupervisor',
      'seniorElectrical', 'seniorMechanical', 'seniorInstrumentation',
      'seniorRefractory', 'refractory', 'operations',
    ]) {
      expect(block).toContain(`'${role}'`);
    }
  });

  test('optional profile values are typed and bounded', () => {
    const block = functionBlock('validUserDocumentShape', 'function isApprovedUser');
    expect(block).toContain("validOptionalUserString(data.get('photoUrl', null), 2048)");
    expect(block).toContain("validOptionalUserString(data.get('fcmToken', null), 4096)");
    expect(block).toContain("data.get('name', '').size() <= 160");
    expect(block).toContain("data.get('email', '').size() <= 320");
  });
});
