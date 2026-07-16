import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _functionSlice(String source, String functionName) {
  final start = source.indexOf('function $functionName(');
  if (start < 0) {
    throw StateError('Missing Firestore Rules function: $functionName');
  }

  final next = source.indexOf('\n    function ', start + 1);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  test(
    'P-02 binds pending self-registration and self-update to verified token email',
    () {
      final rules = File('firestore.rules').readAsStringSync();

      final tokenHelper = _functionSlice(rules, 'hasVerifiedTokenEmail');
      expect(tokenHelper, contains('request.auth.token.email is string'));
      expect(
        tokenHelper,
        contains('request.auth.token.email_verified == true'),
      );

      final matchHelper = _functionSlice(rules, 'requestEmailMatchesToken');
      expect(
        matchHelper,
        contains('request.resource.data.email == request.auth.token.email'),
      );

      final pendingCreate = _functionSlice(rules, 'validPendingUserCreate');
      expect(pendingCreate, contains('requestEmailMatchesToken()'));

      final selfUpdate = _functionSlice(rules, 'validSelfUserUpdate');
      expect(selfUpdate, contains('requestEmailMatchesToken()'));
    },
  );

  test('P-02 emulator contract is consolidated into the existing Rules suite', () {
    final emulatorTest =
        File('test/firestore.rules.test.js').readAsStringSync();

    expect(
      emulatorTest,
      contains('describe("P-02 pending-user Firebase token identity binding"'),
    );

    for (final requiredCase in <String>[
      'verified matching token email may create the pending self profile',
      'mismatched client-asserted email is rejected',
      'missing token email is rejected',
      'unverified token email is rejected',
      'verified user may correct a legacy pending email to the token email',
      'self update cannot replace email with a value different from the token',
      'admin correction path remains available and is not bound to admin email',
    ]) {
      expect(emulatorTest, contains(requiredCase));
    }
  });

  test('existing pending-user fixtures supply verified token claims', () {
    final emulatorTest =
        File('test/firestore.rules.test.js').readAsStringSync();

    expect(emulatorTest, contains('function dbAs(uid, token = {})'));
    expect(
      RegExp(
        r'const db = dbAs\("newUser", \{\s*'
        r'email: "new@test\.local",\s*'
        r'email_verified: true,\s*'
        r'\}\);',
        multiLine: true,
      ).allMatches(emulatorTest).length,
      greaterThanOrEqualTo(3),
    );
  });
}
