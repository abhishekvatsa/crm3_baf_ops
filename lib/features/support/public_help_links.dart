import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public destinations: no profile, credentials or operational data are added.
class PublicHelpLinks {
  PublicHelpLinks._();

  static const owner = 'Abhishek Vatsa';
  static const email = 'email.abhishekvatsa@gmail.com';
  static final privacy = Uri.https('crm3-baf-ops-b8638.web.app', '/privacy');
  static final support = Uri.https('crm3-baf-ops-b8638.web.app', '/support');
  static final accountDeletion = Uri.https(
    'crm3-baf-ops-b8638.web.app',
    '/account-deletion',
  );
  static const deletionRequest =
      'I request deletion of my CRM-III BAF Ops account and associated personal data.\n\n'
      'Account email: \n\n'
      'Please tell me how to verify this request and what information, if any, needs to be retained.';

  static Uri emailDraft({required String subject, String? body}) => Uri(
    scheme: 'mailto',
    path: email,
    // Non-HTTP schemes need percent-encoded spaces, not form-encoded pluses.
    query: {'subject': subject, if (body != null) 'body': body}.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&'),
  );

  static final supportEmail = emailDraft(subject: 'CRM-III BAF Ops support');
  static final deletionEmail = emailDraft(
    subject: 'CRM-III BAF Ops account deletion request',
    body: deletionRequest,
  );
}

/// Direct user-initiated launch, with an in-app fallback if no handler exists.
final publicHelpLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});
