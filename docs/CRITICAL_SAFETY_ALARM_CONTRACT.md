# Critical Safety Alarm Contract

## Purpose and boundary

The Critical Safety Alarm is a coordination aid for approved CRM3 users who
are signed in and reachable. It does not actuate plant equipment, contact
emergency services, notify the control room or Fire and Safety outside CRM3,
or replace the plant emergency procedure. The app must state this boundary at
the point of use.

## Alarm catalogue and criticality

Criticality is derived by the server from the governed catalogue. Clients may
select an alarm type but may not submit or alter its criticality.

| Alarm type | Criticality | Rank |
| --- | --- | ---: |
| Fire | Highest | 1 |
| Major gas leakage | Highest | 1 |
| Blast | Highest | 1 |
| Nitrogen failure | Critical | 2 |
| Hot well pump failure | Critical | 2 |

These alarm types remain distinct even when their rank is equal. There is no
generic contact fallback between alarm types.

## Dispatch sequence

1. The user selects an alarm type and may identify a location or asset.
2. The app shows the scope boundary and requires explicit confirmation.
3. Confirmation sends the alarm immediately. Narrative typing must not delay
   dispatch.
4. The alarm is created with `detailsPending` when no useful narrative was
   supplied. The raiser, Admin or SI must then provide details. Support cannot
   be confirmed while details remain pending unless the confirmer supplies
   those details in the same command.
5. An unavailable or uncertain network result is never queued for delayed
   automatic dispatch. The app states that the outcome is unknown and directs
   the user to check active alarms and follow the plant emergency procedure.

## Lifecycle

The lifecycle is `raised`, `supportConfirmed`, `resolved`, or
`withdrawnInError`. A mistaken alarm is never represented as resolved.

- Any approved user may raise an alarm.
- The raiser, Admin or SI may add the required details.
- Admin or SI may confirm support. A confirmation basis and responder note are
  required.
- Admin or SI may resolve a support-confirmed alarm. A resolution summary is
  required.
- The raiser, Admin or SI may withdraw a raised or support-confirmed alarm in
  error. A withdrawal reason is required.
- Multiple legitimate alarms may be active concurrently. Idempotent command
  receipts prevent duplicate application of the same request.

Every transition is server-authoritative, versioned, timestamped and audited.
The actor's name is deliberately visible to responders because operational
coordination requires identification.

## Contacts

Contacts are Admin-managed, versioned records. Each active record names one or
more exact alarm types, a priority, a label and one of `mobile`, `landline`, or
`plantExtension`. Numbers open the device dialler and are never dialled
automatically. Retired contacts remain in history.

Only contacts explicitly assigned to the selected alarm type may be shown. If
none is configured, the app says: "No approved contact is configured for this
alarm. Follow the plant emergency procedure."

## Delivery and local-state rules

- Alarm commands use the governed workflow callable and receipt contract but
  bypass the ordinary offline retry store.
- Alarm records are read directly from Firestore and are not placed in Isar or
  the global-pull protocol.
- Cached Firestore snapshots and local-pending writes must not drive alarm
  state, sound or lifecycle controls.
- The server emits a high-priority Firebase message through the existing
  idempotent notification-event pipeline to approved registered users.
- Android uses a dedicated high-importance channel. The app must not claim
  guaranteed delivery, Do Not Disturb bypass, full-screen wake, or indefinite
  background ringing without explicit platform permission and physical-device
  evidence.
- A persistent in-app banner and alarm workspace provide the authoritative
  visible state while the app is open.

## User interface

- A globally reachable alarm control is available to every approved user.
- Active alarms remain visible across approved-user screens.
- Home and Control expose an active-alarm count and open the alarm workspace.
- The workspace separates active alarms from history and shows criticality,
  type, location, raiser, time, details, contacts and lifecycle evidence.
- Administration provides contact add, edit and retire controls. There is no
  hard delete from the normal UI.

## Release gates

Source completion requires strict decoder registration, field governance,
Firestore rules tests, handler/idempotency/authority tests, widget tests,
canonical reconciliation and the full existing suite. A distributable build
must additionally prove notification permission, foreground/background
delivery, channel behaviour, dialler opening and lifecycle convergence on a
physical Android device. Without that device proof the source may be complete,
but the alarm must be labelled unproved for pilot safety reliance.
