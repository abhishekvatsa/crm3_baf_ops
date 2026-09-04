# Firebase CLI JSON compatibility

This is a local adapter, not an upstream stream-json release. It delegates all
JSON parsing, filtering, assembly, and nesting-depth protection to the pinned
upstream `stream-json@3.5.0`, installed as `stream-json-modern`.

Firebase CLI 15.22.4 uses the stream-json 1.x CommonJS path names and Node streams.
Upstream 3.5.0 uses lowercase ES module paths and exposes explicit `asStream` /
`withParserAsStream` entry points. These wrappers preserve only the interfaces
actually imported by this pinned CLI: parser, Pick, Filter, StreamArray, and
StreamObject. No parser logic is copied and no depth limit is disabled.

Node 22.12 or later is required for synchronous CommonJS access to the upstream
ES modules. The governed local and CI runtime is Node 22. A future Firebase CLI
upgrade must rerun `tools/dependencies/firebase_json_compat.test.mjs`, including
the exhaustive imported-path check. This adapter is deployment tooling only;
it is not shipped in the Android app or Cloud Functions bundle.

The fixed upstream dependency addresses
[GHSA-528h-pc64-c93x](https://github.com/uhop/stream-json/security/advisories/GHSA-528h-pc64-c93x).
