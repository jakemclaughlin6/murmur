import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/library/library_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tts/spike/spike_page.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/library',
    // Redirect unknown URIs to /library. Android VIEW/SEND intents push
    // content:// or file:// URIs into Flutter's route information channel;
    // GoRouter sees those as deep-link paths and fails with "no routes for
    // location". We handle share/open-in intents ourselves via
    // receive_sharing_intent (ShareIntentListener), so any URI that
    // doesn't match a known prefix is safely sent to /library.
    redirect: (context, state) {
      final loc = state.uri.path;
      if (loc.startsWith('/library') ||
          loc.startsWith('/reader') ||
          loc.startsWith('/settings') ||
          (kDebugMode && loc.startsWith('/_spike'))) {
        return null; // known route, no redirect
      }
      return '/library';
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MurmurShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, __) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reader',
                builder: (_, __) => const ReaderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Top-level /reader/:bookId — sibling to the StatefulShellRoute, NOT
      // a sub-route of the /reader shell branch. Opening an actual book
      // should hide the bottom nav (full-screen reader), which a shell
      // sub-route would not do. Plan 07's book cards will navigate via
      // `context.go('/reader/$bookId')`.
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          final bookId = int.parse(state.pathParameters['bookId']!);
          return ReaderScreen(bookId: bookId);
        },
      ),
      if (kDebugMode)
        GoRoute(
          path: '/_spike/tts',
          builder: (_, __) => const SpikePage(),
        ),
    ],
  );
}

class MurmurShellScaffold extends StatelessWidget {
  const MurmurShellScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Reader',
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
