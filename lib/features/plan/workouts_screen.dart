import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/stepper_button.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final active = ref
        .watch(activeWorkoutProvider)
        .when(data: (a) => a, loading: () => null, error: (_, _) => null);
    final lastDayId = ref
        .watch(historyProvider)
        .when(
          data: (h) => h.isEmpty ? null : h.first.session.dayId,
          loading: () => null,
          error: (_, _) => null,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: AsyncView(
        value: plan,
        builder: (days) {
          final nextId = _nextDayId(days, lastDayId);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (active != null) ...[
                _ResumeBanner(
                  dayName:
                      days
                          .where((d) => d.id == active.dayId)
                          .firstOrNull
                          ?.name ??
                      'Workout',
                ),
                const SizedBox(height: 12),
              ],
              _RotationStepper(days: days),
              const SizedBox(height: 12),
              for (final day in days) ...[
                _DayCard(
                  day: day,
                  isNext: day.id == nextId,
                  hasActive: active != null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  /// The day after the last one trained, among days that can be started.
  static int? _nextDayId(List<DayPlan> days, int? lastDayId) {
    final startable = days.where((d) => d.canStart).toList();
    if (startable.isEmpty) return null;
    final i = days.indexWhere((d) => d.id == lastDayId);
    if (i < 0) return startable.first.id;
    for (var k = 1; k <= days.length; k++) {
      final d = days[(i + k) % days.length];
      if (d.canStart) return d.id;
    }
    return null;
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.dayName});

  final String dayName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.dark,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(Routes.workout),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: t.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workout in progress',
                      style: TextStyle(
                        color: t.onDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dayName,
                      style: TextStyle(color: t.onDark.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
              Text(
                'Resume',
                style: TextStyle(color: t.accent, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.chevron_right, color: t.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _RotationStepper extends ConsumerWidget {
  const _RotationStepper({required this.days});

  final List<DayPlan> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final n = days.length;
    final dao = ref.read(planDaoProvider);

    Future<void> remove() async {
      final last = days.last;
      if (!last.isEmpty) {
        final ok = await confirmDialog(
          context,
          title: 'Remove ${last.name}?',
          message:
              'Its warm-up, exercises and cool-down will be deleted. '
              'Past workouts stay in History.',
          confirm: 'Remove',
          destructive: true,
        );
        if (!ok) return;
      }
      await dao.setDayCount(n - 1);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$n-day rotation',
                    style: const TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Up to ${AppDatabase.maxDays} days',
                    style: TextStyle(color: t.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            StepperButton.minus(onPressed: n > 1 ? remove : null, size: 40),
            const SizedBox(width: 8),
            StepperButton.plus(
              onPressed: n < AppDatabase.maxDays
                  ? () => dao.setDayCount(n + 1)
                  : null,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.day,
    required this.isNext,
    required this.hasActive,
  });

  final DayPlan day;
  final bool isNext;
  final bool hasActive;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    if (hasActive) {
      final ok = await confirmDialog(
        context,
        title: 'Start a new workout?',
        message: 'The workout in progress will be discarded.',
        confirm: 'Start new',
        destructive: true,
      );
      if (!ok) return;
    }
    await ref.read(workoutDaoProvider).start(day);
    if (context.mounted) context.push(Routes.workout);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final label = day.partsLabel;
    final stats = [
      plural(day.exerciseCount, 'exercise'),
      plural(day.setCount, 'set'),
      if (day.warmups.isNotEmpty) '${day.warmups.length} warm-up',
      if (day.cooldowns.isNotEmpty) '${day.cooldowns.length} cool-down',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.name,
                    style: const TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (isNext)
                  Pill('Up next', background: t.accent, foreground: t.onAccent),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label.isEmpty ? 'Not set up yet' : label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: label.isEmpty ? t.muted : t.ink,
              ),
            ),
            if (!day.isEmpty) ...[
              const SizedBox(height: 4),
              Text(stats, style: TextStyle(color: t.muted, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(Routes.day(day.id)),
                    icon: Icon(
                      day.isEmpty ? Icons.add : Icons.edit_outlined,
                      size: 18,
                    ),
                    label: Text(day.isEmpty ? 'Set up day' : 'Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: day.canStart ? () => _start(context, ref) : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start workout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
