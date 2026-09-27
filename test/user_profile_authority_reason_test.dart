import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> profile() => {
    'name': 'Synthetic user',
    'email': 'synthetic@example.invalid',
    'roles': ['operations'],
    'isApproved': false,
    'accessDisposition': 'revoked',
    'authorityRevision': 4,
    'createdAt': DateTime.utc(2026, 9, 27),
  };

  test('absent and nullable authority reasons preserve withdrawn access', () {
    for (final fields in <Map<String, dynamic>>[
      {},
      {'lastAuthorityDecision': <String, dynamic>{}},
      {
        'lastAuthorityDecision': {'reason': null},
      },
    ]) {
      final user = AppUser.fromFirestore({...profile(), ...fields}, 'actor');
      expect(user.lastAuthorityReason, isNull);
      expect(user.isApproved, isFalse);
      expect(user.accessDisposition, 'revoked');
      expect(user.authorityRevision, 4);
    }
  });

  test('recorded authority reason text is preserved exactly', () {
    for (final reason in ['Reviewed withdrawal', '  recorded text  ', '']) {
      final user = AppUser.fromFirestore({
        ...profile(),
        'lastAuthorityDecision': {'reason': reason},
      }, 'actor');
      expect(user.lastAuthorityReason, reason);
      expect(user.isApproved, isFalse);
    }
  });

  test(
    'malformed nested reason gives a typed profile refusal, never a user',
    () {
      for (final reason in <Object>[
        42,
        false,
        <Object>[],
        <String, Object>{},
      ]) {
        expect(
          () => AppUser.fromFirestore({
            ...profile(),
            'lastAuthorityDecision': {'reason': reason},
          }, 'actor'),
          throwsA(
            isA<PersistedDataFormatException>()
                .having(
                  (error) => error.fieldName,
                  'field',
                  'lastAuthorityDecision.reason',
                )
                .having(
                  (error) => error.message,
                  'source',
                  contains('users/actor'),
                ),
          ),
        );
      }
    },
  );

  test('a valid reason cannot relax malformed or contradictory authority', () {
    for (final invalid in <Map<String, dynamic>>[
      {'authorityRevision': '4'},
      {'authorityRevision': -1},
      {'accessDisposition': 'approved'},
    ]) {
      expect(
        () => AppUser.fromFirestore({
          ...profile(),
          ...invalid,
          'lastAuthorityDecision': {'reason': 'Reviewed'},
        }, 'actor'),
        throwsFormatException,
      );
    }
  });
}
