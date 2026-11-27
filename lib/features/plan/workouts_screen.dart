import 'dart:async';

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
import '../../widgets/ui.dart';

/// Tab 1 — "YOUR SPLIT / Workouts".
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  static bool _checkedResume = false;

  @override
  void initState() {
    super.initState();
    // A workout that was in progress when the app was killed reopens on launch.
    if (!_checkedResume) {
      _checkedResume = true;
      ref.read(workoutDaoProvider).getActive().then((active) {
        if (active != null && mounted) context.push(Routes.workout);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final sessions = ref.watch(historyProvider).value ?? const [];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: plan,
          builder: (days) {
            final lastDayId = lastWorkoutDayId(sessions, days);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                ScreenHeader(
                  eyebrow: 'Your split',
                  title: 'Workouts',
                  onSettings: () => context.push(Routes.settings),
                ),
                const SizedBox(height: 16),
                _RotationCard(days: days),
                for (final day in days) ...[
                  // The badged card drops 8px so its badge clears the card above.
                  SizedBox(height: day.id == lastDayId ? 24 : 16),
                  _DayCard(day: day, isLastDone: day.id == lastDayId),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RotationCard extends ConsumerWidget {
  const _RotationCard({required this.days});

  final List<DayPlan> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final n = days.length;
    final dao = ref.read(planDaoProvider);

    Future<void> remove() async {
      if (n <= 1) return;
      final last = days.last;
      if (!last.isEmpty) {
        final ok = await confirmDialog(
          context,
          title: 'Remove ${last.name}?',
          message:
              'Its warm-up, exercises and cool-down will be deleted. '
              'Past workouts stay in History.',
          confirm: 'Remove',
        );
        if (!ok) return;
      }
      await dao.setDayCount(n - 1);
      unawaited(ref.read(driveBackupProvider.notifier).afterDataChanged());
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.dark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Days in your split',
                  style: inter(13, color: t.darkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '$n-day rotation',
                  style: grotesk(
                    15,
                    weight: FontWeight.w600,
                    color: Fixed.white,
                  ),
                ),
              ],
            ),
          ),
          IconBtn(
            icon: Ico.minus,
            label: 'Remove a day',
            onTap: n > 1 ? remove : null,
            border: BorderSide(color: t.darkLine),
            color: Fixed.white,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text(
              '$n',
              textAlign: TextAlign.center,
              style: grotesk(28, color: t.accent),
            ),
          ),
          const SizedBox(width: 6),
          IconBtn(
            icon: Ico.plus,
            label: 'Add a day',
            onTap: n < AppDatabase.maxDays
                ? () async {
                    await dao.setDayCount(n + 1);
                    unawaited(
                      ref.read(driveBackupProvider.notifier).afterDataChanged(),
                    );
                  }
                : null,
            background: t.accent,
            color: t.ink,
          ),
        ],
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.day, this.isLastDone = false});

  final DayPlan day;

  /// This day's was the most recent workout (finished or not).
  final bool isLastDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final hasParts = day.parts.isNotEmpty;
    final meta = hasParts
        ? '${plural(day.parts.length, 'body part')} · '
              '${plural(day.exerciseCount, 'exercise')} · '
              '${plural(day.setCount, 'set')}'
        : 'Tap Set up day to add body parts';

    final card = CardBox(
      padding: isLastDone
          ? const EdgeInsets.fromLTRB(15, 22, 15, 15)
          : const EdgeInsets.all(16),
      border: isLastDone ? t.ink : null,
      borderWidth: isLastDone ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.badge,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              day.name.toUpperCase(),
              style: inter(
                11,
                weight: FontWeight.w700,
                letterSpacing: 0.08,
                color: Fixed.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasParts ? day.partsLabel : 'Not set up yet',
            style: grotesk(
              20,
              weight: FontWeight.w600,
              color: t.ink,
              letterSpacing: -0.01,
            ),
          ),
          const SizedBox(height: 4),
          Text(meta, style: inter(13, color: t.muted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Btn(
                  onTap: () => context.push(Routes.day(day.id)),
                  height: 44,
                  radius: 12,
                  color: Fixed.white,
                  border: BorderSide(color: t.border),
                  child: Text(
                    hasParts ? 'Edit' : 'Set up day',
                    style: inter(14, weight: FontWeight.w600, color: t.ink),
                  ),
                ),
              ),
              if (day.canStart) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(
                    onTap: () async {
                      await ref.read(workoutDaoProvider).start(day);
                      if (context.mounted) context.push(Routes.workout);
                    },
                    height: 44,
                    radius: 12,
                    color: t.accent,
                    child: BtnLabel(
                      'Start workout',
                      style: inter(14, weight: FontWeight.w700, color: t.ink),
                      leading: SvgIcon(Ico.playFilled, size: 14, color: t.ink),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (!isLastDone) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(top: -13, left: 14, child: const LastDoneBadge()),
      ],
    );
  }
}

/// Pill on the top-left edge of the day card whose workout was last
/// completed in full. Fill = accent; text, icon and border = ink.
class LastDoneBadge extends StatelessWidget {
  const LastDoneBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SvgIcon(Ico.check, size: 12, color: t.ink, stroke: 3.2),
          ),
          const SizedBox(width: 5),
          Text(
            'Last workout done',
            maxLines: 1,
            softWrap: false,
            style: inter(12, weight: FontWeight.w700, color: t.ink),
          ),
        ],
      ),
    );
  }
}
