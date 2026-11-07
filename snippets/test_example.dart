// Excerpt from test/phase5_test.dart
// One of 81 automated tests: the focus timer's pause/resume accumulation.
// The clock is injected, so the test is fully deterministic.

test('start, pause and resume accumulate only running time', () {
  final state = AppState.demo(now: _now);
  expect(state.timerRunning, isFalse);

  state.startTimer(at: _now);
  expect(state.timerRunning, isTrue);
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

test('ending a paused session ends the log at the pause moment', () async {
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
