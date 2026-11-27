import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';

// ---------------------------------------------------------------------------
// Icons — the exact SVG paths used in the design (24×24 stroke icons).
// ---------------------------------------------------------------------------

enum Ico {
  gear(
    '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 11-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 11-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 11-2.83-2.83l.06-.06A1.65 1.65 0 004.6 15a1.65 1.65 0 00-1.51-1H3a2 2 0 110-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06A1.65 1.65 0 009 4.6a1.65 1.65 0 001-1.51V3a2 2 0 114 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 112.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 110 4h-.09a1.65 1.65 0 00-1.51 1z"/>',
  ),
  minus('<path d="M5 12h14"/>'),
  plus('<path d="M12 5v14M5 12h14"/>'),
  playFilled('<path d="M7 4.5v15l12.5-7.5z"/>', filled: true),
  playSmall('<path d="M8 5v14l11-7z"/>', filled: true),
  back('<path d="M15 5l-7 7 7 7"/>'),
  chevronRight('<path d="M9 5l7 7-7 7"/>'),
  search('<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>'),
  flame(
    '<path d="M12 3c1 3 4 4.5 4 8.5a4 4 0 01-8 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 0-7.5z"/>',
  ),
  snow('<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/>'),
  close('<path d="M6 6l12 12M18 6L6 18"/>'),
  trash('<path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/>'),
  link(
    '<path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/>',
  ),
  check('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  video(
    '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/>',
  ),
  arrowUp('<path d="M12 19V5M6 11l6-6 6 6"/>'),
  arrowRight('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  undo('<path d="M9 14L4 9l5-5"/><path d="M4 9h11a5 5 0 010 10h-3"/>'),
  upload(
    '<path d="M12 15V3M7 8l5-5 5 5"/><path d="M4 14v5a2 2 0 002 2h12a2 2 0 002-2v-5"/>',
  ),
  download(
    '<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 14v5a2 2 0 002 2h12a2 2 0 002-2v-5"/>',
  ),
  dumbbell('<path d="M6 7v10M3 9.5v5M18 7v10M21 9.5v5M6 12h12"/>'),
  clock('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
  // Pips drawn as tiny stroked circles so they take the icon's one colour.
  dice(
    '<rect x="3.5" y="3.5" width="17" height="17" rx="4"/><circle cx="8.5" cy="8.5" r=".5"/><circle cx="15.5" cy="8.5" r=".5"/><circle cx="12" cy="12" r=".5"/><circle cx="8.5" cy="15.5" r=".5"/><circle cx="15.5" cy="15.5" r=".5"/>',
  ),
  alert('<path d="M12 7v6M12 17h.01"/>');

  const Ico(this.body, {this.filled = false});
  final String body;
  final bool filled;
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.icon, {
    super.key,
    this.size = 18,
    this.color,
    this.stroke = 2.2,
  });

  final Ico icon;
  final double size;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = _hex(
      color ?? DefaultTextStyle.of(context).style.color ?? Fixed.white,
    );
    final paint = icon.filled
        ? 'fill="$c" stroke="none"'
        : 'fill="none" stroke="$c" stroke-width="$stroke" '
              'stroke-linecap="round" stroke-linejoin="round"';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" $paint>'
      '${icon.body}</svg>',
      width: size,
      height: size,
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons & surfaces
// ---------------------------------------------------------------------------

/// A tappable rounded box — the design's `<button>`.
class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Colors.transparent,
    this.border,
    this.radius = 14,
    this.height,
    this.width,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.dashed = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final BorderSide? border;
  final double radius;
  final double? height;
  final double? width;
  final EdgeInsets padding;
  final String? semanticLabel;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: dashed ? BorderSide.none : (border ?? BorderSide.none),
    );
    Widget content = Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height ?? 0,
            minWidth: width ?? 0,
            maxWidth: width ?? double.infinity,
          ),
          child: Padding(
            padding: padding,
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
    if (dashed && border != null) {
      content = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: border!.color,
          width: border!.width,
          radius: radius,
        ),
        child: content,
      );
    }
    if (semanticLabel != null) {
      content = Semantics(button: true, label: semanticLabel, child: content);
    }
    return content;
  }
}

/// Text + optional leading/trailing icon, laid out like the design's buttons.
class BtnLabel extends StatelessWidget {
  const BtnLabel(
    this.text, {
    super.key,
    required this.style,
    this.leading,
    this.trailing,
    this.gap = 6,
    this.alignStart = false,
  });

  final String text;
  final TextStyle style;
  final Widget? leading;
  final Widget? trailing;
  final double gap;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: style,
      child: Row(
        mainAxisSize: alignStart ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: alignStart
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, SizedBox(width: gap)],
          Flexible(
            child: Text(text, style: style, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) ...[SizedBox(width: gap), trailing!],
        ],
      ),
    );
  }
}

/// 44×44 icon-only button.
class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.size = 44,
    this.iconSize = 18,
    this.color,
    this.background = Colors.transparent,
    this.border,
    this.radius = 14,
    this.stroke = 2.2,
    this.width,
  });

  final Ico icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final double iconSize;
  final Color? color;
  final Color background;
  final BorderSide? border;
  final double radius;
  final double stroke;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Btn(
      semanticLabel: label,
      onTap: onTap,
      color: background,
      border: border,
      radius: radius,
      height: size,
      width: width ?? size,
      child: SvgIcon(icon, size: iconSize, color: color, stroke: stroke),
    );
  }
}

/// White card with a 1px line border.
class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color,
    this.border,
    this.borderWidth = 1,
    this.dashed = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? border;
  final double borderWidth;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Fixed.white,
        borderRadius: BorderRadius.circular(radius),
        border: dashed
            ? null
            : Border.all(color: border ?? t.line, width: borderWidth),
      ),
      child: child,
    );
    if (!dashed) return box;
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: border ?? t.border2,
        width: 1.5,
        radius: radius,
      ),
      child: box,
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
  });

  final Color color;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}

/// Uppercase small label: "YOUR SPLIT", "CHEST · 2 LEFT".
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color,
    this.weight = FontWeight.w700,
  });

  final String text;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: inter(
      12,
      weight: weight,
      letterSpacing: 0.1,
      color: color ?? context.tokens.muted,
    ),
  );
}

/// Accent pill with an up arrow: "+2.5 kg vs last time", "2 up".
class UpPill extends StatelessWidget {
  const UpPill(
    this.text, {
    super.key,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.iconSize = 12,
    this.showIcon = true,
  });

  final String text;
  final double fontSize;
  final EdgeInsets padding;
  final double iconSize;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            SvgIcon(Ico.arrowUp, size: iconSize, color: t.ink, stroke: 3),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: inter(fontSize, weight: FontWeight.w700, color: t.ink),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

InputDecoration fieldDecoration(
  AppTokens t, {
  String? hint,
  Color? fill,
  bool bordered = true,
}) {
  final side = bordered ? BorderSide(color: t.border) : BorderSide.none;
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: inter(
      14,
      weight: FontWeight.w500,
      color: t.muted.withValues(alpha: 0.7),
    ),
    filled: true,
    fillColor: fill ?? Fixed.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: bordered ? 12 : 8,
      vertical: 13,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: side,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: side,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: bordered
          ? BorderSide(color: t.ink, width: 1.5)
          : BorderSide.none,
    ),
  );
}

/// A text field whose value lives in the database: shows [value], reports
/// edits through [onChanged], and doesn't get overwritten while focused.
class SyncedField extends StatefulWidget {
  const SyncedField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.number = false,
    this.decimal = false,
    this.fontSize = 14,
    this.weight = FontWeight.w500,
    this.semanticLabel,
    this.url = false,
    this.bordered = true,
    this.fill,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool number;
  final bool decimal;
  final double fontSize;
  final FontWeight weight;
  final String? semanticLabel;
  final bool url;
  final bool bordered;
  final Color? fill;

  @override
  State<SyncedField> createState() => _SyncedFieldState();
}

class _SyncedFieldState extends State<SyncedField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );
  final _focus = FocusNode();

  @override
  void didUpdateWidget(SyncedField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _c.text != widget.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: TextField(
        controller: _c,
        focusNode: _focus,
        onChanged: widget.onChanged,
        textCapitalization: widget.number || widget.url
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        keyboardType: widget.number
            ? TextInputType.numberWithOptions(decimal: widget.decimal)
            : (widget.url ? TextInputType.url : TextInputType.text),
        inputFormatters: widget.number
            ? [
                FilteringTextInputFormatter.allow(
                  widget.decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
                ),
              ]
            : null,
        style: inter(widget.fontSize, weight: widget.weight, color: t.ink),
        decoration: fieldDecoration(
          t,
          hint: widget.hint,
          bordered: widget.bordered,
          fill: widget.fill,
        ),
      ),
    );
  }
}

/// "Paste YouTube or video link (optional)" row with an open button.
class VideoLinkRow extends StatelessWidget {
  const VideoLinkRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.name,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final href = videoHref(value);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: t.field,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SvgIcon(Ico.link, size: 16, color: t.muted, stroke: 2),
                Expanded(
                  child: SyncedField(
                    value: value,
                    onChanged: onChanged,
                    url: true,
                    fontSize: 13,
                    bordered: false,
                    fill: Colors.transparent,
                    hint: 'Paste YouTube or video link (optional)',
                    semanticLabel: 'Video link for $name',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (href != null) ...[
          const SizedBox(width: 8),
          IconBtn(
            icon: Ico.playSmall,
            label: 'Open video for $name',
            onTap: () => openVideo(context, href),
            background: t.dark,
            color: Fixed.white,
            radius: 10,
            iconSize: 16,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets, dialogs, links
// ---------------------------------------------------------------------------

/// The design's bottom sheet: white, 24px top radius, grab handle, dark scrim.
Future<T?> showDesignSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Fixed.white,
    barrierColor: Fixed.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final t = ctx.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              builder(ctx),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
}) async {
  final t = context.tokens;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Fixed.scrim,
    builder: (context) => AlertDialog(
      backgroundColor: Fixed.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: grotesk(20, color: t.ink)),
      content: Text(message, style: inter(14, color: t.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: inter(15, weight: FontWeight.w600, color: t.ink),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirm,
            style: inter(15, weight: FontWeight.w700, color: Fixed.dangerText),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Normalises a typed link: adds https:// when missing. Null when empty.
String? videoHref(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null;
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(s)
      ? s
      : 'https://$s';
}

Future<void> openVideo(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Couldn't open $url")));
  }
}

/// Screen header: optional eyebrow, big title, optional gear button.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.onSettings,
  });

  final String eyebrow;
  final String title;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow, weight: FontWeight.w600),
              const SizedBox(height: 2),
              Text(
                title,
                style: grotesk(34, color: t.ink, letterSpacing: -0.02),
              ),
            ],
          ),
        ),
        if (onSettings != null)
          IconBtn(
            icon: Ico.gear,
            label: 'Settings',
            onTap: onSettings,
            background: Fixed.white,
            border: BorderSide(color: t.line),
            color: t.ink,
            iconSize: 20,
            stroke: 2,
          ),
      ],
    );
  }
}

/// Back chevron + title row used by Edit day and Settings.
class BackHeader extends StatelessWidget {
  const BackHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.titleSize = 26,
    this.backLabel = 'Back',
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final double titleSize;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-10, 0),
          child: IconBtn(
            icon: Ico.back,
            label: backLabel,
            onTap: onBack,
            color: t.ink,
            iconSize: 22,
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: grotesk(titleSize, color: t.ink, letterSpacing: -0.02),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: inter(13, color: t.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
