# CRM3 v4.2_R1.9 custody-regression hotfix

## Scope

R1.9 is a bounded laboratory-custody correction built from R1.8.

It restores the exact ten Flutter platform registrant paths that were present in
R1.7 but accidentally dropped while R1.8 introduced semantic Isar continuity.

## Restored classification

The following exact additions are classified as
`flutter-platform-registrant-added` and remain visible with SHA-256 evidence:

- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- `ios/Runner/GeneratedPluginRegistrant.h`
- `ios/Runner/GeneratedPluginRegistrant.m`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugin_registrant.h`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`

No wildcard, directory-wide ignore, or silent exclusion is used.

## Regression guard

`v4_2_r1_canonical_audit.py` now verifies that:

- the exact ten-path set exists;
- the `flutter-platform-registrant-added` classification exists;
- classification is performed only by membership in the exact set.

## Preserved R1.8 direction

The R1.8 semantic Isar-continuity verifier is unchanged. It continues to fail on
collection-ID changes, missing inherited properties, inherited property type
changes, inherited index changes, and duplicate collection IDs, while reporting
generator-position movement explicitly.

## Excluded changes

R1.9 does not change Flutter product logic, Functions, Firestore Rules, Isar
models, dependencies, Android build configuration, Firebase identities,
programme authority, or deployment permissions.
