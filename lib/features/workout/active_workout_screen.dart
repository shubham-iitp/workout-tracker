import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/phase_stepper.dart';
import '../../widgets/set_row.dart';
import 'quit_sheet.dart';
import 'workout_actions.dart';
import 'workout_logic.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _ticker;
  bool _openedComplete = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _maybeOpenComplete(WorkoutProgress progress) {
    if (!progress.allDone) {
      _openedComplete = false;
      return;
    }
    if (_openedComplete) return;
    _openedComplete = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push(Routes.complete);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = currentWorkout(ref);
    final loading =
        ref.watch(activeWorkoutProvider).isLoading ||
        ref.watch(planProvider).isLoading;

    if (current == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No workout in progress'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go(Routes.workouts),
                      child: const Text('Back to workouts'),
                    ),
                  ],
                ),
        ),
      );
    }

    final (:active, :progress) = current;
    final day = progress.day;
    final dao = ref.read(workoutDaoProvider);
    final t = context.tokens;
    _maybeOpenComplete(progress);

    // If the stored phase became empty (plan edited), show the first non-empty.
    var phase = active.phase;
    if (progress.isPhaseEmpty(phase)) phase = firstPhase(day);

    Future<void> toggle(String key) {
      final order = [...progress.doneOrder];
      if (!order.remove(key)) order.add(key);
      return dao.setDone(order);
    }

    final elapsed = DateTime.now().difference(active.startedAt);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showQuitSheet(context, ref, active, progress);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Quit workout',
            icon: const Icon(Icons.close),
            onPressed: () => showQuitSheet(context, ref, active, progress),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day.name),
              if (day.partsLabel.isNotEmpty)
                Text(
                  day.partsLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: t.muted,
                    fontFamily: bodyFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Pill(
                fmtElapsed(elapsed),
                icon: Icons.timer_outlined,
                background: t.dark,
                foreground: t.onDark,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: PhaseStepper(
                progress: progress,
                current: phase,
                onSelect: dao.setPhase,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (phase == Phase.lifts)
                    ..._liftsPhase(context, progress, toggle)
                  else
                    ..._routinePhase(context, progress, phase, toggle),
                  if (progress.isPhaseComplete(phase))
                    _PhaseDoneCard(
                      phase: phase,
                      next: progress.nextPhase(phase),
                      allDone: progress.allDone,
                      onNext: (p) => dao.setPhase(p),
                      onFinish: () => context.push(Routes.complete),
                    ),
                ],
              ),
            ),
            _ProgressFooter(
              progress: progress,
              onUndo: progress.doneOrder.isEmpty
                  ? null
                  : () => dao.setDone(
                      progress.doneOrder.sublist(
                        0,
                        progress.doneOrder.length - 1,
                      ),
                    ),
              onFinish: () => context.push(Routes.complete),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _routinePhase(
    BuildContext context,
    WorkoutProgress progress,
    String phase,
    Future<void> Function(String key) toggle,
  ) {
    final items = phase == Phase.warmup
        ? progress.day.warmups
        : progress.day.cooldowns;
    return [
      for (final item in items) ...[
        CheckTile(
          title: item.name,
          subtitle: item.detail,
          done: progress.isRoutineDone(item),
          onTap: () => toggle(routineKey(item.id)),
          trailing: VideoButton(url: item.videoUrl, compact: true),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _liftsPhase(
    BuildContext context,
    WorkoutProgress progress,
    Future<void> Function(String key) toggle,
  ) {
    final unit = ref.watch(unitProvider);
    final plan = ref.read(planDaoProvider);
    final t = context.tokens;
    return [
      for (final part in progress.day.parts.where(
        (p) => p.exercises.isNotEmpty,
      )) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            part.name.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 12,
              color: t.muted,
            ),
          ),
        ),
        for (final e in part.exercises) ...[
          _ExerciseCard(
            exercise: e,
            unit: unit,
            progress: progress,
            onToggle: (s) => toggle(setKey(s.id)),
            onWeight: (s, w) => plan.updateSet(s.id, weightKg: w),
            onReps: (s, r) => plan.updateSet(s.id, reps: r),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.unit,
    required this.progress,
    required this.onToggle,
    required this.onWeight,
    required this.onReps,
  });

  final ExercisePlan exercise;
  final WeightUnit unit;
  final WorkoutProgress progress;
  final void Function(ExerciseSet) onToggle;
  final void Function(ExerciseSet, double) onWeight;
  final void Function(ExerciseSet, int) onReps;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final last = exercise.sets
        .where((s) => s.lastWeight != null && s.lastReps != null)
        .map((s) => fmtSet(s.lastWeight!, s.lastReps!, unit))
        .join(' · ');
    final delta = exerciseDelta(exercise);
    final deltaText = switch (delta) {
      WeightUp(:final kg) =>
        '+${fmtNumber(round1(toDisplay(kg, unit)))} ${unit.name} vs last time',
      HeavierSets() => 'Heavier sets',
      RepsUp(:final reps) => '+$reps reps',
      _ => null,
    };
    final done = exercise.sets.where(progress.isSetDone).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Pill('$done/${exercise.sets.length}'),
                VideoButton(url: exercise.videoUrl, compact: true),
              ],
            ),
            Text(
              last.isEmpty
                  ? 'First time: set your baseline'
                  : 'Last time: $last',
              style: TextStyle(color: t.muted, fontSize: 13),
            ),
            if (deltaText != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: UpBadge(label: deltaText),
              ),
            ],
            const SizedBox(height: 10),
            for (final (i, s) in exercise.sets.indexed) ...[
              SetRow(
                index: i,
                weightKg: s.weight,
                reps: s.reps,
                unit: unit,
                weightUp: isWeightUp(s),
                repsUp: isRepsUp(s),
                done: progress.isSetDone(s),
                onToggleDone: () => onToggle(s),
                onWeightChanged: (w) => onWeight(s, w),
                onRepsChanged: (r) => onReps(s, r),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhaseDoneCard extends StatelessWidget {
  const _PhaseDoneCard({
    required this.phase,
    required this.next,
    required this.allDone,
    required this.onNext,
    required this.onFinish,
  });

  final String phase;
  final String? next;
  final bool allDone;
  final ValueChanged<String> onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final nextPhase = next;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: t.accent),
              const SizedBox(width: 8),
              Text(
                '${phaseLabel(phase)} done',
                style: TextStyle(
                  fontFamily: headingFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: t.onDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nextPhase != null)
            FilledButton.icon(
              onPressed: () => onNext(nextPhase),
              icon: const Icon(Icons.arrow_forward),
              label: Text('Next up: ${phaseLabel(nextPhase)}'),
            )
          else
            FilledButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.flag_outlined),
              label: Text(allDone ? 'See summary' : 'Finish & save'),
            ),
        ],
      ),
    );
  }
}

class _ProgressFooter extends StatelessWidget {
  const _ProgressFooter({
    required this.progress,
    required this.onUndo,
    required this.onFinish,
  });

  final WorkoutProgress progress;
  final VoidCallback? onUndo;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${progress.doneCount} of ${progress.totalCount} done',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      plural(progress.setsDone, 'set') +
                          (progress.liftsUp > 0
                              ? ' · ${progress.liftsUp} up'
                              : ''),
                      style: TextStyle(color: t.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: progress.doneCount > 0 ? onFinish : null,
                child: const Text('Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
