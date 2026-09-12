# Independent weakness sweep — 12 September 2026

**Scope:** a self-directed pass over the merged `main`, looking for weaknesses
not raised by the Build 27 business-flow audit or the correction rounds, with
particular attention to the presentation layer, which none of the previous
reviews examined.

**Source examined:** `46425b6a` (merged `main`), plus the installed
`riverpod-2.6.1` and `flutter_lints-3.0.2` package sources.

**Nature of work:** read-only source analysis and package-source verification.
No handset was operated, no production record read, no deployment performed,
and the Firestore emulator suites were not run. Where a failure sequence is
stated, it follows from the inspected control flow; it is not a claim that the
sequence was executed.

## Evidence classification used

| Class | Meaning |
| --- | --- |
| **Confirmed** | Verified by reading the exact source, including package internals where behaviour depends on them |
| **Derived** | The failure sequence follows from inspected control flow; not executed here |
| **Observation** | A measured property of the codebase, offered for judgement rather than as a defect |
| **Checked — sound** | Examined and found correct. Recorded so it is not re-examined |

---

## WS-01 — `AsyncValue.value` throws where the code expects null

**Priority: high · Confirmed · 59 unguarded call sites**

### The mechanism

`riverpod-2.6.1/lib/src/common.dart:493`:

```dart
T? get value {
  if (!hasValue) {
    throwErrorWithCombinedStackTrace(error, stackTrace);
  }
  return _value;
}
```

The getter is typed `T?`, which reads as "may be null". When the provider is in
an **error** state it does not return null — it rethrows the provider's error.
`valueOrNull` is the accessor that returns null.

### Why this is not theoretical here

`currentAppUserProvider` is a `StreamProvider` over
`firestore.collection('users').doc(uid).snapshots()`, and its stream plumbing
**explicitly forwards errors** via `controller.addError(error, stackTrace)` at
two sites in `auth_provider.dart`. A Firestore permission error, an offline
error, or a withdrawn network puts it into the error state.

That is the condition of the 2026-09-09 incident.

### The code is written for the wrong contract

`inner_cover_lifecycle_screen.dart:1514`, inside `_acceptCover`:

```dart
if (ref.read(currentAppUserProvider).value?.uid != user.uid) {
  throw const AssetHierarchyException(
    'The account changed. Return to the original account to check this acceptance.',
  );
}
```

The null-aware `?.` shows the author expected null. What actually happens when
the user document cannot be read:

| | Intended | Actual |
| --- | --- | --- |
| `.value` | returns null | throws the Firestore error |
| Operator sees | "The account changed…" | a raw platform error |

Both are wrong, in different ways. The intended message is itself inaccurate —
the account did not change; the record could not be read — and the actual
behaviour never reaches it.

A second instance, `charge_abnormalities_screen.form.dart:779`, has the same
shape: `if (actor == null) throw StateError('The reporting user could not be
verified.')`. That message is never shown on a provider error.

### Extent

94 sites read `.value` from a provider. 73 of those read
`currentAppUserProvider`. **59 have no `hasError` / `valueOrNull` / `hasValue`
guard within the preceding 15 lines.** Those in submit, accept, close, correct
and delete handlers include:

`_acceptCover`, `_confirmDelete` (five screens), `_correctTicket`,
`_reopenTicket`, `_endRetainedRelevance`, `_closeDirective`, `_submit`
(create directive), `_showCorrectionDialog`.

The correctly guarded pattern already exists in this codebase —
`abnormalities_home_screen.dart:40-59` checks `isLoading`, then `hasError`,
then reads `.value`. The fix is to make the rest match it.

### Suggested correction

Replace `.value` with `valueOrNull` at every site whose surrounding code treats
the result as nullable, and keep `.value` only where a preceding `hasError`
branch has already returned. Where the distinction matters to the operator,
separate "not signed in" from "your account could not be verified right now",
because they have different remedies.

---

## WS-02 — Raw exception objects are shown to operators

**Priority: medium · Confirmed · 60 occurrences across 36 files**

Sixty user-facing strings interpolate an error object directly. Many are bare:

```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
```

`WorkflowException.toString()` renders as
`WorkflowException(versionConflict: The record changed. Refresh it before
trying again.)`. The operator is shown the class name and enum before the one
sentence that is useful to them. A Firestore failure renders as
`[cloud_firestore/permission-denied] …`.

Affected files include `ticket_screen.dart` (6), `quality_home_screen.dart` (3),
`planned_job_detail_screen.dart` (3), `critical_alarm_contacts_panel.dart` (3),
`ticket_screen.governed_actions.dart` (3).

This is not cosmetic. The audience is a fitter on a shop floor deciding whether
their work was recorded. A message they cannot act on is equivalent to no
message, and it is the last thing they see before deciding whether to submit
again — which is how duplicate work starts.

**Suggested correction:** one operator-message mapper for `WorkflowException`
and platform exceptions, returning the actionable sentence and a separate
diagnostic code for support. The domain layer already produces good operator
sentences; they are being buried by the presentation layer rather than missing.

---

## WS-03 — WS-01 and WS-02 compound into one operator-visible failure

**Priority: medium · Derived**

Twelve files containing submit-style handlers have no busy flag under any of
the usual names, so a second tap can dispatch a second command.

For governed commands this is **not** a duplicate-record risk:
`inspection_programmes_screen.dart` carries 10 `expectedVersion` references and
`lane_classification_screen.dart` three, so the second submission is refused as
a version conflict. `job_module_response_form.dart` has none but performs a
local form save whose repeat writes identical values.

So the real consequence of a double tap is a **version-conflict error**, which
under WS-02 is rendered as `WorkflowException(versionConflict: …)`, and under
WS-01 may be preceded by a raw provider error instead of the intended message.

The sequence a fitter experiences is: tap, no visible progress, tap again,
receive a technical error naming a Dart class. Nothing in that sequence tells
them whether the first tap worked.

**Suggested correction:** disable the control while in flight — the pattern is
already used correctly in `maintenance_form.dart` (`_isSubmitting`, early
return, `onPressed: null`) and `inner_cover_lifecycle_screen.acceptance.dart`
(`_busy`) — and treat `versionConflict` as a reload prompt rather than an error
string.

---

## WS-04 — The analyzer is running bare defaults

**Priority: medium · Observation**

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` and adds
**no project rules** — the `rules:` block contains only commented examples.

`use_build_context_synchronously` **is** enabled by that package and the tree is
clean, so the `BuildContext`-after-`await` hazard is already covered.

Not enabled, and relevant to this codebase specifically:

| Rule | Why it matters here |
| --- | --- |
| `unawaited_futures` | Fire-and-forget async is how submitted work disappears silently; this codebase is almost entirely async |
| `cancel_subscriptions` | The stream combiners repaired in CR-05 are exactly this shape |
| `close_sinks` | Four files create `StreamController`s; see *Checked — sound* below |
| `only_throw_errors` | `StateError` is thrown as control flow in several submit paths |
| `avoid_dynamic_calls` | `noSuchMethod` fakes and JSON decoding are widespread |

`flutter_lints` is pinned at **3.0.2** against Flutter 3.44. Later versions add
rules that would have caught defects already found by hand in this project.

This is the cheapest finding in the report: each rule is a class of defect the
toolchain can enforce for free, permanently, without a reviewer.

---

## WS-05 — Accessibility surface is thin for the operating environment

**Priority: low–medium · Observation**

| Measure | Count |
| --- | --- |
| `Semantics(` widgets | 13 |
| `semanticLabel` / `tooltip:` | 175 |
| `IconButton(` | 127 |
| Explicit tap-target sizing | 22 |
| `textScaler` / text-scaling handling | 8 |

Tooltip coverage against icon buttons is reasonable. The thin areas are
**explicit tap-target sizing** and **text-scaling behaviour**, which matter more
than usual for this deployment: gloved hands, and operators who may have the
system font scale raised. Eight text-scaling references across an application
of this size suggests layouts have largely been validated at default scale.

The repository does test overflow in places — `zoomable_pdf_preview_test.dart`
asserts "PDF controls fit without overflow on a narrow phone" — so the
capability exists and is not applied widely.

**Suggested correction:** decide a supported text-scale range and add overflow
tests at its upper bound for the screens an operator uses under time pressure —
ticket creation, acceptance, lane classification, completion.

---

## Checked — sound

Recorded so the auditor does not spend time re-deriving these.

| Area | Finding |
| --- | --- |
| **Planned-job closure gate** | `complete_job_screen.workflow_gate.dart` uses `valueOrNull ?? []` but computes `hasLoadError` from all three providers and includes `!hasLoadError` in `canComplete`, with the message "Workflow readiness cannot be verified". A stream error **blocks** completion. This is the CR-05 lesson applied correctly. |
| **Critical-alarm controller** | `critical_alarm_platform_service.dart` never closes its `StreamController`, but it is a `static final .broadcast()` process-lifetime bus. Correct as written. |
| **Ticket-creation double submit** | Guarded: `_isSubmitting`, early return, `onPressed: _isSubmitting ? null : _submit`. |
| **Inner Cover acceptance double submit** | Guarded: `_busy`, `if (_busy) return`, `onPressed: _busy ? null : _submit`. |
| **`BuildContext` after `await`** | `use_build_context_synchronously` enabled via `flutter_lints`; `flutter analyze` clean. |
| **Empty or swallowing catch blocks** | None found. |
| **Leaked `StreamSubscription`s** | Every file creating one also cancels. |

## Gate state at the time of this sweep

`flutter analyze` clean · Flutter suite **2304 passed, 1 skipped, 0 failed** ·
`functions npm test` **1155 passed, 107 emulator-skipped, 0 failed** ·
canonical audit **150 / 150**.

Twelve Firestore-emulator suites (107 tests) were **not** run. No handset was
operated. Nothing in this sweep reaches *device path demonstrated*.

## What this sweep did not cover

Backend handler logic beyond what WS-01–WS-03 touch; the emulator suites;
Android native code; report calculation correctness; role and permission
matrices; migration and purge paths; and any journey end-to-end. This is a
targeted presentation-and-contract sweep, not the outstanding whole-application
audit, and should not be counted as part of it.
