import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/csv_backup_service.dart';
import '../data/daos/history_dao.dart';
import '../data/daos/plan_dao.dart';
import '../data/daos/workout_dao.dart';
import '../data/database.dart';
import '../data/drive_backup_service.dart';
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

// ---- UI state shared between screens -------------------------------------------

/// Which History card is expanded (a session id). Set to the newest session
/// right after a workout is saved.
class ExpandedSessionNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final expandedSessionProvider = NotifierProvider<ExpandedSessionNotifier, int?>(
  ExpandedSessionNotifier.new,
);

// ---- Backup on Drive (spec §6) ------------------------------------------------

final driveAuthProvider = Provider<DriveAuth>((ref) => GoogleDriveAuth());

final driveServiceProvider = Provider(
  (ref) => DriveBackupService(
    csv: ref.watch(backupServiceProvider),
    auth: ref.watch(driveAuthProvider),
  ),
);

enum DriveStatus { off, on, busy, error }

class DriveState {
  const DriveState({
    this.status = DriveStatus.off,
    this.auto = true,
    this.lastAt,
    this.lastBytes,
    this.lastFile,
    this.uploading,
    this.error,
    this.signInError,
  });

  final DriveStatus status;
  final bool auto;
  final DateTime? lastAt;
  final int? lastBytes;
  final String? lastFile;

  /// File name being uploaded while [DriveStatus.busy].
  final String? uploading;
  final String? error;

  /// Technical reason the last sign-in failed (Off state, design state 5).
  final String? signInError;

  bool get connected => status != DriveStatus.off;
}

class DriveBackupNotifier extends Notifier<DriveState> {
  static const _connected = 'drive_connected';
  static const _account = 'drive_account';
  static const _folder = 'drive_folder_id';
  static const _auto = 'drive_auto';
  static const _lastAt = 'drive_last_at';
  static const _lastBytes = 'drive_last_bytes';
  static const _lastFile = 'drive_last_file';
  static const _error = 'drive_last_error';

  SharedPreferences get _prefs => ref.read(prefsProvider);
  DriveBackupService get _service => ref.read(driveServiceProvider);

  @override
  DriveState build() {
    final p = ref.watch(prefsProvider);
    final connected = p.getBool(_connected) ?? false;
    final error = p.getString(_error);
    return DriveState(
      status: !connected
          ? DriveStatus.off
          : (error != null ? DriveStatus.error : DriveStatus.on),
      auto: p.getBool(_auto) ?? true,
      lastAt: DateTime.tryParse(p.getString(_lastAt) ?? ''),
      lastBytes: p.getInt(_lastBytes),
      lastFile: p.getString(_lastFile),
      error: error,
    );
  }

  DriveState _copy({
    DriveStatus? status,
    bool? auto,
    String? uploading,
    String? error,
    DriveUpload? upload,
  }) => DriveState(
    status: status ?? state.status,
    auto: auto ?? state.auto,
    lastAt: upload?.at ?? state.lastAt,
    lastBytes: upload?.bytes ?? state.lastBytes,
    lastFile: upload?.fileName ?? state.lastFile,
    uploading: uploading,
    error: error,
  );

  Future<void> _saved(DriveUpload u) async {
    await _prefs.setString(_folder, u.folderId);
    await _prefs.setString(_lastAt, u.at.toIso8601String());
    await _prefs.setInt(_lastBytes, u.bytes);
    await _prefs.setString(_lastFile, u.fileName);
    await _prefs.remove(_error);
    state = _copy(status: DriveStatus.on, upload: u);
  }

  Future<void> _failed(DriveFailure f) async {
    await _prefs.setString(_error, f.message);
    state = _copy(status: DriveStatus.error, error: f.message);
  }

  /// "Backup on Drive": sign in, then the first upload.
  Future<void> connect() async {
    if (state.status == DriveStatus.busy) return;
    final String email;
    state = DriveState(auto: state.auto);
    try {
      email = await _service.connect();
    } on DriveFailure catch (f) {
      // Stay Off. Cancelled → nothing shown; otherwise the sign-in error box.
      state = DriveState(
        auto: state.auto,
        signInError: f.kind == DriveFailureKind.cancelled
            ? null
            : (f.detail ?? f.message),
      );
      return;
    }
    await _prefs.setBool(_connected, true);
    await _prefs.setString(_account, email);
    state = const DriveState(status: DriveStatus.on);
    await backupNow();
  }

  /// "Back up now" (interactive) or the automatic upload after a workout.
  Future<void> backupNow({bool interactive = true}) async {
    if (!state.connected) return;
    if (state.status == DriveStatus.busy) {
      // History changed mid-upload: upload once more when this one ends.
      _again = true;
      return;
    }
    state = _copy(
      status: DriveStatus.busy,
      uploading: DriveBackupService.fileNameFor(DateTime.now()),
      error: state.error,
    );
    try {
      final upload = await _service.backup(
        folderId: _prefs.getString(_folder),
        interactive: interactive,
      );
      if (!_stillConnected) return;
      await _saved(upload);
    } on DriveFailure catch (f) {
      if (!_stillConnected) return;
      if (f.kind == DriveFailureKind.cancelled) {
        state = _copy(
          status: state.error != null ? DriveStatus.error : DriveStatus.on,
          error: state.error,
        );
      } else {
        await _failed(f);
      }
    }
    if (_again && _stillConnected) {
      _again = false;
      await backupNow(interactive: false);
    }
  }

  bool _again = false;

  /// False once Disconnect was tapped during an upload.
  bool get _stillConnected => _prefs.getBool(_connected) ?? false;

  /// Called after anything in the CSV changes: a workout saved or deleted,
  /// plan edits saved, day count changed, a workout discarded (its +/− edits
  /// stay in the plan), a CSV imported. Never throws, never shows UI.
  Future<void> afterDataChanged() async {
    if (state.connected && state.auto) await backupNow(interactive: false);
  }

  Future<void> setAuto(bool on) async {
    await _prefs.setBool(_auto, on);
    state = _copy(auto: on, error: state.error);
  }

  Future<void> disconnect() async {
    try {
      await _service.disconnect();
    } catch (_) {
      // Already signed out or offline: forget the connection anyway.
    }
    for (final k in [
      _connected,
      _account,
      _folder,
      _auto,
      _lastAt,
      _lastBytes,
      _lastFile,
      _error,
    ]) {
      await _prefs.remove(k);
    }
    state = const DriveState();
  }
}

final driveBackupProvider = NotifierProvider<DriveBackupNotifier, DriveState>(
  DriveBackupNotifier.new,
);
