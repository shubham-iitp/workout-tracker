import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: AsyncView(
        value: history,
        builder: (sessions) {
          if (sessions.isEmpty) return const _EmptyHistory();
          final weekStart = startOfWeek(DateTime.now());
          final thisWeek = sessions.where(
            (s) => !s.session.startedAt.isBefore(weekStart),
          );
          final liftsUp = thisWeek.fold(0, (n, s) => n + s.liftsUp);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      value: '${thisWeek.length}',
                      label: thisWeek.length == 1
                          ? 'session this week'
                          : 'sessions this week',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      value: '$liftsUp',
                      label: 'lifts up this week',
                      up: liftsUp > 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final s in sessions) ...[
                _SessionCard(view: s),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.up = false});

  final String value;
  final String label;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: headingFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                  color: t.accent,
                ),
              ),
              if (up) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_upward, color: t.accent, size: 22),
              ],
            ],
          ),
          Text(
            label,
            style: TextStyle(color: t.onDark.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({required this.view});

  final SessionView view;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = ref.watch(unitProvider);
    final v = widget.view;
    final s = v.session;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: () async {
          final ok = await confirmDialog(
            context,
            title: 'Delete this workout?',
            message:
                '${s.dayName} on ${fmtDateLong(s.startedAt)} will be removed '
                'from History. Your plan is not changed.',
            confirm: 'Delete',
            destructive: true,
          );
          if (ok) await ref.read(historyDaoProvider).deleteSession(s.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmtDate(s.startedAt),
                          style: const TextStyle(
                            fontFamily: headingFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${fmtTime(s.startedAt)} · ${s.minutes} min',
                          style: TextStyle(color: t.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (v.liftsUp > 0) UpBadge(label: '${v.liftsUp} up'),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: t.muted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.partsLabel.isEmpty
                    ? s.dayName
                    : '${s.dayName} · ${s.partsLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Pill(fmtVolume(v.volumeKg, unit), icon: Icons.fitness_center),
                  Pill('${v.setsDone}/${s.totalSets} sets', icon: Icons.check),
                  if (s.warmTotal > 0)
                    Pill('Warm-up ${s.warmDone}/${s.warmTotal}'),
                  if (s.coolTotal > 0)
                    Pill('Cool-down ${s.coolDone}/${s.coolTotal}'),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                Divider(color: t.line),
                if (v.exercises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No sets recorded',
                      style: TextStyle(color: t.muted),
                    ),
                  ),
                for (final e in v.exercises)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.exercise.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                e.sets
                                    .map((x) => fmtSet(x.weight, x.reps, unit))
                                    .join(' · '),
                                style: TextStyle(color: t.muted),
                              ),
                            ],
                          ),
                        ),
                        if (e.exercise.improved) const UpBadge(),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: t.border),
            const SizedBox(height: 12),
            const Text(
              'No workouts yet',
              style: TextStyle(
                fontFamily: headingFont,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Finish a workout and it shows up here with your sets, '
              'volume and lifts that went up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}
