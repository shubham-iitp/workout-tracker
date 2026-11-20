import '../../app/format.dart';
import '../../data/database.dart';
import '../../data/models.dart';

/// Human-readable list of what changed in one day between [before] (when the
/// editor opened) and [after] (now). Items are matched by id, so a renamed
/// exercise shows as a rename, not a remove + add. Empty when nothing changed.
List<String> describeDayChanges(
  DayPlan before,
  DayPlan after,
  WeightUnit unit,
) {
  final out = <String>[];

  if (before.name != after.name) {
    out.add('Renamed day: ${before.name} → ${after.name}');
  }

  _routine(out, 'warm-up', before.warmups, after.warmups);

  final beforeParts = {for (final p in before.parts) p.id: p};
  final afterParts = {for (final p in after.parts) p.id: p};

  for (final p in after.parts) {
    final old = beforeParts[p.id];
    if (old == null) {
      out.add('Added body part: ${p.name}');
      for (final e in p.exercises) {
        out.add('Added exercise: ${e.name} (${_setsSummary(e, unit)})');
      }
      continue;
    }
    if (old.name != p.name) {
      out.add('Renamed body part: ${old.name} → ${p.name}');
    }
    _exercises(out, old, p, unit);
  }
  for (final p in before.parts) {
    if (!afterParts.containsKey(p.id)) {
      out.add(
        p.exercises.isEmpty
            ? 'Removed body part: ${p.name}'
            : 'Removed body part: ${p.name} '
                  '(${plural(p.exercises.length, 'exercise')})',
      );
    }
  }

  _routine(out, 'cool-down', before.cooldowns, after.cooldowns);
  return out;
}

void _routine(
  List<String> out,
  String label,
  List<RoutineItem> before,
  List<RoutineItem> after,
) {
  String n(RoutineItem r) => r.name.trim().isEmpty ? '(no name)' : r.name;
  final old = {for (final r in before) r.id: r};
  final now = {for (final r in after) r.id: r};

  for (final r in after) {
    final o = old[r.id];
    if (o == null) {
      out.add(
        r.name.trim().isEmpty
            ? 'Added an empty $label item'
            : 'Added $label: ${r.name}',
      );
      continue;
    }
    if (o.name != r.name) out.add('Renamed $label: ${n(o)} → ${n(r)}');
    if ((o.videoUrl ?? '') != (r.videoUrl ?? '')) {
      out.add(_videoChange(n(r), o.videoUrl, r.videoUrl));
    }
  }
  for (final r in before) {
    if (!now.containsKey(r.id)) out.add('Removed $label: ${n(r)}');
  }
}

void _exercises(
  List<String> out,
  BodyPartPlan before,
  BodyPartPlan after,
  WeightUnit unit,
) {
  final old = {for (final e in before.exercises) e.id: e};
  final now = {for (final e in after.exercises) e.id: e};

  for (final e in after.exercises) {
    final o = old[e.id];
    if (o == null) {
      out.add('Added exercise: ${e.name} (${_setsSummary(e, unit)})');
      continue;
    }
    if (o.name != e.name) out.add('Renamed exercise: ${o.name} → ${e.name}');
    if ((o.videoUrl ?? '') != (e.videoUrl ?? '')) {
      out.add(_videoChange(e.name, o.videoUrl, e.videoUrl));
    }
    _sets(out, o, e, unit);
  }
  for (final e in before.exercises) {
    if (!now.containsKey(e.id)) out.add('Removed exercise: ${e.name}');
  }
}

void _sets(
  List<String> out,
  ExercisePlan before,
  ExercisePlan after,
  WeightUnit unit,
) {
  final old = {for (final s in before.sets) s.id: s};
  final now = {for (final s in after.sets) s.id: s};
  final added = after.sets.where((s) => !old.containsKey(s.id)).toList();
  final removed = before.sets.where((s) => !now.containsKey(s.id)).toList();

  if (added.isNotEmpty || removed.isNotEmpty) {
    out.add(
      '${after.name}: ${plural(before.sets.length, 'set')} → '
      '${plural(after.sets.length, 'set')}',
    );
  }
  for (final (i, s) in after.sets.indexed) {
    final o = old[s.id];
    if (o == null) continue;
    if (o.weight != s.weight || o.reps != s.reps) {
      out.add(
        '${after.name} · set ${i + 1}: '
        '${fmtSet(o.weight, o.reps, unit)} → ${fmtSet(s.weight, s.reps, unit)}',
      );
    }
  }
}

String _setsSummary(ExercisePlan e, WeightUnit unit) {
  if (e.sets.isEmpty) return 'no sets';
  final pairs = e.sets.map((s) => fmtSet(s.weight, s.reps, unit)).toSet();
  return pairs.length == 1
      ? '${plural(e.sets.length, 'set')} of ${pairs.first}'
      : plural(e.sets.length, 'set');
}

String _videoChange(String name, String? before, String? after) {
  final b = (before ?? '').trim(), a = (after ?? '').trim();
  if (b.isEmpty) return 'Added video link: $name';
  if (a.isEmpty) return 'Removed video link: $name';
  return 'Changed video link: $name';
}
