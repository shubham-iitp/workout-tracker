import 'package:material_ui/material_ui.dart';

import '../app/format.dart';
import '../app/theme.dart';
import 'dialogs.dart';
import 'stepper_button.dart';

/// One set: "Set 1  [−] 60 kg [+]  [−] 8 reps [+]" plus an optional check
/// button (active workout) or remove button (day editor).
///
/// Weight steps by 0.1 in the display unit; tap the number to type it.
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.weightKg,
    required this.reps,
    required this.unit,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.weightUp = false,
    this.repsUp = false,
    this.done,
    this.onToggleDone,
    this.onRemove,
  });

  /// 0-based.
  final int index;
  final double weightKg;
  final int reps;
  final WeightUnit unit;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;

  /// Show weight / reps in the "up" colour (higher than last time).
  final bool weightUp;
  final bool repsUp;

  /// Non-null in the active workout.
  final bool? done;
  final VoidCallback? onToggleDone;

  /// Non-null in the day editor.
  final VoidCallback? onRemove;

  void _stepWeight(double delta) {
    final display = round1(toDisplay(weightKg, unit));
    final next = round1(display + delta);
    onWeightChanged(next <= 0 ? 0 : round3(fromDisplay(next, unit)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDone = done ?? false;

    Widget value({
      required String text,
      required String suffix,
      required bool up,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: up ? t.up : t.ink,
                  ),
                ),
              ),
              Text(suffix, style: TextStyle(fontSize: 11, color: t.muted)),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDone ? t.accent.withValues(alpha: 0.35) : t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDone ? t.accent : t.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: t.muted),
            ),
          ),
          StepperButton.minus(
            size: 32,
            onPressed: weightKg > 0 ? () => _stepWeight(-0.1) : null,
          ),
          Expanded(
            child: value(
              text: fmtWeightValue(weightKg, unit),
              suffix: weightKg > 0 ? unit.name : 'weight',
              up: weightUp,
              onTap: () async {
                final v = await promptNumber(
                  context,
                  title: 'Weight (0 = bodyweight)',
                  initial: round1(toDisplay(weightKg, unit)),
                  suffix: unit.name,
                );
                if (v != null) {
                  onWeightChanged(round3(fromDisplay(round1(v), unit)));
                }
              },
            ),
          ),
          StepperButton.plus(size: 32, onPressed: () => _stepWeight(0.1)),
          const SizedBox(width: 10),
          StepperButton.minus(
            size: 32,
            onPressed: reps > 1 ? () => onRepsChanged(reps - 1) : null,
          ),
          Expanded(
            child: value(
              text: '$reps',
              suffix: 'reps',
              up: repsUp,
              onTap: () async {
                final v = await promptNumber(
                  context,
                  title: 'Reps',
                  initial: reps.toDouble(),
                  suffix: 'reps',
                  decimal: false,
                );
                if (v != null && v >= 1) onRepsChanged(v.round());
              },
            ),
          ),
          StepperButton.plus(
            size: 32,
            onPressed: () => onRepsChanged(reps + 1),
          ),
          if (onToggleDone != null) ...[
            const SizedBox(width: 8),
            _CheckButton(done: isDone, onTap: onToggleDone!),
          ],
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove set',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, color: t.muted, size: 20),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: done ? 'Mark not done' : 'Mark done',
      child: Material(
        color: done ? t.dark : t.surface,
        shape: CircleBorder(
          side: BorderSide(color: done ? t.dark : t.border, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(Icons.check, color: done ? t.accent : t.border),
          ),
        ),
      ),
    );
  }
}

/// Large check row for warm-up / cool-down items.
class CheckTile extends StatelessWidget {
  const CheckTile({
    super.key,
    required this.title,
    required this.done,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: done ? t.accent.withValues(alpha: 0.35) : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: done ? t.accent : t.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? t.dark : t.border,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: t.ink,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, style: TextStyle(color: t.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
