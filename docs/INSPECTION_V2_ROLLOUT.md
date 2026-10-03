# Inspection labelled-reading rollout

Source preparation does not enable production authoring. The deployment-owned
`CRM_INSPECTION_V2_AUTHORING_ENABLED` environment value must be exactly `true`
to admit a new v2 definition version or a new campaign using a v2 definition.
Missing, false, malformed and differently cased values remain closed. Request
fields, roles, client versions and cached capabilities cannot open this gate.
The origin-bound workflow probe advertises `inspectionReadingsV2.authoring.v1`
only while that same server switch is open. Existing general capabilities and
v1 commands keep their contracts.

The app checks availability for each authoring dialog and freshly before a v2
save. Failed, loading, missing-capability and changed-account results cannot
enable creation. Failed checks retain form entries. Existing v2 records are not
filtered out; observations, corrections, findings and accepted-request replay
remain governed by their original authorities, immutable payloads and versions.
The server rechecks new authoring independently, including legacy callable use.
A request accepted before closure still replays its exact receipt after closure.

Before production opt-in, qualify and distribute v2-capable readers to every
supported operator/reviewer/export path and establish installed-client and
saved-work compatibility. Old v1-only readers can omit rejected definitions or
show incomplete campaigns: a writer minimum version alone does not protect
those readers. Keeping new definitions retired is also insufficient because
readers query the complete register. No universal minimum build is inferred.

Roll back by closing the authoring switch on a v2-capable deployment and keeping
v2-capable clients/readers available. Do not roll back to a v1-only reader or
rewrite/delete existing v2 records; existing programmes may still need valid
observations and corrections. Reopening new authoring requires the same reader
qualification and an explicit exact-source deployment decision.

Only the isolated `demo-crm3-ci-journeys` Functions configuration written by the
business-journey runner opts in automatically, to exercise the selected actual
DEV journey. Host tests restore their original process environment. This change
sets no production flag, deploys no backend and grants no release/signing authority.
