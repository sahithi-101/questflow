import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questflow/data/memory_repositories.dart';
import 'package:questflow/models/quest.dart';
import 'package:questflow/models/quest_stats.dart';
import 'package:questflow/state/app_state.dart';
import 'package:questflow/theme/palette.dart';
import 'package:questflow/util/dates.dart';

// Monday 26 Oct 2026, 09:00 — the fixed clock for every test.
final _now = DateTime(2026, 10, 26, 9);
final _today = dateOnly(_now);

Quest _quest({
  TrackingMode mode = TrackingMode.binary,
  double target = 1,
  double? limit,
  required DateTime startsOn,
  required DateTime endsOn,
  Map<DateTime, double> records = const {},
  String unit = 'min',
}) {
  return Quest(
    id: 'q',
    title: 'q',
    mode: mode,
    unit: unit,
    dailyTarget: target,
    upperLimit: limit,
    startsOn: startsOn,
    endsOn: endsOn,
    records: records,
  );
}

Quest _binaryAroundToday({
  required int back,
  int forward = 5,
  Map<DateTime, double>? records,
}) =>
    _quest(
      startsOn: addDays(_today, -back),
      endsOn: addDays(_today, forward),
      records: records ?? const {},
    );

void main() {
  group('4.1 Binary quest states', () {
    test('grey when not completed, green when completed', () {
      final q = _binaryAroundToday(
        back: 3,
        records: {_today: 1},
      );
      expect(q.stateOn(_today, _now), DayState.target);
      expect(QfColors.heat(q.stateOn(_today, _now)), QfColors.moss);
      expect(q.stateOn(addDays(_today, -1), _now), DayState.none);
      expect(QfColors.heat(q.stateOn(addDays(_today, -1), _now)),
          QfColors.ash);
    });

    test('binary has no partial state — any positive value counts as done',
        () {
      final q = _binaryAroundToday(back: 3, records: {addDays(_today, -1): 1});
      expect(q.isSuccess(addDays(_today, -1)), isTrue);
      expect(q.stateOn(addDays(_today, -1), _now), DayState.target);
    });

    test('binary validateRecord rejects values other than 0 and 1', () {
      final q = _binaryAroundToday(back: 3);
      expect(AppState.validateRecord(q, _today, 0.5, _now), isNotNull);
      expect(AppState.validateRecord(q, _today, 2, _now), isNotNull);
      expect(AppState.validateRecord(q, _today, 0, _now), isNull);
      expect(AppState.validateRecord(q, _today, 1, _now), isNull);
      expect(AppState.validateRecord(q, _today, null, _now), isNull);
    });
  });

  group('4.2 Numeric quest states and colours', () {
    Quest numeric(Map<DateTime, double> records) => _quest(
          mode: TrackingMode.numeric,
          target: 45,
          limit: 120,
          startsOn: addDays(_today, -5),
          endsOn: addDays(_today, 5),
          records: records,
        );

    test('0 records = no progress (grey)', () {
      final q = numeric({addDays(_today, -1): 0});
      expect(q.stateOn(addDays(_today, -1), _now), DayState.none);
      expect(QfColors.heat(DayState.none), QfColors.ash);
    });

    test('below target = partial with green gradient scaled by ratio', () {
      final q = numeric({addDays(_today, -1): 22.5}); // half of 45
      expect(q.stateOn(addDays(_today, -1), _now), DayState.partial);
      // ratio 0.5 sits exactly between the two partial greens
      expect(
        QfColors.heat(DayState.partial, ratio: 0.5),
        Color.lerp(QfColors.partialLight, QfColors.partialDeep, 0.5),
      );
      expect(QfColors.heat(DayState.partial, ratio: 0),
          QfColors.partialLight);
      expect(QfColors.heat(DayState.partial, ratio: 1),
          QfColors.partialDeep);
    });

    test('exactly at target = full green and counts as success', () {
      final q = numeric({addDays(_today, -1): 45});
      expect(q.stateOn(addDays(_today, -1), _now), DayState.target);
      expect(q.isSuccess(addDays(_today, -1)), isTrue);
      expect(QfColors.heat(DayState.target), QfColors.moss);
    });

    test('above target up to the limit = overload purple, still success',
        () {
      final q = numeric({addDays(_today, -1): 46, addDays(_today, -2): 120});
      expect(q.stateOn(addDays(_today, -1), _now), DayState.over);
      expect(q.stateOn(addDays(_today, -2), _now), DayState.over);
      expect(q.isSuccess(addDays(_today, -1)), isTrue);
      expect(QfColors.heat(DayState.over), QfColors.mulberry);
    });

    test('partial progress never counts as a successful day', () {
      final q = numeric({addDays(_today, -1): 44.9});
      expect(q.isSuccess(addDays(_today, -1)), isFalse);
    });
  });

  group('4.2 / section 11 Upper-limit and record validation', () {
    final q = _quest(
      mode: TrackingMode.numeric,
      target: 45,
      limit: 120,
      startsOn: addDays(_today, -5),
      endsOn: addDays(_today, 5),
    );

    test('value above the upper limit is rejected, never capped', () {
      final message = AppState.validateRecord(q, _today, 120.5, _now);
      expect(message, isNotNull);
      expect(message, contains('upper limit'));
    });

    test('value exactly at the upper limit is accepted', () {
      expect(AppState.validateRecord(q, _today, 120, _now), isNull);
    });

    test('negative values are rejected', () {
      expect(AppState.validateRecord(q, _today, -1, _now), isNotNull);
    });

    test('clearing a day (null) is always allowed', () {
      expect(AppState.validateRecord(q, _today, null, _now), isNull);
    });

    test('future days cannot be marked before their day', () {
      expect(
        AppState.validateRecord(q, addDays(_today, 1), 45, _now),
        isNotNull,
      );
    });

    test('dates outside the active range are rejected', () {
      expect(
        AppState.validateRecord(q, addDays(_today, -6), 45, _now),
        isNotNull,
      );
      expect(
        AppState.validateRecord(q, addDays(_today, 6), 45, _now),
        isNotNull,
      );
    });

    test('past corrections are allowed', () {
      expect(
        AppState.validateRecord(q, addDays(_today, -5), 45, _now),
        isNull,
      );
    });
  });

  group('4.3 Eligibility and duration', () {
    test('start and end dates are inclusive', () {
      final q = _quest(startsOn: _today, endsOn: addDays(_today, 2));
      expect(q.isEligible(_today), isTrue);
      expect(q.isEligible(addDays(_today, 2)), isTrue);
      expect(q.isEligible(addDays(_today, -1)), isFalse);
      expect(q.isEligible(addDays(_today, 3)), isFalse);
    });

    test('every calendar day in the range is eligible (continuous)', () {
      final q = _quest(startsOn: _today, endsOn: addDays(_today, 10));
      for (var i = 0; i <= 10; i++) {
        expect(q.isEligible(addDays(_today, i)), isTrue, reason: 'day +$i');
      }
    });

    test('one record per date: writing again replaces, clearing removes',
        () async {
      final q = _quest(
        mode: TrackingMode.numeric,
        target: 10,
        limit: 20,
        startsOn: addDays(_today, -5),
        endsOn: addDays(_today, 5),
        records: {addDays(_today, -1): 5},
      );
      final repo = MemoryQuestRepository([q]);
      await repo.setRecord('q', addDays(_today, -1), 12);
      final afterWrite = (await repo.list()).single;
      expect(afterWrite.records[addDays(_today, -1)], 12);
      expect(afterWrite.records.length, 1);

      await repo.setRecord('q', addDays(_today, -1), null);
      final afterClear = (await repo.list()).single;
      expect(afterClear.records.containsKey(addDays(_today, -1)), isFalse);
    });
  });

  group('4.4 Current streak', () {
    test('ends today when today is successful', () {
      final q = _binaryAroundToday(back: 10, records: {
        _today: 1,
        addDays(_today, -1): 1,
        addDays(_today, -2): 1,
        addDays(_today, -4): 1,
      });
      expect(QuestStats.of(q, _now).currentStreak, 3);
    });

    test('stays alive ending yesterday while today is still incomplete', () {
      final q = _binaryAroundToday(back: 10, records: {
        addDays(_today, -1): 1,
        addDays(_today, -2): 1,
      });
      expect(QuestStats.of(q, _now).currentStreak, 2);
    });

    test('zero when today and yesterday are both incomplete', () {
      final q = _binaryAroundToday(back: 10, records: {
        addDays(_today, -2): 1,
        addDays(_today, -3): 1,
      });
      expect(QuestStats.of(q, _now).currentStreak, 0);
    });

    test('a miss breaks the run', () {
      final q = _binaryAroundToday(back: 10, records: {
        _today: 1,
        addDays(_today, -1): 0,
        addDays(_today, -2): 1,
      });
      expect(QuestStats.of(q, _now).currentStreak, 1);
    });

    test('a missing record on a past day breaks the run too', () {
      final q = _binaryAroundToday(back: 10, records: {
        _today: 1,
        addDays(_today, -2): 1, // yesterday simply has no record
      });
      expect(QuestStats.of(q, _now).currentStreak, 1);
    });

    test('counts back exactly to the quest start, not beyond', () {
      final q = _binaryAroundToday(back: 2, records: {
        _today: 1,
        addDays(_today, -1): 1,
        addDays(_today, -2): 1,
      });
      expect(QuestStats.of(q, _now).currentStreak, 3);
    });

    test('numeric: over-target days keep the streak alive', () {
      final q = _quest(
        mode: TrackingMode.numeric,
        target: 45,
        limit: 120,
        startsOn: addDays(_today, -3),
        endsOn: addDays(_today, 3),
        records: {
          _today: 60,
          addDays(_today, -1): 45,
          addDays(_today, -2): 120,
          addDays(_today, -3): 10,
        },
      );
      expect(QuestStats.of(q, _now).currentStreak, 3);
    });

    test('quest that ended before today: streak counts back from the end',
        () {
      final q = _quest(
        startsOn: addDays(_today, -6),
        endsOn: addDays(_today, -2),
        records: {
          addDays(_today, -2): 1,
          addDays(_today, -3): 1,
          addDays(_today, -4): 1,
          addDays(_today, -5): 0,
          addDays(_today, -6): 1,
        },
      );
      expect(QuestStats.of(q, _now).currentStreak, 3);
    });
  });

  group('4.4 Longest streak', () {
    test('longest past run beats the current run', () {
      final q = _binaryAroundToday(back: 10, records: {
        _today: 1,
        addDays(_today, -1): 1,
        // break
        addDays(_today, -4): 1,
        addDays(_today, -5): 1,
        addDays(_today, -6): 1,
        addDays(_today, -7): 1,
      });
      final s = QuestStats.of(q, _now);
      expect(s.currentStreak, 2);
      expect(s.longestStreak, 4);
    });

    test('single successful day gives longest streak 1', () {
      final q = _binaryAroundToday(back: 5, records: {addDays(_today, -3): 1});
      expect(QuestStats.of(q, _now).longestStreak, 1);
    });

    test('all days failed gives 0', () {
      final q = _binaryAroundToday(back: 5);
      expect(QuestStats.of(q, _now).longestStreak, 0);
    });

    test('every day successful equals the elapsed day count', () {
      final q = _binaryAroundToday(
        back: 4,
        records: {
          for (var i = -4; i <= 0; i++) addDays(_today, i): 1.0,
        },
      );
      final s = QuestStats.of(q, _now);
      expect(s.longestStreak, 5);
      expect(s.elapsedDays, 5);
    });

    test('run touching the quest start boundary', () {
      final q = _binaryAroundToday(back: 3, records: {
        _today: 0,
        addDays(_today, -1): 1,
        addDays(_today, -2): 1,
        addDays(_today, -3): 1, // first eligible day
      });
      expect(QuestStats.of(q, _now).longestStreak, 3);
    });
  });

  group('4.4 Completion rate', () {
    test('successful elapsed days divided by elapsed days', () {
      final q = _binaryAroundToday(back: 9, records: {
        for (var i = -9; i <= -4; i++) addDays(_today, i): 1.0,
      });
      final s = QuestStats.of(q, _now);
      expect(s.elapsedDays, 10);
      expect(s.successDays, 6);
      expect(s.completionRate, closeTo(0.6, 1e-9));
    });

    test('future days are excluded, not counted as failures', () {
      final q = _binaryAroundToday(
        back: 1,
        forward: 20,
        records: {_today: 1, addDays(_today, -1): 1},
      );
      final s = QuestStats.of(q, _now);
      expect(s.elapsedDays, 2); // not 22
      expect(s.completionRate, 1.0);
    });

    test('a missing record on a past eligible day counts as not completed',
        () {
      final q = _binaryAroundToday(
        back: 2,
        records: {_today: 1}, // yesterday has no record
      );
      final s = QuestStats.of(q, _now);
      expect(s.elapsedDays, 3);
      expect(s.successDays, 1);
      expect(s.completionRate, closeTo(1 / 3, 1e-9));
    });

    test('quest that has not started yet: zero everything', () {
      final q = _quest(startsOn: addDays(_today, 3), endsOn: addDays(_today, 9));
      final s = QuestStats.of(q, _now);
      expect(s.elapsedDays, 0);
      expect(s.successDays, 0);
      expect(s.completionRate, 0);
      expect(s.currentStreak, 0);
      expect(s.longestStreak, 0);
    });

    test('quest that ended before today: rate covers the whole range', () {
      final q = _quest(
        startsOn: addDays(_today, -4),
        endsOn: addDays(_today, -2),
        records: {
          addDays(_today, -2): 1,
          addDays(_today, -3): 1,
        },
      );
      final s = QuestStats.of(q, _now);
      expect(s.elapsedDays, 3);
      expect(s.completionRate, closeTo(2 / 3, 1e-9));
    });

    test('quest ending today: today counts as elapsed', () {
      final q = _binaryAroundToday(
        back: 1,
        forward: 0,
        records: {_today: 1, addDays(_today, -1): 0},
      );
      final s = QuestStats.of(q, _now);
      expect(s.elapsedDays, 2);
      expect(s.completionRate, 0.5);
    });
  });

  group('4.4 Overload days', () {
    test('counts elapsed days strictly above target', () {
      final q = _quest(
        mode: TrackingMode.numeric,
        target: 45,
        limit: 120,
        startsOn: addDays(_today, -3),
        endsOn: addDays(_today, 3),
        records: {
          _today: 46,
          addDays(_today, -1): 45, // at target, not overload
          addDays(_today, -2): 120, // at limit, still overload
          addDays(_today, -3): 20, // partial
        },
      );
      final s = QuestStats.of(q, _now);
      expect(s.overloadDays, 2);
    });

    test('future over-target entries are not counted', () {
      final q = _quest(
        mode: TrackingMode.numeric,
        target: 45,
        limit: 120,
        startsOn: addDays(_today, -1),
        endsOn: addDays(_today, 5),
        records: {
          _today: 50,
          addDays(_today, 1): 90, // future — cannot be marked yet anyway
        },
      );
      expect(QuestStats.of(q, _now).overloadDays, 1);
    });

    test('binary quests never have overload days', () {
      final q = _binaryAroundToday(back: 2, records: {
        _today: 1,
        addDays(_today, -1): 1,
      });
      expect(QuestStats.of(q, _now).overloadDays, 0);
    });
  });

  group('Future and outside days', () {
    test('future eligible days are future, never failures', () {
      final q = _binaryAroundToday(back: 2, forward: 5);
      expect(q.stateOn(addDays(_today, 1), _now), DayState.future);
      expect(q.stateOn(addDays(_today, 5), _now), DayState.future);
    });

    test('outside days are neither failures nor successes', () {
      final q = _binaryAroundToday(back: 2, forward: 5);
      expect(q.stateOn(addDays(_today, -3), _now), DayState.outside);
      expect(q.stateOn(addDays(_today, 6), _now), DayState.outside);
    });
  });
}

