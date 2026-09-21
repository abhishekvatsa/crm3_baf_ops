# Kotlin and existing CodeQL coverage

`.github/workflows/codeql.yml` scans Actions, JavaScript/TypeScript, Python and
Java/Kotlin. Kotlin uses the application's pinned Flutter/Android toolchain and
a fresh Gradle build inside CodeQL tracing. It builds an isolated debug package
without production signing or a live Firebase configuration; the package is
neither installed nor uploaded. The query and strict CSV verifier require actual
method bodies from the app's `MainActivity.kt` before security-result upload.

The CodeQL action is pinned to an immutable commit. Its bundled CLI and query
libraries advance according to the action's supported release selection; each
Kotlin proof records the actual CLI version, source commit and source hash.
The proof query resolves libraries from that same bundle, without independently
installing a latest query pack. SARIF and extraction evidence are retained for
14 days; full source databases and built packages are not artifact outputs.

## Initial migration

1. Record the current default-setup settings. On 21 September 2026 these were
   configured, default query suite, remote threat model, weekly schedule,
   standard runner, languages Actions, JavaScript/TypeScript and Python.
2. Set temporary repository variable `CRM3_CODEQL_PREVIEW=true` before first
   publishing the workflow. Default scanning stays active. The advanced workflow
   performs analysis and extraction verification but uploads no SARIF/database.
3. Review the pull request, all four successful preview jobs, and the Kotlin
   method-body proof. Merge after the required repository checks pass; verify
   the preview on the actual main commit too.
4. Disable default setup, remove the temporary variable, and dispatch this
   workflow on that main commit. Variable absence enables normal upload.
5. Read back accepted code-scanning analyses for all four languages at the exact
   main SHA. Require no analysis errors and inspect alerts. Preview success alone
   is not publication or coverage evidence.

If publication fails after the switch, restore the recorded default setup for
the three established languages, reinstate preview mode, and investigate without
claiming Kotlin coverage. No permanent preview switch should remain after a
successful transition. Routine push, pull-request and weekly triggers then run
the advanced workflow normally.

## Local verifier checks

Run `python3 -m unittest discover -s tools/security/codeql -p 'test_*.py'`.
These tests verify evidence rejection and commit binding. They do not establish
that Kotlin was extracted; only the actual traced CI build and query do that.
