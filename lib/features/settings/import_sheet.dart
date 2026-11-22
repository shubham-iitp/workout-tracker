import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../data/csv_backup_service.dart';
import '../../widgets/ui.dart';

/// "Import this file?" — what a valid file contains. Resolves to true for
/// "Replace with this file".
Future<bool> showImportSheet(
  BuildContext context,
  ImportPreview preview,
) async {
  final d = preview.data;
  final found = [
    ('Days in split', '${d.dayCount}'),
    ('Exercises', '${d.exerciseCount} (${d.setCount} sets)'),
    ('Warm-up / cool-down items', '${d.warmupCount + d.cooldownCount}'),
    ('Workouts in history', '${d.sessionCount}'),
    if (d.paletteCount > 0) ('Saved palettes', '${d.paletteCount}'),
  ];

  final result = await showDesignSheet<bool>(
    context,
    builder: (sheet) {
      final t = sheet.tokens;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Import this file?', style: grotesk(22, color: t.ink)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.ground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.dark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'CSV',
                    style: inter(
                      10,
                      weight: FontWeight.w700,
                      color: Fixed.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.fileName,
                        style: inter(15, weight: FontWeight.w600, color: t.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fmtBytes(preview.sizeBytes),
                        style: inter(13, color: t.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.divider)),
            ),
            child: Column(
              children: [
                for (final (label, value) in found)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t.divider)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label, style: inter(14, color: t.muted)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          value,
                          style: inter(
                            14,
                            weight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This replaces your current plan, history and saved palettes. '
            'Export first if you want to keep a copy.',
            style: inter(13, color: Fixed.dangerTitle),
          ),
          const SizedBox(height: 12),
          Btn(
            onTap: () => Navigator.pop(sheet, true),
            height: 52,
            color: t.dark,
            child: Text(
              'Replace with this file',
              style: inter(15, weight: FontWeight.w700, color: Fixed.white),
            ),
          ),
          const SizedBox(height: 12),
          Btn(
            onTap: () => Navigator.pop(sheet, false),
            height: 48,
            child: Text(
              'Cancel',
              style: inter(15, weight: FontWeight.w600, color: t.ink),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
