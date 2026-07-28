# S-08 Crash Report Privacy Boundary

Status: SOURCE_IMPLEMENTED

## Diagnosed defect

`AppLogger` described itself as sanitized, but `warning`, `error`, global
platform/zone handlers and `recordFlutterError` could pass original exception
objects and stack traces to Crashlytics. Truncating arbitrary strings did not
remove email addresses, tokens, URLs, local paths, plant evidence or other
content embedded in exception messages and context values.

## Source correction

`CrashReportSanitizer` is now the only conversion boundary for remote crash
diagnostics:

- an exception is replaced by `SanitizedCrashException`, which retains only a
  constrained runtime type and never retains the original object or message;
- a stack retains at most 64 source-controlled `package:` or `dart:` frames;
- absolute paths, file URIs, native frames and malformed lines become a fixed
  redaction marker;
- event labels, text context and Firebase user identifiers become deterministic
  opaque SHA-256 prefixes;
- numeric and boolean telemetry remains directly queryable;
- Flutter framework failures use sanitized `recordError` input instead of
  passing the original `FlutterErrorDetails` to `recordFlutterFatalError`.

The sanitizer is independent of Firebase initialization and has executable
tests using hostile email, token, URL and filesystem-path examples.

## Deliberate tradeoff

Crashlytics no longer receives readable arbitrary text. Source event labels and
text values can still be correlated by their opaque fingerprints, while key
names, safe source frames and numeric/boolean measurements preserve bounded
diagnostic value. This favors evidence privacy over remote message detail.

## Boundaries

Debug console output remains local and may show original errors during
development. This source tranche does not claim a deployed client, a captured
Crashlytics network payload, production collection behavior or pilot
authorization.

S-08 may transition to `CLOSED` only after exact-head pull-request CI and the
post-merge release gate pass on the resulting exact `main` commit.
