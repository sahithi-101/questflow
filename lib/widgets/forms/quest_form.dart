import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/quest.dart';
import '../../state/app_scope.dart';
import '../../theme/palette.dart';
import 'form_widgets.dart';

/// Create or edit a quest: tracking mode, date range (with month/year
/// presets), and for numeric quests the unit, daily target and upper limit
/// (spec 3.3, 4.3 and the section 11 defaults).
Future<void> showQuestForm(BuildContext context, {Quest? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _QuestForm(existing: existing),
  );
}

class _QuestForm extends StatefulWidget {
  const _QuestForm({this.existing});
  final Quest? existing;

  @override
  State<_QuestForm> createState() => _QuestFormState();
}

enum _RangePreset { custom, month, year }

class _QuestFormState extends State<_QuestForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _target;
  late final TextEditingController _limit;
  late TrackingMode _mode;
  late DateTime? _start;
  late DateTime? _end;
  late _RangePreset _preset;
  bool _autoValidate = false;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _title = TextEditingController(text: q?.title ?? '');
    _description = TextEditingController(text: q?.description ?? '');
    _unit = TextEditingController(text: q?.unit ?? '');
    _target = TextEditingController(
        text: q != null && q.isNumeric ? _fmt(q.dailyTarget) : '');
    _limit = TextEditingController(
        text: q?.upperLimit == null ? '' : _fmt(q!.upperLimit!));
    _mode = q?.mode ?? TrackingMode.binary;
    _start = q?.startsOn;
    _end = q?.endsOn;
    _preset = _RangePreset.custom;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _unit.dispose();
    _target.dispose();
    _limit.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';

  void _applyPreset(_RangePreset p) {
    final now = DateTime.now();
    setState(() {
      _preset = p;
      if (p == _RangePreset.month) {
        _start = DateTime(now.year, now.month, 1);
        _end = DateTime(now.year, now.month + 1, 0);
      } else if (p == _RangePreset.year) {
        _start = DateTime(now.year, 1, 1);
        _end = DateTime(now.year, 12, 31);
      }
    });
  }

  double? _parse(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final start = _start, end = _end;
    final target = _parse(_target.text);
    final limit = _parse(_limit.text);
    String? rangeError;
    if (start == null || end == null) {
      rangeError = 'Both dates are required.';
    } else if (end.isBefore(start)) {
      rangeError = 'The end date must be on or after the start date.';
    }
    String? targetError;
    String? limitError;
    if (_mode == TrackingMode.numeric) {
      if (target == null || target <= 0) {
        targetError = 'Enter a daily target above 0.';
      }
      if (limit == null) {
        limitError = 'Enter an upper limit.';
      } else if (target != null && limit < target) {
        limitError = 'The upper limit must be at least the daily target.';
      }
    }
    setState(() {
      _rangeError = rangeError;
      _autoValidate = true;
    });
    final okBasic = _formKey.currentState!.validate();
    if (rangeError != null || targetError != null || limitError != null ||
        !okBasic) {
      // re-validate numeric fields through their validators
      if (targetError != null || limitError != null) setState(() {});
      return;
    }

    final state = AppScope.of(context);
    final now = DateTime.now();
    final quest = (widget.existing ??
            Quest(
                id: _newId(),
                title: _title.text.trim(),
                mode: _mode,
                startsOn: start!,
                endsOn: end!,
                records: {}))
        .copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      unit: _mode == TrackingMode.numeric ? _unit.text.trim() : '',
      dailyTarget: _mode == TrackingMode.numeric ? target! : 1,
      upperLimit: _mode == TrackingMode.numeric ? limit : null,
      startsOn: start,
      endsOn: end,
      updatedAt: now,
    );
    final saved = widget.existing == null
        ? await state.addQuest(quest)
        : await state.updateQuest(quest);
    if (!mounted) return;
    Navigator.pop(context);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the quest.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final numeric = _mode == TrackingMode.numeric;
    return FormDialog(
      title: editing ? 'Edit quest' : 'New quest',
      formKey: _formKey,
      onSave: _save,
      children: [
        TextFormField(
          controller: _title,
          autofocus: !editing,
          autovalidateMode: _autoValidate
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          decoration: const InputDecoration(labelText: 'Quest name'),
          validator: (v) => requiredText(v, 'Quest name'),
        ),
        const FieldGap(),
        TextFormField(
          controller: _description,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Description (optional)', alignLabelWithHint: true),
        ),
        const FieldGap(),
        const Text('Track',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<TrackingMode>(
          segments: const [
            ButtonSegment(
                value: TrackingMode.binary,
                label: Text('Binary'),
                icon: Icon(Icons.check_circle_outline, size: 18)),
            ButtonSegment(
                value: TrackingMode.numeric,
                label: Text('Numeric'),
                icon: Icon(Icons.tag, size: 18)),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
          showSelectedIcon: false,
        ),
        const FieldGap(),
        if (numeric) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _unit,
                  autovalidateMode: _autoValidate
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  decoration: const InputDecoration(
                      labelText: 'Unit (minutes, pages…)'),
                  validator: (v) => requiredText(v, 'Unit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _target,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d*')),
                  ],
                  autovalidateMode: _autoValidate
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  decoration: const InputDecoration(labelText: 'Daily target'),
                  validator: (v) {
                    final n = _parse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Above 0.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _limit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[.,]?\d*')),
                  ],
                  autovalidateMode: _autoValidate
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  decoration: const InputDecoration(labelText: 'Upper limit'),
                  validator: (v) {
                    final n = _parse(v ?? '');
                    if (n == null) return 'Required.';
                    final t = _parse(_target.text);
                    if (t != null && n < t) {
                      return 'At least the target.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Values above the upper limit are rejected, never capped.',
            style: TextStyle(fontSize: 12.5, color: QfColors.bistreSoft),
          ),
          const FieldGap(),
        ],
        const Text('Runs every day from start to end, inclusive',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<_RangePreset>(
          segments: const [
            ButtonSegment(value: _RangePreset.custom, label: Text('Custom')),
            ButtonSegment(value: _RangePreset.month, label: Text('This month')),
            ButtonSegment(value: _RangePreset.year, label: Text('This year')),
          ],
          selected: {_preset},
          onSelectionChanged: (s) => _applyPreset(s.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 4),
        if (_rangeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_rangeError!,
                style: const TextStyle(
                    color: QfColors.madder, fontSize: 12.5)),
          ),
        const FieldGap(),
        Row(
          children: [
            Expanded(
              child: DateField(
                label: 'Starts on',
                value: _start,
                onChanged: (d) => setState(() {
                  _start = d;
                  _preset = _RangePreset.custom;
                  // Keep the range valid when the start moves forward.
                  if (_end != null && _end!.isBefore(d)) _end = d;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DateField(
                label: 'Ends on',
                value: _end,
                firstDate: _start,
                onChanged: (d) =>
                    setState(() { _end = d; _preset = _RangePreset.custom; }),
              ),
            ),
          ],
        ),
        const FieldGap(height: 4),
      ],
    );
  }
}

String _newId() =>
    'q${DateTime.now().microsecondsSinceEpoch}_${(DateTime.now().hashCode & 0xffff).toRadixString(16)}';
