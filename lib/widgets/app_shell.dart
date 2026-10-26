import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'status_view.dart';

class _Dest {
  const _Dest(this.label, this.path, this.icon, this.selectedIcon);
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Dest('Home', '/', Icons.home_outlined, Icons.home),
  _Dest('Tasks & Events', '/calendar', Icons.calendar_month_outlined,
      Icons.calendar_month),
  _Dest('Quests', '/quests', Icons.local_fire_department_outlined,
      Icons.local_fire_department),
];

/// Sidebar on wide screens, bottom bar on narrow ones. Also renders the
/// cloud error banner and the account footer.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.auth,
  });

  final String location;
  final Widget child;
  final AuthService? auth;

  static const double wideBreakpoint = 860;

  int get _index {
    if (location.startsWith('/calendar')) return 1;
    if (location.startsWith('/quests')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final banner = _errorBanner(context);
    if (wide) {
      return Scaffold(
        body: Column(
          children: [
            if (banner != null) banner,
            Expanded(
              child: Row(
                children: [
                  _Sidebar(index: _index, auth: auth),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (banner != null) banner,
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }

  /// A failed save/delete surfaces here until dismissed.
  Widget? _errorBanner(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    final state = scope?.notifier;
    if (state?.errorMessage == null) return null;
    return ErrorBanner(
      message: state!.errorMessage!,
      onDismiss: state.clearError,
    );
  }
}

/// Three small squares in the item colours: task, event, quest.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    Widget sq(Color c) => Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      sq(QfColors.madder),
      const SizedBox(width: 3),
      sq(QfColors.woad),
      const SizedBox(width: 3),
      sq(QfColors.moss),
    ]);
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, this.auth});
  final int index;
  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    final signedIn = auth != null && auth!.isSignedIn;

    return Container(
      width: 248,
      color: QfColors.bistre,
      padding: const EdgeInsets.fromLTRB(0, 32, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Mark(),
                const SizedBox(height: 10),
                Text('QuestFlow',
                    style: QfTheme.display(26, color: QfColors.pith)),
              ],
            ),
          ),
          const SizedBox(height: 36),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(
              dest: _destinations[i],
              selected: i == index,
              onTap: () => context.go(_destinations[i].path),
            ),
          const Spacer(),
          if (signedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth!.email ?? 'Signed in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: QfColors.lichenDim, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => auth!.signOut(),
                    icon: const Icon(Icons.logout,
                        size: 16, color: QfColors.lichenDim),
                    label: const Text('Sign out',
                        style: TextStyle(
                            color: QfColors.lichenDim, fontSize: 13)),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Showing sample data',
                style: TextStyle(color: QfColors.lichenDim, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(
      {required this.dest, required this.selected, required this.onTap});

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? QfColors.pith : QfColors.lichenDim;
    return Semantics(
      button: true,
      selected: selected,
      label: dest.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 21, right: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: selected ? QfColors.gamboge : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(selected ? dest.selectedIcon : dest.icon,
                  color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  dest.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),            ],
          ),
        ),
      ),
    );
  }
}
