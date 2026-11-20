import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import 'workout_actions.dart';
import 'workout_logic.dart';

/// "Quit workout?" — save what's done, discard, leave for later, or keep going.
Future<void> showQuitSheet(
  BuildContext context,
  WidgetRef ref,
  ActiveWorkout active,
  WorkoutProgress progress,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      final anyDone = progress.doneCount > 0;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quit workout?',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                anyDone
                    ? 'You\'ve done ${progress.doneCount} of ${progress.totalCount} '
                          '(${plural(progress.setsDone, 'set')}). Save what you did, '
                          'or throw this workout away.'
                    : 'Nothing is checked yet.',
                style: TextStyle(color: t.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: anyDone
                    ? () async {
                        Navigator.pop(sheetContext);
                        await saveWorkout(context, ref, active, progress);
                      }
                    : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save workout so far'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.go(Routes.workouts);
                },
                icon: const Icon(Icons.pause),
                label: const Text('Leave — resume later'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.danger,
                  side: BorderSide(color: t.danger),
                ),
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await discardWorkout(context, ref);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Discard workout'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Keep going'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
