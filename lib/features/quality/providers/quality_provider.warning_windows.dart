part of 'quality_provider.dart';

Stream<List<QualityWarning>> combineQualityWarningWindows(
  Stream<List<QualityWarning>> nonClosed,
  Stream<List<QualityWarning>> recent,
) {
  late StreamController<List<QualityWarning>> controller;
  StreamSubscription<List<QualityWarning>>? nonClosedSubscription;
  StreamSubscription<List<QualityWarning>>? recentSubscription;
  List<QualityWarning>? latestNonClosed;
  List<QualityWarning>? latestRecent;
  var observed = <String, QualityWarning>{};

  void emitWhenReady() {
    if (latestNonClosed == null || latestRecent == null) return;
    try {
      final merged = mergeQualityWarningWindows(
        latestNonClosed!,
        latestRecent!,
      );
      // Keep the greatest observed revision while an identity is in either
      // window, even if both listeners later deliver a delayed older snapshot.
      // Removing an identity from both windows also releases this memory.
      final previous = [
        for (final warning in merged)
          if (observed[warning.warningId] case final value?) value,
      ];
      final current = mergeQualityWarningWindows(merged, previous);
      observed = {for (final warning in current) warning.warningId: warning};
      controller.add(current);
    } catch (error, stack) {
      controller.addError(error, stack);
    }
  }

  controller = StreamController<List<QualityWarning>>(
    onListen: () {
      nonClosedSubscription = nonClosed.listen(
        (value) {
          latestNonClosed = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stack) {
          latestNonClosed = null;
          controller.addError(error, stack);
        },
      );
      recentSubscription = recent.listen(
        (value) {
          latestRecent = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stack) {
          latestRecent = null;
          controller.addError(error, stack);
        },
      );
    },
    onCancel: () async {
      await nonClosedSubscription?.cancel();
      await recentSubscription?.cancel();
    },
  );
  return controller.stream;
}
