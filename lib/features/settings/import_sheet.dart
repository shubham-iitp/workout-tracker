import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../data/csv_backup_service.dart';

/// Shows what a valid file contains. Resolves to true for "Replace with this
/// file".
Future<bool> showImportSheet(
  BuildContext context,
  ImportPreview preview,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final t = context.tokens;
      final d = preview.data;

      Widget line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: t.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          ],
        ),
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Import this file?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.ground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: t.ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        preview.fileName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      fmtBytes(preview.sizeBytes),
                      style: TextStyle(color: t.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              line(
                Icons.calendar_view_week_outlined,
                '${d.dayCount} ${d.dayCount == 1 ? 'day' : 'days'}',
              ),
              line(
                Icons.fitness_center,
                '${d.exerciseCount} ${d.exerciseCount == 1 ? 'exercise' : 'exercises'}, '
                '${d.setCount} ${d.setCount == 1 ? 'set' : 'sets'}',
              ),
              line(
                Icons.self_improvement,
                '${d.warmupCount} warm-up + ${d.cooldownCount} cool-down '
                '${d.warmupCount + d.cooldownCount == 1 ? 'item' : 'items'}',
              ),
              line(
                Icons.history,
                '${d.sessionCount} ${d.sessionCount == 1 ? 'workout' : 'workouts'} in history',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'This replaces your current plan and history. '
                  'Export first if you want to keep them.',
                  style: TextStyle(
                    color: t.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace with this file'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
