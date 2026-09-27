# Account-deletion requests

The confirmed request handler is Abhishek Vatsa at email.abhishekvatsa@gmail.com. The app and public `/account-deletion` page open an editable email request. They do not delete an account, silently send a message, or promise that revocation is deletion. This procedure supplies the human follow-through; no production request is executed by publishing it.

## Handling a request

1. Record the request privately. Verify control of the account email or use a proportionate alternative when that mailbox is unavailable. Never ask for a Google password, OTP or signing secret. Establish whether the person requests permanent app-account deletion or merely correction/restoration of access.
2. Reply with the proposed scope and expected completion time. Include the app's Firebase Authentication account, user profile, notification tokens/installation registrations, authority/recovery state and other associated personal information. Ask whether devices contain unsent work before advising any local storage removal. Do not delay legitimate deletion indefinitely because an account is unapproved or the app cannot open.
3. Identify shared work, notification, diagnostic and audit records that refer to the person. Decide deletion/anonymisation and any justified retention separately. Record the exact retained categories, reason, responsible owner and retention/review period. Do not assume all plant records are exempt or assign an arbitrary permanent retention rule.
4. Prepare a concrete, bounded execution plan against verified account identifiers, with affected collections, expected counts and integrity constraints. Prevent new activity under the account before irreversible deletion. Preserve a minimal private request/outcome record only as justified; a blanket new backup of all personal data defeats deletion.
5. Use the approved administrative/backend process to delete the app's Authentication account and applicable profile, notification and personal data. Removing approval alone is insufficient. Handle retries and partially completed requests explicitly. Existing immutable command receipts and content-bound audits must not be edited ad hoc: any justified redaction requires a reviewed compatible process, or an explicitly justified retained-record outcome communicated to the requester.
6. Verify that the deleted account cannot refresh its app session or receive notifications, and that server-side reauthentication cannot recreate approval. Check the actual deletion results, any permitted retention and outstanding provider/backup constraints. A later new app registration must follow ordinary approval; it does not restore the old approval silently.
7. Confirm completion to the requester, including any specific retained information, reason and retention period. Explain whether local app data, downloaded reports or independently shared copies need separate action. Never advise clearing unsent device work without resolving its disposition first. The Google account itself is outside the app-account deletion request.

## Operational boundaries

- The repository currently has no automated end-to-end account erasure command. The email route must be actively handled by the named owner, not treated as completion by itself.
- Clients can retain account-bound pending submissions after sign-out. They cannot be reassigned to another user as a shortcut during deletion.
- Firestore client Rules intentionally prohibit direct user-document deletion. That restriction must not be relaxed to implement account deletion.
- The final deletion scope, identity verification, any authorised administrative actions and outcome belong in private operational records, never a public source PR.
- If fulfillment reveals missing safe deletion tooling, implement and test the bounded process before executing the request. Explain the actual timeline; do not replace a deletion request with indefinite suspension.

The public policy describes request handling and case-specific justified retention, not a fixed period or an already deployed automated deletion service. The owner must keep those statements consistent with actual practice.
