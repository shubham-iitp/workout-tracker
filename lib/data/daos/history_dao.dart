import 'package:drift/drift.dart';

import '../database.dart';
import '../models.dart';

/// Reads saved workouts.
class HistoryDao {
  HistoryDao(this.db);

  final AppDatabase db;

  /// Newest first. Emits again after every change to a history table.
  Stream<List<SessionView>> watchSessions() async* {
    yield await loadSessions(newestFirst: true);
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables(db.historyTables),
    )) {
      yield await loadSessions(newestFirst: true);
    }
  }

  /// All sessions with their exercises and sets. [newestFirst] orders by start
  /// time; otherwise sessions come back in the order they were saved
  /// (insertion order), which is what CSV export uses.
  Future<List<SessionView>> loadSessions({bool newestFirst = false}) async {
    final query = db.select(db.sessions)
      ..orderBy([
        if (newestFirst)
          (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(
          expression: t.id,
          mode: newestFirst ? OrderingMode.desc : OrderingMode.asc,
        ),
      ]);
    final sessions = await query.get();
    final exercises = await (db.select(
      db.sessionExercises,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    final sets = await (db.select(
      db.sessionSets,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();

    final setsByExercise = <int, List<SessionSet>>{};
    for (final s in sets) {
      setsByExercise.putIfAbsent(s.sessionExerciseId, () => []).add(s);
    }
    final exercisesBySession = <int, List<SessionExerciseView>>{};
    for (final e in exercises) {
      exercisesBySession
          .putIfAbsent(e.sessionId, () => [])
          .add(
            SessionExerciseView(exercise: e, sets: setsByExercise[e.id] ?? []),
          );
    }
    return [
      for (final s in sessions)
        SessionView(session: s, exercises: exercisesBySession[s.id] ?? []),
    ];
  }

  Future<void> deleteSession(int id) =>
      (db.delete(db.sessions)..where((t) => t.id.equals(id))).go();
}
