import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/format.dart';
import 'csv_codec.dart';
import 'daos/history_dao.dart';
import 'daos/plan_dao.dart';
import 'database.dart';

/// Result of a successful export.
class ExportResult {
  ExportResult({required this.fileName, required this.data});

  final String fileName;
  final BackupData data;
}

/// A picked and fully validated file, ready to import.
class ImportPreview {
  ImportPreview({
    required this.fileName,
    required this.sizeBytes,
    required this.data,
  });

  final String fileName;
  final int sizeBytes;
  final BackupData data;
}

/// Picking or parsing failed. Nothing in the database has changed.
class ImportFailure implements Exception {
  ImportFailure({required this.fileName, required this.message});

  final String fileName;
  final String message;

  @override
  String toString() => '$fileName: $message';
}

/// Moves the whole plan + history to and from the CSV format (spec §5).
class CsvBackupService {
  CsvBackupService(this.db);

  final AppDatabase db;

  // ---- Database -> BackupData -------------------------------------------------

  Future<BackupData> snapshot() async {
    final plan = await PlanDao(db).loadPlan();
    final sessions = await HistoryDao(db).loadSessions();

    final days = <BackupDay>[];
    for (final d in plan) {
      final day = BackupDay(d.name);
      day.warmups.addAll(d.namedWarmups.map(_routine));
      day.cooldowns.addAll(d.namedCooldowns.map(_routine));
      for (final p in d.parts) {
        // Body parts without exercises have no rows in the format.
        if (p.exercises.isEmpty) continue;
        final part = BackupPart(p.name);
        for (final e in p.exercises) {
          if (e.sets.isEmpty) continue;
          final exercise = BackupExercise(e.name, videoUrl: e.videoUrl);
          exercise.sets.addAll(
            e.sets.map(
              (s) => BackupSet(
                weightKg: s.weight,
                reps: s.reps,
                lastWeightKg: s.lastWeight,
                lastReps: s.lastReps,
              ),
            ),
          );
          part.exercises.add(exercise);
        }
        if (part.exercises.isNotEmpty) day.parts.add(part);
      }
      days.add(day);
    }

    return BackupData(
      days: days,
      sessions: [
        for (final s in sessions)
          BackupSession(
              id: '${s.session.id}',
              startedAt: s.session.startedAt,
              minutes: s.session.minutes,
              dayName: s.session.dayName,
              partsLabel: s.session.partsLabel,
              totalSets: s.session.totalSets,
              warmDone: s.session.warmDone,
              warmTotal: s.session.warmTotal,
              coolDone: s.session.coolDone,
              coolTotal: s.session.coolTotal,
            )
            ..exercises.addAll([
              for (final e in s.exercises)
                BackupSessionExercise(
                    e.exercise.name,
                    improved: e.exercise.improved,
                  )
                  ..sets.addAll(
                    e.sets.map(
                      (x) => BackupSessionSet(weightKg: x.weight, reps: x.reps),
                    ),
                  ),
            ]),
      ],
    );
  }

  static BackupRoutine _routine(RoutineItem r) =>
      BackupRoutine(name: r.name, detail: r.detail, videoUrl: r.videoUrl);

  // ---- BackupData -> Database -------------------------------------------------

  /// Replaces the current plan, history and any in-progress workout with
  /// [data], in one transaction.
  Future<void> replaceAll(BackupData data) async {
    await db.transaction(() async {
      await db.delete(db.activeWorkouts).go();
      await db.delete(db.sessions).go(); // cascades to exercises / sets
      await db.delete(db.splitDays).go(); // cascades to the whole plan

      final dayIds = <String, int>{};
      for (var di = 0; di < data.days.length; di++) {
        final d = data.days[di];
        final dayId = await db
            .into(db.splitDays)
            .insert(SplitDaysCompanion.insert(position: di, name: d.name));
        dayIds[d.name] = dayId;

        for (final (kind, items) in [
          (RoutineKind.warmup, d.warmups),
          (RoutineKind.cooldown, d.cooldowns),
        ]) {
          for (var i = 0; i < items.length; i++) {
            await db
                .into(db.routineItems)
                .insert(
                  RoutineItemsCompanion.insert(
                    dayId: dayId,
                    kind: kind,
                    position: i,
                    name: items[i].name,
                    detail: Value(items[i].detail),
                    videoUrl: Value(items[i].videoUrl),
                  ),
                );
          }
        }

        for (var pi = 0; pi < d.parts.length; pi++) {
          final p = d.parts[pi];
          final partId = await db
              .into(db.bodyParts)
              .insert(
                BodyPartsCompanion.insert(
                  dayId: dayId,
                  position: pi,
                  name: p.name,
                ),
              );
          for (var ei = 0; ei < p.exercises.length; ei++) {
            final e = p.exercises[ei];
            final exerciseId = await db
                .into(db.exercises)
                .insert(
                  ExercisesCompanion.insert(
                    bodyPartId: partId,
                    position: ei,
                    name: e.name,
                    videoUrl: Value(e.videoUrl),
                  ),
                );
            for (var si = 0; si < e.sets.length; si++) {
              final s = e.sets[si];
              await db
                  .into(db.exerciseSets)
                  .insert(
                    ExerciseSetsCompanion.insert(
                      exerciseId: exerciseId,
                      position: si,
                      weight: Value(s.weightKg),
                      reps: s.reps,
                      lastWeight: Value(s.lastWeightKg),
                      lastReps: Value(s.lastReps),
                    ),
                  );
            }
          }
        }
      }

      for (final s in data.sessions) {
        final sessionId = await db
            .into(db.sessions)
            .insert(
              SessionsCompanion.insert(
                dayId: Value(dayIds[s.dayName]),
                dayName: s.dayName,
                partsLabel: Value(s.partsLabel),
                startedAt: s.startedAt,
                finishedAt: s.startedAt.add(Duration(minutes: s.minutes)),
                minutes: s.minutes,
                totalSets: s.totalSets,
                warmDone: Value(s.warmDone),
                warmTotal: Value(s.warmTotal),
                coolDone: Value(s.coolDone),
                coolTotal: Value(s.coolTotal),
              ),
            );
        for (var ei = 0; ei < s.exercises.length; ei++) {
          final e = s.exercises[ei];
          final seId = await db
              .into(db.sessionExercises)
              .insert(
                SessionExercisesCompanion.insert(
                  sessionId: sessionId,
                  position: ei,
                  name: e.name,
                  improved: Value(e.improved),
                ),
              );
          for (var si = 0; si < e.sets.length; si++) {
            await db
                .into(db.sessionSets)
                .insert(
                  SessionSetsCompanion.insert(
                    sessionExerciseId: seId,
                    position: si,
                    weight: e.sets[si].weightKg,
                    reps: e.sets[si].reps,
                  ),
                );
          }
        }
      }
    });
  }

  // ---- Files ------------------------------------------------------------------

  /// Writes `workout-tracker-YYYY-MM-DD.csv` and opens the share sheet.
  Future<ExportResult> exportAndShare({DateTime? now}) async {
    final data = await snapshot();
    final fileName =
        'workout-tracker-${fmtFileDate(now ?? DateTime.now())}.csv';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(encodeBackup(data), encoding: utf8, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: fileName)],
        fileNameOverrides: [fileName],
        subject: fileName,
      ),
    );
    return ExportResult(fileName: fileName, data: data);
  }

  /// Opens the file picker (.csv only) and validates the whole file.
  /// Returns null if the user cancelled. Throws [ImportFailure].
  Future<ImportPreview?> pickAndParse() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (files.isEmpty) return null;
    final picked = files.first;
    final bytes = await picked.xFile.readAsBytes();
    return parseBytes(picked.name, bytes);
  }

  static ImportPreview parseBytes(String fileName, List<int> bytes) {
    if (!fileName.toLowerCase().endsWith('.csv')) {
      throw ImportFailure(
        fileName: fileName,
        message: 'Only .csv files can be imported',
      );
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw ImportFailure(
        fileName: fileName,
        message: 'The file is not UTF-8 text',
      );
    }
    try {
      return ImportPreview(
        fileName: fileName,
        sizeBytes: bytes.length,
        data: decodeBackup(text),
      );
    } on CsvFormatException catch (e) {
      throw ImportFailure(fileName: fileName, message: e.message);
    }
  }
}

/// "2 days, 3 exercises and 1 workout".
String summaryShort(BackupData d) =>
    '${plural(d.dayCount, 'day')}, ${plural(d.exerciseCount, 'exercise')} '
    'and ${plural(d.sessionCount, 'workout')}';

/// "2 days · 3 exercises, 6 sets · 2 warm-up + 1 cool-down items ·
/// 1 workout in history".
String summaryLong(BackupData d) {
  final routines = d.warmupCount + d.cooldownCount;
  return '${plural(d.dayCount, 'day')} · '
      '${plural(d.exerciseCount, 'exercise')}, ${plural(d.setCount, 'set')} · '
      '${d.warmupCount} warm-up + ${d.cooldownCount} cool-down '
      '${routines == 1 ? 'item' : 'items'} · '
      '${plural(d.sessionCount, 'workout')} in history';
}

String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
