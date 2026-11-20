import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/data/csv_backup_service.dart';
import 'package:workout_tracker/data/csv_codec.dart';
import 'package:workout_tracker/data/daos/history_dao.dart';
import 'package:workout_tracker/data/daos/plan_dao.dart';
import 'package:workout_tracker/data/daos/workout_dao.dart';
import 'package:workout_tracker/data/database.dart';
import 'package:workout_tracker/features/workout/workout_logic.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late CsvBackupService backup;
  late PlanDao plan;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backup = CsvBackupService(db);
    plan = PlanDao(db);
  });
  tearDown(() => db.close());

  final sample = File('test/fixtures/sample_valid.csv').readAsStringSync();

  test('a new database starts with 3 empty days', () async {
    final days = await plan.loadPlan();
    expect(days.map((d) => d.name), ['Day 1', 'Day 2', 'Day 3']);
    expect(days.every((d) => !d.canStart), isTrue);
  });

  test('import then export gives the identical file', () async {
    await backup.replaceAll(decodeBackup(sample));
    final exported = encodeBackup(await backup.snapshot());
    expect(exported, sample);
  });

  test('import replaces everything', () async {
    await plan.setDayCount(5);
    await backup.replaceAll(decodeBackup(sample));
    final days = await plan.loadPlan();
    expect(days.map((d) => d.name), ['Day 1', 'Day 2']);
    expect(days.first.partsLabel, 'Chest & Triceps');
    expect(days.first.canStart, isTrue);
    expect(days[1].canStart, isFalse);
  });

  test('delta labels from the sample', () async {
    await backup.replaceAll(decodeBackup(sample));
    final day = (await plan.loadPlan()).first;
    final bench = day.exercises.firstWhere((e) => e.name == 'Bench press');
    final fly = day.exercises.firstWhere((e) => e.name == 'Cable fly');
    final rope = day.exercises.firstWhere((e) => e.name == 'Rope pushdown');
    expect(
      exerciseDelta(bench),
      isA<WeightUp>().having((d) => d.kg, 'kg', 2.5),
    );
    expect(isWeightUp(bench.sets[1]), isTrue);
    expect(exerciseDelta(fly), isA<NoChange>());
    expect(exerciseDelta(rope), isA<FirstTime>());
  });

  test('cascade delete removes a day\'s plan', () async {
    await backup.replaceAll(decodeBackup(sample));
    await plan.setDayCount(1);
    await plan.setDayCount(1);
    final dayId = (await plan.loadPlan()).first.id;
    final partId = await plan.addBodyPart(dayId, 'Legs');
    await plan.addExercise(
      bodyPartId: partId,
      name: 'Squat',
      sets: 3,
      reps: 5,
      weightKg: 100,
    );
    expect((await plan.loadPlan()).first.setCount, 9);
    await plan.deleteBodyPart(partId);
    expect((await plan.loadPlan()).first.setCount, 6);
    final orphanSets = await db.select(db.exerciseSets).get();
    expect(orphanSets.length, 6);
  });

  test('saving a workout stores done sets and updates last time', () async {
    await backup.replaceAll(decodeBackup(sample));
    final workouts = WorkoutDao(db);
    var day = (await plan.loadPlan()).first;
    final start = DateTime(2026, 11, 20, 7, 0);
    await workouts.start(day, now: start);

    final active = (await workouts.getActive())!;
    expect(active.phase, Phase.warmup);

    final bench = day.exercises.first;
    // Bench press both sets + one warm-up item.
    final done = [
      routineKey(day.warmups.first.id),
      setKey(bench.sets[0].id),
      setKey(bench.sets[1].id),
    ];
    await workouts.setDone(done);
    final progress = WorkoutProgress(day, done);
    expect(progress.setsDone, 2);
    expect(progress.liftsUp, 1);

    await workouts.save(
      progress,
      (await workouts.getActive())!,
      now: start.add(const Duration(minutes: 42)),
    );

    expect(await workouts.getActive(), isNull);
    final sessions = await HistoryDao(db).loadSessions(newestFirst: true);
    expect(sessions.length, 2);
    final s = sessions.first;
    expect(s.session.minutes, 42);
    expect(s.session.warmDone, 1);
    expect(s.session.totalSets, 6);
    expect(s.exercises.single.exercise.name, 'Bench press');
    expect(s.exercises.single.exercise.improved, isTrue);
    expect(s.volumeKg, 60 * 8 + 62.5 * 8);

    day = (await plan.loadPlan()).first;
    final benchAfter = day.exercises.first;
    expect(benchAfter.sets.map((x) => x.lastWeight), [60, 62.5]);
    expect(exerciseDelta(benchAfter), isA<NoChange>());
  });
}
