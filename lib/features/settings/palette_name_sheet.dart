import 'package:material_ui/material_ui.dart';

import '../../app/random_palette.dart';
import '../../app/theme.dart';
import '../../data/daos/palette_dao.dart';
import '../../widgets/ui.dart';

/// "Name this palette" (design 7.3 / 7.4). Resolves to the trimmed name, or
/// null for Cancel. A name that matches a saved palette replaces it.
Future<String?> showPaletteNameSheet(
  BuildContext context, {
  required GeneratedPalette palette,
  required List<SavedPalette> saved,
}) {
  return showDesignSheet<String>(
    context,
    builder: (sheet) => _NameSheet(palette: palette, saved: saved),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.palette, required this.saved});

  final GeneratedPalette palette;
  final List<SavedPalette> saved;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _c = TextEditingController(
    text: 'My palette ${widget.saved.length + 1}',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final raw = _c.text;
    final name = raw.trim();
    final preset = isPresetPaletteName(name);
    final canSave = paletteNameProblem(name) == null;
    final dup = widget.saved
        .where((p) => samePaletteName(p.name, name))
        .firstOrNull;

    Widget note(String text, {bool error = false}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: error ? Fixed.dangerBg : t.ground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error ? Fixed.dangerBorder : t.border),
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: inter(13, color: error ? Fixed.dangerTitle : t.ink),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text('Name this palette', style: grotesk(22, color: t.ink)),
          ),
          const SizedBox(height: 14),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final (i, hex)
                    in widget.palette.colors.swatches.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: hexColor(hex),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1F000000)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Palette name',
            style: inter(12, weight: FontWeight.w600, color: t.muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _c,
            autofocus: true,
            maxLength: maxPaletteNameLength,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canSave) Navigator.pop(context, name);
            },
            style: inter(16, weight: FontWeight.w600, color: t.ink),
            decoration: InputDecoration(
              hintText: 'e.g. Sunset',
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Fixed.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.ink, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.ink, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'It shows up in Colour palette next to the presets.',
                  style: inter(12, color: t.muted),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${raw.length} / $maxPaletteNameLength',
                style: inter(12, color: t.muted),
              ),
            ],
          ),
          if (dup != null && canSave) ...[
            const SizedBox(height: 14),
            note(
              'You already have a palette called “${dup.name}”. '
              'Saving will replace it.',
            ),
          ],
          if (preset) ...[
            const SizedBox(height: 14),
            note(
              'That name is used by a built-in palette. Pick another one.',
              error: true,
            ),
          ],
          const SizedBox(height: 14),
          Btn(
            onTap: canSave ? () => Navigator.pop(context, name) : null,
            height: 52,
            color: canSave ? t.dark : t.border2,
            child: Text(
              dup != null && canSave ? 'Replace palette' : 'Save palette',
              style: inter(15, weight: FontWeight.w700, color: Fixed.white),
            ),
          ),
          const SizedBox(height: 4),
          Btn(
            onTap: () => Navigator.pop(context),
            height: 48,
            child: Text(
              'Cancel',
              style: inter(15, weight: FontWeight.w600, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}
