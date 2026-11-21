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

  /// Completion, 0–100: done ÷ planned items, counting warm-up items, sets
  /// and cool-down items together. 100 when nothing was planned.
  int get completionPct {
    final planned = session.warmTotal + session.totalSets + session.coolTotal;
    if (planned <= 0) return 100;
    final done = session.warmDone + setsDone + session.coolDone;
    return (done * 100 / planned).round().clamp(0, 100);
  }

  /// Quit or finished early.
  bool get isPartial => completionPct < 100;

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

/// "A", "A & B", "A, B & C".
String joinAnd(Iterable<String> items) {
  final list = items.toList();
  if (list.isEmpty) return '';
  if (list.length == 1) return list.first;
  return '${list.sublist(0, list.length - 1).join(', ')} & ${list.last}';
}
