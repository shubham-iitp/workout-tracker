import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui.dart';

/// Tab 2 — "LOGBOOK / History".
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final t = context.tokens;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: history,
          builder: (sessions) {
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final week = sessions
                .where((s) => s.session.startedAt.isAfter(weekAgo))
                .toList();
            final upWeek = week.fold(0, (n, s) => n + s.liftsUp);
            final expanded =
                ref.watch(expandedSessionProvider) ??
                (sessions.isEmpty ? null : sessions.first.session.id);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                ScreenHeader(
                  eyebrow: 'Logbook',
                  title: 'History',
                  onSettings: () => context.push(Routes.settings),
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '$upWeek',
                          label: 'Lifts up this week',
                          dark: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${week.length}',
                          label: 'Workouts this week',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${sessions.length}',
                          label: 'All workouts',
                        ),
                      ),
                    ],
                  ),
                ),
                if (sessions.isEmpty) ...[
                  const SizedBox(height: 16),
                  CardBox(
                    dashed: true,
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.ground,
                            shape: BoxShape.circle,
                          ),
                          child: SvgIcon(
                            Ico.clock,
                            size: 26,
                            color: t.muted,
                            stroke: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No workouts logged yet',
                          style: grotesk(20, color: t.ink),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Start a day from Workouts. When you save it, every set '
                          'you did shows up here with the date and time.',
                          textAlign: TextAlign.center,
                          style: inter(14, color: t.muted),
                        ),
                        const SizedBox(height: 16),
                        Btn(
                          onTap: () => context.go(Routes.workouts),
                          height: 48,
                          color: t.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Go to workouts',
                            style: inter(
                              14,
                              weight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final s in sessions) ...[
                  const SizedBox(height: 16),
                  _SessionCard(
                    view: s,
                    open: s.session.id == expanded,
                    onToggle: () => ref
                        .read(expandedSessionProvider.notifier)
                        .set(s.session.id == expanded ? -1 : s.session.id),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.dark = false});

  final String value;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? t.dark : Fixed.white,
        borderRadius: BorderRadius.circular(16),
        border: dark ? null : Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: grotesk(28, color: dark ? t.accent : t.ink)),
          const SizedBox(height: 2),
          Text(label, style: inter(12, color: dark ? t.darkMuted : t.muted)),
        ],
      ),
    );
  }
}

/// Pill for a partial workout: a small progress ring + "N%". Shown in place
/// of the "N up" tag.
class _PartialPill extends StatelessWidget {
  const _PartialPill(this.pct);

  final int pct;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Partial workout, $pct% done',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 4, 9, 4),
        decoration: BoxDecoration(
          color: t.line,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(16),
              painter: _RingPainter(
                fraction: pct / 100,
                track: t.checkIdle,
                arc: t.ink,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$pct%',
              style: inter(12, weight: FontWeight.w700, color: t.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// r = 6, stroke 2.5 in a 16×16 box; the arc starts at 12 o'clock.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.track,
    required this.arc,
  });

  final double fraction;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(rect, stroke..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        stroke
          ..color = arc
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.arc != arc;
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({
    required this.view,
    required this.open,
    required this.onToggle,
  });

  final SessionView view;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final unit = ref.watch(unitProvider);
    final s = view.session;
    final d = s.startedAt;
    final routine = [
      if (s.warmTotal > 0) 'Warm-up ${s.warmDone}/${s.warmTotal}',
      if (s.coolTotal > 0) 'Cool-down ${s.coolDone}/${s.coolTotal}',
    ].join(' · ');
    final title = s.partsLabel.isEmpty
        ? s.dayName
        : '${s.dayName} · ${s.partsLabel}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Fixed.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              onLongPress: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete this workout?',
                  message:
                      '$title on ${fmtDateLong(d)} will be removed from '
                      'History. Your plan is not changed.',
                  confirm: 'Delete',
                );
                if (ok) {
                  await ref.read(historyDaoProvider).deleteSession(s.id);
                  // Same auto backup as after saving a workout.
                  unawaited(
                    ref.read(driveBackupProvider.notifier).afterDataChanged(),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 60,
                      decoration: BoxDecoration(
                        color: t.ground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('MMM').format(d).toUpperCase(),
                            style: inter(
                              11,
                              weight: FontWeight.w700,
                              letterSpacing: 0.08,
                              color: t.muted,
                            ),
                          ),
                          Text(
                            '${d.day}',
                            style: grotesk(24, color: t.ink, height: 1.1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: inter(
                              15,
                              weight: FontWeight.w600,
                              color: t.ink,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${DateFormat('EEE').format(d)}, ${fmtTime(d)} · ${s.minutes} min',
                            style: inter(13, color: t.muted, height: 1.35),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${fmtVolume(view.volumeKg, unit)} lifted · '
                            '${view.setsDone}/${s.totalSets} sets',
                            style: inter(13, color: t.muted, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    if (view.isPartial) ...[
                      const SizedBox(width: 14),
                      _PartialPill(view.completionPct),
                    ] else if (view.liftsUp > 0) ...[
                      const SizedBox(width: 14),
                      UpPill(
                        '${view.liftsUp} up',
                        iconSize: 11,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (routine.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: t.divider)),
                      ),
                      child: Text(routine, style: inter(13, color: t.muted)),
                    ),
                  for (final e in view.exercises)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: t.divider)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.exercise.name,
                                  style: inter(
                                    14,
                                    weight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  e.sets
                                      .map(
                                        (x) => fmtSet(x.weight, x.reps, unit),
                                      )
                                      .join(' · '),
                                  style: inter(13, color: t.muted),
                                ),
                              ],
                            ),
                          ),
                          if (e.exercise.improved) ...[
                            const SizedBox(width: 10),
                            const UpPill('Up', fontSize: 11, showIcon: false),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
