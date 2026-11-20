import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../data/database.dart';
import '../features/workout/workout_logic.dart';

String phaseLabel(String phase) => switch (phase) {
  Phase.warmup => 'Warm-up',
  Phase.cooldown => 'Cool-down',
  _ => 'Workout',
};

/// Warm-up → Workout → Cool-down, with done counts and overall progress.
class PhaseStepper extends StatelessWidget {
  const PhaseStepper({
    super.key,
    required this.progress,
    required this.current,
    required this.onSelect,
  });

  final WorkoutProgress progress;
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final percent = (progress.fraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, phase) in Phase.all.indexed) ...[
              if (i > 0) Container(width: 10, height: 2, color: t.border),
              Expanded(child: _step(context, phase)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 8,
                  color: t.accent,
                  backgroundColor: t.line,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$percent%',
              style: const TextStyle(
                fontFamily: headingFont,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _step(BuildContext context, String phase) {
    final t = context.tokens;
    final selected = phase == current;
    final empty = progress.isPhaseEmpty(phase);
    final complete = !empty && progress.isPhaseComplete(phase);
    final label = empty
        ? 'None today'
        : '${progress.doneIn(phase)}/${progress.totalIn(phase)}';

    return Material(
      color: selected ? t.dark : t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: empty ? null : () => onSelect(phase),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? t.dark : t.line),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (complete) ...[
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: selected ? t.accent : t.up,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      phaseLabel(phase),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected ? t.onDark : (empty ? t.muted : t.ink),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? t.onDark.withValues(alpha: 0.8) : t.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
