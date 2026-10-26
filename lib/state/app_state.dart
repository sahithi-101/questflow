import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/memory_repositories.dart';
import '../data/repositories.dart';
import '../data/sample_data.dart';
import '../models/event.dart';
import '../models/quest.dart';
import '../models/task.dart';
import '../util/dates.dart';

enum LoadStatus { loading, ready, error }

/// Holds everything the UI shows and routes every change through the
/// repository interfaces. Screens never touch a storage backend directly.
class AppState extends ChangeNotifier {
  AppState({
    DateTime? now,
    required this.repos,
    this.isDemo = false,
  }) : now = now ?? DateTime.now() {
    status = LoadStatus.loading;
    // Re-check retention periodically during long sessions.
    _purgeTimer = Timer.periodic(const Duration(hours: 1), (_) {
      purgeExpired();
    });
  }

  /// Demo mode: in-memory repositories pre-seeded with sample data.
  factory AppState.demo({DateTime? now}) {
    final at = now ?? DateTime.now();
    final sample = SampleData.build(at);
    return AppState(
      now: at,
      isDemo: true,
      repos: RepositoryBundle(
        tasks: MemoryTaskRepository(sample.tasks),
        events: MemoryEventRepository(sample.events),
        quests: MemoryQuestRepository(sample.quests),
      ),
    );
  }

  final DateTime now;
  final RepositoryBundle repos;

  List<Task> _tasks = const [];
  List<Event> _events = const [];
  List<Quest> _quests = const [];

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Event> get events => List.unmodifiable(_events);
  List<Quest> get quests => List.unmodifiable(_quests);

  /// Cloud mode uses this while fetching; demo mode is ready immediately.
  LoadStatus status = LoadStatus.loading;
  String? errorMessage;

  /// How long finished items stay before the sweep removes them.
  static const Duration retentionPeriod = Duration(days: 7);

  Timer? _purgeTimer;

  /// Demo mode shows sample data; cloud mode shows the signed-in user's.
  final bool isDemo;

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  /// First load from the repository (no-op data-wise in demo mode).
  Future<void> load() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final tasks = List.of(await repos.tasks.list());
      final events = List.of(await repos.events.list());
      final quests = List.of(await repos.quests.list());
      _tasks = tasks;
      _events = events;
      _quests = quests;
      status = LoadStatus.ready;
      await purgeExpired(at: now);
    } catch (e) {
      status = LoadStatus.error;
      errorMessage = 'Could not load your data. ${_describe(e)}';
    }
    notifyListeners();
  }

  static String _describe(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  /// Retention sweep: removes finished items once the one-week buffer has
  /// passed (spec addition).
  ///
  ///  - completed tasks: one week after [Task.completedAt]
  ///  - events: one week after they end (or start, when no end time)
  ///  - quests: one week after [Quest.endsOn]; its daily records go too
  ///
  /// Pending tasks and active quests are never touched, and a failure on
  /// one item does not stop the rest.
  Future<void> purgeExpired({DateTime? at}) async {
    if (status != LoadStatus.ready) return;
    final ref = at ?? DateTime.now();
    final dtCutoff = ref.subtract(retentionPeriod);
    final dayCutoff = dateOnly(ref).subtract(const Duration(days: 7));

    // Completed tasks past their buffer.
    final taskIds = [
      for (final t in _tasks)
        if (t.isCompleted &&
            (t.completedAt ?? t.updatedAt).isBefore(dtCutoff))
          t.id,
    ];
    for (final id in taskIds) {
      try {
        await repos.tasks.delete(id);
      } catch (_) {
        continue; // keep the row; the next sweep retries
      }
    }
    if (taskIds.isNotEmpty) {
      _tasks = [
        for (final t in _tasks) if (!taskIds.contains(t.id)) t,
      ];
    }

    // Events a week past their last moment.
    final eventIds = [
      for (final e in _events)
        if ((e.end ?? e.start).isBefore(dtCutoff)) e.id,
    ];
    for (final id in eventIds) {
      try {
        await repos.events.delete(id);
      } catch (_) {
        continue;
      }
    }
    if (eventIds.isNotEmpty) {
      _events = [
        for (final e in _events) if (!eventIds.contains(e.id)) e,
      ];
    }

    // Quests whose range ended more than a week ago.
    final questIds = [
      for (final q in _quests) if (q.endsOn.isBefore(dayCutoff)) q.id,
    ];
    for (final id in questIds) {
      try {
        await repos.quests.delete(id);
      } catch (_) {
        continue;
      }
    }
    if (questIds.isNotEmpty) {
      _quests = [
        for (final q in _quests) if (!questIds.contains(q.id)) q,
      ];
    }

    if (taskIds.isNotEmpty || eventIds.isNotEmpty || questIds.isNotEmpty) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _purgeTimer?.cancel();
    super.dispose();
  }

  Task? taskById(String id) =>
      _tasks.cast<Task?>().firstWhere((t) => t!.id == id, orElse: () => null);
  Event? eventById(String id) =>
      _events.cast<Event?>().firstWhere((e) => e!.id == id, orElse: () => null);
  Quest? questById(String id) =>
      _quests.cast<Quest?>().firstWhere((q) => q!.id == id, orElse: () => null);

  // ---- Tasks ----------------------------------------------------------

  Future<bool> addTask(Task task) => _guard(() async {
        final saved = await repos.tasks.create(task);
        _tasks = [..._tasks, saved];
      });

  Future<bool> updateTask(Task task) => _guard(() async {
        await repos.tasks.update(task);
        _tasks = [
          for (final t in _tasks) t.id == task.id ? task : t,
        ];
      });

  Future<bool> deleteTask(String id) => _guard(() async {
        await repos.tasks.delete(id);
        _tasks = [for (final t in _tasks) if (t.id != id) t];
      });

  /// Complete or reopen a task, stamping/clearing completed_at.
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

  // ---- Events ---------------------------------------------------------

  Future<bool> addEvent(Event event) => _guard(() async {
        final saved = await repos.events.create(event);
        _events = [..._events, saved];
      });

  Future<bool> updateEvent(Event event) => _guard(() async {
        await repos.events.update(event);
        _events = [
          for (final e in _events) e.id == event.id ? event : e,
        ];
      });

  Future<bool> deleteEvent(String id) => _guard(() async {
        await repos.events.delete(id);
        _events = [for (final e in _events) if (e.id != id) e];
      });

  // ---- Quests ---------------------------------------------------------

  Future<bool> addQuest(Quest quest) => _guard(() async {
        final saved = await repos.quests.create(quest);
        _quests = [..._quests, saved];
      });

  Future<bool> updateQuest(Quest quest) => _guard(() async {
        await repos.quests.update(quest);
        _quests = [
          for (final q in _quests) q.id == quest.id ? quest : q,
        ];
      });

  Future<bool> deleteQuest(String id) => _guard(() async {
        await repos.quests.delete(id);
        _quests = [for (final q in _quests) if (q.id != id) q];
      });

  Future<bool> archiveQuest(Quest quest) => updateQuest(
      quest.copyWith(archivedAt: DateTime.now(), updatedAt: DateTime.now()));

  Future<bool> unarchiveQuest(Quest quest) =>
      updateQuest(quest.copyWith(clearArchivedAt: true, updatedAt: DateTime.now()));

  /// Writes one daily record after validating the spec's rules. Returns a
  /// user-facing error message and changes nothing when invalid.
  ///
  /// Rules (spec 4 and the section 11 defaults):
  ///  - future dates cannot be marked before their day
  ///  - numeric values below 0 or above the quest's upper limit are rejected,
  ///    never silently capped
  ///  - a day holds one record; writing again replaces it
  Future<String?> setDayValue(Quest quest, DateTime date, double? value) {
    final error = validateRecord(quest, date, value, now);
    if (error != null) return Future.value(error);
    return repos.quests.setRecord(quest.id, date, value).then((_) {
      final i = _quests.indexWhere((q) => q.id == quest.id);
      if (i != -1) {
        final d = dateOnly(date);
        final records = Map.of(_quests[i].records);
        if (value == null) {
          records.remove(d);
        } else {
          records[d] = value;
        }
        _quests[i] = _quests[i].copyWith(records: records);
      }
      notifyListeners();
      return null;
    }, onError: (Object e) => 'Could not save that day. ${_describe(e)}');
  }

  static String? validateRecord(
      Quest quest, DateTime date, double? value, DateTime now) {
    if (!quest.isEligible(date)) {
      return 'That date is outside this quest.';
    }
    if (dateOnly(date).isAfter(dateOnly(now))) {
      return "Future days can't be marked before their day.";
    }
    if (value == null) return null; // clearing a day is always allowed
    if (value < 0) return 'The value cannot be negative.';
    if (quest.isNumeric) {
      final limit = quest.upperLimit;
      if (limit != null && value > limit) {
        return 'Above the upper limit of ${_fmt(limit)} ${quest.unit}. '
            'Change the limit if you really did more.';
      }
    } else if (value != 0 && value != 1) {
      return 'Binary quests accept only done or not done.';
    }
    return null;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';

  // ---- plumbing -------------------------------------------------------

  /// Runs a mutation, surfacing failures as an error banner instead of
  /// silently losing the edit.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'That change did not save. ${_describe(e)}';
      notifyListeners();
      return false;
    }
  }
}
