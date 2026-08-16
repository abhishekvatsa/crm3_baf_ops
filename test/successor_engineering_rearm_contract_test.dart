import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

void main() {
  test(
    'successor engineering is re-armed without changing Build 11 authority',
    () {
      final ledger = _readObject('governance/programme-ledger.json');
      final sealedDecision =
          (ledger['programmeDecision'] as Map).cast<String, dynamic>();
      final successorDecision =
          (ledger['successorEngineeringDecision'] as Map)
              .cast<String, dynamic>();
      final authority = _readObject(
        'governance/successor-engineering-rearm-2026-08-16.json',
      );

      expect(
        sealedDecision['decisionScope'],
        'SEALED_BUILD11_STAGE2D_PROGRAMME',
      );
      expect(
        sealedDecision['pilotHandout'],
        'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
      );
      expect(sealedDecision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');
      expect(successorDecision['status'], 'RE_ARMED_SOURCE_AND_CI');
      expect(successorDecision['releaseAuthority'], 'NONE_SOURCE_AND_CI_ONLY');
      expect(successorDecision['sealedBuild11AuthorityChanged'], isFalse);
      expect(authority['status'], 'ACTIVE_SOURCE_AND_CI_ONLY');
      expect(
        _strings(authority['notAuthorized']),
        containsAll(<String>[
          'production Firebase deployment',
          'App Check or Play Integrity activation',
          'reuse of the Build 11 package identity',
          'unrestricted distribution',
        ]),
      );
    },
  );

  test(
    'current successor index distinguishes every release authority plane',
    () {
      final state = _readObject('release/current-successor-state.json');
      final localStore = (state['localStore'] as Map).cast<String, dynamic>();
      final backend = (state['deployedBackend'] as Map).cast<String, dynamic>();
      final appCheck = (state['appCheck'] as Map).cast<String, dynamic>();
      final client = (state['client'] as Map).cast<String, dynamic>();
      final device = (state['deviceAndPilot'] as Map).cast<String, dynamic>();

      expect(
        state['status'],
        'SUCCESSOR_SOURCE_CAMPAIGN_ACTIVE_NOT_RELEASE_AUTHORITY',
      );
      expect(localStore['schemaVersion'], 6);
      expect(backend['currentSuccessorSourceDeployment'], 'NOT_PROVED');
      expect(appCheck['mutatingCallableSourceDefault'], isFalse);
      expect(client['successorBuild'], 'NOT_FROZEN_NOT_NUMBERED_NOT_SIGNED');
      expect(device['currentSuccessorPilotHandout'], 'NOT_AUTHORIZED');
      expect(device['unrestrictedDistribution'], 'NO_GO');
    },
  );
}
