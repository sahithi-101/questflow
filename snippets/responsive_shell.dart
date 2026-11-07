// Excerpt from lib/widgets/app_shell.dart
// Responsive shell: MediaQuery decides between a desktop sidebar and a
// mobile bottom navigation bar. The same child screen renders in both.

class AppShell extends StatelessWidget {
  static const double wideBreakpoint = 860;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(index: _index, auth: auth), // 248 px sidebar
            Expanded(child: child),              // the active screen
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: child),
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
}
