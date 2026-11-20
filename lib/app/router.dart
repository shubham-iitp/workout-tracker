import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/history/history_screen.dart';
import '../features/plan/day_editor_screen.dart';
import '../features/plan/workouts_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/workout/active_workout_screen.dart';
import '../features/workout/complete_screen.dart';

abstract final class Routes {
  static const workouts = '/workouts';
  static const history = '/history';
  static const settings = '/settings';
  static const workout = '/workout';
  static const complete = '/workout/complete';
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/day/:id',
      builder: (_, state) =>
          DayEditorScreen(dayId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: Routes.workout,
      builder: (_, _) => const ActiveWorkoutScreen(),
      routes: [
        GoRoute(path: 'complete', builder: (_, _) => const CompleteScreen()),
      ],
    ),
  ],
);

class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
