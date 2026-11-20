import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app/format.dart';
import 'package:workout_tracker/data/csv_backup_service.dart';
import 'package:workout_tracker/data/csv_codec.dart';
import 'package:workout_tracker/data/daos/plan_dao.dart';
import 'package:workout_tracker/data/database.dart';
import 'package:workout_tracker/data/models.dart';
import 'package:workout_tracker/features/plan/plan_diff.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final sample = File('test/fixtures/sample_valid.csv').readAsStringSync();

  late AppDatabase db;
  late PlanDao dao;
  late DayPlan before;

  Future<DayPlan> day1() async => (await dao.loadPlan()).first;
  Future<List<String>> changes([WeightUnit unit = WeightUnit.kg]) async =>
      describeDayChanges(before, await day1(), unit);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = PlanDao(db);
    await CsvBackupService(db).replaceAll(decodeBackup(sample));
    before = await day1();
  });
  tearDown(() => db.close());

  test('no edits → no changes', () async {
    expect(await changes(), isEmpty);
  });

  test('set weight / reps edits', () async {
    final bench = before.exercises.first;
    await dao.updateSet(bench.sets[1].id, weightKg: 65);
    await dao.updateSet(bench.sets[0].id, reps: 10);
    expect(await changes(), [
      'Bench press · set 1: 60×8 → 60×10',
      'Bench press · set 2: 62.5×8 → 65×8',
    ]);
  });

  test('shown in lb when the unit is lb', () async {
    await dao.updateSet(before.exercises.first.sets[0].id, weightKg: 65);
    expect(await changes(WeightUnit.lb), [
      'Bench press · set 1: 132.3×8 → 143.3×8',
    ]);
  });

  test('added and removed sets', () async {
    final fly = before.exercises.firstWhere((e) => e.name == 'Cable fly');
    await dao.addSet(fly.id);
    await dao.deleteSet(before.exercises.first.sets.last.id);
    expect(await changes(), [
      'Bench press: 2 sets → 1 set',
      'Cable fly: 2 sets → 3 sets',
    ]);
  });

  test('exercises, body parts and video links', () async {
    final chest = before.parts.first;
    await dao.addExercise(
      bodyPartId: chest.id,
      name: 'Dips',
      sets: 3,
      reps: 10,
      weightKg: 0,
    );
    await dao.deleteExercise(
      before.exercises.firstWhere((e) => e.name == 'Rope pushdown').id,
    );
    await dao.updateExercise(before.exercises.first.id, videoUrl: '');
    final legs = await dao.addBodyPart(before.id, 'Legs');
    await dao.addExercise(
      bodyPartId: legs,
      name: 'Squat',
      sets: 4,
      reps: 5,
      weightKg: 100,
    );
    expect(await changes(), [
      'Removed video link: Bench press',
      'Added exercise: Dips (3 sets of BW×10)',
      'Removed exercise: Rope pushdown',
      'Added body part: Legs',
      'Added exercise: Squat (4 sets of 100×5)',
    ]);
  });

  test('warm-up and cool-down items', () async {
    await dao.updateRoutineItem(
      before.warmups.first.id,
      name: 'Big arm circles',
    );
    await dao.deleteRoutineItem(before.warmups[1].id);
    await dao.addRoutineItem(
      dayId: before.id,
      kind: RoutineKind.cooldown,
      name: 'Child pose',
    );
    await dao.addRoutineItem(
      dayId: before.id,
      kind: RoutineKind.warmup,
      name: '',
    );
    expect(await changes(), [
      'Renamed warm-up: Arm circles → Big arm circles',
      'Added an empty warm-up item',
      'Removed warm-up: Band pull-aparts',
      'Added cool-down: Child pose',
    ]);
  });

  test('restoreDay puts everything back exactly (same ids)', () async {
    await dao.updateSet(before.exercises.first.sets[0].id, weightKg: 99);
    await dao.deleteExercise(before.exercises.last.id);
    await dao.deleteBodyPart(before.parts.first.id);
    await dao.deleteRoutineItem(before.warmups.first.id);
    await dao.addBodyPart(before.id, 'Legs');
    expect(await changes(), isNotEmpty);

    await dao.restoreDay(before);
    expect(await changes(), isEmpty);
    final after = await day1();
    expect(
      after.sets.map((s) => (s.id, s.weight, s.reps, s.lastWeight, s.lastReps)),
      before.sets.map(
        (s) => (s.id, s.weight, s.reps, s.lastWeight, s.lastReps),
      ),
    );
    expect(after.warmups.map((r) => r.id), before.warmups.map((r) => r.id));
    // Other days are untouched.
    expect((await dao.loadPlan())[1].name, 'Day 2');
  });
}
