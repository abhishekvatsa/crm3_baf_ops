# brace-expansion compatibility adapter

`brace-expansion` 5.0.8 contains the upstream denial-of-service fix but changes
the CommonJS export from a callable function to an object containing `expand`.
Several locked CRM3 development and Firebase CLI dependencies still consume the
legacy callable interface.

This private adapter delegates all expansion work to the registry-custodied
5.0.8 package while exposing both interfaces:

- CommonJS callers receive a callable function with the 5.0.8 named exports.
- ESM callers receive the 5.0.8 default and named exports.

All three npm trust domains pin this directory as `brace-expansion` and use an
npm override so no vulnerable 1.x or 2.x implementation remains installed.
