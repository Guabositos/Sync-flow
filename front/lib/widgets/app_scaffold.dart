import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  // Route order mirrors tab order for consistency
  static const _routes = [
    '/dashboard',
    '/tasks',
    '/chat',
    '/notes',
    '/calendar',
    '/users',
  ];

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.check_circle_outline_rounded, // Tasks
    Icons.chat_bubble_outline_rounded,
    Icons.note_alt_outlined,
    Icons.calendar_month_rounded,
    Icons.group_outlined, // Users
  ];

  static const _labels = [
    'Home',
    'Tasks',
    'Chat',
    'Notes',
    'Calendar',
    'Users',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final location = GoRouterState.of(context).matchedLocation;

    final isManager = auth.isManager;

    // Visible tabs (indices into _routes/_icons/_labels)
    final tabs = <int>[
      0, // Home
      1, // Tasks
      2, // Chat
      3, // Notes
      4, // Calendar
      if (isManager) 5, // Users
    ];

    int currentIndex = tabs.indexWhere((i) => location.startsWith(_routes[i]));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(_routes[tabs[index]]),
        destinations: [
          for (final i in tabs)
            NavigationDestination(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
