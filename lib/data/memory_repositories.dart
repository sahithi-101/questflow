import '../models/event.dart';
import '../models/quest.dart';
import '../models/task.dart';
import '../util/dates.dart';
import 'repositories.dart';

/// In-memory repositories backing the demo mode (no Supabase configured).
/// Mutations write straight into the held lists.

class MemoryTaskRepository implements TaskRepository {
  MemoryTaskRepository(this._list);
  final List<Task> _list;

  @override
  Future<List<Task>> list() async => List.unmodifiable(_list);

  @override
  Future<Task> create(Task task) async {
    _list.add(task);
    return task;
  }

  @override
  Future<void> update(Task task) async => _replace(_list, task);

  @override
  Future<void> delete(String id) async => _list.removeWhere((t) => t.id == id);
}

class MemoryEventRepository implements EventRepository {
  MemoryEventRepository(this._list);
  final List<Event> _list;

  @override
  Future<List<Event>> list() async => List.unmodifiable(_list);

  @override
  Future<Event> create(Event event) async {
    _list.add(event);
    return event;
  }

  @override
  Future<void> update(Event event) async => _replace(_list, event);

  @override
  Future<void> delete(String id) async => _list.removeWhere((e) => e.id == id);
}

class MemoryQuestRepository implements QuestRepository {
  MemoryQuestRepository(this._list);
  final List<Quest> _list;

  @override
  Future<List<Quest>> list() async => List.unmodifiable(_list);

  @override
  Future<Quest> create(Quest quest) async {
    _list.add(quest);
    return quest;
  }

  @override
  Future<void> update(Quest quest) async => _replace(_list, quest);

  @override
  Future<void> delete(String id) async => _list.removeWhere((q) => q.id == id);

  @override
  Future<void> setRecord(String questId, DateTime date, double? value) async {
    final i = _list.indexWhere((q) => q.id == questId);
    if (i == -1) throw StateError('Quest $questId not found');
    final d = dateOnly(date);
    final records = Map.of(_list[i].records);
    if (value == null) {
      records.remove(d);
    } else {
      records[d] = value;
    }
    _list[i] = _list[i].copyWith(records: records, updatedAt: DateTime.now());
  }
}

void _replace<T extends Object>(List<T> list, T item) {
  String idOf(T t) => switch (t) {
        Task() => t.id,
        Event() => t.id,
        Quest() => t.id,
        _ => throw StateError('unexpected type'),
      };
  final i = list.indexWhere((t) => idOf(t) == idOf(item));
  if (i == -1) {
    list.add(item);
  } else {
    list[i] = item;
  }
}
