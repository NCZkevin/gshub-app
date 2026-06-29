import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/connection/presentation/connection_provider.dart';
import '../features/connection/presentation/connection_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/navigation/presentation/navigation_screen.dart';
import '../features/mapping/presentation/mapping_screen.dart';
import '../features/logs/presentation/logs_screen.dart';
import '../features/remote/presentation/remote_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'adaptive_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final connectionState = ref.watch(connectionProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final hasConnection = connectionState.activeId != null;
      final onConnection = state.matchedLocation == '/connection';

      // Redirect to connection screen only if no active connection
      // and not already there. Always allow visiting /connection.
      if (!hasConnection && !onConnection) return '/connection';
      return null;
    },
    routes: [
      GoRoute(
        path: '/connection',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: '/remote',
        builder: (context, state) => const RemoteScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdaptiveShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/navigation',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NavigationScreen()),
          ),
          GoRoute(
            path: '/mapping',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MappingScreen()),
          ),
          GoRoute(
            path: '/logs',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LogsScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
