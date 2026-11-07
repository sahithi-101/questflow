// Excerpt from lib/state/app_state.dart
// Central state management: one ChangeNotifier holds every list the UI
// shows. Mutations flow through it and end in notifyListeners(), which
// rebuilds every listening widget.

class AppState extends ChangeNotifier {
  List<Task> _tasks = const [];
  List<Task> get tasks => List.unmodifiable(_tasks);

  // ---- Tasks ----------------------------------------------------------

  /// Adds a task. The repository returns the stored row (with its real
  /// database id), which the state keeps from then on.
  Future<bool> addTask(Task task) => _guard(() async {
        final saved = await repos.tasks.create(task);
        _tasks = [..._tasks, saved];
      });

  Future<bool> setTaskDone(Task task, bool done) {
    final updated = done
        ? task.copyWith(
            status: TaskStatus.completed,
            completedAt: DateTime.now(),
            updatedAt: DateTime.now())
        : task.copyWith(
            status: TaskStatus.pending,
            clearCompletedAt: true,
            updatedAt: DateTime.now());
    return updateTask(updated);
  }

  // ---- plumbing -------------------------------------------------------

  /// Runs a mutation, surfacing failures as an error banner instead of
  /// silently losing the edit.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      notifyListeners(); // <- every listening widget rebuilds here
      return true;
    } catch (e) {
      errorMessage = 'That change did not save. ${_describe(e)}';
      notifyListeners();
      return false;
    }
  }
}
