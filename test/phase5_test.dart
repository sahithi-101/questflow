import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questflow/app.dart';
import 'package:questflow/data/memory_repositories.dart';
import 'package:questflow/data/repositories.dart';
import 'package:questflow/models/time_log.dart';
import 'package:questflow/state/app_scope.dart';
import 'package:questflow/state/app_state.dart';
import 'package:questflow/util/dates.dart';

// Monday 26 Oct 2026, 09:00
final _now = DateTime(2026, 10, 26, 9);
final _today = dateOnly(_now);

DateTime at(int dayOffset, int hour, [int minute = 0]) {
  final d = addDays(_today, dayOffset);
  return DateTime(d.year, d.month, d.day, hour, minute);
}

TimeLog log(String id, String title, DateTime start, DateTime end) =>
    TimeLog(id: id, title: title, startedAt: start, endedAt: end);

/// Repository whose writes always fail, for testing error paths.
class _FailingTimeLogRepository implements TimeLogRepository {
  @override
  Future<List<TimeLog>> list() async => [];

  @override
  Future<TimeLog> create(TimeLog log) async =>
      throw Exception('network down');

  @override
  Future<void> update(TimeLog log) async {}

  @override
  Future<void> delete(String id) async {}
}

Future<void> _pump(WidgetTester t, {Size size = const Size(1280, 900)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(QuestFlowApp(
    now: _now,
    cloud: false,
    clock: () => _now, // stopwatch runs on the injected clock in tests
  ));
  await t.pumpAndSettle();
}

void main() {
  group('Focus timer session', () {
    test('start, pause and resume accumulate only running time', () {
      final state = AppState.demo(now: _now);
      expect(state.timerRunning, isFalse);

      state.startTimer(at: _now);
      expect(state.timerRunning, isTrue);
      expect(state.timerPaused, isFalse);
      expect(state.timerElapsed(at: _now.add(const Duration(minutes: 10))),
          const Duration(minutes: 10));

      state.pauseTimer(at: _now.add(const Duration(minutes: 12)));
      expect(state.timerPaused, isTrue);
      // Frozen while paused, even hours later.
      expect(state.timerElapsed(at: _now.add(const Duration(hours: 2))),
          const Duration(minutes: 12));

      state.resumeTimer(at: _now.add(const Duration(minutes: 30)));
      expect(state.timerPaused, isFalse);
      expect(state.timerElapsed(at: _now.add(const Duration(minutes: 40))),
          const Duration(minutes: 22));
    });

    test('starting twice does not reset the session', () {
      final state = AppState.demo(now: _now);
      state.startTimer(at: _now);
      state.startTimer(at: _now.add(const Duration(minutes: 5)));
      expect(
        state.timerElapsed(at: _now.add(const Duration(minutes: 10))),
        const Duration(minutes: 10),
      );
    });

    test('ending a running session saves a named log with exact times',
        () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final before = state.timeLogs.length;

      state.startTimer(at: at(0, 10));
      final error = await state.endTimer('Revise Flutter',
          at: at(0, 10, 45));

      expect(error, isNull);
      expect(state.timerRunning, isFalse);
      expect(state.timeLogs.length, before + 1);
      final saved = state.timeLogs.last;
      expect(saved.title, 'Revise Flutter');
      expect(saved.startedAt, at(0, 10));
      expect(saved.endedAt, at(0, 10, 45));
      expect(saved.duration, const Duration(minutes: 45));
    });

    test('ending a paused session ends the log at the pause moment',
        () async {
      final state = AppState.demo(now: _now);
      await state.load();

      state.startTimer(at: at(0, 10));
      state.pauseTimer(at: at(0, 10, 25));
      // The user comes back much later and ends it while still paused.
      await state.endTimer('Broken into chunks', at: at(0, 12));

      final saved = state.timeLogs.last;
      expect(saved.startedAt, at(0, 10));
      expect(saved.endedAt, at(0, 10, 25));
      expect(saved.duration, const Duration(minutes: 25));
    });

    test('ending with no running session reports an error and saves nothing',
        () async {
      final state = AppState.demo(now: _now);
      await state.load();
      final before = state.timeLogs.length;

      final error = await state.endTimer('Nothing', at: _now);

      expect(error, isNotNull);
      expect(state.timeLogs.length, before);
    });

    test('a failed save keeps the session running so time is not lost',
        () async {
      final state = AppState(
        now: _now,
        repos: RepositoryBundle(
          tasks: MemoryTaskRepository([]),
          events: MemoryEventRepository([]),
          quests: MemoryQuestRepository([]),
          timeLogs: _FailingTimeLogRepository(),
        ),
      );
      await state.load();

      state.startTimer(at: _now);
      final error = await state.endTimer('Lost?',
          at: _now.add(const Duration(minutes: 5)));

      expect(error, isNotNull);
      expect(state.timerRunning, isTrue);
      // Still accumulating — the user can retry the save.
      expect(state.timerElapsed(at: _now.add(const Duration(minutes: 7))),
          const Duration(minutes: 7));
    });
  });

  group('Time logs', () {
    test('demo data loads two sample logs', () async {
      final state = AppState.demo(now: _now);
      await state.load();
      expect(state.timeLogs.length, 2);
      expect(state.timeLogById('l1')?.title, 'Morning study session');
    });

    test('addTimeLog stores and deleteTimeLog removes', () async {
      final state = AppState.demo(now: _now);
      await state.load();

      await state.addTimeLog(
          log('x1', 'Extra session', at(0, 5), at(0, 5, 30)));
      expect(state.timeLogById('x1'), isNotNull);

      await state.deleteTimeLog('x1');
      expect(state.timeLogById('x1'), isNull);
    });

    test('time logs go 30 days after their day, timestamps aside', () async {
      final state = AppState.demo(now: _now);
      await state.load();

      // Ended 31 days ago: past the buffer, removed.
      final old = log('l-old', 'Old session', at(-31, 8), at(-31, 9, 30));
      // Ended on the 30th-days-ago day at 23:59: kept — the time of day
      // never matters, only the calendar day.
      final edge = log('l-edge', 'Edge session', at(-30, 23), at(-30, 23, 59));
      // Ended 29 days ago: inside the buffer.
      final recent = log('l-recent', 'Recent session', at(-29, 8), at(-29, 9));
      await state.addTimeLog(old);
      await state.addTimeLog(edge);
      await state.addTimeLog(recent);

      await state.purgeExpired(at: _now);

      expect(state.timeLogById('l-old'), isNull);
      expect(state.timeLogById('l-edge'), isNotNull);
      expect(state.timeLogById('l-recent'), isNotNull);
    });

    test('a log is judged by the day it ended, not when it started',
        () async {
      final state = AppState.demo(now: _now);
      await state.load();
      // Started 32 days ago but ended 31 days ago at one minute past
      // midnight: its day is 31 days ago, so it goes.
      final spansMidnight = log(
        'l-span',
        'Overnight session',
        at(-32, 23, 30),
        at(-31, 0, 1),
      );
      await state.addTimeLog(spansMidnight);

      await state.purgeExpired(at: _now);

      expect(state.timeLogById('l-span'), isNull);
    });
  });

  group('Timer screen', () {
    testWidgets('start, end, name the log and see it saved', (t) async {
      await _pump(t);
      await t.tap(find.text('Timer'));
      await t.pumpAndSettle();

      expect(find.text('Ready'), findsOneWidget);
      await t.tap(find.text('Start'));
      await t.pump();
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('End & log'), findsOneWidget);

      // Discarding keeps the session running.
      await t.tap(find.text('End & log'));
      await t.pumpAndSettle();
      expect(find.text('Name this log'), findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.text('End & log'), findsOneWidget);

      // Saving stores the log and returns the page to idle.
      await t.tap(find.text('End & log'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Revise Flutter');
      await t.pump(); // let the Save button enable before tapping it
      await t.tap(find.text('Save log'));
      await t.pumpAndSettle();
      expect(find.text('Revise Flutter'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('empty log name cannot be saved', (t) async {
      await _pump(t);
      await t.tap(find.text('Timer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Start'));
      await t.pump();
      await t.tap(find.text('End & log'));
      await t.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save log');
      expect(t.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets("today's logs show name, start–end time and duration",
        (t) async {
      await _pump(t);
      await t.tap(find.text('Timer'));
      await t.pumpAndSettle();
      expect(find.text('Morning study session'), findsOneWidget);
      expect(find.text('7:30 am – 9:00 am'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('Total 1h 30m'), findsOneWidget);
    });

    testWidgets('the log shows on the calendar agenda for its date and '
        'can be deleted from there', (t) async {
      await _pump(t);
      await t.tap(find.text('Tasks & Events'));
      await t.pumpAndSettle();

      expect(find.text('Morning study session'), findsOneWidget);
      expect(find.text('7:30 am – 9:00 am · 1h 30m'), findsOneWidget);

      await t.tap(find.text('Morning study session'));
      await t.pumpAndSettle();
      expect(find.text('Delete this log?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      expect(find.text('Morning study session'), findsNothing);
    });

    testWidgets('a log on another day shows under that day, not today',
        (t) async {
      await _pump(t);
      await t.tap(find.text('Tasks & Events'));
      await t.pumpAndSettle();

      // Yesterday holds the 'Library reading' sample log: select the 25th.
      await t.tap(find.text('25'));
      await t.pumpAndSettle();
      expect(find.text('Library reading'), findsOneWidget);
      expect(find.text('6:00 pm – 7:15 pm · 1h 15m'), findsOneWidget);
    });
  });
}
