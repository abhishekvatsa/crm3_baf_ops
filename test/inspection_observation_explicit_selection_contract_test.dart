import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new boolean and choice observations require an explicit selection', () {
    final source = File(
      'lib/features/inspections/presentation/'
      'inspection_programmes_editors.dart',
    ).readAsStringSync();

    expect(source, contains('_booleanValue = correction?.booleanValue;'));
    expect(source, contains('_choiceValue = correction?.choiceValue;'));
    expect(source, contains("'Choose Yes or No.'"));
    expect(source, contains("'Choose an observed value.'"));
    expect(source, isNot(contains('correction?.booleanValue ?? false')));
    expect(
      source,
      isNot(contains('widget.campaign.definition.choiceValues.firstOrNull')),
    );
  });
}
