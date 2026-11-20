import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/csv_backup_service.dart';
import '../data/daos/history_dao.dart';
import '../data/daos/plan_dao.dart';
import '../data/daos/workout_dao.dart';
import '../data/database.dart';
import '../data/models.dart';
import 'format.dart';
import 'theme.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Overridden in `main()` with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final planDaoProvider = Provider((ref) => PlanDao(ref.watch(databaseProvider)));
final historyDaoProvider = Provider(
  (ref) => HistoryDao(ref.watch(databaseProvider)),
);
final workoutDaoProvider = Provider(
  (ref) => WorkoutDao(ref.watch(databaseProvider)),
);
final backupServiceProvider = Provider(
  (ref) => CsvBackupService(ref.watch(databaseProvider)),
);

final planProvider = StreamProvider<List<DayPlan>>(
  (ref) => ref.watch(planDaoProvider).watchPlan(),
);

final historyProvider = StreamProvider<List<SessionView>>(
  (ref) => ref.watch(historyDaoProvider).watchSessions(),
);

final activeWorkoutProvider = StreamProvider<ActiveWorkout?>(
  (ref) => ref.watch(workoutDaoProvider).watchActive(),
);

// ---- Settings ---------------------------------------------------------------

class AppSettings {
  const AppSettings({required this.unit, required this.palette});

  final WeightUnit unit;
  final AppPalette palette;

  AppSettings copyWith({WeightUnit? unit, AppPalette? palette}) =>
      AppSettings(unit: unit ?? this.unit, palette: palette ?? this.palette);
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _unitKey = 'unit';
  static const _themeKey = 'theme';

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(prefsProvider);
    return AppSettings(
      unit: WeightUnit.fromName(prefs.getString(_unitKey)),
      palette: AppPalette.fromName(prefs.getString(_themeKey)),
    );
  }

  Future<void> setUnit(WeightUnit unit) async {
    state = state.copyWith(unit: unit);
    await _prefs.setString(_unitKey, unit.name);
  }

  Future<void> setPalette(AppPalette palette) async {
    state = state.copyWith(palette: palette);
    await _prefs.setString(_themeKey, palette.name);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final unitProvider = Provider((ref) => ref.watch(settingsProvider).unit);
