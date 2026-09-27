import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/baf_design_system.dart';
import '../../core/widgets/brand/brand_widgets.dart';
import 'public_help_links.dart';

class PublicHelpScreen extends StatelessWidget {
  const PublicHelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BafColors.background,
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'Privacy & support',
        subtitle: 'Contact and account requests',
        icon: Icons.help_outline_rounded,
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: PublicHelpContent(),
          ),
        ),
      ),
    ),
  );
}

/// Also works above MaterialApp's Navigator, where the online access gate lives.
/// The inline route never reveals or replaces a protected application subtree.
class PublicHelpAccess extends StatefulWidget {
  const PublicHelpAccess({super.key, this.onDarkBackground = false});
  final bool onDarkBackground;

  @override
  State<PublicHelpAccess> createState() => _PublicHelpAccessState();
}

class _PublicHelpAccessState extends State<PublicHelpAccess> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        key: const ValueKey('public-help-entry'),
        style: widget.onDarkBackground
            ? TextButton.styleFrom(foregroundColor: Colors.white)
            : null,
        onPressed: () {
          final navigator = Navigator.maybeOf(context);
          if (navigator != null) {
            navigator.push<void>(
              MaterialPageRoute(builder: (_) => const PublicHelpScreen()),
            );
          } else {
            setState(() => _expanded = !_expanded);
          }
        },
        icon: Icon(_expanded ? Icons.close : Icons.help_outline_rounded),
        label: Text(_expanded ? 'Close help' : 'Privacy & support'),
      ),
      if (_expanded)
        const Material(
          color: BafColors.card,
          borderRadius: BorderRadius.all(Radius.circular(BafRadius.large)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: PublicHelpContent(),
          ),
        ),
    ],
  );
}

class PublicHelpContent extends StatelessWidget {
  const PublicHelpContent({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(BafBrand.productName, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Help is available without signing in or waiting for account approval.',
      ),
      const SizedBox(height: 24),
      _HelpSection(
        title: 'Privacy policy',
        icon: Icons.privacy_tip_outlined,
        children: [
          const Text(
            'Read how account information, operational records, notifications '
            'and diagnostics are handled, and how to contact the app owner.',
          ),
          _PublicLinkButton(
            id: 'public-privacy-link',
            label: 'Read privacy policy',
            uri: PublicHelpLinks.privacy,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _HelpSection(
        title: 'Support & contact',
        icon: Icons.contact_support_outlined,
        children: [
          const Text('App owner: ${PublicHelpLinks.owner}'),
          const SizedBox(height: 8),
          const SelectableText(PublicHelpLinks.email),
          const Text(
            'Use this address for support, privacy questions or account requests. '
            'Do not send passwords or verification codes.',
          ),
          _PublicLinkButton(
            id: 'public-support-email',
            label: 'Email support',
            uri: PublicHelpLinks.supportEmail,
          ),
          const _CopyButton(
            id: 'public-copy-email',
            label: 'Copy email address',
            value: PublicHelpLinks.email,
          ),
          _PublicLinkButton(
            id: 'public-support-link',
            label: 'Open support page',
            uri: PublicHelpLinks.support,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _HelpSection(
        title: 'Account deletion request',
        icon: Icons.person_remove_outlined,
        children: [
          const Text(
            'Request deletion of your account and associated personal data by '
            'emailing the app owner. Include the email address you use to sign in. '
            'The owner will verify the request and explain how it can be handled, '
            'including any records that need to be retained.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Opening an email draft does not send a request or delete anything. '
            'Review and send it in your email app. This screen does not sign you '
            'out, clear saved work or discard unsent changes.',
          ),
          _PublicLinkButton(
            id: 'public-deletion-email',
            label: 'Request account deletion by email',
            uri: PublicHelpLinks.deletionEmail,
          ),
          const _CopyButton(
            id: 'public-copy-deletion-request',
            label: 'Copy request text',
            value: PublicHelpLinks.deletionRequest,
          ),
          _PublicLinkButton(
            id: 'public-deletion-link',
            label: 'Read account deletion information',
            uri: PublicHelpLinks.accountDeletion,
          ),
        ],
      ),
    ],
  );
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BafColors.surfaceTint,
      border: Border.all(color: BafColors.border),
      borderRadius: BorderRadius.circular(BafRadius.large),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BafColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _PublicLinkButton extends ConsumerStatefulWidget {
  const _PublicLinkButton({
    required this.id,
    required this.label,
    required this.uri,
  });
  final String id;
  final String label;
  final Uri uri;

  @override
  ConsumerState<_PublicLinkButton> createState() => _PublicLinkButtonState();
}

class _PublicLinkButtonState extends ConsumerState<_PublicLinkButton> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await ref.read(publicHelpLauncherProvider)(widget.uri);
    } catch (_) {
      // Keep a usable copy fallback when a browser/email app is unavailable.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: ValueKey(widget.id),
        onPressed: _busy ? null : _open,
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(_busy ? 'Opening…' : widget.label),
      ),
      if (_failed) ...[
        Text(
          widget.uri.scheme == 'mailto'
              ? 'Could not open an email app. Copy the address and request text below, '
                    'then send them using your email service. No request has been sent by this app.'
              : 'Could not open the page. Copy this link into your browser.',
        ),
        if (widget.uri.scheme != 'mailto') ...[
          SelectableText(widget.uri.toString()),
          _CopyButton(
            id: '${widget.id}-copy',
            label: 'Copy link',
            value: widget.uri.toString(),
          ),
        ] else
          const SelectableText(PublicHelpLinks.email),
      ],
    ],
  );
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({
    required this.id,
    required this.label,
    required this.value,
  });
  final String id;
  final String label;
  final String value;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  String? _result;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        key: ValueKey(widget.id),
        onPressed: () async {
          try {
            await Clipboard.setData(ClipboardData(text: widget.value));
            if (mounted) setState(() => _result = 'Copied');
          } catch (_) {
            if (mounted) {
              setState(
                () => _result = 'Could not copy. Select the text below.',
              );
            }
          }
        },
        icon: const Icon(Icons.copy_outlined, size: 18),
        label: Text(widget.label),
      ),
      if (_result != null) Text(_result!, semanticsLabel: _result),
      if (_result != null && _result != 'Copied') SelectableText(widget.value),
    ],
  );
}
