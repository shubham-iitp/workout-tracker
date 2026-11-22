/// Workout Tracker CSV format (tech spec §5). Pure Dart, no database or
/// Flutter imports, so it can be unit-tested on its own.
library;

import '../app/random_palette.dart';

const csvColumns = [
  'type',
  'day',
  'section',
  'body_part',
  'exercise',
  'set',
  'weight_kg',
  'reps',
  'detail',
  'video_url',
  'last_weight_kg',
  'last_reps',
  'session_id',
  'started_at',
  'minutes',
  'improved',
  'warm_done',
  'warm_total',
  'cool_done',
  'cool_total',
];

const maxBackupDays = 14;

// ---------------------------------------------------------------------------
// In-memory model of a backup file
// ---------------------------------------------------------------------------

class BackupData {
  BackupData({
    required this.days,
    required this.sessions,
    List<BackupPalette>? palettes,
    this.selectedPalette,
  }) : palettes = palettes ?? [];

  final List<BackupDay> days;
  final List<BackupSession> sessions;

  /// Saved random palettes, in list order.
  final List<BackupPalette> palettes;
  int get paletteCount => palettes.length;

  /// The palette the app uses: a preset's name ("Ocean blue") or one of
  /// [palettes]. Null in files from before it was backed up.
  final String? selectedPalette;

  int get dayCount => days.length;
  int get exerciseCount => days.fold(
    0,
    (n, d) => n + d.parts.fold(0, (m, p) => m + p.exercises.length),
  );
  int get setCount => days.fold(
    0,
    (n, d) =>
        n +
        d.parts.fold(
          0,
          (m, p) => m + p.exercises.fold(0, (k, e) => k + e.sets.length),
        ),
  );
  int get warmupCount => days.fold(0, (n, d) => n + d.warmups.length);
  int get cooldownCount => days.fold(0, (n, d) => n + d.cooldowns.length);
  int get sessionCount => sessions.length;
}

class BackupDay {
  BackupDay(this.name);

  final String name;
  final List<BackupRoutine> warmups = [];
  final List<BackupRoutine> cooldowns = [];
  final List<BackupPart> parts = [];
}

class BackupRoutine {
  BackupRoutine({required this.name, this.detail = '', this.videoUrl});

  final String name;
  final String detail;
  final String? videoUrl;
}

class BackupPart {
  BackupPart(this.name);

  final String name;
  final List<BackupExercise> exercises = [];
}

class BackupExercise {
  BackupExercise(this.name, {this.videoUrl});

  final String name;
  final String? videoUrl;
  final List<BackupSet> sets = [];
}

class BackupSet {
  BackupSet({
    required this.weightKg,
    required this.reps,
    this.lastWeightKg,
    this.lastReps,
  });

  final double weightKg;
  final int reps;
  final double? lastWeightKg;
  final int? lastReps;
}

class BackupSession {
  BackupSession({
    required this.id,
    required this.startedAt,
    required this.minutes,
    required this.dayName,
    required this.partsLabel,
    required this.totalSets,
    required this.warmDone,
    required this.warmTotal,
    required this.coolDone,
    required this.coolTotal,
  });

  /// Only meaningful inside one file ("s1"); export renumbers.
  final String id;
  final DateTime startedAt;
  final int minutes;
  final String dayName;
  final String partsLabel;
  final int totalSets;
  final int warmDone;
  final int warmTotal;
  final int coolDone;
  final int coolTotal;
  final List<BackupSessionExercise> exercises = [];
}

class BackupSessionExercise {
  BackupSessionExercise(this.name, {required this.improved});

  final String name;
  final bool improved;
  final List<BackupSessionSet> sets = [];
}

class BackupSessionSet {
  BackupSessionSet({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;
}

/// A saved random palette. In the file it is one `palette` row: the name in
/// the `exercise` column and every colour in `detail` as
/// `scheme=analogous;hue=4;ink=#2B1A19;dark=#…;…` (no commas, so no quoting).
class BackupPalette {
  BackupPalette({
    required this.name,
    required this.scheme,
    required this.hue,
    required this.colors,
  });

  final String name;
  final String scheme;
  final int hue;
  final PaletteColors colors;

  String encodeDetail() => [
    'scheme=$scheme',
    'hue=$hue',
    for (final k in paletteTokenKeys) '$k=${colors[k]}',
  ].join(';');
}

/// Import failed. [message] names the row and column, e.g.
/// "Row 14 has no value in the reps column".
class CsvFormatException implements Exception {
  CsvFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/// Serialises [data] to the CSV format. Session ids are renumbered s1, s2, …
String encodeBackup(BackupData data) {
  final rows = <List<String>>[csvColumns];

  List<String> row(Map<String, String> cells) => [
    for (final c in csvColumns) cells[c] ?? '',
  ];

  for (final d in data.days) {
    rows.add(row({'type': 'day', 'day': d.name}));
  }
  for (final d in data.days) {
    for (final (section, items) in [
      ('warmup', d.warmups),
      ('cooldown', d.cooldowns),
    ]) {
      for (final r in items) {
        rows.add(
          row({
            'type': 'routine',
            'day': d.name,
            'section': section,
            'exercise': r.name,
            'detail': r.detail,
            'video_url': r.videoUrl ?? '',
          }),
        );
      }
    }
  }
  for (final d in data.days) {
    for (final p in d.parts) {
      for (final e in p.exercises) {
        for (var i = 0; i < e.sets.length; i++) {
          final s = e.sets[i];
          rows.add(
            row({
              'type': 'set',
              'day': d.name,
              'body_part': p.name,
              'exercise': e.name,
              'set': '${i + 1}',
              'weight_kg': formatCsvNumber(s.weightKg),
              'reps': '${s.reps}',
              'video_url': e.videoUrl ?? '',
              'last_weight_kg': s.lastWeightKg == null
                  ? ''
                  : formatCsvNumber(s.lastWeightKg!),
              'last_reps': s.lastReps?.toString() ?? '',
            }),
          );
        }
      }
    }
  }
  for (var i = 0; i < data.sessions.length; i++) {
    final s = data.sessions[i];
    final id = 's${i + 1}';
    rows.add(
      row({
        'type': 'session',
        'day': s.dayName,
        'body_part': s.partsLabel,
        'set': '${s.totalSets}',
        'session_id': id,
        'started_at': formatIsoLocal(s.startedAt),
        'minutes': '${s.minutes}',
        'warm_done': '${s.warmDone}',
        'warm_total': '${s.warmTotal}',
        'cool_done': '${s.coolDone}',
        'cool_total': '${s.coolTotal}',
      }),
    );
    for (final e in s.exercises) {
      for (var j = 0; j < e.sets.length; j++) {
        final set = e.sets[j];
        rows.add(
          row({
            'type': 'session_set',
            'exercise': e.name,
            'set': '${j + 1}',
            'weight_kg': formatCsvNumber(set.weightKg),
            'reps': '${set.reps}',
            'session_id': id,
            'improved': e.improved ? 'true' : 'false',
          }),
        );
      }
    }
  }
  for (final p in data.palettes) {
    rows.add(
      row({'type': 'palette', 'exercise': p.name, 'detail': p.encodeDetail()}),
    );
  }
  if (data.selectedPalette case final name?) {
    rows.add(row({'type': 'theme', 'exercise': name}));
  }

  final out = StringBuffer();
  for (final r in rows) {
    out.write(r.map(_quote).join(','));
    out.write('\n');
  }
  return out.toString();
}

String _quote(String cell) {
  if (cell.contains(',') ||
      cell.contains('"') ||
      cell.contains('\n') ||
      cell.contains('\r')) {
    return '"${cell.replaceAll('"', '""')}"';
  }
  return cell;
}

/// "60", "62.5", "27.216" — up to 3 decimals, no trailing zeros.
String formatCsvNumber(double v) {
  var s = v.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}

/// "2026-11-16T06:55:00" in local time.
String formatIsoLocal(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}'
      'T${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/// Splits CSV text into rows of cells (RFC 4180: quoted cells, doubled quotes,
/// CRLF or LF). Trailing blank lines are dropped.
List<List<String>> splitCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        cell.write(ch);
      }
      i++;
      continue;
    }
    switch (ch) {
      case '"':
        inQuotes = true;
      case ',':
        endCell();
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        cell.write(ch);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();

  while (rows.isNotEmpty &&
      rows.last.length == 1 &&
      rows.last.first.trim().isEmpty) {
    rows.removeLast();
  }
  return rows;
}

/// Parses and validates the whole file. Throws [CsvFormatException] with a
/// row/column message on the first problem; never returns partial data.
BackupData decodeBackup(String text) {
  final rows = splitCsv(text);
  if (rows.isEmpty || !_isHeader(rows.first)) {
    throw CsvFormatException('Row 1 is not the Workout Tracker header');
  }

  final days = <BackupDay>[];
  final dayByName = <String, BackupDay>{};
  final partByKey = <String, BackupPart>{};
  final exerciseByKey = <String, BackupExercise>{};
  final sessions = <BackupSession>[];
  final sessionById = <String, BackupSession>{};
  final palettes = <BackupPalette>[];
  String? selected;
  var selectedRow = 0;

  for (var i = 1; i < rows.length; i++) {
    final r = _Row(rows[i], i + 1);
    if (rows[i].length != csvColumns.length) {
      throw CsvFormatException(
        'Row ${r.number} has ${rows[i].length} columns, '
        'expected ${csvColumns.length}',
      );
    }

    BackupDay dayFor() {
      final name = r.required('day');
      final day = dayByName[name];
      if (day == null) {
        throw CsvFormatException(
          "Row ${r.number} uses day '$name', which has no day row",
        );
      }
      return day;
    }

    switch (r.cell('type')) {
      case 'day':
        final name = r.required('day');
        if (dayByName.containsKey(name)) {
          throw CsvFormatException(
            "Row ${r.number} repeats day '$name'; day names must be unique",
          );
        }
        if (days.length >= maxBackupDays) {
          throw CsvFormatException(
            'Row ${r.number} is day ${days.length + 1}; '
            'the app allows up to $maxBackupDays days',
          );
        }
        final day = BackupDay(name);
        days.add(day);
        dayByName[name] = day;

      case 'routine':
        final day = dayFor();
        final section = r.required('section');
        final item = BackupRoutine(
          name: r.required('exercise'),
          detail: r.cell('detail'),
          videoUrl: r.optional('video_url'),
        );
        switch (section) {
          case 'warmup':
            day.warmups.add(item);
          case 'cooldown':
            day.cooldowns.add(item);
          default:
            throw CsvFormatException(
              "Row ${r.number} has '$section' in the section column",
            );
        }

      case 'set':
        final day = dayFor();
        final partName = r.required('body_part');
        final exerciseName = r.required('exercise');
        r.integer('set');
        final set = BackupSet(
          weightKg: r.decimal('weight_kg'),
          reps: r.integer('reps'),
          lastWeightKg: r.optionalNumber('last_weight_kg'),
          lastReps: r.optionalInteger('last_reps'),
        );
        final partKey = '${day.name}\u0000$partName';
        final part = partByKey.putIfAbsent(partKey, () {
          final p = BackupPart(partName);
          day.parts.add(p);
          return p;
        });
        final exerciseKey = '$partKey\u0000$exerciseName';
        final exercise = exerciseByKey.putIfAbsent(exerciseKey, () {
          final e = BackupExercise(
            exerciseName,
            videoUrl: r.optional('video_url'),
          );
          part.exercises.add(e);
          return e;
        });
        exercise.sets.add(set);

      case 'session':
        final id = r.required('session_id');
        if (sessionById.containsKey(id)) {
          throw CsvFormatException(
            "Row ${r.number} repeats session '$id'; session ids must be unique",
          );
        }
        final session = BackupSession(
          id: id,
          startedAt: r.dateTime('started_at'),
          minutes: r.integer('minutes'),
          dayName: r.required('day'),
          partsLabel: r.cell('body_part'),
          totalSets: r.integer('set'),
          warmDone: r.integer('warm_done'),
          warmTotal: r.integer('warm_total'),
          coolDone: r.integer('cool_done'),
          coolTotal: r.integer('cool_total'),
        );
        sessions.add(session);
        sessionById[id] = session;

      case 'session_set':
        final id = r.required('session_id');
        final session = sessionById[id];
        if (session == null) {
          throw CsvFormatException(
            "Row ${r.number} uses session '$id', which has no session row",
          );
        }
        final name = r.required('exercise');
        r.integer('set');
        final set = BackupSessionSet(
          weightKg: r.decimal('weight_kg'),
          reps: r.integer('reps'),
        );
        final improved = r.boolean('improved');
        // Consecutive rows with the same exercise name belong together.
        final last = session.exercises.isEmpty ? null : session.exercises.last;
        final BackupSessionExercise exercise;
        if (last != null && last.name == name) {
          exercise = last;
        } else {
          exercise = BackupSessionExercise(name, improved: improved);
          session.exercises.add(exercise);
        }
        exercise.sets.add(set);

      case 'palette':
        final name = r.required('exercise');
        if (name.length > maxPaletteNameLength) {
          throw CsvFormatException(
            "Row ${r.number} has palette name '$name'; "
            'names are up to $maxPaletteNameLength characters',
          );
        }
        if (isPresetPaletteName(name)) {
          throw CsvFormatException(
            "Row ${r.number} uses the built-in palette name '$name'",
          );
        }
        if (palettes.any((p) => samePaletteName(p.name, name))) {
          throw CsvFormatException(
            "Row ${r.number} repeats palette '$name'; "
            'palette names must be unique',
          );
        }
        palettes.add(_paletteDetail(r, name));

      case 'theme':
        final name = r.required('exercise');
        if (selected != null) {
          throw CsvFormatException(
            'Row ${r.number} is a second theme row; '
            'a file selects one palette',
          );
        }
        selected = name;
        selectedRow = r.number;

      case '':
        throw CsvFormatException(
          'Row ${r.number} has no value in the type column',
        );

      default:
        throw CsvFormatException(
          "Row ${r.number} has an unknown type '${r.cell('type')}'",
        );
    }
  }

  // Checked after every row: the palette row may come after the theme row.
  if (selected != null) {
    final preset = presetPaletteNames
        .where((p) => samePaletteName(p, selected!))
        .firstOrNull;
    final saved = palettes
        .where((p) => samePaletteName(p.name, selected!))
        .firstOrNull;
    if (preset == null && saved == null) {
      throw CsvFormatException(
        "Row $selectedRow selects palette '$selected', "
        'which is not a built-in palette or a palette row in the file',
      );
    }
    selected = preset ?? saved!.name;
  }

  return BackupData(
    days: days,
    sessions: sessions,
    palettes: palettes,
    selectedPalette: selected,
  );
}

/// Parses a `palette` row's `detail` cell (see [BackupPalette]).
BackupPalette _paletteDetail(_Row r, String name) {
  final detail = r.required('detail');
  final values = <String, String>{};
  for (final part in detail.split(';')) {
    final eq = part.indexOf('=');
    if (eq <= 0) {
      throw CsvFormatException(
        "Row ${r.number} has '$part' in the detail column; "
        'expected key=value pairs',
      );
    }
    values[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
  }

  final scheme = values['scheme'] ?? '';
  if (!paletteSchemes.contains(scheme)) {
    throw CsvFormatException(
      "Row ${r.number} has scheme '$scheme' in the detail column",
    );
  }
  final hue = int.tryParse(values['hue'] ?? '');
  if (hue == null || hue < 0 || hue > 359) {
    throw CsvFormatException(
      "Row ${r.number} has hue '${values['hue'] ?? ''}' in the detail column",
    );
  }
  final colors = <String, String>{};
  for (final k in paletteTokenKeys) {
    final v = (values[k] ?? '').toUpperCase();
    if (v.isEmpty) {
      throw CsvFormatException(
        'Row ${r.number} has no $k colour in the detail column',
      );
    }
    if (!isPaletteHex(v)) {
      throw CsvFormatException(
        "Row ${r.number} has '${values[k]}' as the $k colour in the detail column",
      );
    }
    colors[k] = v;
  }
  return BackupPalette(
    name: name,
    scheme: scheme,
    hue: hue,
    colors: PaletteColors(colors),
  );
}

bool _isHeader(List<String> row) {
  if (row.length != csvColumns.length) return false;
  for (var i = 0; i < row.length; i++) {
    if (row[i].trim() != csvColumns[i]) return false;
  }
  return true;
}

final _isoPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:?\d{2})?$',
);

/// One data row with typed, validated accessors.
class _Row {
  _Row(this.cells, this.number);

  final List<String> cells;

  /// 1-based, header is row 1.
  final int number;

  String cell(String column) => cells[csvColumns.indexOf(column)].trim();

  String required(String column) {
    final v = cell(column);
    if (v.isEmpty) {
      throw CsvFormatException(
        'Row $number has no value in the $column column',
      );
    }
    return v;
  }

  String? optional(String column) {
    final v = cell(column);
    return v.isEmpty ? null : v;
  }

  Never _bad(String column, String value) => throw CsvFormatException(
    "Row $number has '$value' in the $column column",
  );

  double decimal(String column) {
    final v = required(column);
    final d = double.tryParse(v);
    if (d == null || !d.isFinite || d < 0) _bad(column, v);
    return d;
  }

  double? optionalNumber(String column) =>
      cell(column).isEmpty ? null : decimal(column);

  int integer(String column) {
    final v = required(column);
    final n = int.tryParse(v);
    if (n == null || n < 0) _bad(column, v);
    return n;
  }

  int? optionalInteger(String column) =>
      cell(column).isEmpty ? null : integer(column);

  bool boolean(String column) {
    final v = cell(column).toLowerCase();
    if (v.isEmpty || v == 'false') return false;
    if (v == 'true') return true;
    _bad(column, cell(column));
  }

  DateTime dateTime(String column) {
    final v = required(column);
    final d = _isoPattern.hasMatch(v) ? DateTime.tryParse(v) : null;
    if (d == null) _bad(column, v);
    return d.toLocal();
  }
}
