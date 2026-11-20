import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Plan (what the user edits)
// ---------------------------------------------------------------------------

@DataClassName('SplitDay')
class SplitDays extends Table {
  @override
  String get tableName => 'split_day';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
}

/// Warm-up and cool-down items. `kind` is [RoutineKind.warmup] or
/// [RoutineKind.cooldown].
@DataClassName('RoutineItem')
class RoutineItems extends Table {
  @override
  String get tableName => 'routine_item';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayId =>
      integer().references(SplitDays, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  TextColumn get detail => text().withDefault(const Constant(''))();
  TextColumn get videoUrl => text().nullable()();
}

@DataClassName('BodyPart')
class BodyParts extends Table {
  @override
  String get tableName => 'body_part';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayId =>
      integer().references(SplitDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get name => text()();
}

@DataClassName('Exercise')
class Exercises extends Table {
  @override
  String get tableName => 'exercise';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bodyPartId =>
      integer().references(BodyParts, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  TextColumn get videoUrl => text().nullable()();
}

/// The plan's target for each set. Weight is always stored in kg
/// (0 = bodyweight). `lastWeight` / `lastReps` hold what was actually done
/// the last time this set was completed.
@DataClassName('ExerciseSet')
class ExerciseSets extends Table {
  @override
  String get tableName => 'exercise_set';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  RealColumn get weight => real().withDefault(const Constant(0))();
  IntColumn get reps => integer()();
  RealColumn get lastWeight => real().nullable()();
  IntColumn get lastReps => integer().nullable()();
}

// ---------------------------------------------------------------------------
// History (snapshots — editing the plan never changes past sessions)
// ---------------------------------------------------------------------------

@DataClassName('WorkoutSession')
class Sessions extends Table {
  @override
  String get tableName => 'session';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayId => integer().nullable().references(
    SplitDays,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get dayName => text()();
  TextColumn get partsLabel => text().withDefault(const Constant(''))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime()();
  IntColumn get minutes => integer()();
  IntColumn get totalSets => integer()();
  IntColumn get warmDone => integer().withDefault(const Constant(0))();
  IntColumn get warmTotal => integer().withDefault(const Constant(0))();
  IntColumn get coolDone => integer().withDefault(const Constant(0))();
  IntColumn get coolTotal => integer().withDefault(const Constant(0))();
}

@DataClassName('SessionExercise')
class SessionExercises extends Table {
  @override
  String get tableName => 'session_exercise';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  BoolColumn get improved => boolean().withDefault(const Constant(false))();
}

@DataClassName('SessionSet')
class SessionSets extends Table {
  @override
  String get tableName => 'session_set';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionExerciseId => integer().references(
    SessionExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
}

// ---------------------------------------------------------------------------
// In-progress workout (0 or 1 row) so an app kill doesn't lose a workout
// ---------------------------------------------------------------------------

@DataClassName('ActiveWorkout')
class ActiveWorkouts extends Table {
  @override
  String get tableName => 'active_workout';

  /// Always [AppDatabase.activeWorkoutId]; there is at most one row.
  IntColumn get id => integer()();
  IntColumn get dayId =>
      integer().references(SplitDays, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get phase => text()();

  /// JSON list of checked keys in the order they were checked, e.g.
  /// `["r:3","s:12"]` (`r:` = routine item id, `s:` = exercise set id).
  TextColumn get doneIds => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

abstract final class RoutineKind {
  static const warmup = 'warmup';
  static const cooldown = 'cooldown';
}

abstract final class Phase {
  static const warmup = 'warmup';
  static const lifts = 'lifts';
  static const cooldown = 'cooldown';
  static const all = [warmup, lifts, cooldown];
}

@DriftDatabase(
  tables: [
    SplitDays,
    RoutineItems,
    BodyParts,
    Exercises,
    ExerciseSets,
    Sessions,
    SessionExercises,
    SessionSets,
    ActiveWorkouts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'workout_tracker'));

  static const activeWorkoutId = 1;
  static const maxDays = 14;
  static const defaultDays = 3;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (var i = 0; i < defaultDays; i++) {
        await into(
          splitDays,
        ).insert(SplitDaysCompanion.insert(position: i, name: 'Day ${i + 1}'));
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Tables that make up the editable plan.
  List<TableInfo> get planTables => [
    splitDays,
    routineItems,
    bodyParts,
    exercises,
    exerciseSets,
  ];

  /// Tables that make up workout history.
  List<TableInfo> get historyTables => [
    sessions,
    sessionExercises,
    sessionSets,
  ];
}
