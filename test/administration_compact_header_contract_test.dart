import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact Administration header consolidates support actions', () {
    final source =
        File(
          'lib/features/admin/presentation/admin_data_browser.dart',
        ).readAsStringSync();

    expect(source, contains('MediaQuery.sizeOf(context).width < 720'));
    expect(source, contains("ValueKey('admin-support-menu')"));
    expect(source, contains("tooltip: 'Administration support tools'"));
    expect(source, contains('if (compactHeader && _selectedTab != 5)'));
    expect(source, contains("ValueKey('asset-hierarchy-sync-header')"));
    expect(source, contains('child: SyncStatusIndicator()'));
  });
}
