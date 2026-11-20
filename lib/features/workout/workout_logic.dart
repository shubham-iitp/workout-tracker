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

  /// Warm-up / cool-down items with a name (blank rows are still being typed
  /// in the editor and don't count).
  List<RoutineItem> get warmups => day.namedWarmups;
  List<RoutineItem> get cooldowns => day.namedCooldowns;

  bool isRoutineDone(RoutineItem r) => done.contains(routineKey(r.id));
  bool isSetDone(ExerciseSet s) => done.contains(setKey(s.id));

  int get warmDone => warmups.where(isRoutineDone).length;
  int get warmTotal => warmups.length;
  int get coolDone => cooldowns.where(isRoutineDone).length;
  int get coolTotal => cooldowns.length;
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
  bool isPhaseComplete(String phase) =>
      !isPhaseEmpty(phase) && doneIn(phase) >= totalIn(phase);

  /// Phases that have something in them, in order.
  List<String> get availablePhases =>
      Phase.all.where((p) => !isPhaseEmpty(p)).toList();

  int get doneCount => warmDone + setsDone + coolDone;
  int get totalCount => warmTotal + setsTotal + coolTotal;
  bool get allDone => totalCount > 0 && doneCount >= totalCount;

  /// Next phase after [phase] that still has unchecked items, or null.
  String? nextPhase(String phase) {
    final avail = availablePhases;
    final i = avail.indexOf(phase);
    for (final p in avail.skip(i + 1)) {
      if (doneIn(p) < totalIn(p)) return p;
    }
    return null;
  }

  /// Exercises with a "vs last time" delta (the "N lifts up" count).
  int get liftsUp => day.exercises.where((e) => exerciseDelta(e).isUp).length;

  double get volumeDoneKg =>
      day.sets.where(isSetDone).fold(0.0, (v, s) => v + s.weight * s.reps);
}

/// First phase with something in it.
String firstPhase(DayPlan day) {
  if (day.namedWarmups.isNotEmpty) return Phase.warmup;
  if (day.setCount > 0) return Phase.lifts;
  return Phase.cooldown;
}

/// Weight shown in the "up" colour: heavier than last time.
bool isWeightUp(ExerciseSet s) =>
    s.lastWeight != null && s.weight > s.lastWeight! + 1e-9;

/// Reps shown in the "up" colour: at least as heavy and more reps.
bool isRepsUp(ExerciseSet s) =>
    s.lastWeight != null &&
    s.lastReps != null &&
    s.weight >= s.lastWeight! - 1e-9 &&
    s.reps > s.lastReps!;

/// What changed vs last time, for one exercise.
sealed class Delta {
  const Delta();

  bool get isUp => this is WeightUp || this is HeavierSets || this is RepsUp;
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

/// "+X kg vs last time" if the top weight rose, else "Heavier sets vs last
/// time" if the sets are heavier overall, else "+N reps vs last time".
Delta exerciseDelta(ExercisePlan e) {
  final withLast = e.sets.where((s) => s.lastWeight != null).toList();
  if (withLast.isEmpty) return const FirstTime();

  final maxNow = e.sets.map((s) => s.weight).reduce(math.max);
  final maxLast = withLast.map((s) => s.lastWeight!).reduce(math.max);
  if (maxNow > maxLast + 1e-9) return WeightUp(maxNow - maxLast);

  final wDiff = withLast.fold(0.0, (t, s) => t + (s.weight - s.lastWeight!));
  if (wDiff > 1e-9) return const HeavierSets();

  final repDiff = withLast.fold(
    0,
    (t, s) => t + (s.reps - (s.lastReps ?? s.reps)),
  );
  if (repDiff > 0 && wDiff >= -1e-9) return RepsUp(repDiff);
  return const NoChange();
}
