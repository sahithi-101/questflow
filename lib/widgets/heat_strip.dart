import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../theme/palette.dart';
import '../util/dates.dart';

/// The last [days] days of a quest as small cells. The full heatmap and its
/// day dialog arrive in Phase 3; the colour rules here are already the
/// spec's (4.1 and 4.2).
class HeatStrip extends StatelessWidget {
  const HeatStrip({
    super.key,
    required this.quest,
    required this.today,
    this.days = 28,
    this.cell = 14.0,
  });

  final Quest quest;
  final DateTime today;
  final int days;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final t = dateOnly(today);
    var successes = 0;
    final cells = <Widget>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = addDays(t, -i);
      final state = quest.stateOn(date, t);
      if (state != DayState.outside && quest.isSuccess(date)) successes++;
      final ratio = quest.dailyTarget == 0
          ? 0.0
          : quest.valueOn(date) / quest.dailyTarget;
      cells.add(_Cell(
        size: cell,
        color: QfColors.heat(state, ratio: ratio),
        isToday: i == 0,
        hollow: state == DayState.outside || state == DayState.future,
        tooltip: '${weekdayShort(date)} ${date.day} ${monthShort(date.month)}: '
            '${_describe(state, quest.valueOn(date))}',
      ));
    }
    return Semantics(
      container: true,
      label: 'Last $days days: $successes successful days',
      child: ExcludeSemantics(
        child: Wrap(spacing: 3, runSpacing: 3, children: cells),
      ),
    );
  }

  String _describe(DayState s, double v) {
    final value = v == v.roundToDouble() ? v.toInt().toString() : '$v';
    switch (s) {
      case DayState.outside:
        return 'not part of this quest';
      case DayState.future:
        return 'upcoming';
      case DayState.none:
        return 'not done';
      case DayState.target:
        return quest.isNumeric ? '$value ${quest.unit}, target reached' : 'done';
      case DayState.partial:
        return '$value of ${quest.dailyTarget.toInt()} ${quest.unit}';
      case DayState.over:
        return '$value ${quest.unit}, above target';
    }
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.color,
    required this.isToday,
    required this.hollow,
    required this.tooltip,
  });

  final double size;
  final Color color;
  final bool isToday;
  final bool hollow;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: isToday
              ? Border.all(color: QfColors.bistre, width: 2)
              : hollow
                  ? Border.all(color: QfColors.rule)
                  : null,
        ),
      ),
    );
  }
}

/// Explains the cell colours. Upcoming days are outlined, never red or grey,
/// so they cannot be mistaken for misses.
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        );
    Widget box(Color c, {bool outline = false}) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: outline ? Border.all(color: QfColors.bistreSoft) : null,
          ),
        );
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item(box(QfColors.ash), 'No progress'),
        item(
          Row(mainAxisSize: MainAxisSize.min, children: [
            box(QfColors.partialLight),
            const SizedBox(width: 2),
            box(QfColors.partialDeep),
          ]),
          'Partial',
        ),
        item(box(QfColors.moss), 'Target reached'),
        item(box(QfColors.mulberry), 'Above target'),
        item(box(Colors.transparent, outline: true), 'Upcoming'),
      ],
    );
  }
}
