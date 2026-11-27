import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/data/daos/plan_dao.dart';
import 'package:workout_tracker/data/database.dart';
import 'package:workout_tracker/data/models.dart';
import 'package:workout_tracker/features/plan/exercise_search_sheet.dart';

SessionView _session({
  required int id,
  int? dayId,
  String dayName = 'Day 1',
  required DateTime at,
  int totalSets = 4,
  int setsDone = 4,
  int warm = 0,
  int warmTotal = 0,
  int cool = 0,
  int coolTotal = 0,
}) => SessionView(
  session: WorkoutSession(
    id: id,
    dayId: dayId,
    dayName: dayName,
    partsLabel: '',
    startedAt: at,
    finishedAt: at,
    minutes: 30,
    totalSets: totalSets,
    warmDone: warm,
    warmTotal: warmTotal,
    coolDone: cool,
    coolTotal: coolTotal,
  ),
  exercises: [
    SessionExerciseView(
      exercise: SessionExercise(
        id: id,
        sessionId: id,
        position: 0,
        name: 'Bench',
        improved: false,
      ),
      sets: [
        for (var i = 0; i < setsDone; i++)
          SessionSet(
            id: id * 100 + i,
            sessionExerciseId: id,
            position: i,
            weight: 60,
            reps: 8,
          ),
      ],
    ),
  ],
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('completion %', () {
    test('counts working sets only, not warm-up or cool-down', () {
      final s = _session(
        id: 1,
        at: DateTime(2026),
        totalSets: 10,
        setsDone: 6,
        warm: 0,
        warmTotal: 3,
        cool: 0,
        coolTotal: 2,
      );
      expect(s.completionPct, 60);
      expect(s.isPartial, isTrue);
    });

    test('all sets done but warm-up skipped is not partial', () {
      final s = _session(id: 1, at: DateTime(2026), warm: 0, warmTotal: 3);
      expect(s.completionPct, 100);
      expect(s.isPartial, isFalse);
    });

    test('never rounds a missing set up to 100%', () {
      final s = _session(
        id: 1,
        at: DateTime(2026),
        totalSets: 200,
        setsDone: 199,
      );
      expect(s.completionPct, 99);
      expect(s.isPartial, isTrue);
    });
  });

  group('last workout done', () {
    late AppDatabase db;
    late PlanDao plan;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      plan = PlanDao(db);
    });
    tearDown(() => db.close());

    test('newest session wins, finished or not', () async {
      final days = await plan.loadPlan();
      final d1 = days[0].id, d2 = days[1].id;
      final sessions = [
        _session(id: 2, dayId: d1, at: DateTime(2026, 2)),
        _session(id: 3, dayId: d2, at: DateTime(2026, 3), setsDone: 2),
        _session(id: 1, dayId: d1, at: DateTime(2026, 1)),
      ];
      expect(lastWorkoutDayId(sessions, days), d2);
      expect(lastWorkoutDayId(const [], days), isNull);
    });

    test('falls back to the day name when the day id is gone', () async {
      final days = await plan.loadPlan();
      final s = _session(id: 1, dayName: 'Day 3', at: DateTime(2026));
      expect(lastWorkoutDayId([s], days), days[2].id);
    });
  });

  group('exercise search', () {
    late AppDatabase db;
    late PlanDao plan;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      plan = PlanDao(db);
    });
    tearDown(() => db.close());

    test('catalog, search and filter; copy is independent', () async {
      final days0 = await plan.loadPlan();
      final chest = await plan.addBodyPart(days0[0].id, 'Chest');
      final shoulders = await plan.addBodyPart(days0[1].id, 'Shoulders');
      await plan.addExercise(
        bodyPartId: chest,
        name: 'Bench press',
        sets: 4,
        reps: 8,
        weightKg: 60,
        videoUrl: 'https://youtu.be/x',
      );
      await plan.addExercise(
        bodyPartId: shoulders,
        name: 'bench press ',
        sets: 2,
        reps: 8,
        weightKg: 20,
      );
      await plan.addExercise(
        bodyPartId: shoulders,
        name: 'Overhead press',
        sets: 3,
        reps: 8,
        weightKg: 40,
      );
      final days = await plan.loadPlan();
      final all = buildExerciseCatalog(days);
      // Duplicate name (case/space-insensitive): first found wins.
      expect(all.map((x) => x.name), ['Bench press', 'Overhead press']);
      expect(all.first.part, 'Chest');

      expect(filterCatalog(all, query: 'PRESS').length, 2);
      expect(filterCatalog(all, query: 'should').single.name, 'Overhead press');
      expect(filterCatalog(all, filter: 'Chest').single.name, 'Bench press');
      expect(filterCatalog(all, query: 'overhead', filter: 'Chest'), isEmpty);

      final newId = await plan.copyExercise(
        source: all.first.exercise,
        bodyPartId: shoulders,
      );
      final after = await plan.loadPlan();
      final copy = after[1].exercises.firstWhere((e) => e.id == newId);
      expect(copy.name, 'Bench press');
      expect(copy.videoUrl, 'https://youtu.be/x');
      expect(copy.sets.map((s) => s.weight), [60, 60, 60, 60]);
      expect(after[1].parts.single.exercises.last.id, newId);

      await plan.updateSet(copy.sets.first.id, weightKg: 99);
      final orig = (await plan.loadPlan())[0].exercises.single;
      expect(orig.sets.first.weight, 60);
    });
  });
}
