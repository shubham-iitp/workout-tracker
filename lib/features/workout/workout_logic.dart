import 'dart:convert';
import 'dart:math' as math;

import '../../data/database.dart';
import '../../data/models.dart';

/// Keys stored in `active_workout.done_ids`.
String routineKey(int routineItemId) => 'r:$routineItemId';
String setKey(int exerciseSetId) => 's:$exerciseSetId';

List<String> decodeDone(String json) {
  try {
    return (jsonDecode(json) as List).map((e) => e.toString()).toList();
  } catch (_) {
    return [];
  }
}

String encodeDone(List<String> done) => jsonEncode(done);

/// Progress of one in-progress workout against its day plan.
class WorkoutProgress {
  WorkoutProgress(this.day, List<String> doneOrder)
    : doneOrder = List.unmodifiable(doneOrder),
      done = doneOrder.toSet();

  final DayPlan day;

  /// Checked keys, oldest first (last one is what "Undo" removes).
  final List<String> doneOrder;
  final Set<String> done;

  bool isRoutineDone(RoutineItem r) => done.contains(routineKey(r.id));
  bool isSetDone(ExerciseSet s) => done.contains(setKey(s.id));

  int get warmDone => day.warmups.where(isRoutineDone).length;
  int get warmTotal => day.warmups.length;
  int get coolDone => day.cooldowns.where(isRoutineDone).length;
  int get coolTotal => day.cooldowns.length;
  int get setsDone => day.sets.where(isSetDone).length;
  int get setsTotal => day.setCount;

  int doneIn(String phase) => switch (phase) {
    Phase.warmup => warmDone,
    Phase.cooldown => coolDone,
    _ => setsDone,
  };

  int totalIn(String phase) => switch (phase) {
    Phase.warmup => warmTotal,
    Phase.cooldown => coolTotal,
    _ => setsTotal,
  };

  bool isPhaseEmpty(String phase) => totalIn(phase) == 0;
  bool isPhaseComplete(String phase) => doneIn(phase) >= totalIn(phase);

  int get doneCount => warmDone + setsDone + coolDone;
  int get totalCount => warmTotal + setsTotal + coolTotal;
  bool get allDone => totalCount > 0 && doneCount >= totalCount;
  double get fraction => totalCount == 0 ? 0 : doneCount / totalCount;

  /// Next phase after [phase] that has something in it, or null.
  String? nextPhase(String phase) {
    final i = Phase.all.indexOf(phase);
    for (final p in Phase.all.skip(i + 1)) {
      if (!isPhaseEmpty(p)) return p;
    }
    return null;
  }

  /// Exercises that improved on at least one *done* set.
  int get liftsUp => day.exercises
      .where((e) => e.sets.where(isSetDone).any(isSetImproved))
      .length;

  double get volumeDoneKg =>
      day.sets.where(isSetDone).fold(0.0, (v, s) => v + s.weight * s.reps);
}

/// First phase with something in it.
String firstPhase(DayPlan day) {
  if (day.warmups.isNotEmpty) return Phase.warmup;
  if (day.exerciseCount > 0) return Phase.lifts;
  return Phase.cooldown;
}

bool isWeightUp(ExerciseSet s) =>
    s.lastWeight != null && s.weight > s.lastWeight! + 1e-9;

bool isRepsUp(ExerciseSet s) => s.lastReps != null && s.reps > s.lastReps!;

/// A set "went up" when its weight or reps (shown green) beat last time.
bool isSetImproved(ExerciseSet s) => isWeightUp(s) || isRepsUp(s);

/// What changed vs last time, for one exercise.
sealed class Delta {
  const Delta();
}

class FirstTime extends Delta {
  const FirstTime();
}

class WeightUp extends Delta {
  const WeightUp(this.kg);
  final double kg;
}

class HeavierSets extends Delta {
  const HeavierSets();
}

class RepsUp extends Delta {
  const RepsUp(this.reps);
  final int reps;
}

class NoChange extends Delta {
  const NoChange();
}

/// "+X kg vs last time" if max weight rose, else "Heavier sets", else
/// "+N reps".
Delta exerciseDelta(ExercisePlan e) {
  final withLast = e.sets.where((s) => s.lastWeight != null).toList();
  if (withLast.isEmpty) return const FirstTime();

  final maxNow = e.sets.map((s) => s.weight).reduce(math.max);
  final maxLast = withLast.map((s) => s.lastWeight!).reduce(math.max);
  if (maxNow > maxLast + 1e-9) return WeightUp(maxNow - maxLast);
  if (withLast.any(isWeightUp)) return const HeavierSets();

  final repsNow = withLast.fold(0, (n, s) => n + s.reps);
  final repsLast = withLast.fold(0, (n, s) => n + (s.lastReps ?? s.reps));
  if (repsNow > repsLast) return RepsUp(repsNow - repsLast);
  return const NoChange();
}
