import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stage 2D-C production client platform scope remains explicit', () {
    final file = File('release/client-platform-scope.prod.json');
    expect(file.existsSync(), isTrue);

    final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    expect(payload['schemaVersion'], 2);
    expect(payload['projectId'], 'crm3-baf-ops-b8638');
    expect(payload['declarationStatus'], 'GOVERNED_PRODUCTION_RELEASE_SCOPE');
    expect(payload['currentReleasePlatforms'], <String>['android']);
    expect(payload['futurePlatforms'], <String>['web']);
    expect(payload['excludedPlatforms'], <String>[
      'ios',
      'macos',
      'windows',
      'linux',
      'fuchsia',
    ]);
    expect(payload['appCheckCurrentEnforcementEligiblePlatforms'], <String>[
      'android',
    ]);
    expect(payload['providerPlanningAuthorizedPlatforms'], <String>['android']);

    final decisions = payload['platformDecisions'] as Map<String, dynamic>;
    expect(
      (decisions['windows'] as Map<String, dynamic>)['classification'],
      'EXCLUDED_FROM_CURRENT_RELEASE',
    );
    expect(
      (decisions['web'] as Map<String, dynamic>)['classification'],
      'FUTURE_PLATFORM',
    );
  });
}
