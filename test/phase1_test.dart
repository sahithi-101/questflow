import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questflow/app.dart';
import 'package:questflow/models/quest.dart';
import 'package:questflow/models/quest_stats.dart';
import 'package:questflow/util/dates.dart';

// Monday 26 Oct 2026, 09:00
final _now = DateTime(2026, 10, 26, 9);

Future<void> _pump(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(QuestFlowApp(now: _now, cloud: false));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('wide: sidebar, three Home bars, navigation', (t) async {
    await _pump(t, const Size(1280, 900));
    expect(find.text('QuestFlow'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text("Today's quests"), findsOneWidget);

    await t.tap(find.text('Quests'));
    await t.pumpAndSettle();
    expect(find.text('New quest'), findsOneWidget);

    await t.tap(find.text('Tasks & Events'));
    await t.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('narrow: bottom navigation, Home bar opens filtered calendar',
      (t) async {
    await _pump(t, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);

    await t.tap(find.text('Tasks'));
    await t.pumpAndSettle();
    expect(find.text('Tasks only'), findsOneWidget);
  });

  test('QuestStats: streak ends today when today succeeded', () {
    final today = dateOnly(_now);
    final q = Quest(
      id: 'x',
      title: 'x',
      mode: TrackingMode.binary,
      startsOn: addDays(today, -10),
      endsOn: addDays(today, 10),
      records: {
        today: 1,
        addDays(today, -1): 1,
        addDays(today, -2): 1,
        addDays(today, -4): 1,
      },
    );
    expect(QuestStats.of(q, _now).currentStreak, 3);
  });

  test('QuestStats: open today keeps yesterday streak alive', () {
    final today = dateOnly(_now);
    final q = Quest(
      id: 'x',
      title: 'x',
      mode: TrackingMode.binary,
      startsOn: addDays(today, -10),
      endsOn: addDays(today, 10),
      records: {addDays(today, -1): 1, addDays(today, -2): 1},
    );
    expect(QuestStats.of(q, _now).currentStreak, 2);
  });

  test('Numeric day states follow the spec table', () {
    final today = dateOnly(_now);
    final q = Quest(
      id: 'n',
      title: 'n',
      mode: TrackingMode.numeric,
      unit: 'min',
      dailyTarget: 45,
      upperLimit: 120,
      startsOn: addDays(today, -5),
      endsOn: addDays(today, 5),
      records: {
        addDays(today, -1): 0,
        addDays(today, -2): 20,
        addDays(today, -3): 45,
        addDays(today, -4): 60,
      },
    );
    expect(q.stateOn(addDays(today, -1), today), DayState.none);
    expect(q.stateOn(addDays(today, -2), today), DayState.partial);
    expect(q.stateOn(addDays(today, -3), today), DayState.target);
    expect(q.stateOn(addDays(today, -4), today), DayState.over);
    expect(q.stateOn(addDays(today, 1), today), DayState.future);
    expect(q.stateOn(addDays(today, -9), today), DayState.outside);
  });
}
