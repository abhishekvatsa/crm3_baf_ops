# Functions Clean Emit Custody

Status: SOURCE_AND_CI_IMPLEMENTED

## Closed defect

The Functions build previously invoked `tsc` without first removing `functions/lib`.
TypeScript overwrites outputs for current sources but does not remove JavaScript or
source maps left by deleted or renamed sources. A locally prepared deployment could
therefore retain an obsolete module even when the TypeScript build succeeded.

## Source control

`functions/package.json` now separates:

- `typecheck`: a no-emit TypeScript gate;
- `clean`: removal of the configured output directory;
- `build`: clean, compile, exact emitted-output audit and callable inventory audit;
- `test:emitted-output-custody`: negative regression coverage.

`functions/tools/emitted_output_custody.mjs` derives the expected output set from the
TypeScript compiler API and the checked-in `tsconfig.json`. It rejects missing files,
orphaned files, output outside the configured child directory and unsupported
filesystem entries. The clean command removes that same compiler-resolved directory.

The canonical local laboratory now calls `npm run typecheck` directly for its early
no-emit gate. It no longer appends TypeScript arguments to the compound build script.

## Regression boundary

The focused tests prove:

1. exact source/output correspondence succeeds;
2. deleting a source while retaining its JavaScript and source map fails;
3. a missing emitted file fails;
4. clean removes the entire configured output directory.

## Nonclaims

This control does not deploy Functions, remove the latent legacy
`functions/index.js` source file or authorize any runtime or pilot transition.
