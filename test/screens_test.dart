// Renders every screen at the design's 390×844 frame with the real fonts.
//
//   flutter test test/screens_test.dart --update-goldens
//
// writes PNGs to build/screens/ for side-by-side comparison with the design
// canvas. Without --update-goldens it only checks each screen builds without
// layout overflow or exceptions.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/app/providers.dart';
import 'package:workout_tracker/app/router.dart';
import 'package:workout_tracker/data/csv_backup_service.dart';
import 'package:workout_tracker/data/csv_codec.dart';
import 'package:workout_tracker/data/daos/plan_dao.dart';
import 'package:workout_tracker/data/daos/workout_dao.dart';
import 'package:workout_tracker/data/database.dart';
import 'package:workout_tracker/features/workout/workout_logic.dart';
import 'package:workout_tracker/main.dart';
import 'package:workout_tracker/widgets/ui.dart';

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }

  await family('Inter', [
    'inter-400.ttf',
    'inter-500.ttf',
    'inter-600.ttf',
    'inter-700.ttf',
  ]);
  await family('SpaceGrotesk', [
    'space-grotesk-500.ttf',
    'space-grotesk-600.ttf',
    'space-grotesk-700.ttf',
  ]);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final sample = File('test/fixtures/sample_valid.csv').readAsStringSync();
  final update = autoUpdateGoldenFiles;

  setUpAll(loadFonts);

  Future<AppDatabase> seeded(WidgetTester tester) async {
    late AppDatabase db;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await CsvBackupService(db).replaceAll(decodeBackup(sample));
    });
    return db;
  }

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    String? location,
    Future<String> Function(AppDatabase db)? prepare,
    String palette = 'lime',
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'theme': palette});
    final prefs = await SharedPreferences.getInstance();
    final db = await seeded(tester);
    var loc = location ?? Routes.workouts;
    if (prepare != null) {
      await tester.runAsync(() async => loc = await prepare(db));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const WorkoutTrackerApp(),
      ),
    );
    appRouter.go(loc);
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (update) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/screens/$name.png'),
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    // In-memory DB: closing it while drift streams wind down can hang the
    // test binding, and it is garbage collected anyway.
  }

  Future<String> startDay1(AppDatabase db) async {
    final day = (await PlanDao(db).loadPlan()).first;
    await WorkoutDao(db)
        .start(day, now: DateTime.now().subtract(const Duration(minutes: 7)));
    return Routes.workout;
  }

  testWidgets(
    'workouts',
    (t) => shoot(t, '1-workouts', location: Routes.workouts),
  );

  testWidgets(
    'day editor',
    (t) => shoot(
      t,
      '2-day-editor',
      prepare: (db) async =>
          Routes.day((await PlanDao(db).loadPlan()).first.id),
    ),
  );

  testWidgets(
    'day editor (empty day)',
    (t) => shoot(
      t,
      '3-day-editor-empty',
      prepare: (db) async => Routes.day((await PlanDao(db).loadPlan())[1].id),
    ),
  );

  testWidgets(
    'workout - warm-up',
    (t) => shoot(t, '4-workout-warmup', prepare: startDay1),
  );

  testWidgets(
    'workout - lifts',
    (t) => shoot(
      t,
      '5-workout-lifts',
      prepare: (db) async {
        await startDay1(db);
        final day = (await PlanDao(db).loadPlan()).first;
        final dao = WorkoutDao(db);
        await dao.setPhase(Phase.lifts);
        await dao.setDone([
          ...day.warmups.map((r) => routineKey(r.id)),
          setKey(day.exercises.first.sets.first.id),
        ]);
        return Routes.workout;
      },
    ),
  );

  testWidgets(
    'history',
    (t) => shoot(t, '6-history', location: Routes.history),
  );

  testWidgets(
    'settings',
    (t) => shoot(t, '7-settings', location: Routes.settings),
  );

  testWidgets(
    'workouts - rose',
    (t) =>
        shoot(t, '8-workouts-rose', location: Routes.workouts, palette: 'rose'),
  );

  testWidgets('Add body part is enabled only when the box has text', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = await seeded(t);
    late int dayId;
    await t.runAsync(() async => dayId = (await PlanDao(db).loadPlan())[1].id);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const WorkoutTrackerApp(),
      ),
    );
    appRouter.go(Routes.day(dayId));
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await t.pump(const Duration(milliseconds: 300));
    }

    Btn addButton() => t.widget<Btn>(
      find.ancestor(of: find.text('Add body part'), matching: find.byType(Btn)),
    );
    final box = find.widgetWithText(TextField, 'e.g. Shoulders, Legs, Abs');

    expect(addButton().onTap, isNull);
    await t.enterText(box, '   ');
    await t.pump();
    expect(addButton().onTap, isNull, reason: 'spaces only');
    await t.enterText(box, 'Legs');
    await t.pump();
    expect(addButton().onTap, isNotNull);
    await t.enterText(box, '');
    await t.pump();
    expect(addButton().onTap, isNull);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  group('Day editor asks before leaving with unsaved changes', () {
    Future<(AppDatabase, int)> openEditor(WidgetTester t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = await seeded(t);
      late int dayId;
      await t.runAsync(
        () async => dayId = (await PlanDao(db).loadPlan()).first.id,
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: const WorkoutTrackerApp(),
        ),
      );
      appRouter.go(Routes.workouts);
      await settle(t);
      appRouter.push(Routes.day(dayId));
      await settle(t);
      return (db, dayId);
    }

    Finder back() => find.byWidgetPredicate(
      (w) => w is IconBtn && w.label == 'Back to workouts',
    );

    Future<void> tapBack(WidgetTester t) async {
      await t.tap(back());
      await settle(t);
    }

    Future<void> done(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('no edits: back leaves straight away', (t) async {
      await openEditor(t);
      await tapBack(t);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('YOUR SPLIT'), findsOneWidget);
      await done(t);
    });

    testWidgets('edit, back, discard restores the plan', (t) async {
      final (db, _) = await openEditor(t);
      final reps = find.byWidgetPredicate(
        (w) => w is SyncedField && w.semanticLabel == 'Bench press set 1 reps',
      );
      await t.enterText(
        find.descendant(of: reps, matching: find.byType(TextField)),
        '12',
      );
      await settle(t);
      await tapBack(t);

      expect(find.text('Save changes to Day 1?'), findsOneWidget);
      expect(find.text('You made 1 change:'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Bench press · set 1: 60×8 to 60×12'),
        findsOneWidget,
      );

      if (autoUpdateGoldenFiles) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../build/screens/9-save-changes-sheet.png'),
        );
      }
      await t.tap(find.text('Discard changes'));
      await settle(t);
      expect(find.text('YOUR SPLIT'), findsOneWidget);
      expect(find.text('Changes to Day 1 discarded'), findsOneWidget);
      late int savedReps;
      await t.runAsync(() async {
        savedReps = (await PlanDao(db).loadPlan()).first.sets.first.reps;
      });
      expect(savedReps, 8);
      await done(t);
    });

    testWidgets('edit, back, save keeps the change', (t) async {
      final (db, _) = await openEditor(t);
      final reps = find.byWidgetPredicate(
        (w) => w is SyncedField && w.semanticLabel == 'Bench press set 1 reps',
      );
      await t.enterText(
        find.descendant(of: reps, matching: find.byType(TextField)),
        '12',
      );
      await settle(t);
      await tapBack(t);
      await t.tap(find.text('Save changes'));
      await settle(t);
      expect(find.text('Day 1 saved · 1 change'), findsOneWidget);
      late int savedReps;
      await t.runAsync(() async {
        savedReps = (await PlanDao(db).loadPlan()).first.sets.first.reps;
      });
      expect(savedReps, 12);
      await done(t);
    });
  });
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 300));
  }
}
