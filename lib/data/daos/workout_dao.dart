import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../features/workout/workout_logic.dart';
import '../database.dart';
import '../models.dart';

/// The in-progress workout and saving it to history.
class WorkoutDao {
  WorkoutDao(this.db);

  final AppDatabase db;

  Stream<ActiveWorkout?> watchActive() =>
      db.select(db.activeWorkouts).watchSingleOrNull();

  Future<ActiveWorkout?> getActive() =>
      db.select(db.activeWorkouts).getSingleOrNull();

  /// Starts a workout for [day], replacing any in-progress one.
  Future<void> start(DayPlan day, {DateTime? now}) => db
      .into(db.activeWorkouts)
      .insertOnConflictUpdate(
        ActiveWorkoutsCompanion.insert(
          id: const Value(AppDatabase.activeWorkoutId),
          dayId: day.id,
          startedAt: now ?? DateTime.now(),
          phase: firstPhase(day),
          doneIds: const Value('[]'),
        ),
      );

  Future<void> setPhase(String phase) => db
      .update(db.activeWorkouts)
      .write(ActiveWorkoutsCompanion(phase: Value(phase)));

  Future<void> setDone(List<String> doneOrder) => db
      .update(db.activeWorkouts)
      .write(ActiveWorkoutsCompanion(doneIds: Value(encodeDone(doneOrder))));

  Future<void> discard() => db.delete(db.activeWorkouts).go();

  /// Saves the done parts of the workout to history, copies done sets into
  /// the plan's "last time" values and clears the active workout.
  Future<int> save(
    WorkoutProgress progress,
    ActiveWorkout active, {
    DateTime? now,
  }) {
    final finished = now ?? DateTime.now();
    final day = progress.day;
    return db.transaction(() async {
      final minutes = math.max(
        1,
        (finished.difference(active.startedAt).inSeconds / 60).round(),
      );
      final sessionId = await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              dayId: Value(day.id),
              dayName: day.name,
              partsLabel: Value(day.partsLabel),
              startedAt: active.startedAt,
              finishedAt: finished,
              minutes: minutes,
              totalSets: day.setCount,
              warmDone: Value(progress.warmDone),
              warmTotal: Value(progress.warmTotal),
              coolDone: Value(progress.coolDone),
              coolTotal: Value(progress.coolTotal),
            ),
          );

      var position = 0;
      for (final exercise in day.exercises) {
        final doneSets = exercise.sets.where(progress.isSetDone).toList();
        if (doneSets.isEmpty) continue;
        final sessionExerciseId = await db
            .into(db.sessionExercises)
            .insert(
              SessionExercisesCompanion.insert(
                sessionId: sessionId,
                position: position++,
                name: exercise.name,
                improved: Value(exerciseDelta(exercise).isUp),
              ),
            );
        for (var i = 0; i < doneSets.length; i++) {
          final s = doneSets[i];
          await db
              .into(db.sessionSets)
              .insert(
                SessionSetsCompanion.insert(
                  sessionExerciseId: sessionExerciseId,
                  position: i,
                  weight: s.weight,
                  reps: s.reps,
                ),
              );
          await (db.update(
            db.exerciseSets,
          )..where((t) => t.id.equals(s.id))).write(
            ExerciseSetsCompanion(
              lastWeight: Value(s.weight),
              lastReps: Value(s.reps),
            ),
          );
        }
      }

      await db.delete(db.activeWorkouts).go();
      return sessionId;
    });
  }
}
