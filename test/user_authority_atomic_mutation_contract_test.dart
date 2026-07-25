import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin UI has no direct authority or audit writer', () {
    final source =
        File(
          'lib/features/admin/presentation/user_management_screen.dart',
        ).readAsStringSync();

    expect(source, contains('userAuthorityCommandServiceProvider'));
    expect(source, isNot(contains("_isLastApprovedAdmin")));
    expect(source, isNot(contains("arrayContains: AppRole.admin.name")));
    expect(source, isNot(contains("auditRepositoryProvider")));
    expect(
      source,
      isNot(contains(".collection('users').doc(user.uid).update")),
    );
  });

  test('authority service uses the dedicated callable contract', () {
    final source =
        File(
          'lib/features/admin/services/user_authority_command_service.dart',
        ).readAsStringSync();

    expect(
      source,
      contains("userAuthorityCallableName = 'mutateUserAuthority'"),
    );
    expect(source, contains("'expectedAuthorityDigest'"));
    expect(source, contains("'requestId'"));
    expect(source, contains("'reason'"));
  });
}
