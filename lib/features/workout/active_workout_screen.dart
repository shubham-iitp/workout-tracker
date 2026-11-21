import 'dart:async';

import 'package:flutter/services.dart';
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
import '../../widgets/ui.dart';
import 'workout_logic.dart';

String phaseTitle(String phase) => switch (phase) {
  Phase.warmup => 'Warm-up',
  Phase.cooldown => 'Cool-down',
  _ => 'Workout',
};

String _unitWord(String phase) => phase == Phase.lifts ? 'set' : 'item';

/// A workout that was just saved automatically (everything checked).
class _Completed {
  _Completed(this.progress, this.startedAt, this.minutes);

  final WorkoutProgress progress;
  final DateTime startedAt;
  final int minutes;
}

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  _Completed? _completed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  ({ActiveWorkout active, WorkoutProgress progress})? _current() {
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

  Future<int> _save(ActiveWorkout active, WorkoutProgress progress) async {
    final id = await ref.read(workoutDaoProvider).save(progress, active);
    ref.read(expandedSessionProvider.notifier).set(id);
    // Background upload to Drive; never blocks the Complete / History screen.
    unawaited(ref.read(driveBackupProvider.notifier).afterWorkoutSaved());
    return id;
  }

  Future<void> _toggle(
    ActiveWorkout active,
    WorkoutProgress progress,
    String key,
  ) async {
    if (_saving) return;
    final order = [...progress.doneOrder];
    if (!order.remove(key)) order.add(key);
    final next = WorkoutProgress(progress.day, order);
    if (next.allDone) {
      // Last item checked: save straight away and show "Workout complete".
      _saving = true;
      final now = DateTime.now();
      final minutes = (now.difference(active.startedAt).inSeconds / 60)
          .round()
          .clamp(1, 1 << 30);
      setState(() => _completed = _Completed(next, active.startedAt, minutes));
      await _save(active, next);
      _saving = false;
    } else {
      await ref.read(workoutDaoProvider).setDone(order);
    }
  }

  Future<void> _finish(ActiveWorkout active, WorkoutProgress progress) async {
    if (_saving) return;
    _saving = true;
    await _save(active, progress);
    if (mounted) context.go(Routes.history);
  }

  Future<void> _discard() async {
    await ref.read(workoutDaoProvider).discard();
    if (mounted) context.go(Routes.workouts);
  }

  void _openQuit(ActiveWorkout active, WorkoutProgress progress) {
    final t = context.tokens;
    final line = progress.availablePhases
        .map(
          (p) =>
              '${phaseTitle(p)} ${progress.doneIn(p)}/${progress.totalIn(p)}',
        )
        .join(' · ');
    showDesignSheet<void>(
      context,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quit this workout?', style: grotesk(22, color: t.ink)),
          const SizedBox(height: 10),
          Text(
            'So far: $line. Save what you did to History, or throw this session away.',
            style: inter(14, color: t.muted),
          ),
          const SizedBox(height: 16),
          if (progress.doneCount > 0) ...[
            Btn(
              onTap: () {
                Navigator.pop(sheet);
                _finish(active, progress);
              },
              height: 52,
              color: t.dark,
              child: Text(
                'Save & quit',
                style: inter(15, weight: FontWeight.w700, color: Fixed.white),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Btn(
            onTap: () {
              Navigator.pop(sheet);
              _discard();
            },
            height: 52,
            color: Fixed.white,
            border: const BorderSide(color: Fixed.dangerBorder),
            child: Text(
              'Discard workout',
              style: inter(
                15,
                weight: FontWeight.w700,
                color: Fixed.dangerText,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Btn(
            onTap: () => Navigator.pop(sheet),
            height: 48,
            child: Text(
              'Keep going',
              style: inter(15, weight: FontWeight.w600, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final completed = _completed;
    final current = completed == null ? _current() : null;

    if (completed == null && current == null) {
      final loading =
          ref.watch(activeWorkoutProvider).isLoading ||
          ref.watch(planProvider).isLoading;
      return Scaffold(
        body: Center(
          child: loading
              ? CircularProgressIndicator(color: t.ink)
              : Btn(
                  onTap: () => context.go(Routes.workouts),
                  height: 48,
                  color: t.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Back to workouts',
                    style: inter(14, weight: FontWeight.w700, color: t.ink),
                  ),
                ),
        ),
      );
    }

    final progress = completed?.progress ?? current!.progress;
    final active = current?.active;
    final startedAt = completed?.startedAt ?? active!.startedAt;
    final avail = progress.availablePhases;
    final allDone = completed != null;
    var phase = active?.phase ?? Phase.lifts;
    if (!avail.contains(phase) && avail.isNotEmpty) phase = avail.first;
    final phaseDone = !allDone && progress.isPhaseComplete(phase);
    final dao = ref.read(workoutDaoProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (allDone) {
            context.go(Routes.workouts);
          } else {
            _openQuit(active!, progress);
          }
        },
        child: Scaffold(
          body: Column(
            children: [
              _Header(
                progress: progress,
                current: allDone ? null : phase,
                startedAt: startedAt,
                onQuit: allDone
                    ? () => context.go(Routes.workouts)
                    : () => _openQuit(active!, progress),
                onPhase: dao.setPhase,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
                    if (!allDone) ...[
                      _PhaseHead(
                        progress: progress,
                        phase: phase,
                        step: avail.indexOf(phase) + 1,
                        steps: avail.length,
                      ),
                      const SizedBox(height: 14),
                      if (phase == Phase.lifts)
                        ..._lifts(progress, active!)
                      else
                        ..._routine(progress, active!, phase),
                    ],
                    if (phaseDone)
                      _PhaseDoneCard(
                        phase: phase,
                        progress: progress,
                        onNext: (p) => dao.setPhase(p),
                        onFinish: () => _finish(active!, progress),
                      ),
                    if (allDone)
                      _CompleteCard(
                        completed: completed,
                        onHistory: () => context.go(Routes.history),
                        onDone: () => context.go(Routes.workouts),
                      ),
                  ],
                ),
              ),
              if (!allDone && progress.doneCount > 0 && !phaseDone)
                _Footer(
                  onUndo: () => dao.setDone(
                    progress.doneOrder.sublist(
                      0,
                      progress.doneOrder.length - 1,
                    ),
                  ),
                  onFinish: () => _finish(active!, progress),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _routine(
    WorkoutProgress progress,
    ActiveWorkout active,
    String phase,
  ) {
    final items = phase == Phase.warmup ? progress.warmups : progress.cooldowns;
    return [
      for (final r in items) ...[
        _RoutineRow(
          item: r,
          done: progress.isRoutineDone(r),
          onToggle: () => _toggle(active, progress, routineKey(r.id)),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }

  List<Widget> _lifts(WorkoutProgress progress, ActiveWorkout active) {
    final unit = ref.watch(unitProvider);
    final plan = ref.read(planDaoProvider);
    final out = <Widget>[];
    for (final part in progress.day.parts) {
      final left = part.exercises
          .where((e) => e.sets.any((s) => !progress.isSetDone(s)))
          .toList();
      if (left.isEmpty) continue;
      out.add(Eyebrow('${part.name} · ${left.length} left'));
      out.add(const SizedBox(height: 8));
      for (final e in left) {
        out.add(
          _ExerciseCard(
            exercise: e,
            unit: unit,
            progress: progress,
            onToggle: (s) => _toggle(active, progress, setKey(s.id)),
            onWeight: (s, w) => plan.updateSet(s.id, weightKg: w),
            onReps: (s, r) => plan.updateSet(s.id, reps: r),
          ),
        );
        out.add(const SizedBox(height: 8));
      }
      out.add(const SizedBox(height: 6));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.progress,
    required this.current,
    required this.startedAt,
    required this.onQuit,
    required this.onPhase,
  });

  final WorkoutProgress progress;
  final String? current;
  final DateTime startedAt;
  final VoidCallback onQuit;
  final ValueChanged<String> onPhase;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final day = progress.day;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 18),
      decoration: BoxDecoration(
        color: t.dark,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform.translate(
                offset: const Offset(-12, 0),
                child: Btn(
                  onTap: onQuit,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: BtnLabel(
                    'Quit',
                    gap: 4,
                    style: inter(
                      14,
                      weight: FontWeight.w600,
                      color: t.darkMuted,
                    ),
                    leading: SvgIcon(Ico.back, size: 18, color: t.darkMuted),
                  ),
                ),
              ),
              Text(
                'Started ${fmtTime(startedAt)}',
                style: inter(13, color: t.darkMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            day.name.toUpperCase(),
            style: inter(
              12,
              weight: FontWeight.w700,
              letterSpacing: 0.1,
              color: t.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day.partsLabel,
            style: grotesk(24, color: Fixed.white, letterSpacing: -0.02),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, p) in Phase.all.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _phaseButton(context, p)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseButton(BuildContext context, String phase) {
    final t = context.tokens;
    final none = progress.isPhaseEmpty(phase);
    final isCur = phase == current;
    final done = progress.isPhaseComplete(phase);
    final total = progress.totalIn(phase);
    final doneN = progress.doneIn(phase);
    final pct = total == 0 ? 0.0 : doneN / total;
    final count = none
        ? 'None today'
        : '$doneN/$total${phase == Phase.lifts ? ' sets' : ''}';

    return Opacity(
      opacity: none ? 0.45 : 1,
      child: Semantics(
        button: true,
        enabled: !none,
        selected: isCur,
        label:
            '${phaseTitle(phase)}'
            '${none ? ', none today' : ', $doneN of $total done'}',
        excludeSemantics: true,
        child: Material(
          color: isCur ? t.darkTrack : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isCur
                ? BorderSide(color: t.accent, width: 2)
                : BorderSide(color: t.darkLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: none || current == null ? null : () => onPhase(phase),
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (done) ...[
                        Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                          child: SvgIcon(
                            Ico.check,
                            size: 10,
                            color: t.ink,
                            stroke: 3.5,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          phaseTitle(phase).toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: inter(
                            11,
                            weight: FontWeight.w700,
                            letterSpacing: 0.06,
                            color: isCur ? t.accent : Fixed.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    count,
                    style: inter(
                      13,
                      weight: FontWeight.w600,
                      color: t.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 4,
                      child: Stack(
                        children: [
                          Container(color: t.darkLine),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(color: t.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhaseHead extends StatelessWidget {
  const _PhaseHead({
    required this.progress,
    required this.phase,
    required this.step,
    required this.steps,
  });

  final WorkoutProgress progress;
  final String phase;
  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = progress.totalIn(phase);
    final done = progress.doneIn(phase);
    final pct = total == 0 ? 0.0 : done / total;
    final hint = switch (phase) {
      Phase.warmup =>
        'Tap the check when you finish each one. Tap again to undo.',
      Phase.cooldown =>
        'Stretch it out. Tap the check when you finish each one.',
      _ =>
        'Change weight or reps here and ${progress.day.name} updates for next time.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('Step $step of $steps'),
                  const SizedBox(height: 2),
                  Text(
                    phaseTitle(phase),
                    style: grotesk(26, color: t.ink, letterSpacing: -0.02),
                  ),
                ],
              ),
            ),
            Text(
              '$done/$total${phase == Phase.lifts ? ' sets' : ''}',
              style: grotesk(17, color: t.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: t.line),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.ease,
                  widthFactor: pct,
                  child: Container(color: t.ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint, style: inter(12, color: t.muted)),
      ],
    );
  }
}

/// 44px round check button.
class _Check extends StatelessWidget {
  const _Check({required this.done, required this.onTap, required this.label});

  final bool done;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      toggled: done,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: done ? t.accent : Fixed.white,
        shape: CircleBorder(
          side: BorderSide(
            color: done ? Colors.transparent : t.border2,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: SvgIcon(
                Ico.check,
                size: 18,
                color: done ? t.ink : t.checkIdle,
                stroke: done ? 2.8 : 2.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoBtn extends StatelessWidget {
  const _VideoBtn({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final href = videoHref(url);
    if (href == null) return const SizedBox.shrink();
    final t = context.tokens;
    return IconBtn(
      icon: Ico.video,
      label: 'Watch video for $name',
      onTap: () => openVideo(context, href),
      background: t.ground,
      color: t.ink,
      radius: 12,
      stroke: 2,
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.item,
    required this.done,
    required this.onToggle,
  });

  final RoutineItem item;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: done ? 0.4 : 1,
      child: CardBox(
        padding: const EdgeInsets.all(10),
        radius: 16,
        child: Row(
          children: [
            _Check(
              done: done,
              onTap: onToggle,
              label: done ? 'Undo ${item.name}' : 'Mark ${item.name} done',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: inter(
                      15,
                      weight: FontWeight.w600,
                      color: t.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _VideoBtn(url: item.videoUrl, name: item.name),
          ],
        ),
      ),
    );
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
    final withLast = exercise.sets
        .where((s) => s.lastWeight != null && s.lastReps != null)
        .toList();
    final lastLine = withLast.isEmpty
        ? 'First time: set your baseline'
        : 'Last time: ${withLast.map((s) => fmtSet(s.lastWeight!, s.lastReps!, unit)).join(' · ')}';
    final deltaText = switch (exerciseDelta(exercise)) {
      WeightUp(:final kg) =>
        '+${fmtNumber(toDisplay(kg, unit), decimals: 2)} ${unit.name} vs last time',
      HeavierSets() => 'Heavier sets vs last time',
      RepsUp(:final reps) => '+${plural(reps, 'rep')} vs last time',
      _ => null,
    };
    final header = inter(
      11,
      weight: FontWeight.w700,
      letterSpacing: 0.06,
      color: t.muted,
    );

    Widget grid(List<Widget> c) => Row(
      children: [
        SizedBox(width: 44, child: c[0]),
        const SizedBox(width: 8),
        SizedBox(width: 136, child: c[1]),
        const SizedBox(width: 8),
        Expanded(child: c[2]),
      ],
    );

    return CardBox(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: inter(16, weight: FontWeight.w600, color: t.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(lastLine, style: inter(12, color: t.muted)),
                      if (deltaText != null) ...[
                        const SizedBox(height: 4),
                        UpPill(deltaText),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _VideoBtn(url: exercise.videoUrl, name: exercise.name),
              ],
            ),
          ),
          const SizedBox(height: 8),
          grid([
            Text('SET', textAlign: TextAlign.center, style: header),
            Text(
              'WEIGHT (${unit.name.toUpperCase()})',
              textAlign: TextAlign.center,
              style: header,
            ),
            Text('REPS', textAlign: TextAlign.center, style: header),
          ]),
          for (final (i, s) in exercise.sets.indexed) ...[
            const SizedBox(height: 8),
            _setRow(context, i, s, grid),
          ],
        ],
      ),
    );
  }

  Widget _setRow(
    BuildContext context,
    int i,
    ExerciseSet s,
    Widget Function(List<Widget>) grid,
  ) {
    final t = context.tokens;
    final done = progress.isSetDone(s);
    final strike = done ? TextDecoration.lineThrough : null;

    void stepWeight(double delta) {
      final display = round1(toDisplay(s.weight, unit));
      final next = round1(display + delta);
      onWeight(s, next <= 0 ? 0 : round3(fromDisplay(next, unit)));
    }

    Widget stepper({
      required String value,
      required Color color,
      required VoidCallback onDown,
      required VoidCallback onUp,
      required String downLabel,
      required String upLabel,
    }) => Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.ground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconBtn(
            icon: Ico.minus,
            label: downLabel,
            onTap: onDown,
            width: 40,
            iconSize: 14,
            stroke: 2.6,
            color: t.ink,
            radius: 12,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: grotesk(17, color: color, decoration: strike),
              ),
            ),
          ),
          IconBtn(
            icon: Ico.plus,
            label: upLabel,
            onTap: onUp,
            width: 40,
            iconSize: 14,
            stroke: 2.6,
            color: t.ink,
            radius: 12,
          ),
        ],
      ),
    );

    return AnimatedOpacity(
      key: ValueKey(s.id),
      duration: const Duration(milliseconds: 200),
      opacity: done ? 0.4 : 1,
      child: grid([
        _Check(
          done: done,
          onTap: () => onToggle(s),
          label: done
              ? 'Undo set ${i + 1} of ${exercise.name}'
              : 'Mark set ${i + 1} of ${exercise.name} done',
        ),
        stepper(
          value: fmtWeightValue(s.weight, unit),
          color: isWeightUp(s) ? t.up : t.ink,
          onDown: () => stepWeight(-0.1),
          onUp: () => stepWeight(0.1),
          downLabel: 'Decrease weight, set ${i + 1}',
          upLabel: 'Increase weight, set ${i + 1}',
        ),
        stepper(
          value: '${s.reps}',
          color: isRepsUp(s) ? t.up : t.ink,
          onDown: () => onReps(s, s.reps > 0 ? s.reps - 1 : 0),
          onUp: () => onReps(s, s.reps + 1),
          downLabel: 'Fewer reps, set ${i + 1}',
          upLabel: 'More reps, set ${i + 1}',
        ),
      ]),
    );
  }
}

class _PhaseDoneCard extends StatelessWidget {
  const _PhaseDoneCard({
    required this.phase,
    required this.progress,
    required this.onNext,
    required this.onFinish,
  });

  final String phase;
  final WorkoutProgress progress;
  final ValueChanged<String> onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final next = progress.nextPhase(phase);
    final text = next == null
        ? 'Everything else is done too. Save it to your history.'
        : 'Next up: ${phaseTitle(next).toLowerCase()} '
              '(${plural(progress.totalIn(next) - progress.doneIn(next), _unitWord(next))}).';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.dark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent,
                  shape: BoxShape.circle,
                ),
                child: SvgIcon(Ico.check, size: 18, color: t.ink, stroke: 2.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${phaseTitle(phase)} done',
                      style: grotesk(19, color: Fixed.white),
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: inter(13, color: t.darkText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Btn(
            onTap: next == null ? onFinish : () => onNext(next),
            height: 52,
            color: t.accent,
            child: BtnLabel(
              next == null
                  ? 'Finish & save'
                  : 'Start ${phaseTitle(next).toLowerCase()}',
              style: inter(15, weight: FontWeight.w700, color: t.ink),
              trailing: SvgIcon(
                Ico.arrowRight,
                size: 16,
                color: t.ink,
                stroke: 2.4,
              ),
              gap: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteCard extends StatelessWidget {
  const _CompleteCard({
    required this.completed,
    required this.onHistory,
    required this.onDone,
  });

  final _Completed completed;
  final VoidCallback onHistory;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = completed.progress;
    final day = p.day;
    final ups = p.liftsUp;

    return CardBox(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: SvgIcon(Ico.check, size: 34, color: t.ink, stroke: 2.6),
          ),
          const SizedBox(height: 10),
          Text('Workout complete', style: grotesk(26, color: t.ink)),
          const SizedBox(height: 10),
          Text(
            '${completed.minutes} min · ${day.name} · ${day.partsLabel}',
            textAlign: TextAlign.center,
            style: inter(14, color: t.muted),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.divider)),
            ),
            child: Column(
              children: [
                for (final ph in p.availablePhases)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t.divider)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.isPhaseComplete(ph) ? t.accent : t.line,
                            shape: BoxShape.circle,
                          ),
                          child: SvgIcon(
                            Ico.check,
                            size: 12,
                            color: t.ink,
                            stroke: 3.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            phaseTitle(ph),
                            style: inter(
                              15,
                              weight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${p.doneIn(ph)}/${plural(p.totalIn(ph), _unitWord(ph))}',
                          style: inter(14, color: t.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (ups > 0) ...[
            const SizedBox(height: 14),
            UpPill(
              '${plural(ups, 'lift')} up vs last time',
              fontSize: 13,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(Ico.check, size: 14, color: t.up, stroke: 2.6),
              const SizedBox(width: 6),
              Text(
                'Saved to history automatically',
                style: inter(13, weight: FontWeight.w600, color: t.up),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Btn(
                  onTap: onHistory,
                  height: 52,
                  color: Fixed.white,
                  border: BorderSide(color: t.border),
                  child: Text(
                    'View in history',
                    style: inter(15, weight: FontWeight.w600, color: t.ink),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Btn(
                  onTap: onDone,
                  height: 52,
                  color: t.dark,
                  child: Text(
                    'Done',
                    style: inter(
                      15,
                      weight: FontWeight.w700,
                      color: Fixed.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onUndo, required this.onFinish});

  final VoidCallback onUndo;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: t.ground,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Btn(
            onTap: onUndo,
            height: 48,
            color: Fixed.white,
            border: BorderSide(color: t.border),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BtnLabel(
              'Undo',
              style: inter(14, weight: FontWeight.w600, color: t.ink),
              leading: SvgIcon(Ico.undo, size: 16, color: t.ink),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Btn(
              onTap: onFinish,
              height: 48,
              color: t.dark,
              child: Text(
                'Finish early & save',
                style: inter(14, weight: FontWeight.w600, color: Fixed.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
