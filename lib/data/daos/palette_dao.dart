import 'dart:convert';

import 'package:drift/drift.dart';

import '../../app/random_palette.dart';
import '../database.dart';

/// A saved random palette, as the app uses it.
class SavedPalette {
  SavedPalette({
    required this.id,
    required this.name,
    required this.scheme,
    required this.hue,
    required this.colors,
  });

  final int id;
  final String name;
  final String scheme;
  final int hue;
  final PaletteColors colors;

  static SavedPalette fromRow(CustomPaletteRow r) => SavedPalette(
    id: r.id,
    name: r.name,
    scheme: r.scheme,
    hue: r.hue,
    colors: decodePaletteColors(r.colors),
  );
}

String encodePaletteColors(PaletteColors c) => jsonEncode(c.colors);

PaletteColors decodePaletteColors(String json) =>
    PaletteColors((jsonDecode(json) as Map).cast<String, String>());

class PaletteDao {
  PaletteDao(this.db);

  final AppDatabase db;

  SimpleSelectStatement<$CustomPalettesTable, CustomPaletteRow> get _all =>
      db.select(db.customPalettes)
        ..orderBy([(p) => OrderingTerm.asc(p.position)]);

  Stream<List<SavedPalette>> watchAll() =>
      _all.watch().map((rows) => rows.map(SavedPalette.fromRow).toList());

  Future<List<SavedPalette>> loadAll() async =>
      (await _all.get()).map(SavedPalette.fromRow).toList();

  /// Saves [palette] as [name]. If a saved palette already has that name
  /// (ignoring case) its colours are replaced in place, keeping its id and
  /// list position; otherwise it is added at the end. Returns the saved row.
  Future<SavedPalette> save(String name, GeneratedPalette palette) {
    final trimmed = name.trim();
    final problem = paletteNameProblem(trimmed);
    if (problem != null) throw ArgumentError(problem);

    return db.transaction(() async {
      final existing = await loadAll();
      final dup = existing
          .where((p) => samePaletteName(p.name, trimmed))
          .firstOrNull;
      final values = CustomPalettesCompanion(
        name: Value(trimmed),
        scheme: Value(palette.scheme),
        hue: Value(palette.hue),
        colors: Value(encodePaletteColors(palette.colors)),
      );
      final int id;
      if (dup != null) {
        id = dup.id;
        await (db.update(
          db.customPalettes,
        )..where((p) => p.id.equals(id))).write(values);
      } else {
        id = await db
            .into(db.customPalettes)
            .insert(values.copyWith(position: Value(existing.length)));
      }
      return SavedPalette(
        id: id,
        name: trimmed,
        scheme: palette.scheme,
        hue: palette.hue,
        colors: palette.colors,
      );
    });
  }
}
