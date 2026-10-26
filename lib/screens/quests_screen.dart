import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/quest.dart';
import '../models/quest_stats.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/dates.dart';
import '../widgets/forms/day_dialog.dart';
import '../widgets/forms/quest_form.dart';
import '../widgets/heat_strip.dart';
import '../widgets/status_view.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key, this.openAdd = false});

  /// Open the add flow on arrival (from Home's quick add).
  final bool openAdd;

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showQuestForm(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.status != LoadStatus.ready) {
      return const StatusView();
    }
    final today = dateOnly(state.now);
    final active =
        state.quests.where((q) => !q.isArchived).toList();
    final activeNow = active.where((q) => q.isEligible(today)).toList();
    final archived = state.quests.where((q) => q.isArchived).toList();
    final pad = MediaQuery.sizeOf(context).width >= 640 ? 40.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showQuestForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New quest',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, pad >= 40 ? 40 : 24, pad, 96),
            children: [
              Text('Quests', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                '${activeNow.length} active today. Open a quest for its full heatmap.',
                style: const TextStyle(color: QfColors.bistreSoft),
              ),
              const SizedBox(height: 16),
              const HeatLegend(),
              const SizedBox(height: 24),
              if (active.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: QfColors.pith,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'No quests yet. Use "New quest" to start tracking a habit.',
                    style: TextStyle(color: QfColors.bistreSoft),
                  ),
                )
              else
                for (final q in active) ...[
                  _QuestCard(quest: q, today: today),
                  const SizedBox(height: 12),
                ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _showArchived = !_showArchived),
                  child: Row(
                    children: [
                      Icon(
                        _showArchived
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: QfColors.bistreSoft,
                      ),
                      const SizedBox(width: 6),
                      Text('Archived (${archived.length})',
                          style: const TextStyle(
                              color: QfColors.bistreSoft,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                if (_showArchived)
                  for (final q in archived) ...[
                    const SizedBox(height: 8),
                    _ArchivedCard(quest: q),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.today});

  final Quest quest;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final stats = QuestStats.of(quest, today);
    final value = quest.valueOn(today);
    final dayState = quest.stateOn(today, today);
    final ratio = quest.dailyTarget == 0 ? 0.0 : value / quest.dailyTarget;

    final modeLine = quest.isNumeric
        ? 'Numeric, ${QuestFormatters.number(quest.dailyTarget)} ${quest.unit} a day'
        : 'Binary, once a day';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QfColors.pith,
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: QfColors.moss, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.go('/quests/${quest.id}'),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  child: Text(quest.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const Icon(Icons.chevron_right, color: QfColors.bistreSoft),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(modeLine, style: const TextStyle(color: QfColors.bistreSoft)),
          const SizedBox(height: 14),
          if (quest.isNumeric)
            _NumericProgress(
                quest: quest, value: value, ratio: ratio, state: dayState)
          else
            Row(
              children: [
                Icon(
                  dayState == DayState.target
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: dayState == DayState.target
                      ? QfColors.moss
                      : QfColors.bistreSoft,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(dayState == DayState.target
                    ? 'Done today'
                    : 'Not done yet today'),
              ],
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(
                  value: '${stats.currentStreak}',
                  label: 'day streak'),
              const SizedBox(width: 32),
              _Stat(
                  value: '${(stats.completionRate * 100).round()}%',
                  label: 'completion'),
              const Spacer(),
              TextButton.icon(
                onPressed: quest.isEligible(today)
                    ? () => showDayDialog(
                        context: context, quest: quest, date: today)
                    : null,
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text("Today's progress"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HeatStrip(quest: quest, today: today),
        ],
      ),
    );
  }
}

class _ArchivedCard extends StatelessWidget {
  const _ArchivedCard({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QfColors.pith,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: QfColors.rule),
      ),
      child: Row(
        children: [
          const Icon(Icons.archive_outlined,
              size: 20, color: QfColors.bistreSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(quest.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => state.unarchiveQuest(quest),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );
  }
}

class _NumericProgress extends StatelessWidget {
  const _NumericProgress({
    required this.quest,
    required this.value,
    required this.ratio,
    required this.state,
  });

  final Quest quest;
  final double value;
  final double ratio;
  final DayState state;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fill = QfColors.heat(state, ratio: ratio);
    final pct = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${QuestFormatters.number(value)} of '
                '${QuestFormatters.number(quest.dailyTarget)} ${quest.unit}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text('$pct% of target', style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: QfColors.ash,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  color: state == DayState.none || state == DayState.future
                      ? Colors.transparent
                      : fill,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: QfTheme.display(26, spacing: -0.6)),
        Text(label,
            style: const TextStyle(color: QfColors.bistreSoft, fontSize: 13)),
      ],
    );
  }
}
