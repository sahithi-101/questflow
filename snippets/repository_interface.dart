// Excerpt from lib/data/repositories.dart
// The UI and AppState depend only on these interfaces, so the storage
// backend (in-memory demo or Supabase cloud) can be swapped without
// touching a single screen.

abstract class TaskRepository {
  Future<List<Task>> list();

  /// Inserts the task and returns the stored row (with its real id).
  Future<Task> create(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
}

/// The set of repositories the app runs against.
class RepositoryBundle {
  const RepositoryBundle({
    required this.tasks,
    required this.events,
    required this.quests,
    required this.timeLogs,
  });

  final TaskRepository tasks;
  final EventRepository events;
  final QuestRepository quests;
  final TimeLogRepository timeLogs;
}
