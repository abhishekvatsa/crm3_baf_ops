# Security and credential custody

## Firebase client API keys

Firebase client API keys identify this Firebase project to Firebase services.
They are not backend authorization credentials and are expected in generated
client configuration.

Only these tracked files may contain Firebase client API key values:

- `android/app/google-services.json`
- `lib/firebase_options.dart`

The source-custody test scans all tracked files and fails if a key is copied to
another path, either generated file disappears, the platform key sets diverge,
or the expected key count changes. Evidence contains hashes and counts only.

The live readback separately requires the source key set to match exactly three
active Firebase-created keys. Every key must have the exact Firebase API
allowlist in `release/firebase-client-api-key-policy.json`; the Generative
Language API is explicitly forbidden. Application-restriction object types and
entry counts are also recorded exactly, but empty entries are not represented
as an authorization control.

See the official Firebase guidance:

- https://firebase.google.com/docs/projects/api-keys
- https://firebase.google.com/support/guides/security-checklist

## Values that must remain private

Do not commit or publish service-account private keys, Android signing keys or
passwords, OAuth client secrets, FCM server keys, access or refresh tokens,
private HMAC material, or user passwords. Firebase client API keys do not relax
this rule for any other credential type.

## Authorization boundary

Firebase Security Rules, backend IAM and callable authorization control access
to application data. App Check is a separate anti-abuse control. Passing the
client-key custody checks does not close, activate or bypass any App Check gate.

## Alert adjudication

A GitHub secret-scanning alert for an allowed generated Firebase client key may
be resolved as a false positive only after both source custody and strict live
restriction readback pass. A key found anywhere else remains a failure until
the extra copy is removed and the tracked-file audit passes.
