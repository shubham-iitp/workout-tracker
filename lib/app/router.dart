import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/history/history_screen.dart';
import '../features/plan/day_editor_screen.dart';
import '../features/plan/workouts_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/workout/active_workout_screen.dart';
import '../widgets/ui.dart';
import 'theme.dart';

abstract final class Routes {
  static const workouts = '/workouts';
  static const history = '/history';
  static const settings = '/settings';
  static const workout = '/workout';
  static String day(int id) => '/day/$id';
}

final appRouter = GoRouter(
  initialLocation: Routes.workouts,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _TabScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.workouts,
              builder: (_, _) => const WorkoutsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.history,
              builder: (_, _) => const HistoryScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/day/:id',
      builder: (_, state) =>
          DayEditorScreen(dayId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: Routes.workout,
      builder: (_, _) => const ActiveWorkoutScreen(),
    ),
  ],
);

class _TabScaffold extends ConsumerWidget {
  const _TabScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget tab(int index, Ico icon, String label) {
      final selected = shell.currentIndex == index;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => shell.goBranch(index, initialLocation: selected),
            child: SizedBox(
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected ? t.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: SvgIcon(
                      icon,
                      size: 20,
                      color: selected ? t.ink : t.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: inter(
                      12,
                      weight: FontWeight.w600,
                      color: selected ? t.ink : t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Fixed.white,
          border: Border(top: BorderSide(color: t.line)),
        ),
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottom > 0 ? bottom : 18),
        child: Row(
          children: [
            tab(0, Ico.dumbbell, 'Workouts'),
            tab(1, Ico.clock, 'History'),
          ],
        ),
      ),
    );
  }
}
