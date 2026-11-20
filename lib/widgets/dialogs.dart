import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';

/// Asks for one line of text. Returns null on cancel.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Name',
  String confirm = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final v = controller.text.trim();
        if (v.isNotEmpty) Navigator.pop(context, v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: Text(confirm)),
        ],
      );
    },
  );
}

/// Asks for a number. Returns null on cancel.
Future<double?> promptNumber(
  BuildContext context, {
  required String title,
  required double initial,
  required String suffix,
  bool decimal = true,
}) {
  final controller = TextEditingController(
    text: decimal
        ? (initial == initial.roundToDouble()
              ? initial.toInt().toString()
              : initial.toString())
        : initial.toInt().toString(),
  )..selection = TextSelection(baseOffset: 0, extentOffset: 999);
  return showDialog<double>(
    context: context,
    builder: (context) {
      void submit() {
        final v = double.tryParse(controller.text.replaceAll(',', '.'));
        if (v != null && v >= 0) Navigator.pop(context, v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          decoration: InputDecoration(suffixText: suffix),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: const Text('Set')),
        ],
      );
    },
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.tokens.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Opens a video link in the YouTube app / browser.
Future<void> openVideo(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Couldn't open $url")));
  }
}

/// Small "▶ Video" button; hidden when there is no link.
class VideoButton extends StatelessWidget {
  const VideoButton({super.key, required this.url, this.compact = false});

  final String? url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final link = url;
    if (link == null || link.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    if (compact) {
      return IconButton(
        tooltip: 'Watch video',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.play_circle_outline, color: t.ink),
        onPressed: () => openVideo(context, link),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: t.ink,
      ),
      onPressed: () => openVideo(context, link),
      icon: const Icon(Icons.play_circle_outline, size: 18),
      label: const Text('Video'),
    );
  }
}

/// Pill-shaped label.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.background,
    this.foreground,
    this.icon,
  });

  final String text;
  final Color? background;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = foreground ?? t.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? t.ground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green "▲ up" badge.
class UpBadge extends StatelessWidget {
  const UpBadge({super.key, this.label = 'up'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Pill(
      label,
      icon: Icons.arrow_upward,
      background: t.up,
      foreground: Colors.white,
    );
  }
}

/// Section heading used inside lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: t.muted, fontSize: 13),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
