part of 'template_publisher_screen.dart';

extension _TemplatePublisherHelpers on _TemplatePublisherScreenState {
  void _showValidationFailure(_ValidationResult validation) {
    final first =
        validation.errors.isNotEmpty
            ? validation.errors.first
            : validation.warnings.firstOrNull ?? 'Validation failed.';
    _showSnack(first, BafColors.danger);
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}
