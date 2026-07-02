# Stage 2D security source rollout

## Purpose

This source change prepares four controls together without activating production:

1. Flutter App Check client source.
2. App Check enforcement for `getBackendReleaseIdentity`.
3. A dedicated runtime service-account source binding for that callable.
4. Lockfile remediation of the `form-data` and `protobufjs` advisories.

The source branch, merge, IAM, App Check registration, client release, Function
deployment, and removal of the default Compute service account's `roles/editor`
binding remain distinct evidence gates.

## Source behaviour

### Flutter client

App Check initialization runs immediately after `Firebase.initializeApp()` and
before Crashlytics, Messaging, Firestore, Functions, or other Firebase services.

The source is intentionally staged off by default:

```text
CRM3_APP_CHECK_ENABLED=false
```

A governed build enables it with:

```text
--dart-define=CRM3_APP_CHECK_ENABLED=true
```

Provider selection is explicit:

| Platform | Debug build | Non-debug build |
|---|---|---|
| Android | Debug provider | Play Integrity |
| iOS/macOS | Debug provider | App Attest with DeviceCheck fallback |
| Web | Debug provider | reCAPTCHA v3; site key required |
| Windows | Debug provider only | Fails closed |
| Linux/Fuchsia | Unsupported | Fails closed |

The web release key is supplied only at build time:

```text
CRM3_APP_CHECK_WEB_RECAPTCHA_V3_SITE_KEY
```

An optional debug token may be supplied only for trusted development builds:

```text
CRM3_APP_CHECK_DEBUG_TOKEN
```

Do not commit a debug token or reCAPTCHA site key into source. Do not distribute
debug-provider builds to untrusted users.

### Callable enforcement

Only `getBackendReleaseIdentity` receives the Stage 2D callable security options:

```text
enforceAppCheck=true
consumeAppCheckToken=false
serviceAccount=crm3-backend-identity-runtime@crm3-baf-ops-b8638.iam.gserviceaccount.com
```

Replay-token consumption remains disabled because it adds a separate backend
verification call and provider quota/latency considerations. Enabling App Check
does not replace Firebase Authentication or the approved-user Firestore gate.

### Dedicated runtime identity

The dedicated account is deliberately referenced before it exists. Source can
be reviewed and merged, but deployment must fail until the separately governed
IAM campaign creates the exact account and grants only the permissions proven
necessary.

The identity callable reads `users/{uid}` through the Admin SDK and emits normal
runtime logs. The IAM campaign must derive and test minimum roles rather than
copy the default Compute account's broad project roles.

Other Functions still use the default Compute account. Therefore removal of
project `roles/editor` from that account is prohibited until every remaining
Function has been migrated or independently proven against a replacement role
set.

## Required order after source merge

1. Create the exact dedicated service account.
2. Grant the deployment principal `iam.serviceAccounts.actAs` on that account.
3. Derive and grant only runtime permissions needed by the identity callable.
4. Register App Check providers for every supported release app.
5. Build and distribute App Check-enabled clients.
6. Observe App Check metrics and prove legitimate-client coverage.
7. Deploy only `getBackendReleaseIdentity` from the exact merged source.
8. Verify:
   - valid authenticated registered clients succeed;
   - missing or invalid App Check tokens are rejected;
   - unapproved users remain rejected;
   - backend identity output remains exact;
   - runtime service account is the dedicated account;
   - no other Function changed.
9. Reassess default Compute `roles/editor` only after the remaining Function fleet
   has its own least-privilege migration evidence.

## Windows limitation

`firebase_app_check` 0.4.5 exposes only a debug provider on Windows. The source
therefore refuses App Check-enabled non-debug Windows startup. A Windows
production release must remain outside the enforcement population until a
governed custom attestation design exists.

## Public callable transport

The Cloud Run invoker may remain `allUsers` for Firebase callable transport.
Authentication, approved-user authorization, and App Check are application-layer
controls. This source change does not remove or alter Cloud Run IAM.

## Dependency remediation

The governed Functions candidate changes only `functions/package-lock.json`.
It:

- upgrades `form-data` from 2.5.5 to 2.5.6;
- upgrades `protobufjs` from 7.5.8 to 7.6.4;
- removes the obsolete `@protobufjs/inquire` node;
- preserves `functions/package.json`;
- passes the complete Functions test suite;
- reports zero npm audit vulnerabilities.

The root development-tooling manifest also pinned `protobufjs` 7.5.8 through
an override. The source candidate updates that override and `package-lock.json`
to 7.6.4. Root audit then has zero high or critical findings, while one low
`@babel/core` finding and one moderate `js-yaml` finding remain explicitly open
as non-deployed tooling findings.

The broad patch-level Functions lockfile refresh produced by `npm audit fix
--package-lock-only` is retained and tested as one atomic candidate.
