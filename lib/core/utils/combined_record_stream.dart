import 'dart:async';

String plannedExecutionReportTimestampBound(DateTime value) =>
    value.toUtc().toIso8601String();

Stream<List<T>> combineLatestUniqueRecordStreams<T>({
  required List<Stream<List<T>>> streams,
  required Object Function(T value) identityOf,
  Comparator<T>? compare,
}) {
  if (streams.isEmpty) return Stream<List<T>>.value(const []);

  late final StreamController<List<T>> controller;
  final subscriptions = <StreamSubscription<List<T>>>[];
  final latest = List<List<T>?>.filled(streams.length, null);
  final done = List<bool>.filled(streams.length, false);

  void emitIfReady() {
    if (latest.any((items) => items == null) || controller.isClosed) return;
    final byIdentity = <Object, T>{};
    for (final records in latest) {
      for (final record in records!) {
        byIdentity[identityOf(record)] = record;
      }
    }
    final result = byIdentity.values.toList(growable: false);
    if (compare != null) result.sort(compare);
    controller.add(List<T>.unmodifiable(result));
  }

  void closeIfDone() {
    if (done.every((value) => value) && !controller.isClosed) {
      controller.close();
    }
  }

  controller = StreamController<List<T>>(
    onListen: () {
      for (var index = 0; index < streams.length; index++) {
        subscriptions.add(
          streams[index].listen(
            (records) {
              latest[index] = records;
              emitIfReady();
            },
            onError: controller.addError,
            onDone: () {
              done[index] = true;
              closeIfDone();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
