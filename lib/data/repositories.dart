import '../models/event.dart';
import '../models/quest.dart';
import '../models/task.dart';

/// Data-layer interfaces. The UI and [AppState] talk to these only, so the
/// storage backend (in-memory demo or Supabase cloud) can be swapped without
/// touching screens (spec 6.1).

abstract class TaskRepository {
  Future<List<Task>> list();

  /// Inserts the task and returns the stored row (with its real id).
  Future<Task> create(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
}

abstract class EventRepository {
  Future<List<Event>> list();

  /// Inserts the event and returns the stored row (with its real id).
  Future<Event> create(Event event);
  Future<void> update(Event event);
  Future<void> delete(String id);
}

abstract class QuestRepository {
  Future<List<Quest>> list();

  /// Inserts the quest and returns the stored row (with its real id).
  Future<Quest> create(Quest quest);
  Future<void> update(Quest quest);
  Future<void> delete(String id);

  /// Upserts one daily record. `value == null` clears the day.
  Future<void> setRecord(String questId, DateTime date, double? value);
}

/// The set of repositories the app runs against.
class RepositoryBundle {
  const RepositoryBundle({
    required this.tasks,
    required this.events,
    required this.quests,
  });

  final TaskRepository tasks;
  final EventRepository events;
  final QuestRepository quests;
}
