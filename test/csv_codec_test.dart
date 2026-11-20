import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/data/csv_backup_service.dart';
import 'package:workout_tracker/data/csv_codec.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

const header =
    'type,day,section,body_part,exercise,set,weight_kg,reps,detail,video_url,'
    'last_weight_kg,last_reps,session_id,started_at,minutes,improved,'
    'warm_done,warm_total,cool_done,cool_total';

/// Builds a 20-column row from a sparse map.
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
  group('sample_valid.csv (spec §5.1)', () {
    late BackupData data;
    setUp(() => data = decodeBackup(fixture('sample_valid.csv')));

    test('parses the plan', () {
      expect(data.days.map((d) => d.name), ['Day 1', 'Day 2']);
      final day1 = data.days.first;
      expect(day1.warmups.map((r) => r.name), [
        'Arm circles',
        'Band pull-aparts',
      ]);
      expect(day1.warmups.first.videoUrl, contains('arm+circles'));
      expect(day1.warmups[1].detail, '2 × 15');
      expect(day1.cooldowns.single.detail, '30 sec, each side');
      expect(day1.parts.map((p) => p.name), ['Chest', 'Triceps']);
      final bench = day1.parts.first.exercises.first;
      expect(bench.name, 'Bench press');
      expect(bench.sets.map((s) => s.weightKg), [60, 62.5]);
      expect(bench.sets.map((s) => s.lastWeightKg), [60, 60]);
      final rope = day1.parts[1].exercises.single;
      expect(rope.sets.first.lastWeightKg, isNull);
      expect(data.days[1].parts, isEmpty);
    });

    test('parses history', () {
      final s = data.sessions.single;
      expect(s.startedAt, DateTime(2026, 11, 16, 6, 55));
      expect(s.minutes, 49);
      expect(s.partsLabel, 'Chest & Triceps');
      expect(s.totalSets, 6);
      expect([s.warmDone, s.warmTotal, s.coolDone, s.coolTotal], [2, 2, 1, 1]);
      expect(s.exercises.map((e) => e.name), ['Bench press', 'Cable fly']);
      final volume = s.exercises
          .expand((e) => e.sets)
          .fold(0.0, (v, x) => v + x.weightKg * x.reps);
      expect(volume, 1320);
    });

    test('import sheet summary', () {
      expect(
        summaryLong(data),
        '2 days · 3 exercises, 6 sets · 2 warm-up + 1 cool-down items · '
        '1 workout in history',
      );
      expect(summaryShort(data), '2 days, 3 exercises and 1 workout');
    });

    test('round trip: export is identical to the imported file', () {
      expect(encodeBackup(data), fixture('sample_valid.csv'));
    });
  });

  group('invalid files (spec §5.2)', () {
    test('missing reps', () {
      expect(
        expectError(fixture('sample_missing_reps.csv')),
        'Row 3 has no value in the reps column',
      );
    });

    test('header missing or reordered', () {
      expect(
        expectError(row({'type': 'day', 'day': 'Day 1'})),
        'Row 1 is not the Workout Tracker header',
      );
      expect(
        expectError(header.replaceFirst('day,section', 'section,day')),
        'Row 1 is not the Workout Tracker header',
      );
    });

    test('wrong column count', () {
      final csv = [
        header,
        row({'type': 'day', 'day': 'Day 1'}),
        row({'type': 'day', 'day': 'Day 2'}),
        row({'type': 'day', 'day': 'Day 3'}),
        'day,Day 4,,,,,,,,,,,,,,,,',
      ].join('\n');
      expect(expectError(csv), 'Row 5 has 18 columns, expected 20');
    });

    test('unknown type', () {
      final csv = [
        header,
        row({'type': 'day', 'day': 'Day 1'}),
        row({'type': 'day', 'day': 'Day 2'}),
        row({'type': 'exercise', 'day': 'Day 1'}),
      ].join('\n');
      expect(expectError(csv), "Row 4 has an unknown type 'exercise'");
    });

    test('day with no day row', () {
      final csv = [
        header,
        for (var i = 1; i <= 4; i++) row({'type': 'day', 'day': 'Day $i'}),
        row({
          'type': 'set',
          'day': 'Day 9',
          'body_part': 'Chest',
          'exercise': 'Bench',
          'set': '1',
          'weight_kg': '60',
          'reps': '8',
        }),
      ].join('\n');
      expect(expectError(csv), "Row 6 uses day 'Day 9', which has no day row");
    });

    test('number column not a number', () {
      final csv = [
        header,
        for (var i = 1; i <= 5; i++) row({'type': 'day', 'day': 'Day $i'}),
        row({
          'type': 'set',
          'day': 'Day 1',
          'body_part': 'Chest',
          'exercise': 'Bench',
          'set': '1',
          'weight_kg': 'sixty',
          'reps': '8',
        }),
      ].join('\n');
      expect(expectError(csv), "Row 7 has 'sixty' in the weight_kg column");
    });

    test('bad section', () {
      final csv = [
        header,
        row({'type': 'day', 'day': 'Day 1'}),
        row({'type': 'day', 'day': 'Day 2'}),
        row({
          'type': 'routine',
          'day': 'Day 1',
          'section': 'stretch',
          'exercise': 'X',
        }),
      ].join('\n');
      expect(expectError(csv), "Row 4 has 'stretch' in the section column");
    });

    test('session_set without its session', () {
      final csv = [
        header,
        row({'type': 'day', 'day': 'Day 1'}),
        row({
          'type': 'session_set',
          'session_id': 's9',
          'exercise': 'Bench',
          'set': '1',
          'weight_kg': '60',
          'reps': '8',
        }),
      ].join('\n');
      expect(
        expectError(csv),
        "Row 3 uses session 's9', which has no session row",
      );
    });

    test('started_at not ISO 8601', () {
      final csv = [
        header,
        row({'type': 'day', 'day': 'Day 1'}),
        row({
          'type': 'session',
          'day': 'Day 1',
          'set': '6',
          'session_id': 's1',
          'started_at': '16/11/2026',
          'minutes': '49',
          'warm_done': '0',
          'warm_total': '0',
          'cool_done': '0',
          'cool_total': '0',
        }),
      ].join('\n');
      expect(
        expectError(csv),
        "Row 3 has '16/11/2026' in the started_at column",
      );
    });

    test('more than 14 days', () {
      final csv = [
        header,
        for (var i = 1; i <= 15; i++) row({'type': 'day', 'day': 'Day $i'}),
      ].join('\n');
      expect(
        expectError(csv),
        'Row 16 is day 15; the app allows up to 14 days',
      );
    });
  });

  group('csv details', () {
    test('quotes commas and doubles quotes', () {
      final rows = splitCsv('a,"b, c","say ""hi"""\r\nd,e,f\n\n');
      expect(rows, [
        ['a', 'b, c', 'say "hi"'],
        ['d', 'e', 'f'],
      ]);
    });

    test('number formatting', () {
      expect(formatCsvNumber(60), '60');
      expect(formatCsvNumber(62.5), '62.5');
      expect(formatCsvNumber(0), '0');
      expect(formatCsvNumber(27.2156), '27.216');
    });

    test('parseBytes rejects non-csv and reports file name', () {
      expect(
        () => CsvBackupService.parseBytes('x.txt', [65]),
        throwsA(isA<ImportFailure>()),
      );
      try {
        CsvBackupService.parseBytes(
          'sample_missing_reps.csv',
          File('test/fixtures/sample_missing_reps.csv').readAsBytesSync(),
        );
        fail('should throw');
      } on ImportFailure catch (e) {
        expect(e.fileName, 'sample_missing_reps.csv');
        expect(e.message, 'Row 3 has no value in the reps column');
      }
    });
  });
}
