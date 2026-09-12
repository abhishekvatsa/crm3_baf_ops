/// UTC milliseconds are the wire precision for new governed commands.
/// This does not alter stored timestamps or an already frozen request.
String commandUtcMillis(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  value.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
