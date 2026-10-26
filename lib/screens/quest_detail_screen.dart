import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/quest.dart';
import '../models/quest_stats.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/dates.dart';
import '../widgets/forms/confirm_delete.dart';
import '../widgets/forms/day_dialog.dart';
import '../widgets/forms/quest_form.dart';
import '../widgets/status_view.dart';

/// The full quest screen: statistics and the complete start-to-end heatmap.
/// Tapping an eligible day opens the day dialog (spec 3.3, 4.3).
class QuestDetailScreen extends StatelessWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.status != LoadStatus.ready) {
      return const StatusView();
    }
    final quest = state.questById(questId);

    if (quest == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This quest no longer exists.'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => context.go('/quests'),
                  child: const Text('Back to quests')),
            ],
          ),
        ),
      );
    }

    final today = dateOnly(state.now);
    final stats = QuestStats.of(quest, today);
    final pad = MediaQuery.sizeOf(context).width >= 640 ? 40.0 : 20.0;

    final modeLine = quest.isNumeric
        ? 'Numeric · ${QuestFormatters.number(quest.dailyTarget)} ${quest.unit} a day'
            '${quest.upperLimit == null ? '' : ' · up to ${QuestFormatters.number(quest.upperLimit!)}'}'
        : 'Binary · done or not done each day';
    final rangeLine =
        '${dateRangeLabel(quest.startsOn, quest.endsOn)}'
        '${quest.isArchived ? ' · archived' : ''}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, pad >= 40 ? 28 : 16, pad, 96),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/quests'),
                    tooltip: 'Back to quests',
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text('Quest',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Quest actions',
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit quest')),
                      if (!quest.isArchived)
                        const PopupMenuItem(
                            value: 'archive', child: Text('Archive')),
                      if (quest.isArchived)
                        const PopupMenuItem(
                            value: 'unarchive', child: Text('Unarchive')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete…')),
                    ],
                    onSelected: (action) async {
                      switch (action) {
                        case 'edit':
                          showQuestForm(context, existing: quest);
                        case 'archive':
                          await state.archiveQuest(quest);
                        case 'unarchive':
                          await state.unarchiveQuest(quest);
                        case 'delete':
                          await showConfirmDelete(
                            context,
                            kind: 'quest',
                            title: quest.title,
                            warning:
                                'Its ${quest.records.length} daily record(s) are deleted too. '
                                'Archiving keeps the history — consider that instead.',
                            onDelete: () async {
                              await state.deleteQuest(quest.id);
                              if (context.mounted) context.go('/quests');
                            },
                          );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(quest.title,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(modeLine,
                  style: const TextStyle(color: QfColors.bistreSoft)),
              Text(rangeLine,
                  style: const TextStyle(color: QfColors.bistreSoft)),
              if (quest.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(quest.description),
              ],
              const SizedBox(height: 20),
              _StatsRow(quest: quest, stats: stats),
              const SizedBox(height: 24),
              _Heatmap(quest: quest, today: today),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.quest, required this.stats});

  final Quest quest;
  final QuestStats stats;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, {Color? color}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: QfTheme.display(30, spacing: -0.8, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: QfColors.bistreSoft, fontSize: 13)),
          ],
        );

    final cells = <Widget>[
      stat('${stats.currentStreak}', 'current streak',
          color: stats.currentStreak > 0 ? QfColors.moss : null),
      stat('${stats.longestStreak}', 'longest streak'),
      stat('${(stats.completionRate * 100).round()}%', 'completion rate'),
      stat('${stats.successDays} of ${stats.elapsedDays}', 'days done'),
    ];
    if (quest.isNumeric) {
      cells.add(stat('${stats.overloadDays}', 'overload days',
          color: stats.overloadDays > 0 ? QfColors.mulberry : null));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QfColors.pith,
        borderRadius: BorderRadius.circular(6),
        border:
            const Border(left: BorderSide(color: QfColors.moss, width: 4)),
      ),
      child: Wrap(
        spacing: 40,
        runSpacing: 14,
        children: cells,
      ),
    );
  }
}

/// Every eligible day from the quest start to its end, grouped by month,
/// Monday-first, coloured by the spec 4 rules.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.quest, required this.today});

  final Quest quest;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final months = <DateTime>[];
    var m = DateTime(quest.startsOn.year, quest.startsOn.month);
    while (!m.isAfter(quest.endsOn)) {
      months.add(m);
      m = DateTime(m.year, m.month + 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HeatLegendFull(),
        const SizedBox(height: 16),
        for (final month in months) ...[
          _MonthBlock(quest: quest, month: month, today: today),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class HeatLegendFull extends StatelessWidget {
  const HeatLegendFull({super.key});

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, {bool outline = false}) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: outline ? Border.all(color: QfColors.bistreSoft) : null,
          ),
        );
    Widget item(Widget w, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            w,
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        );
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item(swatch(QfColors.ash), 'No progress'),
        item(Row(mainAxisSize: MainAxisSize.min, children: [
          swatch(QfColors.partialLight),
          const SizedBox(width: 2),
          swatch(QfColors.partialDeep),
        ]), 'Partial'),
        item(swatch(QfColors.moss), 'Target reached'),
        item(swatch(QfColors.mulberry), 'Above target'),
        item(swatch(Colors.transparent, outline: true), 'Upcoming'),
      ],
    );
  }
}

class _MonthBlock extends StatelessWidget {
  const _MonthBlock({required this.quest, required this.month, required this.today});

  final Quest quest;
  final DateTime month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // Monday-first
    final days = DateTime(month.year, month.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${monthLong(month.month)} ${month.year}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: 7 * 25,
          child: Column(
            children: [
              Row(
                children: [
                  for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    SizedBox(
                      width: 25,
                      child: Center(
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: QfColors.bistreSoft)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              for (var row = 0; row < ((lead + days) / 7).ceil(); row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Builder(builder: (context) {
                        final index = row * 7 + col;
                        if (index < lead || index >= lead + days) {
                          return const SizedBox(width: 25, height: 25);
                        }
                        final day = DateTime(
                            month.year, month.month, index - lead + 1);
                        return _HeatCell(
                            quest: quest, day: day, today: today);
                      }),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.quest, required this.day, required this.today});

  final Quest quest;
  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final state = quest.stateOn(day, today);
    final eligible = state != DayState.outside;
    final ratio =
        quest.dailyTarget == 0 ? 0.0 : quest.valueOn(day) / quest.dailyTarget;
    final color = QfColors.heat(state, ratio: ratio);
    final isToday = sameDay(day, today);
    final value = quest.valueOn(day);

    final label = switch (state) {
      DayState.outside => 'Not part of this quest',
      DayState.future => 'Upcoming',
      DayState.none => 'No progress',
      DayState.partial =>
        '${QuestFormatters.number(value)} of ${QuestFormatters.number(quest.dailyTarget)} ${quest.unit}',
      DayState.target => quest.isNumeric
          ? 'Target reached: ${QuestFormatters.number(value)} ${quest.unit}'
          : 'Done',
      DayState.over =>
        'Over target: ${QuestFormatters.number(value)} ${quest.unit}',
    };

    final cell = Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: isToday
            ? Border.all(color: QfColors.bistre, width: 2)
            : (state == DayState.future || state == DayState.outside)
                ? Border.all(color: QfColors.rule)
                : null,
      ),
    );

    return Tooltip(
      message: '${day.day} ${monthShort(day.month)}: $label',
      child: eligible
          ? InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () =>
                  showDayDialog(context: context, quest: quest, date: day),
              child: cell,
            )
          : cell,
    );
  }
}
