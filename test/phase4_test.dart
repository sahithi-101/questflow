import 'package:flutter_test/flutter_test.dart';
import 'package:questflow/data/memory_repositories.dart';
import 'package:questflow/data/repositories.dart';
import 'package:questflow/data/supabase_repositories.dart';
import 'package:questflow/models/event.dart';
import 'package:questflow/models/quest.dart';
import 'package:questflow/models/task.dart';
import 'package:questflow/state/app_state.dart';
import 'package:questflow/util/dates.dart';

final _now = DateTime(2026, 10, 26, 9);
final _today = dateOnly(_now);

void main() {
  group('Supabase row mapping', () {
    test('task row maps to a Task with local timestamps', () {
      final t = SupabaseTaskRepository.fromRow({
        'id': '11111111-1111-1111-1111-111111111111',
        'title': 'Pay fee',
        'description': 'hostel',
        'category': 'admin',
        'deadline_at': '2026-10-27T06:00:00+00:00',
        'priority': 'high',
        'status': 'pending',
        'created_at': '2026-10-01T06:00:00+00:00',
        'updated_at': '2026-10-02T06:00:00+00:00',
        'completed_at': null,
      });
      expect(t.title, 'Pay fee');
      expect(t.priority, TaskPriority.high);
      expect(t.isOverdue(DateTime.parse('2026-10-28T00:00:00+00:00')), isTrue);
      expect(t.completedAt, isNull);
    });

    test('event row handles nulls and reminder offsets', () {
      final e = SupabaseEventRepository.fromRow({
        'id': 'e',
        'title': 'Seminar',
        'description': '',
        'starts_at': '2026-10-27T10:00:00+00:00',
        'ends_at': null,
        'location': null,
        'reminder_offsets': [0, 10, 60],
        'created_at': '2026-10-01T06:00:00+00:00',
        'updated_at': '2026-10-01T06:00:00+00:00',
      });
      expect(e.end, isNull);
      expect(e.location, isNull);
      expect(e.reminderOffsets, [0, 10, 60]);
    });

    test('quest row maps mode, targets and daily records', () {
      final q = SupabaseQuestRepository.fromRow({
        'id': 'q',
        'title': 'Read',
        'description': '',
        'tracking_mode': 'numeric',
        'unit': 'pages',
        'daily_target': '20', // numeric columns can arrive as strings
        'upper_limit': '60',
        'starts_on': '2026-10-01',
        'ends_on': '2026-10-31',
        'archived_at': null,
        'created_at': '2026-10-01T06:00:00+00:00',
        'updated_at': '2026-10-01T06:00:00+00:00',
      }, [
        {
          'quest_id': 'q',
          'record_date': '2026-10-02',
          'recorded_value': '12',
          'binary_completed': false,
        },
        {
          'quest_id': 'q',
          'record_date': '2026-10-03',
          'recorded_value': '20',
          'binary_completed': true,
        },
      ]);
      expect(q.isNumeric, isTrue);
      expect(q.dailyTarget, 20);
      expect(q.upperLimit, 60);
      expect(q.startsOn, DateTime(2026, 10, 1));
      expect(q.valueOn(DateTime(2026, 10, 2)), 12);
      expect(q.valueOn(DateTime(2026, 10, 3)), 20);
      expect(q.isSuccess(DateTime(2026, 10, 3)), isTrue);
      expect(q.isSuccess(DateTime(2026, 10, 2)), isFalse);
    });

    test('binary quest records come from binary_completed', () {
      final q = SupabaseQuestRepository.fromRow({
        'id': 'q',
        'title': 'Lights out',
        'tracking_mode': 'binary',
        'daily_target': '1',
        'upper_limit': null,
        'starts_on': '2026-10-01',
        'ends_on': '2026-10-31',
      }, [
        {
          'quest_id': 'q',
          'record_date': '2026-10-02',
          'recorded_value': '1',
          'binary_completed': true,
        },
      ]);
      expect(q.valueOn(DateTime(2026, 10, 2)), 1);
      expect(q.isSuccess(DateTime(2026, 10, 2)), isTrue);
      expect(q.stateOn(DateTime(2026, 10, 2), _now), DayState.target);
    });

    test('date values round-trip without timezone shifts', () {
      final d = DateTime(2026, 3, 5);
      // Direct check of the date handling through a quest row.
      final q = SupabaseQuestRepository.fromRow({
        'id': 'q',
        'title': 'x',
        'tracking_mode': 'binary',
        'daily_target': '1',
        'starts_on': '2026-03-05',
        'ends_on': '2026-03-05',
      }, const []);
      expect(q.startsOn, d);
      expect(q.endsOn, d);
      expect(q.isEligible(d), isTrue);
    });
  });

  group('AppState over repositories', () {
    test('task CRUD flows through the repository bundle', () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final before = state.tasks.length;

      final task = Task(
          id: 'new-1',
          title: 'Write tests',
          deadline: DateTime(2026, 10, 30, 18));
      expect(await state.addTask(task), isTrue);
      expect(state.tasks.length, before + 1);

      expect(
        await state.updateTask(task.copyWith(
            title: 'Write more tests', updatedAt: DateTime.now())),
        isTrue,
      );
      expect(state.tasks.firstWhere((t) => t.id == 'new-1').title,
          'Write more tests');

      expect(await state.deleteTask('new-1'), isTrue);
      expect(state.tasks.length, before);
    });

    test('setDayValue upserts one record per date and validates', () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final quest = state.quests
          .firstWhere((q) => q.isNumeric && q.upperLimit != null);

      // write, replace, clear — still a single record for the date
      expect(await state.setDayValue(quest, _today, 5), isNull);
      var updated = state.questById(quest.id)!;
      expect(updated.valueOn(_today), 5);

      expect(await state.setDayValue(quest, _today, 7), isNull);
      updated = state.questById(quest.id)!;
      expect(updated.valueOn(_today), 7);
      expect(updated.records.length, quest.records.length);

      expect(await state.setDayValue(quest, _today, null), isNull);
      updated = state.questById(quest.id)!;
      expect(updated.records.containsKey(_today), isFalse);

      // validation: future and over-limit rejected without changes
      expect(
        await state.setDayValue(quest, addDays(_today, 1), 1),
        isNotNull,
      );
      expect(
        await state.setDayValue(quest, _today, quest.upperLimit! + 1),
        isNotNull,
      );
      expect(state.questById(quest.id)!.records.containsKey(_today), isFalse);
    });

    test('repository interfaces stay swappable', () async {
      final RepositoryBundle bundle = RepositoryBundle(
        tasks: MemoryTaskRepository([]),
        events: MemoryEventRepository([]),
        quests: MemoryQuestRepository([]),
      );
      await bundle.tasks.create(Task(
          id: 'x', title: 'x', deadline: DateTime(2026, 11, 1)));
      expect((await bundle.tasks.list()).length, 1);
      await bundle.tasks.delete('x');
      expect((await bundle.tasks.list()), isEmpty);
    });
  });

  group('One-week retention sweep', () {
    Task completedAt(DateTime when) => Task(
          id: 't-${when.millisecondsSinceEpoch}',
          title: 'done task',
          deadline: when.subtract(const Duration(days: 1)),
          status: TaskStatus.completed,
          completedAt: when,
        );

    test('completed tasks go a week after completion, pending ones stay',
        () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final old = completedAt(addDays(_today, -8));
      final recent = completedAt(addDays(_today, -3));
      final pending = Task(
          id: 'pending-old',
          title: 'still open',
          deadline: addDays(_today, -30)); // overdue but not done
      await state.addTask(old);
      await state.addTask(recent);
      await state.addTask(pending);

      await state.purgeExpired(at: _now);

      expect(state.taskById(old.id), isNull);
      expect(state.taskById(recent.id), isNotNull);
      expect(state.taskById('pending-old'), isNotNull);
    });

    test('events go a week after they end; upcoming ones stay', () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final past = Event(
        id: 'e-old',
        title: 'old event',
        start: addDays(_today, -10),
        end: addDays(_today, -8).add(const Duration(hours: 1)),
      );
      final noEnd = Event(
          id: 'e-noend',
          title: 'old no-end',
          start: DateTime(_today.year, _today.month, _today.day - 9, 10));
      final upcoming = Event(
          id: 'e-future',
          title: 'future event',
          start: addDays(_today, 2));
      await state.addEvent(past);
      await state.addEvent(noEnd);
      await state.addEvent(upcoming);

      await state.purgeExpired(at: _now);

      expect(state.eventById('e-old'), isNull);
      expect(state.eventById('e-noend'), isNull);
      expect(state.eventById('e-future'), isNotNull);
    });

    test('quests go a week after their end date, records included', () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final ended = Quest(
        id: 'q-ended',
        title: 'ended quest',
        mode: TrackingMode.binary,
        startsOn: addDays(_today, -20),
        endsOn: addDays(_today, -8),
        records: {addDays(_today, -10): 1},
      );
      final active = Quest(
        id: 'q-active',
        title: 'active quest',
        mode: TrackingMode.binary,
        startsOn: addDays(_today, -5),
        endsOn: addDays(_today, 5),
        records: {addDays(_today, -1): 1},
      );
      await state.addQuest(ended);
      await state.addQuest(active);

      await state.purgeExpired(at: _now);

      expect(state.questById('q-ended'), isNull);
      expect(state.questById('q-active'), isNotNull);
    });

    test('load() itself runs the sweep', () async {
      final oldTask = completedAt(addDays(_today, -30));
      final state = AppState(
        now: _now,
        repos: RepositoryBundle(
          tasks: MemoryTaskRepository([oldTask]),
          events: MemoryEventRepository([]),
          quests: MemoryQuestRepository([]),
        ),
      );
      await state.load();
      expect(state.taskById(oldTask.id), isNull);
    });
  });
}
