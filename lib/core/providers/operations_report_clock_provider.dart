import 'package:flutter_riverpod/flutter_riverpod.dart';

const operationsReportClockInterval = Duration(minutes: 1);

Stream<DateTime> operationsReportClock({
  Duration interval = operationsReportClockInterval,
  DateTime Function()? now,
}) async* {
  final readNow = now ?? DateTime.now;
  yield readNow();
  yield* Stream<DateTime>.periodic(interval, (_) => readNow());
}

final operationsReportClockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => operationsReportClock(),
);
