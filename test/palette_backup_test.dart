// Saved random palettes are part of the backup: stored in the database,
// written to the CSV (Export + Drive), and restored by Import.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app/random_palette.dart';
import 'package:workout_tracker/data/csv_backup_service.dart';
import 'package:workout_tracker/data/csv_codec.dart';
import 'package:workout_tracker/data/daos/palette_dao.dart';
import 'package:workout_tracker/data/database.dart';

String row(Map<String, String> cells) =>
    [for (final c in csvColumns) cells[c] ?? ''].join(',');

String expectError(String csv) {
  try {
    decodeBackup(csv);
  } on CsvFormatException catch (e) {
    return e.message;
  }
  fail('expected the file to be rejected');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final sample = File('test/fixtures/sample_valid.csv').readAsStringSync();
  final header = sample.split('\n').first;
  final seven = generatePalette(seededRandom(7))!;
  final ninetyNine = generatePalette(seededRandom(99))!;

  String paletteRow(String name, GeneratedPalette p) => row({
    'type': 'palette',
    'exercise': name,
    'detail': BackupPalette(
      name: name,
      scheme: p.scheme,
      hue: p.hue,
      colors: p.colors,
    ).encodeDetail(),
  });

  group('CSV', () {
    test('palette rows round-trip and old files still import', () {
      final csv =
          '$sample${paletteRow('Sunset', seven)}\n'
          '${paletteRow('Deep sea', ninetyNine)}\n';
      final data = decodeBackup(csv);
      expect(data.palettes.map((p) => p.name), ['Sunset', 'Deep sea']);
      expect(data.palettes.first.colors, seven.colors);
      expect(data.palettes.first.scheme, 'analogous');
      expect(data.palettes.first.hue, 4);
      expect(encodeBackup(data), csv);

      expect(decodeBackup(sample).palettes, isEmpty);
    });

    test('summaries mention saved palettes only when there are any', () {
      final data = decodeBackup('$sample${paletteRow('Sunset', seven)}\n');
      expect(
        summaryShort(data),
        '2 days, 3 exercises, 1 workout and 1 saved palette',
      );
      expect(
        summaryLong(data),
        endsWith('1 workout in history · 1 saved palette'),
      );
      expect(
        summaryShort(decodeBackup(sample)),
        '2 days, 3 exercises and 1 workout',
      );
    });

    test('bad palette rows are rejected with the row', () {
      final good = paletteRow('Sunset', seven);
      expect(
        expectError('$header\n$good\n$good\n'),
        "Row 3 repeats palette 'Sunset'; palette names must be unique",
      );
      expect(
        expectError('$header\n${paletteRow('lime', seven)}\n'),
        "Row 2 uses the built-in palette name 'lime'",
      );
      expect(
        expectError('$header\n${row({'type': 'palette', 'detail': 'x=1'})}\n'),
        'Row 2 has no value in the exercise column',
      );
      expect(
        expectError(
          '$header\n${good.replaceFirst(RegExp('ink=#[0-9A-F]{6}'), 'ink=red')}\n',
        ),
        "Row 2 has 'red' as the ink colour in the detail column",
      );
      expect(
        expectError(
          '$header\n${good.replaceFirst(RegExp(';accent=#[0-9A-F]{6}'), '')}\n',
        ),
        'Row 2 has no accent colour in the detail column',
      );
      expect(
        expectError(
          '$header\n${good.replaceFirst('scheme=analogous', 'scheme=mono')}\n',
        ),
        "Row 2 has scheme 'mono' in the detail column",
      );
    });
  });

  group('database', () {
    late AppDatabase db;
    late PaletteDao dao;
    late CsvBackupService backup;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = PaletteDao(db);
      backup = CsvBackupService(db);
    });
    tearDown(() => db.close());

    test('saving adds palettes in order; the same name replaces', () async {
      final a = await dao.save('Sunset', seven);
      await dao.save('Deep sea', ninetyNine);
      final replaced = await dao.save(' sunset ', ninetyNine);

      final all = await dao.loadAll();
      expect(all.map((p) => p.name), ['sunset', 'Deep sea']);
      expect(replaced.id, a.id);
      expect(all.first.colors, ninetyNine.colors);
    });

    test('preset names cannot be saved', () async {
      expect(() => dao.save('Lime', seven), throwsArgumentError);
      expect(() => dao.save('  ', seven), throwsArgumentError);
    });

    test('export includes saved palettes, import restores them', () async {
      await backup.replaceAll(decodeBackup(sample));
      await dao.save('Sunset', seven);
      await dao.save('Deep sea', ninetyNine);

      final exported = encodeBackup(await backup.snapshot());
      expect(exported, startsWith(sample));
      expect(exported, contains('palette,,,,Sunset,'));

      // A fresh phone: import brings the palettes back exactly.
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await CsvBackupService(other).replaceAll(decodeBackup(exported));
      final restored = await PaletteDao(other).loadAll();
      expect(restored.map((p) => p.name), ['Sunset', 'Deep sea']);
      expect(restored.first.colors, seven.colors);
      expect(encodeBackup(await CsvBackupService(other).snapshot()), exported);
    });

    test('import replaces saved palettes', () async {
      await dao.save('Sunset', seven);
      await backup.replaceAll(decodeBackup(sample));
      expect(await dao.loadAll(), isEmpty);
    });
  });
}
