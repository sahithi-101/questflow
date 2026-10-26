import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/quest.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../util/dates.dart';

/// Inspect or edit one quest day (spec 3.3: "Selecting a day in the heatmap
/// opens a dialog to inspect or edit that day's progress").
///
/// Binary quests toggle done / not done. Numeric quests record a value that
/// must sit between 0 and the quest's upper limit — higher values are
/// rejected with a message, never silently capped. Future days cannot be
/// marked before their day.
Future<void> showDayDialog({
  required BuildContext context,
  required Quest quest,
  required DateTime date,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DayDialog(quest: quest, date: dateOnly(date)),
  );
}

class _DayDialog extends StatefulWidget {
  const _DayDialog({required this.quest, required this.date});

  final Quest quest;
  final DateTime date;

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  late final TextEditingController _value;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.quest.valueOn(widget.date);
    _value = TextEditingController(
        text: v == 0 ? '' : QuestFormatters.number(v));
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save(double? value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final state = AppScope.of(context);
    final error = await state.setDayValue(widget.quest, widget.date, value);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final date = widget.date;
    final state = AppScope.of(context);
    final today = dateOnly(state.now);
    final isFuture = date.isAfter(today);
    final current = quest.valueOn(date);
    final dayState = quest.stateOn(date, today);

    final heading =
        '${weekdayLong(date)} ${date.day} ${monthLong(date.month)} ${date.year}';
    final relative = dayLabel(date, state.now).toLowerCase();

    return AlertDialog(
      backgroundColor: QfColors.pith,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 24, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quest.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('$relative · $heading',
              style: const TextStyle(
                  color: QfColors.bistreSoft, fontSize: 14)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFuture) ...[
              const Text(
                'This day has not happened yet. Come back on the day to '
                'record it.',
                style: TextStyle(color: QfColors.bistreSoft),
              ),
            ] else if (quest.isNumeric) ...[
              Text(
                'Target: ${QuestFormatters.number(quest.dailyTarget)} '
                '${quest.unit}'
                '${quest.upperLimit == null ? '' : ' · up to ${QuestFormatters.number(quest.upperLimit!)}'}',
                style: const TextStyle(color: QfColors.bistreSoft),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
                ],
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Amount for this day',
                  suffixText: quest.unit,
                  errorText: _error,
                  helperText: 'Leave empty to clear the day',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    dayState == DayState.target
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: dayState == DayState.target
                        ? QfColors.moss
                        : QfColors.bistreSoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dayState == DayState.target
                          ? 'Marked as done'
                          : 'Not marked yet',
                      style: QfTheme.display(17, weight: 600),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: QfColors.madder, fontSize: 13)),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (!isFuture && current != 0)
          TextButton(
            onPressed: _saving ? null : () => _save(null),
            child: const Text('Clear day'),
          ),
        if (!isFuture && !quest.isNumeric)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: dayState == DayState.target
                  ? QfColors.bistreSoft
                  : QfColors.moss,
            ),
            onPressed: _saving
                ? null
                : () => _save(dayState == DayState.target ? 0 : 1),
            icon: Icon(dayState == DayState.target
                ? Icons.close
                : Icons.check),
            label: Text(dayState == DayState.target ? 'Undo' : 'Mark done'),
          ),
        if (!isFuture && quest.isNumeric)
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: const Text('Save'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _submit() {
    final text = _value.text.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      _save(null);
      return;
    }
    final v = double.tryParse(text);
    if (v == null) {
      setState(() => _error = 'Enter a number.');
      return;
    }
    _save(v);
  }
}

/// Number formatting shared by the dialog and the quest screens.
abstract final class QuestFormatters {
  static String number(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';
}
