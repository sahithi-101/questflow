import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';
import 'config.dart';
import 'data/supabase_repositories.dart';
import 'router.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';

class QuestFlowApp extends StatefulWidget {
  const QuestFlowApp({super.key, this.now, this.cloud});

  /// Injectable clock for tests.
  final DateTime? now;

  /// Force demo (false) or cloud (true) mode. Defaults to auto-detecting:
  /// cloud mode runs when Supabase keys are configured *and* the Supabase
  /// SDK was initialised (which happens in main()).
  final bool? cloud;

  @override
  State<QuestFlowApp> createState() => _QuestFlowAppState();
}

class _QuestFlowAppState extends State<QuestFlowApp> {
  late final GoRouter _router;
  AuthService? _auth;
  AppState? _cloudState;
  String? _userId;
  AppState? _demoState;

  bool get _cloud => widget.cloud ?? _detectCloud();

  static bool _detectCloud() {
    if (!cloudConfigured) return false;
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      // Keys are configured but Supabase.initialize() never ran (tests).
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_cloud) {
      final client = Supabase.instance.client;
      _auth = AuthService(client);
      _auth!.addListener(_onAuthChanged);
      _router = buildRouter(cloudMode: true, auth: _auth);
    } else {
      _router = buildRouter();
    }  }

  /// Session restored or changed: swap the repository-backed state for the
  /// signed-in user (or drop it on sign-out).
  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null) return;
    if (auth.isSignedIn) {
      final uid = auth.user!.id;
      if (_userId != uid) {
        _cloudState?.dispose();
        _cloudState = AppState(
          now: DateTime.now(),
          repos: supabaseBundle(Supabase.instance.client),
        );
        _userId = uid;
        _cloudState!.load();
      }
    } else {
      _cloudState?.dispose();
      _cloudState = null;
      _userId = null;
      // Covers both the sidebar sign-out and an expired session.
      if (_router.routerDelegate.currentConfiguration.uri.path != '/auth') {
        _router.go('/auth');
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _cloudState?.dispose();
    _demoState?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cloud) {
      _demoState ??= AppState.demo(now: widget.now)..load();
      return AppScope(
        state: _demoState!,
        child: MaterialApp.router(
          title: 'QuestFlow',
          debugShowCheckedModeBanner: false,
          theme: QfTheme.light(),
          routerConfig: _router,
        ),
      );
    }

    final app = MaterialApp.router(
      title: 'QuestFlow',
      debugShowCheckedModeBanner: false,
      theme: QfTheme.light(),
      routerConfig: _router,
    );

    final state = _cloudState;
    if (state == null) {
      // Signed out: only /auth is reachable.
      return app;
    }
    return AppScope(state: state, child: app);
  }
}

/// Exported so main.dart can initialise Supabase before runApp.
Future<void> initialiseCloud() async {
  if (cloudConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
}
