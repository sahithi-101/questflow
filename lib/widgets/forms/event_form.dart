import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../state/app_scope.dart';
import '../../theme/palette.dart';
import 'form_widgets.dart';

/// Create or edit an event. Required: title and start (spec 3.2). An end
/// time is optional but must not sit before the start.
Future<void> showEventForm(BuildContext context, {Event? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EventForm(existing: existing),
  );
}

class _EventForm extends StatefulWidget {
  const _EventForm({this.existing});
  final Event? existing;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late DateTime? _start;
  late DateTime? _end;
  late List<int> _reminders;
  bool _autoValidate = false;
  String? _endError;

  static const _presetReminders = [(0, 'At event time'), (10, '10 min before'), (60, '1 hour before')];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _start = e?.start;
    _end = e?.end;
    _reminders = List.of(e?.reminderOffsets ?? const [0]);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _toggleReminder(int minutes) {
    setState(() {
      if (_reminders.contains(minutes)) {
        if (_reminders.length > 1) _reminders.remove(minutes);
      } else {
        _reminders.add(minutes);
        _reminders.sort();
      }
    });
  }

  Future<void> _save() async {
    final endInvalid = _end != null && _start != null && _end!.isBefore(_start!);
    setState(() {
      _endError = endInvalid ? 'End must be after the start.' : null;
    });
    if (!_formKey.currentState!.validate() || endInvalid) {
      setState(() => _autoValidate = true);
      return;
    }
    final state = AppScope.of(context);
    final event = (widget.existing ??
            Event(id: _newId(), title: _title.text.trim(), start: _start!))
        .copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      start: _start!,
      end: _end,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      reminderOffsets: _reminders,
      updatedAt: DateTime.now(),
    );
    final ok = widget.existing == null
        ? await state.addEvent(event)
        : await state.updateEvent(event);
    if (!mounted) return;
    Navigator.pop(context);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the event.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return FormDialog(
      title: editing ? 'Edit event' : 'New event',
      formKey: _formKey,
      onSave: _save,
      children: [
        TextFormField(
          controller: _title,
          autofocus: !editing,
          autovalidateMode: _autoValidate
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => requiredText(v, 'Title'),
        ),
        const FieldGap(),
        DateTimeField(
          label: 'Starts *',
          value: _start,
          errorText: _autoValidate && _start == null
              ? 'A start time is required.'
              : null,
          onChanged: (d) => setState(() => _start = d),
        ),
        const FieldGap(),
        DateTimeField(
          label: 'Ends (optional)',
          value: _end,
          hint: 'No end time',
          errorText: _endError,
          onChanged: (d) => setState(() => _end = d),
        ),
        const FieldGap(),
        TextFormField(
          controller: _location,
          decoration:
              const InputDecoration(labelText: 'Location (optional)'),
        ),
        const FieldGap(),
        TextFormField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Description (optional)', alignLabelWithHint: true),
        ),
        const FieldGap(),
        const Text('Remind me',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (minutes, label) in _presetReminders)
              FilterChip(
                label: Text(label),
                selected: _reminders.contains(minutes),
                onSelected: (_) => _toggleReminder(minutes),
                selectedColor: QfColors.lichen,
                checkmarkColor: QfColors.bistre,
                showCheckmark: false,
              ),
          ],
        ),
        const FieldGap(height: 4),
      ],
    );
  }
}

String _newId() =>
    'e${DateTime.now().microsecondsSinceEpoch}_${(DateTime.now().hashCode & 0xffff).toRadixString(16)}';
