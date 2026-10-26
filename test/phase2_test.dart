import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questflow/app.dart';
import 'package:questflow/state/app_scope.dart';
import 'package:questflow/util/dates.dart';

// Monday 26 Oct 2026, 09:00
final _now = DateTime(2026, 10, 26, 9);

Future<void> _pump(WidgetTester t, {Size size = const Size(1280, 900)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(QuestFlowApp(now: _now, cloud: false));
  await t.pumpAndSettle();
}

void main() {
  group('Task flows', () {
    testWidgets('empty task form shows validation errors', (t) async {
      await _pump(t);
      await t.tap(find.text('Tasks & Events'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Add a task or event'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Task'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Title is required.'), findsOneWidget);
      expect(find.text('A deadline is required.'), findsOneWidget);
    });

    testWidgets('agenda row opens detail; delete asks and confirms',
        (t) async {
      await _pump(t);
      await t.tap(find.text('Tasks & Events'));
      await t.pumpAndSettle();
      // The today-selected agenda shows the DBMS sample task.
      await t.tap(find.text('DBMS unit 3 assignment'));
      await t.pumpAndSettle();
      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.text('Delete this task?'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
      // Confirm inside the dialog.
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      expect(find.text('DBMS unit 3 assignment'), findsNothing);
    });

    testWidgets('detail can toggle complete and reopen', (t) async {
      await _pump(t);
      await t.tap(find.text('Tasks & Events'));
      await t.pumpAndSettle();
      await t.tap(find.text('DBMS unit 3 assignment'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mark done'));
      await t.pumpAndSettle();
      final state = AppScope.of(t.element(find.text('Tasks & Events').first));
      final task =
          state.tasks.firstWhere((task) => task.title == 'DBMS unit 3 assignment');
      expect(task.isCompleted, isTrue);
      expect(task.completedAt, isNotNull);
    });
  });

  group('Event flows', () {
    testWidgets('empty event form shows validation errors', (t) async {
      await _pump(t);
      await t.tap(find.text('Tasks & Events'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Add a task or event'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Event'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Title is required.'), findsOneWidget);
      expect(find.text('A start time is required.'), findsOneWidget);
    });
  });

  group('Quest flows', () {
    testWidgets('quest card opens the heatmap screen with stats', (t) async {
      await _pump(t);
      await t.tap(find.text('Quests'));
      await t.pumpAndSettle();
      await t.tap(find.text('Solve DSA problems'));
      await t.pumpAndSettle();
      expect(find.text('current streak'), findsOneWidget);
      expect(find.text('longest streak'), findsOneWidget);
      expect(find.text('completion rate'), findsOneWidget);
      expect(find.text('overload days'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('empty quest form shows validation errors', (t) async {
      await _pump(t);
      await t.tap(find.text('Quests'));
      await t.pumpAndSettle();
      await t.tap(find.text('New quest'));
      await t.pumpAndSettle();
      // Numeric mode: unit, target and limit are required too.
      await t.tap(find.text('Numeric'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Quest name is required.'), findsOneWidget);
      expect(find.text('Unit is required.'), findsOneWidget);
      expect(find.text('Both dates are required.'), findsOneWidget);
    });
  });

  group('Daily progress rules', () {
    testWidgets('future day cannot be marked', (t) async {
      await _pump(t);
      await t.tap(find.text('Quests'));
      await t.pumpAndSettle();
      await t.tap(find.text('Solve DSA problems'));
      await t.pumpAndSettle();
      // Tomorrow's cell inside the current month grid.
      final tomorrow = addDays(dateOnly(_now), 1);
      await t.tap(find.byTooltip(
          '${tomorrow.day} Oct: Upcoming'));
      await t.pumpAndSettle();
      expect(find.text("Future days can't be marked before their day."),
          findsNothing); // dialog shows its own message instead
      expect(find.textContaining('This day has not happened yet.'),
          findsOneWidget);
      expect(find.text('Mark done'), findsNothing);
      expect(find.text('Save'), findsNothing);
    });
  });
}
