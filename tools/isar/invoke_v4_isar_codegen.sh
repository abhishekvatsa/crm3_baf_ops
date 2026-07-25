#!/usr/bin/env bash
set -euo pipefail
cd "${1:-.}"

machine="$(flutter --version --machine)"
python3 - "$machine" <<'PY'
import json, re, sys
info=json.loads(sys.argv[1])
if info.get('frameworkVersion') != '3.44.0':
    raise SystemExit(f"Flutter 3.44.0 required; found {info.get('frameworkVersion')}")
if not re.match(r'^3\.12\.0(?:\b|-)', str(info.get('dartSdkVersion',''))):
    raise SystemExit(f"Dart 3.12.0 required; found {info.get('dartSdkVersion')}")
PY
flutter pub get
dart run build_runner build --delete-conflicting-outputs
python3 tools/isar/verify_v4_isar_schema.py --release
flutter analyze
flutter test
echo 'PASS: pinned v4 Isar codegen, Flutter analysis and Flutter tests.'
