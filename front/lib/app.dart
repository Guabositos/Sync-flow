import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_state.dart';
import 'widgets/app_scaffold.dart';

// Pages
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'dashboard/dashboard_page.dart';
import 'tasks/tasks_page.dart';
import 'chat/chat_page.dart';
import 'notes/notes_page.dart';
import 'calendar/calendar_page.dart';

import 'users/users_page.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final _routerRefresh = _GoRouterRefresh(ref);

  late final GoRouter _router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _routerRefresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggedIn = auth.isAuthenticated;

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup';

      // Auth gate
      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/dashboard';

      // Manager-only gate
      final managerOnly = loc.startsWith('/history') || loc.startsWith('/users');
      if (managerOnly && !auth.isManager) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),

      // Main shell: bottom navigation lives here
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksPage(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatPage(),
          ),
          GoRoute(
            path: '/notes',
            builder: (context, state) => const NotesPage(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarPage(),
          ),
          
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensures AuthController starts (token check + refresh loop)
    ref.watch(authControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: 'My App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
    );
  }
}

/// Refreshes GoRouter when auth state changes (no timers, minimal & correct).
class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh(this.ref) {
    // In newer Riverpod versions, ref.listen returns void.
    // We just trigger notifyListeners on every auth change.
    ref.listen<AuthState>(
      authControllerProvider,
      (prev, next) => notifyListeners(),
    );
  }

  final WidgetRef ref;

  @override
  void dispose() {
    super.dispose();
  }
}
