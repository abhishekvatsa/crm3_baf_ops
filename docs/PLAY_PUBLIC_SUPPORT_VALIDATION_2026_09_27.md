# Public Play support preparation — 27 September 2026

The owner-confirmed publisher and contact are Abhishek Vatsa and `email.abhishekvatsa@gmail.com`. This note records published public resources and source verification. It does not approve a production app release or certify Play Console acceptance.

## Public resources

The separate [Hosting-only configuration](../firebase.play-support.json) publishes [public-support](../public-support/) to the existing Firebase Hosting site. Before publication, the live site had no release and returned HTTP404. The final successful publication, using repository-standard line endings, created Hosting version `0aded07511ac5ee0`; no Functions, Firestore Rules, IAM or business-data operations were included.

Anonymous HTTPS readback at `2026-09-27T15:17:35.4393768Z` returned HTTP200 and exact reviewed source bytes:

| Resource | SHA-256 |
| --- | --- |
| [Home](https://crm3-baf-ops-b8638.web.app/) | `AF97AACB7E665331B65FFF3A20E7D27F289AB6978D90A3E2498CD77127F32F97` |
| [Privacy](https://crm3-baf-ops-b8638.web.app/privacy) | `EB0D48F198F99B1EEF5438D0377E9F99845D29601B0C3CC56C6B0F08CBE8B99B` |
| [Support](https://crm3-baf-ops-b8638.web.app/support) | `28677DB238DF8F623BF43485248DD57CB714F00A9441F53892E515181836CED1` |
| [Account deletion](https://crm3-baf-ops-b8638.web.app/account-deletion) | `368D9CA4FE39D6C6D2F0B380231B4B04269C2E0E5649874F7F50EB8251D4F204` |
| [Stylesheet](https://crm3-baf-ops-b8638.web.app/styles.css) | `E662D9E8D9CE7F4840DB89B4F2E278790F8C91BA15871E527B7958BC7A75BD3E` |

All returned the configured Content Security Policy, `no-referrer` and `nosniff` headers. The site contains no scripts, analytics, external fonts, sign-in wall or submission form. Email links open an editable draft; they do not automatically send a message. The browser layout check passed eight mobile/desktop views at 390px/1280px, including local links, one main heading and no horizontal overflow. Representative screenshots were inspected. Private deployment/readback logs and screenshots remain outside committed source.

## In-app request route

Public Privacy & support is available from More, sign-in, pending approval, access-check and setup/error screens. The access-gate entry also works above the app Navigator, where it displays public content without revealing the protected workspace. Email and browser launches are initiated by a tap and have visible copy/select fallbacks. No profile or business content is added to the public URLs or email draft. Saved work is not deleted and sign-out is not triggered.

The first focused run passed 32 navigation/help/access tests. A subsequent complete Flutter run found that the new screen header did not use the existing shared app identity; the implementation was corrected to use `BafAppBarTitle`. The corrected focused help/design/historical-deferral selection passed 42 tests. The complete Flutter rerun passed **4,107 tests, with one existing skip**; full analysis reported no issues. The canonical audit passed **153/153 checks with 434 retained hash pointers**, evidence-taxonomy verification passed, and the existing production-policy verifier passed with Build29 still unapproved for distribution. Widget tests use a controlled launch boundary; they do not prove the physical device's email/browser handler or Play-installed behavior. Fresh CI is required on the committed combined head.

The [data inventory](PLAY_DATA_HANDLING_INVENTORY_2026_09_27.md) and [request-handling procedure](ACCOUNT_DELETION_REQUEST_HANDLING.md) explain collection and fulfillment. A public email route is only the start of deletion handling. No deletion request was submitted or fulfilled, no blanket retention exemption is claimed, and no automatic erasure operation has been implemented.

## Remaining external evidence

The authenticated Play Console could not be refreshed: supported browser/native control failed before startup with `windows sandbox failed: helper_unknown_error: setup refresh had errors`. No Console settings, certificate changes, app-content declarations or uploads were performed. Current Console state and final signed-client behavior remain required under the [readiness checklist](PLAY_DISTRIBUTION_READINESS_2026_09_27.md).
