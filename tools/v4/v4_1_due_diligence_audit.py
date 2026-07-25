#!/usr/bin/env python3
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
failures = []
passes = []

def check(name, condition, detail=''):
    (passes if condition else failures).append((name, detail))
    print(f"{'PASS' if condition else 'FAIL'} | {name}" + (f" | {detail}" if detail else ''))

firebase = json.loads((ROOT / 'firebase.json').read_text(encoding="utf-8"))
policy = json.loads((ROOT / 'release/production-release-policy.json').read_text(encoding="utf-8"))
receipt = json.loads((ROOT / 'release/approvals/firebase-registration-receipt.json').read_text(encoding="utf-8"))
android_id = firebase['flutter']['platforms']['android']['default']['appId']
dart_id = firebase['flutter']['platforms']['dart']['lib/firebase_options.dart']['configurations']['android']
expected_id = policy['firebaseAndroidApp']['firebaseAppId']
check('Firebase Android app identity is single-valued',
      android_id == dart_id == expected_id == receipt['firebaseAppId'],
      f'appId={android_id}')

rules = (ROOT / 'firestore.rules').read_text(encoding="utf-8")
shape_start = rules.find('function validUserDocumentShape')
shape_end = rules.find('function isApprovedUser', shape_start)
shape = rules[shape_start:shape_end]
admin_start = rules.find('function validAdminUserWrite')
admin_end = rules.find('// ─────────────────────────────────────────────', admin_start)
admin = rules[admin_start:admin_end]
required_fields = ['name','email','photoUrl','roles','isApproved','fcmToken','createdAt']
check('Admin user writes use exact top-level whitelist',
      shape_start >= 0
      and 'keys().hasOnly([' in shape
      and all(f"'{f}'" in shape for f in required_fields)
      and admin_start >= 0
      and 'validUserDocumentShape(request.resource.data)' in admin)

mapper = (ROOT / 'lib/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart').read_text(encoding="utf-8")
mapper_fields = [
    'priorityKey','raisedByUid','raisedByName','raisedAt','acknowledgedByUid',
    'acknowledgedByName','acknowledgedAt','compliedByUid','compliedByName',
    'compliedAt','complianceNote','confirmedByUid','confirmedByName','confirmedAt',
    'confirmNote','dueMarkedByUid','dueMarkedByName','dueMarkedAt',
    'counterDecisionByUid','counterDecisionByName','counterDecisionAt',
    'counterDecisionNote','lastCorrectionByUid','lastCorrectionByName',
    'lastCorrectionAt','lastCorrectionReason','escalationTier','lastEscalatedAt',
    'acknowledgementDueAt','complianceDueAt','isDeleted','deletedAt',
    'deletedByUid','deletedByName','deleteReason','metadataJson'
]
check('Compliance Firestore mapper covers complete lifecycle projection',
      'complianceRequestRecordFromFirestoreData' in mapper and all(f'..{f} =' in mapper for f in mapper_fields),
      f'fields={len(mapper_fields)}')

adapter = (ROOT / 'functions/src/maintenanceWorkflow/firebaseStore.ts').read_text(encoding="utf-8")
adapter_test = (ROOT / 'functions/test/maintenanceWorkflowFirebaseStore.test.js').read_text(encoding="utf-8")
check('Workflow persistence adapter converts ISO lifecycle deadlines to Timestamp',
      'admin.firestore.Timestamp.fromDate(new Date(value))' in adapter
      and 'nextEscalationAt' in adapter_test
      and 'acknowledgementDueAt' in adapter_test
      and 'complianceDueAt' in adapter_test)

rules_test = (ROOT / 'functions/test/userRulesHardeningSource.test.js').read_text(encoding="utf-8")
check('Admin whitelist regression guard exists', 'hasOnly' in rules_test and 'createdAt' in rules_test)

mapper_test = ROOT / 'test/maintenance_workflow/compliance_request_mapper_test.dart'
check('Compliance projection test source exists', mapper_test.exists() and 'escalationTier' in mapper_test.read_text(encoding="utf-8"))

readme = (ROOT / 'README.md').read_text(encoding="utf-8")
check('Root operational documentation replaces Flutter boilerplate',
      'CRM-III BAF Ops' in readme and 'successor' in readme.lower()
      and 'This project is a starting point for a Flutter application' not in readme)

custody = ROOT / 'docs/FIREBASE_CONFIGURATION_CUSTODY.md'
check('Firebase configuration custody boundary is explicit',
      custody.exists() and expected_id in custody.read_text(encoding="utf-8"))

adjudication = ROOT / 'docs/V4_1_DUE_DILIGENCE_ADJUDICATION.md'
check('Review adjudication preserves successor-programme authority',
      adjudication.exists() and 'successor architecture' in adjudication.read_text(encoding="utf-8"))

print(f'SUMMARY | pass={len(passes)} fail={len(failures)} total={len(passes)+len(failures)}')
sys.exit(1 if failures else 0)
