import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quest_detail_screen.dart';
import 'screens/quests_screen.dart';
import 'widgets/app_shell.dart';

/// Routes:
///   /auth                     Sign in / sign up / password reset (cloud mode)
///   /                         Home
///   /calendar?filter=...      Tasks & Events (filter: tasks | events | overdue)
///   /calendar?add=task|event  open the add flow
///   /quests?add=1             open the add flow
///   /quests/:id               quest detail with full heatmap
///
/// The route table is static — auth gating happens in the builders, not in
/// a GoRouter redirect. A redirect driven by refreshListenable races with
/// the burst of onAuthStateChange events that follow email confirmation and
/// crashes go_router's matcher, so it is deliberately avoided here.
GoRouter buildRouter({bool cloudMode = false, AuthService? auth}) {
  Page<void> page(GoRouterState state, Widget child) =>
      NoTransitionPage<void>(key: state.pageKey, child: child);

  Widget shellBuilder(BuildContext context, GoRouterState state, Widget child) {
    if (cloudMode && auth != null && !auth.isSignedIn) {
      return AuthScreen(auth: auth);
    }
    return AppShell(auth: auth, location: state.uri.path, child: child);
  }

  return GoRouter(
    routes: [
      if (cloudMode && auth != null)
        GoRoute(
          path: '/auth',
          pageBuilder: (context, state) => page(
            state,
            auth.isSignedIn
                ? const _ContinueHome()
                : AuthScreen(auth: auth),
          ),
        ),
      ShellRoute(
        builder: shellBuilder,
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => page(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => page(
              state,
              CalendarScreen(
                filter: state.uri.queryParameters['filter'],
                add: state.uri.queryParameters['add'],
              ),
            ),
          ),
          GoRoute(
            path: '/quests',
            pageBuilder: (context, state) => page(
              state,
              QuestsScreen(openAdd: state.uri.queryParameters['add'] == '1'),
            ),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => page(
                  state,
                  QuestDetailScreen(questId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Landing on /auth while already signed in: hop straight home.
class _ContinueHome extends StatefulWidget {
  const _ContinueHome();

  @override
  State<_ContinueHome> createState() => _ContinueHomeState();
}

class _ContinueHomeState extends State<_ContinueHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
