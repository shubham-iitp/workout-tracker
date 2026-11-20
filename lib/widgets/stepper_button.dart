import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// Round −/+ button. Holding it repeats the action.
class StepperButton extends StatefulWidget {
  const StepperButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 36,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  const StepperButton.minus({
    super.key,
    required this.onPressed,
    this.size = 36,
    this.tooltip = 'Decrease',
  }) : icon = Icons.remove;

  const StepperButton.plus({
    super.key,
    required this.onPressed,
    this.size = 36,
    this.tooltip = 'Increase',
  }) : icon = Icons.add;

  @override
  State<StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<StepperButton> {
  Timer? _repeat;

  void _startRepeat() {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      widget.onPressed?.call();
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onPressed != null;
    final button = GestureDetector(
      onLongPressStart: enabled ? (_) => _startRepeat() : null,
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: Material(
        color: enabled ? t.ground : t.surface,
        shape: CircleBorder(side: BorderSide(color: t.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: widget.size,
            child: Icon(
              widget.icon,
              size: widget.size * 0.5,
              color: enabled ? t.ink : t.border,
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}
