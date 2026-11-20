import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/csv_backup_service.dart';
import '../../data/csv_codec.dart';
import '../../widgets/dialogs.dart';
import 'import_sheet.dart';

/// Banner shown under "Your data" after an export / import.
class _Banner {
  const _Banner({
    required this.title,
    required this.message,
    this.error = false,
  });

  final String title;
  final String message;
  final bool error;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _Banner? _banner;
  bool _busy = false;
  bool _formatExpanded = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(backupServiceProvider).exportAndShare();
      setState(
        () => _banner = _Banner(
          title: 'Exported ${result.fileName}',
          message: summaryShort(result.data),
        ),
      );
    } catch (e) {
      setState(
        () => _banner = _Banner(
          title: 'Export failed',
          message: '$e',
          error: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    try {
      final preview = await service.pickAndParse();
      if (preview == null || !mounted) return;
      final ok = await showImportSheet(context, preview);
      if (!ok) return;
      await service.replaceAll(preview.data);
      setState(() {
        _formatExpanded = false;
        _banner = _Banner(
          title: 'Imported ${preview.fileName}',
          message: summaryShort(preview.data),
        );
      });
    } on ImportFailure catch (e) {
      setState(() {
        _formatExpanded = true;
        _banner = _Banner(
          title: "Couldn't import ${e.fileName}",
          message: '${e.message}. Nothing was changed.',
          error: true,
        );
      });
    } catch (e) {
      setState(
        () => _banner = _Banner(
          title: 'Import failed',
          message: '$e. Nothing was changed.',
          error: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('Colour palette'),
          for (final p in AppPalette.values) ...[
            _PaletteTile(
              palette: p,
              selected: p == settings.palette,
              onTap: () => notifier.setPalette(p),
            ),
            const SizedBox(height: 8),
          ],
          const SectionHeader(
            'Weight unit',
            subtitle: 'Weights are always stored in kg',
          ),
          SegmentedButton<WeightUnit>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: t.accent,
              selectedForegroundColor: t.onAccent,
              side: BorderSide(color: t.border),
            ),
            segments: const [
              ButtonSegment(
                value: WeightUnit.kg,
                label: Text('Kilograms (kg)'),
              ),
              ButtonSegment(value: WeightUnit.lb, label: Text('Pounds (lb)')),
            ],
            selected: {settings.unit},
            onSelectionChanged: (s) => notifier.setUnit(s.first),
          ),
          const SectionHeader(
            'Your data',
            subtitle:
                'Everything lives on this phone. Uninstalling the app '
                'deletes it — export a backup first.',
          ),
          if (_banner != null) ...[
            _BannerCard(
              banner: _banner!,
              onClose: () => setState(() => _banner = null),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export CSV'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Import CSV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CsvFormatHelp(
            expanded: _formatExpanded,
            onToggle: () => setState(() => _formatExpanded = !_formatExpanded),
          ),
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = palette.tokens;
    Widget swatch(Color c) => Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? t.dark : t.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              swatch(p.accent),
              swatch(p.dark),
              swatch(p.badge),
              swatch(p.ground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  palette.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: t.dark),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onClose});

  final _Banner banner;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = banner.error ? t.danger : t.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            banner.error ? Icons.error_outline : Icons.check_circle,
            color: banner.error ? Colors.white : t.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banner.message,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _CsvFormatHelp extends StatelessWidget {
  const _CsvFormatHelp({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
    Widget rule(String type, String cols) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: t.ink, fontSize: 13, fontFamily: bodyFont),
          children: [
            TextSpan(
              text: type,
              style: mono.copyWith(fontWeight: FontWeight.w700, color: t.ink),
            ),
            TextSpan(text: ' — $cols'),
          ],
        ),
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text(
              'CSV format',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A header row, then one row per item. Every row has exactly '
                    '${csvColumns.length} columns; unused cells are empty. The first '
                    'column says what the row is. Weights are always kg. Quote any '
                    'cell that contains a comma.',
                    style: TextStyle(color: t.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.ground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(csvColumns.join(','), style: mono),
                  ),
                  rule('day', 'day (name; row order = order)'),
                  rule(
                    'routine',
                    'day, section (warmup / cooldown), exercise (item name), detail, video_url',
                  ),
                  rule(
                    'set',
                    'day, body_part, exercise, set (1, 2, …), weight_kg, reps, video_url, '
                        'last_weight_kg, last_reps',
                  ),
                  rule(
                    'session',
                    'session_id, started_at (2026-11-16T06:55:00), minutes, day, '
                        'body_part (parts label), set (planned sets), warm_done, warm_total, '
                        'cool_done, cool_total',
                  ),
                  rule(
                    'session_set',
                    'session_id, exercise, set, weight_kg, reps, improved (true / false); '
                        'must come after its session row',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Up to $maxBackupDays days. Rows are counted with the header as row 1.',
                    style: TextStyle(color: t.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
