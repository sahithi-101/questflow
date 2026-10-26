import '../models/event.dart';
import '../models/quest.dart';
import '../models/task.dart';
import '../util/dates.dart';

/// Phase 2 seeds the in-memory repositories with this. Phase 4 swaps the
/// payload for Supabase-backed repositories without touching the screens.
class SampleData {
  SampleData._(this.now, this.tasks, this.events, this.quests);

  final DateTime now;
  final List<Task> tasks;
  final List<Event> events;
  final List<Quest> quests;

  factory SampleData.build(DateTime now) {
    final today = dateOnly(now);
    DateTime at(int dayOffset, int hour, [int minute = 0]) {
      final d = addDays(today, dayOffset);
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    final tasks = <Task>[
      Task(
        id: 't1',
        title: 'Pay hostel fee',
        deadline: at(-1, 12),
        priority: TaskPriority.high,
      ),
      Task(
        id: 't2',
        title: 'Print resume for placement drive',
        deadline: at(-3, 17),
      ),
      Task(
        id: 't3',
        title: 'DBMS unit 3 assignment',
        deadline: at(0, 23, 30),
        priority: TaskPriority.high,
      ),
      Task(
        id: 't4',
        title: 'Submit Flutter lab record',
        deadline: at(2, 17),
        priority: TaskPriority.high,
      ),
      Task(
        id: 't5',
        title: 'Revise OS scheduling notes',
        deadline: at(4, 20),
        priority: TaskPriority.low,
      ),
      Task(
        id: 't6',
        title: 'Book train tickets home',
        deadline: at(7, 10),
      ),
      Task(
        id: 't7',
        title: 'Email project guide the abstract',
        deadline: at(-1, 18),
        status: TaskStatus.completed,
        completedAt: at(-1, 19),
      ),
    ];

    final events = <Event>[
      Event(
        id: 'e1',
        title: 'Flutter lecture',
        start: at(0, 10),
        end: at(0, 11),
        location: 'Room 204',
      ),
      Event(
        id: 'e2',
        title: 'Hackathon kickoff',
        start: at(0, 16, 30),
        end: at(0, 17, 30),
        location: 'Seminar hall',
      ),
      Event(
        id: 'e3',
        title: 'Department seminar',
        start: at(1, 11),
        end: at(1, 12, 30),
        location: 'Auditorium',
      ),
      Event(id: 'e4', title: 'Engagement function', start: at(5, 19)),
      Event(
        id: 'e5',
        title: 'Lab viva',
        start: at(9, 14),
        location: 'CSE lab 2',
      ),
    ];

    final quests = <Quest>[
      _numeric('q1', 'Solve DSA problems', 'problems', 3, 10, today,
          seed: 1, todayValue: 3),
      _numeric('q2', 'Read a book', 'pages', 20, 60, today,
          seed: 2, todayValue: 12),
      _numeric('q3', 'Evening walk', 'min', 45, 120, today,
          seed: 3, todayValue: null),
      _binary('q4', 'Lights out by 11 pm', today, seed: 4, todayDone: false),
    ];

    return SampleData._(now, tasks, events, quests);
  }

  // Deterministic history: roughly 20% missed, 10% partial, 50% on target,
  // 20% over target. Only the pattern matters for the demo.
  static int _roll(int seed, int i) => (i * 7 + seed * 3) % 10;

  static Quest _numeric(String id, String title, String unit, double target,
      double limit, DateTime today,
      {required int seed, required double? todayValue}) {
    final records = <DateTime, double>{};
    for (var i = 1; i <= 44; i++) {
      final r = _roll(seed, i);
      final d = addDays(today, -i);
      if (r < 2) {
        continue;
      } else if (r < 3) {
        records[d] = (target * 0.5).roundToDouble();
      } else if (r < 8) {
        records[d] = target;
      } else {
        records[d] = (target * 1.5).roundToDouble().clamp(0.0, limit).toDouble();
      }
    }
    if (todayValue != null) records[today] = todayValue;
    return Quest(
      id: id,
      title: title,
      mode: TrackingMode.numeric,
      unit: unit,
      dailyTarget: target,
      upperLimit: limit,
      startsOn: addDays(today, -45),
      endsOn: addDays(today, 45),
      records: records,
    );
  }

  static Quest _binary(String id, String title, DateTime today,
      {required int seed, required bool todayDone}) {
    final records = <DateTime, double>{};
    for (var i = 1; i <= 44; i++) {
      if (_roll(seed, i) >= 2) records[addDays(today, -i)] = 1;
    }
    if (todayDone) records[today] = 1;
    return Quest(
      id: id,
      title: title,
      mode: TrackingMode.binary,
      startsOn: addDays(today, -45),
      endsOn: addDays(today, 45),
      records: records,
    );
  }
}
