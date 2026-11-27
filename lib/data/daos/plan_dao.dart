import 'package:drift/drift.dart';

import '../database.dart';
import '../models.dart';

/// Reads and edits the workout plan (days, routines, body parts, exercises,
/// sets).
class PlanDao {
  PlanDao(this.db);

  final AppDatabase db;

  /// Emits the whole plan now and again after every change to a plan table.
  Stream<List<DayPlan>> watchPlan() async* {
    yield await loadPlan();
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables(db.planTables),
    )) {
      yield await loadPlan();
    }
  }

  Future<List<DayPlan>> loadPlan() async {
    final days = await (db.select(
      db.splitDays,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    final routines = await (db.select(
      db.routineItems,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    final parts = await (db.select(
      db.bodyParts,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    final exercises = await (db.select(
      db.exercises,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    final sets = await (db.select(
      db.exerciseSets,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();

    final setsByExercise = <int, List<ExerciseSet>>{};
    for (final s in sets) {
      setsByExercise.putIfAbsent(s.exerciseId, () => []).add(s);
    }
    final exercisesByPart = <int, List<ExercisePlan>>{};
    for (final e in exercises) {
      exercisesByPart
          .putIfAbsent(e.bodyPartId, () => [])
          .add(ExercisePlan(exercise: e, sets: setsByExercise[e.id] ?? []));
    }

    return [
      for (final d in days)
        DayPlan(
          day: d,
          warmups: routines
              .where((r) => r.dayId == d.id && r.kind == RoutineKind.warmup)
              .toList(),
          cooldowns: routines
              .where((r) => r.dayId == d.id && r.kind == RoutineKind.cooldown)
              .toList(),
          parts: [
            for (final p in parts.where((p) => p.dayId == d.id))
              BodyPartPlan(part: p, exercises: exercisesByPart[p.id] ?? []),
          ],
        ),
    ];
  }

  // ---- Days ---------------------------------------------------------------

  /// Adds or removes days at the end so there are exactly [count] days.
  Future<void> setDayCount(int count) async {
    count = count.clamp(1, AppDatabase.maxDays);
    await db.transaction(() async {
      final days = await (db.select(
        db.splitDays,
      )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
      if (count > days.length) {
        final used = days.map((d) => d.name).toSet();
        var n = days.length;
        for (var i = days.length; i < count; i++) {
          String name;
          do {
            n++;
            name = 'Day $n';
          } while (used.contains(name));
          used.add(name);
          await db
              .into(db.splitDays)
              .insert(SplitDaysCompanion.insert(position: i, name: name));
        }
      } else {
        for (final d in days.sublist(count)) {
          await (db.delete(db.splitDays)..where((t) => t.id.equals(d.id))).go();
        }
      }
    });
  }

  Future<void> renameDay(int dayId, String name) =>
      (db.update(db.splitDays)..where((t) => t.id.equals(dayId))).write(
        SplitDaysCompanion(name: Value(name)),
      );

  // ---- Warm-up / cool-down ---------------------------------------------------

  Future<void> addRoutineItem({
    required int dayId,
    required String kind,
    required String name,
    String detail = '',
    String? videoUrl,
  }) async {
    final position = await _nextPosition(
      db.routineItems,
      db.routineItems.position,
      db.routineItems.dayId.equals(dayId) & db.routineItems.kind.equals(kind),
    );
    await db
        .into(db.routineItems)
        .insert(
          RoutineItemsCompanion.insert(
            dayId: dayId,
            kind: kind,
            position: position,
            name: name,
            detail: Value(detail),
            videoUrl: Value(_blankToNull(videoUrl)),
          ),
        );
  }

  /// Updates only the fields given (name / detail / video link).
  Future<void> updateRoutineItem(
    int id, {
    String? name,
    String? detail,
    String? videoUrl,
  }) => (db.update(db.routineItems)..where((t) => t.id.equals(id))).write(
    RoutineItemsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      detail: detail == null ? const Value.absent() : Value(detail),
      videoUrl: videoUrl == null
          ? const Value.absent()
          : Value(_blankToNull(videoUrl)),
    ),
  );

  Future<void> deleteRoutineItem(int id) =>
      (db.delete(db.routineItems)..where((t) => t.id.equals(id))).go();

  // ---- Body parts -------------------------------------------------------------

  Future<int> addBodyPart(int dayId, String name) async {
    final position = await _nextPosition(
      db.bodyParts,
      db.bodyParts.position,
      db.bodyParts.dayId.equals(dayId),
    );
    return db
        .into(db.bodyParts)
        .insert(
          BodyPartsCompanion.insert(
            dayId: dayId,
            position: position,
            name: name,
          ),
        );
  }

  Future<void> renameBodyPart(int id, String name) =>
      (db.update(db.bodyParts)..where((t) => t.id.equals(id))).write(
        BodyPartsCompanion(name: Value(name)),
      );

  Future<void> deleteBodyPart(int id) =>
      (db.delete(db.bodyParts)..where((t) => t.id.equals(id))).go();

  // ---- Exercises & sets -------------------------------------------------------

  Future<void> addExercise({
    required int bodyPartId,
    required String name,
    required int sets,
    required int reps,
    required double weightKg,
    String? videoUrl,
  }) async {
    await db.transaction(() async {
      final position = await _nextPosition(
        db.exercises,
        db.exercises.position,
        db.exercises.bodyPartId.equals(bodyPartId),
      );
      final exerciseId = await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              bodyPartId: bodyPartId,
              position: position,
              name: name,
              videoUrl: Value(_blankToNull(videoUrl)),
            ),
          );
      for (var i = 0; i < sets; i++) {
        await db
            .into(db.exerciseSets)
            .insert(
              ExerciseSetsCompanion.insert(
                exerciseId: exerciseId,
                position: i,
                weight: Value(weightKg),
                reps: reps,
              ),
            );
      }
    });
  }

  /// Copies [source] — name, video link and every set (weight, reps and the
  /// "last time" values) — as a new exercise at the end of [bodyPartId], in
  /// one transaction. The copy is independent of the original. Returns the
  /// new exercise's id.
  Future<int> copyExercise({
    required ExercisePlan source,
    required int bodyPartId,
  }) {
    return db.transaction(() async {
      final position = await _nextPosition(
        db.exercises,
        db.exercises.position,
        db.exercises.bodyPartId.equals(bodyPartId),
      );
      final exerciseId = await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              bodyPartId: bodyPartId,
              position: position,
              name: source.name,
              videoUrl: Value(_blankToNull(source.videoUrl)),
            ),
          );
      for (var i = 0; i < source.sets.length; i++) {
        final s = source.sets[i];
        await db
            .into(db.exerciseSets)
            .insert(
              ExerciseSetsCompanion.insert(
                exerciseId: exerciseId,
                position: i,
                weight: Value(s.weight),
                reps: s.reps,
                lastWeight: Value(s.lastWeight),
                lastReps: Value(s.lastReps),
              ),
            );
      }
      return exerciseId;
    });
  }

  /// Updates only the fields given (name / video link).
  Future<void> updateExercise(int id, {String? name, String? videoUrl}) =>
      (db.update(db.exercises)..where((t) => t.id.equals(id))).write(
        ExercisesCompanion(
          name: name == null ? const Value.absent() : Value(name),
          videoUrl: videoUrl == null
              ? const Value.absent()
              : Value(_blankToNull(videoUrl)),
        ),
      );

  Future<void> deleteExercise(int id) =>
      (db.delete(db.exercises)..where((t) => t.id.equals(id))).go();

  /// Adds a set at the end, copying the weight and reps of the last set.
  Future<void> addSet(int exerciseId) async {
    await db.transaction(() async {
      final last =
          await (db.select(db.exerciseSets)
                ..where((t) => t.exerciseId.equals(exerciseId))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.position,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .getSingleOrNull();
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              exerciseId: exerciseId,
              position: (last?.position ?? -1) + 1,
              weight: Value(last?.weight ?? 0),
              reps: last?.reps ?? 10,
            ),
          );
    });
  }

  Future<void> deleteSet(int setId) =>
      (db.delete(db.exerciseSets)..where((t) => t.id.equals(setId))).go();

  Future<void> updateSet(int setId, {double? weightKg, int? reps}) =>
      (db.update(db.exerciseSets)..where((t) => t.id.equals(setId))).write(
        ExerciseSetsCompanion(
          weight: weightKg == null ? const Value.absent() : Value(weightKg),
          reps: reps == null ? const Value.absent() : Value(reps),
        ),
      );

  // ---- Undo a whole editing session ---------------------------------------------

  /// Puts one day back exactly as [snapshot] (taken when the editor opened):
  /// same rows, ids, order, weights, reps and "last time" values. Used by
  /// "Discard changes".
  Future<void> restoreDay(DayPlan snapshot) async {
    final dayId = snapshot.id;
    await db.transaction(() async {
      await (db.update(db.splitDays)..where((t) => t.id.equals(dayId))).write(
        SplitDaysCompanion(name: Value(snapshot.name)),
      );
      await (db.delete(
        db.routineItems,
      )..where((t) => t.dayId.equals(dayId))).go();
      // Cascades to the day's exercises and sets.
      await (db.delete(db.bodyParts)..where((t) => t.dayId.equals(dayId))).go();

      for (final r in [...snapshot.warmups, ...snapshot.cooldowns]) {
        await db.into(db.routineItems).insert(r);
      }
      for (final p in snapshot.parts) {
        await db.into(db.bodyParts).insert(p.part);
        for (final e in p.exercises) {
          await db.into(db.exercises).insert(e.exercise);
          for (final s in e.sets) {
            await db.into(db.exerciseSets).insert(s);
          }
        }
      }
    });
  }

  // ---- Helpers ----------------------------------------------------------------

  Future<int> _nextPosition(
    TableInfo table,
    GeneratedColumn<int> position,
    Expression<bool> where,
  ) async {
    final max = position.max();
    final row =
        await (db.selectOnly(table)
              ..addColumns([max])
              ..where(where))
            .getSingle();
    final current = row.read(max);
    return current == null ? 0 : current + 1;
  }
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
