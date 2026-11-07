// Excerpt from lib/router.dart
// Navigation with go_router: a ShellRoute wraps every page in the shared
// app shell (sidebar / bottom bar), with a nested route for quest details
// and query parameters driving the add-item flows.

GoRouter buildRouter({bool cloudMode = false, AuthService? auth}) {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          auth: auth,
          location: state.uri.path,
          child: child,
        ),
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
                path: ':id', // nested: /quests/<id>
                pageBuilder: (context, state) => page(
                  state,
                  QuestDetailScreen(questId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/timer',
            pageBuilder: (context, state) => page(state, const TimerScreen()),
          ),
        ],
      ),
    ],
  );
}
