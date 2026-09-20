import 'dart:collection';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import 'operational_directive_model.dart';

class DirectivePopulation extends ListBase<OperationalDirective> {
  DirectivePopulation(this.batch);
  final DecodedSnapshotBatch<OperationalDirective> batch;
  bool get isQualified => batch.isComplete && batch.isServerConfirmed;
  @override
  int get length => batch.records.length;
  @override
  set length(int value) =>
      throw UnsupportedError('Immutable directive population');
  @override
  OperationalDirective operator [](int index) => batch.records[index];
  @override
  void operator []=(int index, OperationalDirective value) =>
      throw UnsupportedError('Immutable directive population');
}

bool directivesAreQualified(List<OperationalDirective> rows) =>
    rows is! DirectivePopulation || rows.isQualified;

/// Known pull failures remain visible after restart, separately for each account.
class DirectiveReadHealth {
  static final _changes = StreamController<String>.broadcast();
  static String _key(String uid) => 'directive_population_unconfirmed:$uid';
  static Future<bool> incomplete(String uid) async =>
      (await SharedPreferences.getInstance()).getBool(_key(uid)) ?? false;
  static Future<void> record(String uid, bool incomplete) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key(uid), incomplete)) {
      throw StateError('Could not retain directive read completeness.');
    }
    _changes.add(uid);
  }

  static Stream<bool> watch(String uid) {
    late StreamController<bool> output;
    StreamSubscription<String>? subscription;
    output = StreamController<bool>(
      onListen: () {
        void emit() {
          incomplete(uid).then((value) {
            if (!output.isClosed) output.add(value);
          }, onError: output.addError);
        }

        subscription = _changes.stream
            .where((changed) => changed == uid)
            .listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return output.stream.distinct();
  }
}
