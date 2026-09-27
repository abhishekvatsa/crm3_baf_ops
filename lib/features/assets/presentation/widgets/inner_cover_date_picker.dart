import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/inner_cover_date_format.dart';

/// Calendar selection and typed entry use the same unambiguous day-first date.
class InnerCoverCalendarDelegate extends GregorianCalendarDelegate {
  const InnerCoverCalendarDelegate();

  @override
  String formatCompactDate(
    DateTime date,
    MaterialLocalizations localizations,
  ) => DateFormat(innerCoverDatePattern).format(date);

  @override
  DateTime? parseCompactDate(
    String? inputString,
    MaterialLocalizations localizations,
  ) {
    final input = inputString?.trim();
    if (input == null || !RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(input)) {
      return null;
    }
    try {
      return DateFormat(innerCoverDatePattern).parseStrict(input);
    } on FormatException {
      return null;
    }
  }

  @override
  String dateHelpText(MaterialLocalizations localizations) => 'dd-MM-yyyy';
}

Future<DateTime?> showInnerCoverDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  helpText: helpText,
  fieldHintText: 'dd-MM-yyyy',
  fieldLabelText: 'Date (dd-MM-yyyy)',
  errorFormatText: 'Enter a valid date as dd-MM-yyyy.',
  calendarDelegate: const InnerCoverCalendarDelegate(),
);
