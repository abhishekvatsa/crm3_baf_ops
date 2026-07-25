# CRM3 v4.2_R1.8 evidence adjudication

## Submitted evidence

The submitted laboratory archive `CRM3_V42_R1_8_CANONICAL_LOCAL_LAB_20260722_224952.zip`
has SHA-256:

`DB18B9FE2C1CACBC0967D45B88ADF589E79EBE89A2ACC794FB3F2BD6D3C786C4`

The evidence states that stages 01 through 16 passed. Stage 17 failed before the
semantic Isar-continuity verifier could execute.

## Exact finding

The R1.8 source package accidentally omitted the exact ten-path Flutter
platform-registrant classification that R1.7 had introduced. Authentic
`flutter pub get` and Isar code generation therefore created the same ten
standard Flutter platform registrants, but the R1.8 custody verifier classified
all ten as `unexpected-non-ephemeral-file-added`.

This is a packaging/reconciliation regression in the laboratory verifier. It is
not a Flutter application, Functions, Rules, Isar-model, dependency, or Firebase
runtime failure.

## Proven passes retained

The run independently proved:

- candidate and disposable-workspace manifest custody;
- root, Functions, and Firebase CLI dependency installation;
- zero known vulnerabilities in all three audited npm trees;
- Functions TypeScript compilation;
- Firebase CLI version/load smoke;
- Flutter dependency resolution;
- authentic Isar generation under Flutter 3.44.0 / Dart 3.12.0.

## Safety result

The evidence records no Git remote mutation, Firebase deployment, production
data mutation, device uninstall, or device-data clear.

## Governing correction

R1.9 restores the exact R1.7 ten-path registrant classification while retaining
the R1.8 semantic Isar-continuity verifier unchanged. A static audit now prevents
the registrant classification from being omitted again.
