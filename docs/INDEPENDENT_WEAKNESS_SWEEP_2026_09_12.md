# Independent weakness sweep — 12 September 2026, revision 2

**Scope:** a self-directed pass over merged `main`, looking for weaknesses not
raised by the Build 27 business-flow audit or the correction rounds, with
attention to the presentation layer.

**Source examined:** `d2eac79e`, plus installed `riverpod-2.6.1` and
`flutter_lints-3.0.2` package sources.

**Nature of work:** read-only source and package-source analysis. No handset, no
production record, no deployment, and the Firestore emulator suites were not run
during this sweep.

## Revision 2 — what changed and why

Revision 1 was reviewed and several of its "confirmed" conclusions were wrong.
The corrections were verified here against package source before being accepted,
and they are material enough that revision 1 should not be used.

| Revision 1 said | Correct position |
| --- | --- |
| `.value` throws on error; swap to `valueOrNull` | **Incomplete and partly wrong.** After one successful load, an error retains the previous value and *both* accessors return stale data. The swap would not fix the more dangerous case |
| A raw Firestore error reaches the operator in `charge_abnormalities_screen.form.dart` | **Wrong.** Its catch supplies a plain-English fallback |
| 12 submit handlers lack a busy guard | **~Half were false positives.** Guards are supplied by a shared `WorkflowActionGuard` and by parent `_runBusyAction` wrappers, which a local-flag search cannot see |
| Version fencing means a double tap yields a conflict, not a duplicate | **Unsafe reassurance.** Creation commands mint fresh identities — see WS-03 |
| `only_throw_errors` would catch `StateError` control flow | **Wrong.** `StateError` extends `Error`, so the rule permits it |
| Accessibility is thin: 22 tap-target refs, 8 text-scaling refs | **Measured the wrong things.** Tap target size is set globally in the theme; text scaling is tested at 2× |
| The 2026-09-09 network block put providers into error | **Unproven.** Firestore serves from cache on connectivity loss and does not necessarily error the listener |

The emulator suites were not rerun here; prior passing evidence exists. The 107
host skips are 106 emulator tests plus one fixture generator.

---

## WS-01 — Account state is read without distinguishing its four cases

**Priority: high · Confirmed at one site · Review needed at others**

### The actual mechanism

From `riverpod-2.6.1/lib/src/common.dart`:

```dart
AsyncError<T> copyWithPrevious(AsyncValue<T> previous, {bool isRefresh = true}) {
  return AsyncError._(error, stackTrace: stackTrace, isLoading: isLoading,
    value: previous.valueOrNull, hasValue: previous.hasValue);
}
```

So the behaviour depends on whether a value was ever loaded:

| Provider condition | `.value` | `valueOrNull` |
| --- | --- | --- |
| Error, no prior value | **throws** | returns null |
| Error, after a prior value | **returns the stale value** | **returns the stale value** |
| Loading, no prior value | returns null | returns null |

Revision 1 reported only the first row and recommended swapping accessors. That
swap does not address the second row, which is the more dangerous one: an action
proceeding on a previously loaded account while verification is currently
failing.

### Confirmed instance

`inner_cover_lifecycle_screen.dart:176`, in the Inner Cover intake screen added
this month:

```dart
final user = ref.watch(currentAppUserProvider).value;
...
body: user == null || !user.isApproved ? <access-required panel> : <content>
```

There is no `isLoading` and no `hasError` branch, so three of the four cases are
mishandled: it throws during build with no prior value, renders content from a
stale account with one, and shows an "access required" lock while it is merely
still checking — which tells an approved operator they lack permission.

A second site, `inner_cover_lifecycle_screen.dart:1514` in `_acceptCover`, uses
`.value?.uid` — the null-aware access shows the author expected null — and its
intended message ("The account changed…") would be inaccurate for a read
failure even if it were reached.

### Extent, stated honestly

94 sites read `.value` from a provider; 73 read `currentAppUserProvider`; 59
have no `hasError` / `valueOrNull` / `hasValue` within the preceding 15 lines.

**These are 59 sites warranting review, not 59 established defects.** The
proximity heuristic cannot see guards supplied by an enclosing branch, a wrapper
widget or a parent. Revision 1 presented the count as though it were a defect
count.

The correctly guarded pattern exists at `abnormalities_home_screen.dart:40-59`
(`isLoading` → `hasError` → `.value`).

### Correction

Not an accessor swap. Introduce one account-state resolution that returns a
distinct result for **verifying**, **verification failed**, **signed out or
unapproved**, and **valid actor**, and have submit paths refuse on the first two
rather than proceed on retained data. Then review the 59 sites against it.

---

## WS-02 — Technical exception text reaches operators

**Priority: medium · Confirmed at specific sites · Count is a text pattern**

`ticket_screen.dart:476` is a confirmed example: a raw exception reaches an
operator acknowledging a ticket.

The **60 occurrences across 36 files** figure is reproducible as a text-pattern
count, but it is **not** 60 confirmed bad messages — some counted sites already
prefix a friendly sentence, and some exception types render acceptably.
`WorkflowException.toString()` produces
`WorkflowException(versionConflict: …)`, which does put a class name and enum in
front of the useful sentence.

The audience is a fitter deciding whether their work was recorded. The
distinction worth engineering is not prettier text but **"rejected" versus
"recorded, confirmation pending"** — they have opposite next actions.

**Correction:** one operator-message mapper returning an actionable sentence
plus a separate support code. The domain layer already writes good sentences;
presentation buries them.

---

## WS-03 — Retry after an uncertain outcome can create a second record

**Priority: high · Confirmed · Replaces revision 1's double-submit item**

Revision 1 claimed twelve unguarded submit handlers and reassured that version
fencing turns a double tap into a conflict. Both parts were wrong, and the
reassurance was the more serious error.

`inspection_programmes_screen.dart:1934`:

```dart
commandId: 'createInspectionCampaign_${const Uuid().v4()}',
aggregateId: 'inspection-campaign-${const Uuid().v4()}',
expectedVersion: 0,
```

Both identities are minted at invocation, against a brand-new aggregate at
version 0. **No version check can conflict**, because there is no prior version
to conflict with. If the first submission is accepted but its response is lost,
re-creating the campaign produces a second campaign.

This is the same defect class as BF-09 (operational-event creation generating a
fresh `eventId` per invocation), which the business-flow audit raised for
operational events and which was remediated there. It had not been reported for
inspection campaigns.

It is a **retry** risk, not a double-tap risk: two taps on one dialog do not
demonstrate it.

**Correction:** creation commands need an identity that survives the retry —
derived from the draft, or persisted before dispatch, as the Package B design
proposes for maintenance creation. Until then, the uncertain-outcome path for
campaign creation should not offer an unqualified "try again".

Busy protection itself is in better shape than revision 1 claimed:
`WorkflowActionGuard(busy: commandState.isLoading)` in lane classification, and
`_runBusyAction` with `if (_isBusy) return` in the job-module detail screen,
which also supplies busy state to its child form.

---

## WS-04 — Analyzer configuration is bare defaults

**Priority: medium · Observation**

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` and adds no
project rules. `use_build_context_synchronously` is enabled by that package and
the tree is clean.

Not enabled, and plausibly relevant:

| Rule | Relevance |
| --- | --- |
| `unawaited_futures` | Fire-and-forget async is how submitted work disappears |
| `cancel_subscriptions` | The stream combiners repaired in CR-05 are this shape |
| `close_sinks` | Four files create `StreamController`s |
| `avoid_dynamic_calls` | `noSuchMethod` fakes and JSON decoding are widespread |

Revision 1 also listed `only_throw_errors` with a `StateError` example. That was
wrong: `StateError` extends `Error`, so the rule permits it.

Revision 1 further implied these rules would have caught defects already found by
hand. **That was not demonstrated and is withdrawn.** The proposal stands on its
own terms — enabling a rule is cheap and permanent — but the benefit should be
established by enabling one and reading the output, not asserted.

`flutter_lints` is pinned at 3.0.2 against Flutter 3.44.

---

## WS-05 — Withdrawn as a deficiency; retained as a testing request

**Priority: low · Observation**

Revision 1 inferred weak accessibility from widget counts. That inference was
invalid:

- `baf_design_system.dart:150` sets `materialTapTargetSize:
  MaterialTapTargetSize.padded` **globally**, so the "22 explicit sizing
  references" figure measured something irrelevant.
- Seven test files configure text scaling, and `baf_ui_system_v2_test.dart`
  exercises `TextScaler.linear(2)`.

Counting `Semantics` widgets cannot establish accessibility quality.

What remains reasonable, as a request rather than a finding: exercise the
journeys an operator runs under time pressure — ticket creation, Inner Cover
acceptance, lane classification, job completion — with enlarged text and
TalkBack, on a device.

---

## Checked — sound

| Area | Finding |
| --- | --- |
| **Planned-job closure gate** | `complete_job_screen.workflow_gate.dart` uses `valueOrNull ?? []` but computes `hasLoadError` across all three providers and includes `!hasLoadError` in `canComplete`, with "Workflow readiness cannot be verified". A stream error **blocks** completion |
| **Charge-abnormality asset selection** | Its catch supplies a plain-English fallback for non-domain errors |
| **Critical-alarm controller** | Never closed, but a `static final .broadcast()` process-lifetime bus. Correct |
| **Ticket-creation double submit** | `_isSubmitting`, early return, `onPressed: null` |
| **Inner Cover acceptance double submit** | `_busy`, early return, `onPressed: null` |
| **Lane classification / job-module submit** | Guarded by shared `WorkflowActionGuard` and parent `_runBusyAction` |
| **Global tap target size** | `MaterialTapTargetSize.padded` in the theme |
| **`BuildContext` after `await`** | Lint enabled; analyzer clean |
| **Empty or swallowing catch blocks** | None found |
| **Leaked `StreamSubscription`s** | Every file creating one also cancels |

## Suggested priority

1. **Account-state handling** — one resolution distinguishing verifying,
   verification failed, signed out, and valid actor; then review the 59 sites.
2. **Inspection campaign creation identity** — survive a retry after an
   uncertain outcome.
3. **Operator messages** — "rejected" versus "recorded, confirmation pending".

Each needs a failure-path test, not only a happy-path one.

## Limits

No handset was operated. The emulator suites were not run during this sweep.
The link between the 2026-09-09 network block and provider error states is
**not established** — Firestore serves from cache on connectivity loss and does
not necessarily error a listener. This is a targeted presentation-and-contract
sweep and is not part of the outstanding whole-application audit.
