import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/csv_backup_service.dart';
import '../../widgets/ui.dart';
import 'drive_section.dart';
import 'import_sheet.dart';

/// Banner under "Your data" after an export / import.
class _Banner {
  const _Banner({required this.title, required this.body, this.error = false});

  final String title;
  final String body;
  final bool error;
}

const _rowTypes = [
  ('day', 'day name, position'),
  ('routine', 'day, section (warmup / cooldown), name, video_url'),
  (
    'set',
    'day, body_part, exercise, set, weight_kg, reps, video_url, last_weight_kg, last_reps',
  ),
  (
    'session',
    'session_id, started_at, minutes, day, warm_done, warm_total, cool_done, cool_total',
  ),
  ('session_set', 'session_id, exercise, set, weight_kg, reps, improved'),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _Banner? _banner;
  bool _busy = false;
  bool _formatOpen = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(backupServiceProvider).exportAndShare();
      setState(
        () => _banner = _Banner(
          title: 'Exported ${r.fileName}',
          body:
              '${summaryShort(r.data)}. Choose where to save or send it from the share sheet.',
        ),
      );
    } catch (e) {
      setState(
        () =>
            _banner = _Banner(title: 'Export failed', body: '$e', error: true),
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
      unawaited(ref.read(driveBackupProvider.notifier).afterDataChanged());
      final d = preview.data;
      setState(() {
        _formatOpen = false;
        _banner = _Banner(
          title: 'Imported ${preview.fileName}',
          body:
              'Your plan now has ${plural(d.dayCount, 'day')} and '
              '${plural(d.exerciseCount, 'exercise')}, and history has '
              '${plural(d.sessionCount, 'workout')}.',
        );
      });
    } on ImportFailure catch (e) {
      setState(() {
        _formatOpen = true;
        _banner = _Banner(
          title: "Couldn't import ${e.fileName}",
          body: '${e.message}. Nothing was changed.',
          error: true,
        );
      });
    } catch (e) {
      setState(
        () => _banner = _Banner(
          title: 'Import failed',
          body: '$e. Nothing was changed.',
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
    final h2 = inter(
      12,
      weight: FontWeight.w700,
      letterSpacing: 0.1,
      color: t.muted,
    );

    Widget sectionTitle(String title, [String? sub]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: h2),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub, style: inter(13, color: t.muted)),
        ],
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            BackHeader(
              title: 'Settings',
              titleSize: 28,
              onBack: () => context.pop(),
            ),
            const SizedBox(height: 16),
            sectionTitle(
              'Colour palette',
              'Applies to the whole app straight away.',
            ),
            const SizedBox(height: 10),
            for (final p in AppPalette.values) ...[
              _PaletteOption(
                palette: p,
                selected: p == settings.palette,
                onTap: () => notifier.setPalette(p),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            sectionTitle('Weight unit'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Fixed.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  for (final (i, u) in WeightUnit.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Semantics(
                        selected: u == settings.unit,
                        child: Btn(
                          onTap: () => notifier.setUnit(u),
                          height: 44,
                          radius: 10,
                          color: u == settings.unit
                              ? t.dark
                              : Colors.transparent,
                          child: Text(
                            u.name,
                            style: inter(
                              15,
                              weight: FontWeight.w700,
                              color: u == settings.unit ? Fixed.white : t.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Weight + / − always moves by 0.1.',
              style: inter(13, color: t.muted),
            ),
            const SizedBox(height: 16),
            sectionTitle(
              'Your data',
              'Your plan and workout history, as one CSV file.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Btn(
                    onTap: _busy ? null : _export,
                    height: 52,
                    color: t.dark,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: BtnLabel(
                      'Export CSV',
                      alignStart: true,
                      gap: 10,
                      style: inter(
                        15,
                        weight: FontWeight.w600,
                        color: Fixed.white,
                      ),
                      leading: const SvgIcon(Ico.upload, color: Fixed.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(
                    onTap: _busy ? null : _import,
                    height: 52,
                    color: Fixed.white,
                    border: BorderSide(color: t.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: BtnLabel(
                      'Import CSV',
                      alignStart: true,
                      gap: 10,
                      style: inter(15, weight: FontWeight.w600, color: t.ink),
                      leading: SvgIcon(Ico.download, color: t.ink),
                    ),
                  ),
                ),
              ],
            ),
            if (_banner != null) ...[
              const SizedBox(height: 10),
              _BannerBox(banner: _banner!),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                expanded: _formatOpen,
                child: Btn(
                  onTap: () => setState(() => _formatOpen = !_formatOpen),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    _formatOpen ? 'Hide CSV format' : 'See CSV format',
                    style: inter(
                      14,
                      weight: FontWeight.w600,
                      color: t.ink,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
            if (_formatOpen) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Fixed.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One row per item. The first column says what the row is:',
                      style: inter(12, weight: FontWeight.w700, color: t.ink),
                    ),
                    for (final (code, text) in _rowTypes) ...[
                      const SizedBox(height: 8),
                      Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(text, style: inter(12, color: t.muted)),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Weights are stored in kg. Empty cells are allowed for anything optional.',
                      style: inter(12, color: t.muted),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const DriveSection(),
          ],
        ),
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  const _PaletteOption({
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
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: palette.label,
      child: Material(
        color: Fixed.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected
              ? BorderSide(color: t.ink, width: 2)
              : BorderSide(color: t.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: Row(
              children: [
                // Mini preview of the palette.
                Container(
                  width: 48,
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p.ground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        color: p.dark,
                        padding: const EdgeInsets.fromLTRB(7, 0, 7, 5),
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: 28,
                          height: 4,
                          decoration: BoxDecoration(
                            color: p.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 6, 7, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Fixed.white,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 26,
                              height: 9,
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
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
                        palette.label,
                        style: inter(16, weight: FontWeight.w600, color: t.ink),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final c in p.swatches) ...[
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x1F000000),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? t.ink : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? t.ink : t.border2,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const SvgIcon(
                          Ico.check,
                          size: 14,
                          color: Fixed.white,
                          stroke: 3,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerBox extends StatelessWidget {
  const _BannerBox({required this.banner});

  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final err = banner.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: err ? Fixed.dangerBg : Fixed.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: err ? Fixed.dangerBorder : t.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: err ? Fixed.dangerText : t.up,
                shape: BoxShape.circle,
              ),
              child: SvgIcon(
                err ? Ico.alert : Ico.check,
                size: 12,
                color: Fixed.white,
                stroke: 3.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: inter(
                      14,
                      weight: FontWeight.w700,
                      color: err ? Fixed.dangerTitle : t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(banner.body, style: inter(13, color: t.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
