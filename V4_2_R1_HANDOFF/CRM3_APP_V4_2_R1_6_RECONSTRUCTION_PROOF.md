# v4.2_R1.6 reconstruction proof

R1.6 was reconstructed from the exact R1.5 candidate tree. The accompanying binary-capable patch records the bounded delta.

Primary semantic changes:

- Firebase CLI `@hono/node-server`: `1.19.14` → `2.0.10`;
- exact lock URL/integrity update;
- Firebase CLI load smoke;
- nonblocking evidence continuation for tooling advisory verdicts, while final PASS remains prohibited.

No application or backend product source was intentionally changed.

Patch: `CRM3_APP_V4_2_R1_5_TO_R1_6_FIREBASE_CLI_HONO_AND_PARALLEL_VERDICT_HOTFIX.patch`
