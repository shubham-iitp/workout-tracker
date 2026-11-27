import 'database.dart';

/// A full day of the plan, loaded with everything nested under it.
class DayPlan {
  DayPlan({
    required this.day,
    required this.warmups,
    required this.cooldowns,
    required this.parts,
  });

  final SplitDay day;
  final List<RoutineItem> warmups;
  final List<RoutineItem> cooldowns;
  final List<BodyPartPlan> parts;

  int get id => day.id;
  String get name => day.name;

  Iterable<ExercisePlan> get exercises => parts.expand((p) => p.exercises);
  Iterable<ExerciseSet> get sets => exercises.expand((e) => e.sets);

  /// Routine items with a name (blank rows are still being typed).
  List<RoutineItem> get namedWarmups =>
      warmups.where((r) => r.name.trim().isNotEmpty).toList();
  List<RoutineItem> get namedCooldowns =>
      cooldowns.where((r) => r.name.trim().isNotEmpty).toList();

  int get exerciseCount => exercises.length;
  int get setCount => sets.length;
  bool get canStart => exerciseCount > 0;
  bool get isEmpty => parts.isEmpty && warmups.isEmpty && cooldowns.isEmpty;

  /// "Chest & Triceps", "Chest, Back & Arms"; empty when no body parts.
  String get partsLabel => joinAnd(parts.map((p) => p.name));
}

class BodyPartPlan {
  BodyPartPlan({required this.part, required this.exercises});

  final BodyPart part;
  final List<ExercisePlan> exercises;

  int get id => part.id;
  String get name => part.name;
}

class ExercisePlan {
  ExercisePlan({required this.exercise, required this.sets});

  final Exercise exercise;
  final List<ExerciseSet> sets;

  int get id => exercise.id;
  String get name => exercise.name;
  String? get videoUrl => exercise.videoUrl;

  bool get hasHistory => sets.any((s) => s.lastWeight != null);
}

/// A saved workout with its exercises and sets.
class SessionView {
  SessionView({required this.session, required this.exercises});

  final WorkoutSession session;
  final List<SessionExerciseView> exercises;

  int get setsDone => exercises.fold(0, (n, e) => n + e.sets.length);
  int get liftsUp => exercises.where((e) => e.exercise.improved).length;

  /// Completion, 0–100: working sets done ÷ planned working sets. Warm-up
  /// and cool-down items are not counted. 100 when no sets were planned.
  int get completionPct {
    final planned = session.totalSets;
    if (planned <= 0) return 100;
    final pct = (setsDone * 100 / planned).round().clamp(0, 100);
    // Never show 100% while a set is still missing (e.g. 199 of 200).
    return setsDone < planned ? pct.clamp(0, 99) : pct;
  }

  /// Quit or finished early (not every working set was done).
  bool get isPartial => setsDone < session.totalSets;

  /// Σ weight × reps, in kg.
  double get volumeKg => exercises.fold(
    0.0,
    (v, e) => e.sets.fold(v, (v2, s) => v2 + s.weight * s.reps),
  );
}

class SessionExerciseView {
  SessionExerciseView({required this.exercise, required this.sets});

  final SessionExercise exercise;
  final List<SessionSet> sets;
}

/// The plan day that gets the "Last workout done" badge: the day of the
/// newest saved session, whether it was finished in full or not. Null when
/// there is no history yet or that day no longer exists. Matches by day id,
/// or by name for sessions whose day id was cleared (e.g. imported from CSV
/// or the day was removed).
int? lastWorkoutDayId(List<SessionView> sessions, List<DayPlan> days) {
  SessionView? newest;
  for (final s in sessions) {
    if (newest == null ||
        s.session.startedAt.isAfter(newest.session.startedAt) ||
        (s.session.startedAt == newest.session.startedAt &&
            s.session.id > newest.session.id)) {
      newest = s;
    }
  }
  if (newest == null) return null;
  final dayId = newest.session.dayId;
  if (dayId != null && days.any((d) => d.id == dayId)) return dayId;
  return days.where((d) => d.name == newest!.session.dayName).firstOrNull?.id;
}

/// "A", "A & B", "A, B & C".
String joinAnd(Iterable<String> items) {
  final list = items.toList();
  if (list.isEmpty) return '';
  if (list.length == 1) return list.first;
  return '${list.sublist(0, list.length - 1).join(', ')} & ${list.last}';
}
