import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/core/validation/charge_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('five-digit charge contract is shared by input and persisted reads', () {
    expect(parseOptionalChargeNumber('10000'), 10000);
    expect(parseOptionalChargeNumber('99999'), 99999);
    expect(parseOptionalChargeNumber('9999'), isNull);
    expect(parseOptionalChargeNumber('100000'), isNull);
    expect(readRequiredPersistedChargeNumber(54321, field: 'chargeNo'), 54321);
    expect(
      () => readRequiredPersistedChargeNumber(1234, field: 'chargeNo'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => readRequiredPersistedChargeNumber(123456, field: 'chargeNo'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
