import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/database.dart';
import 'workout_logic.dart';

/// The in-progress workout joined with its day plan, or null.
({ActiveWorkout active, WorkoutProgress progress})? currentWorkout(
  WidgetRef ref,
) {
  final active = ref
      .watch(activeWorkoutProvider)
      .when(data: (a) => a, loading: () => null, error: (_, _) => null);
  if (active == null) return null;
  final day = ref
      .watch(planProvider)
      .when(
        data: (days) => days.where((d) => d.id == active.dayId).firstOrNull,
        loading: () => null,
        error: (_, _) => null,
      );
  if (day == null) return null;
  return (
    active: active,
    progress: WorkoutProgress(day, decodeDone(active.doneIds)),
  );
}

/// Saves the workout (done sets only), then shows History.
Future<void> saveWorkout(
  BuildContext context,
  WidgetRef ref,
  ActiveWorkout active,
  WorkoutProgress progress,
) async {
  await ref.read(workoutDaoProvider).save(progress, active);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  context.go(Routes.history);
  messenger.showSnackBar(const SnackBar(content: Text('Workout saved')));
}

Future<void> discardWorkout(BuildContext context, WidgetRef ref) async {
  await ref.read(workoutDaoProvider).discard();
  if (context.mounted) context.go(Routes.workouts);
}
