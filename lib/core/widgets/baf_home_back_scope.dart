import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps system Back inside the workspace until the user reaches Home.
class BafHomeBackScope extends StatefulWidget {
  const BafHomeBackScope({
    super.key,
    required this.isHomeSelected,
    required this.onReturnHome,
    required this.child,
    this.onExitApp,
  });

  final bool isHomeSelected;
  final VoidCallback onReturnHome;
  final Widget child;
  final Future<void> Function()? onExitApp;

  @override
  State<BafHomeBackScope> createState() => _BafHomeBackScopeState();
}

class _BafHomeBackScopeState extends State<BafHomeBackScope> {
  bool _exitConfirmationOpen = false;

  Future<void> _handleBack() async {
    if (!widget.isHomeSelected) {
      widget.onReturnHome();
      return;
    }
    if (_exitConfirmationOpen) return;

    _exitConfirmationOpen = true;
    try {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Exit CRM-III BAF Ops?'),
          content: const Text('You are on Home. Exit the app now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Exit app'),
            ),
          ],
        ),
      );
      if (!mounted || shouldExit != true) return;
      await (widget.onExitApp ?? SystemNavigator.pop)();
    } finally {
      _exitConfirmationOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: widget.child,
    );
  }
}
