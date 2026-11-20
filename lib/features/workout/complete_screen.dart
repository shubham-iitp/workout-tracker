import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../widgets/dialogs.dart';
import 'workout_actions.dart';
import 'workout_logic.dart';

/// Summary per phase, lifts up, Save.
class CompleteScreen extends ConsumerStatefulWidget {
  const CompleteScreen({super.key});

  @override
  ConsumerState<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends ConsumerState<CompleteScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final current = currentWorkout(ref);
    final t = context.tokens;
    final unit = ref.watch(unitProvider);

    if (current == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(Routes.workouts),
            child: const Text('Back to workouts'),
          ),
        ),
      );
    }
    final (:active, :progress) = current;
    final day = progress.day;
    final minutes = (DateTime.now().difference(active.startedAt).inSeconds / 60)
        .round();
    final improved = day.exercises
        .where((e) => e.sets.where(progress.isSetDone).any(isSetImproved))
        .toList();

    Widget row(String label, String value, {bool skipped = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: headingFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: skipped ? t.muted : t.ink,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Workout complete')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.dark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emoji_events_outlined, color: t.accent, size: 36),
                const SizedBox(height: 8),
                Text(
                  progress.allDone ? 'Everything done!' : 'Nice work',
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    color: t.onDark,
                  ),
                ),
                Text(
                  '${day.name}${day.partsLabel.isEmpty ? '' : ' · ${day.partsLabel}'}',
                  style: TextStyle(color: t.onDark.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(
                      '${minutes < 1 ? 1 : minutes} min',
                      icon: Icons.timer_outlined,
                      background: t.accent,
                      foreground: t.onAccent,
                    ),
                    Pill(
                      fmtVolume(progress.volumeDoneKg, unit),
                      icon: Icons.fitness_center,
                      background: t.accent,
                      foreground: t.onAccent,
                    ),
                    if (progress.liftsUp > 0)
                      Pill(
                        '${progress.liftsUp} up',
                        icon: Icons.arrow_upward,
                        background: t.up,
                        foreground: Colors.white,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  row(
                    'Warm-up',
                    progress.warmTotal == 0
                        ? 'None today'
                        : '${progress.warmDone}/${progress.warmTotal}',
                    skipped: progress.warmTotal == 0,
                  ),
                  Divider(color: t.line),
                  row(
                    'Workout',
                    '${progress.setsDone}/${progress.setsTotal} sets',
                  ),
                  Divider(color: t.line),
                  row(
                    'Cool-down',
                    progress.coolTotal == 0
                        ? 'None today'
                        : '${progress.coolDone}/${progress.coolTotal}',
                    skipped: progress.coolTotal == 0,
                  ),
                ],
              ),
            ),
          ),
          if (improved.isNotEmpty) ...[
            const SectionHeader('Lifts up'),
            Card(
              child: Column(
                children: [
                  for (final e in improved)
                    ListTile(
                      title: Text(
                        e.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        e.sets
                            .where(progress.isSetDone)
                            .map((s) => fmtSet(s.weight, s.reps, unit))
                            .join(' · '),
                      ),
                      trailing: const UpBadge(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Back to workout'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving || progress.doneCount == 0
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await saveWorkout(context, ref, active, progress);
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
