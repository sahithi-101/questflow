import 'package:flutter/widgets.dart';

import 'app_state.dart';

export 'app_state.dart';

/// Gives widgets access to the [AppState]. Notifier-backed, so screens
/// rebuild whenever data changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this context');
    return scope!.notifier!;
  }
}
