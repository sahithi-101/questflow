import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/event.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/dates.dart';
import '../widgets/add_chooser.dart';
import '../widgets/status_view.dart';
import '../widgets/summary_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context);
    if (data.status != LoadStatus.ready) {
      return const StatusView();
    }
    final now = data.now;
    final wide = MediaQuery.sizeOf(context).width >= 640;

    final pending = data.tasks.where((t) => !t.isCompleted).toList();
    final overdue = pending.where((t) => t.isOverdue(now)).toList();
    final dueToday = pending.where((t) => sameDay(t.deadline, now)).toList();
    final upcoming = pending.where((t) => !t.isOverdue(now)).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    final soonEvents = data.events
        .where((e) =>
            sameDay(e.start, now) || sameDay(e.start, addDays(now, 1)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final eventsToday = soonEvents.where((e) => sameDay(e.start, now)).length;

    final activeToday = data.quests.where((q) => q.isEligible(now)).toList();
    final doneToday = activeToday.where((q) => q.isSuccess(now)).length;
    final percent =
        activeToday.isEmpty ? 0 : (doneToday * 100 / activeToday.length).round();

    final pad = wide ? 40.0 : 20.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, wide ? 40 : 24, pad, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(weekdayLong(now),
                          style: Theme.of(context).textTheme.displaySmall),
                      Text('${now.day} ${monthLong(now.month)}',
                          style: QfTheme.display(24,
                              weight: 500, color: QfColors.bistreSoft)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _quickAdd(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _sentence(dueToday.length, overdue.length, eventsToday),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SummaryBar(
              color: QfColors.madder,
              icon: Icons.check_box_outlined,
              headline: '${pending.length}',
              caption: 'pending',
              title: 'Tasks',
              semanticLabel:
                  'Tasks: ${pending.length} pending, ${overdue.length} overdue. Open tasks.',
              onTap: () => context.go('/calendar?filter=tasks'),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatPill('${dueToday.length} due today'),
                  StatPill(
                    '${overdue.length} overdue',
                    color: overdue.isEmpty ? null : QfColors.madder,
                    onTap: overdue.isEmpty
                        ? null
                        : () => context.go('/calendar?filter=overdue'),
                  ),
                  if (upcoming.isNotEmpty)
                    StatPill(
                        'Next: ${upcoming.first.title}, ${dayLabel(upcoming.first.deadline, now)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SummaryBar(
              color: QfColors.woad,
              icon: Icons.event,
              headline: '$eventsToday',
              caption: eventsToday == 1 ? 'event today' : 'events today',
              title: 'Events',
              semanticLabel:
                  'Events: $eventsToday today, ${soonEvents.length - eventsToday} tomorrow. Open events.',
              onTap: () => context.go('/calendar?filter=events'),
              child: _EventList(events: soonEvents, now: now),
            ),
            const SizedBox(height: 12),
            SummaryBar(
              color: QfColors.moss,
              icon: Icons.local_fire_department,
              headline: '$doneToday/${activeToday.length}',
              caption: '$percent% done',
              title: "Today's quests",
              semanticLabel:
                  "Today's quests: $doneToday of ${activeToday.length} done. Open quests.",
              onTap: () => context.go('/quests'),
              child: _QuestCells(data: data),
            ),
          ],
        ),
      ),
    );
  }

  String _sentence(int due, int overdue, int events) {
    final parts = <String>[];
    if (overdue > 0) parts.add('$overdue overdue');
    parts.add(due == 0 ? 'nothing due today' : '$due due today');
    parts.add(events == 0 ? 'no events' : '$events ${events == 1 ? 'event' : 'events'}');
    return 'Today: ${parts.join(', ')}.';
  }

  Future<void> _quickAdd(BuildContext context) async {
    final kind = await showAddChooser(context, includeQuest: true);
    if (kind == null || !context.mounted) return;
    switch (kind) {
      case AddKind.task:
        context.go('/calendar?add=task');
      case AddKind.event:
        context.go('/calendar?add=event');
      case AddKind.quest:
        context.go('/quests?add=1');
    }
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.now});
  final List<Event> events;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text('Nothing scheduled today or tomorrow.',
          style: TextStyle(color: QfColors.bistreSoft));
    }
    final shown = events.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    sameDay(e.start, now)
                        ? clock(e.start)
                        : 'Tmrw ${clock(e.start)}',
                    style: const TextStyle(
                        color: QfColors.woad, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(e.title, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        if (events.length > shown.length)
          Text('and ${events.length - shown.length} more',
              style: const TextStyle(color: QfColors.bistreSoft, fontSize: 13)),
      ],
    );
  }
}

/// One cell per active quest today, coloured by today's state.
class _QuestCells extends StatelessWidget {
  const _QuestCells({required this.data});
  final AppState data;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(data.now);
    final active = data.quests.where((q) => q.isEligible(today)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: QfColors.heat(
                      q.stateOn(today, today),
                      ratio: q.valueOn(today) / q.dailyTarget,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(q.title, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
