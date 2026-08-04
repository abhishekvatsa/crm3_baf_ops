# Firebase Client API Key Custody

## Decision

The three Firebase-created client API keys are public-by-design application
configuration, not data-access credentials. Keeping them in generated Firebase
configuration is correct when their live API restrictions remain limited to
Firebase-related services.

This tranche therefore does not rotate or delete the active keys. It removes
two obsolete one-off direct-write diagnostics that duplicated the browser key,
then makes any future copy outside the two generated files a CI failure.

## Source boundary

The only permitted tracked paths are:

- `android/app/google-services.json`
- `lib/firebase_options.dart`

The source audit requires:

- exactly three distinct client keys;
- five generated Flutter option occurrences;
- two Android configuration occurrences containing one Android key;
- every Android key to exist in the Flutter options;
- no matching key in any other tracked file;
- no raw key value in audit output.

`tools/direct_completion_denial_check.html` and
`tools/direct_completion_denial_check.mjs` were unreferenced production-facing
diagnostics with a fixed record target. Their denial behavior is already covered
by the governed Firestore Rules and emulator suites, so deletion removes stale
surface without reducing coverage.

## Live boundary

The readback uses the pinned Firebase CLI authentication path and Google API
Keys API. It obtains each key string only long enough to hash-bind live state to
the source set. Raw key values and the authenticated account identity are not
written to the receipt.

Strict PASS requires:

- exactly the Android, Browser and iOS keys auto-created by Firebase;
- exact equality between the three live key hashes and three source hashes;
- all keys active;
- the same exact 27-service Firebase API allowlist on every key;
- no method-level wildcard drift represented in the API response;
- the Generative Language API absent;
- exact platform restriction-object shapes.

The current platform restriction objects are Android, Browser and iOS
respectively, each with zero entries. This is recorded explicitly and is not
claimed as an app-client restriction. Adding application restrictions to
production keys remains a separate compatibility-tested change because an
incorrect package, certificate, bundle or referrer restriction can break a
correctly signed client.

## Security boundary

Firebase documents these client keys as safe to include in code when they are
restricted to Firebase-related APIs. Data authorization still depends on
Security Rules and backend IAM. App Check remains a distinct governed deferral;
this work neither activates it nor claims it closed.

The relevant official guidance is:

- https://firebase.google.com/docs/projects/api-keys
- https://firebase.google.com/support/guides/security-checklist

## GitHub alert disposition

After merge and a clean post-merge strict readback:

- alerts whose only locations are the two generated files may be resolved as
  Firebase client configuration false positives;
- the alert that also referenced the two obsolete diagnostic files may be
  resolved only after their deletion is present on the default branch;
- any later key occurrence outside the allowlist re-arms CI and requires fresh
  adjudication.

No key rotation, API restriction mutation, backend deployment, Rules deployment
or application distribution is part of this tranche.
