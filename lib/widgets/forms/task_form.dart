import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../state/app_scope.dart';
import 'form_widgets.dart';

/// Create or edit a task. Validation: title and deadline are required
/// (spec 3.2). Opens as a dialog and saves through [AppState].
Future<void> showTaskForm(BuildContext context, {Task? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TaskForm(existing: existing),
  );
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.existing});
  final Task? existing;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late DateTime? _deadline;
  late TaskPriority _priority;
  late TaskStatus _status;
  bool _autoValidate = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _category = TextEditingController(text: t?.category ?? '');
    _deadline = t?.deadline;
    _priority = t?.priority ?? TaskPriority.medium;
    _status = t?.status ?? TaskStatus.pending;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidate = true);
      return;
    }
    final state = AppScope.of(context);
    final now = DateTime.now();
    final deadline = _deadline!;
    final task = (widget.existing ?? Task(id: _newId(), title: '', deadline: deadline))
        .copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim(),
      deadline: deadline,
      priority: _priority,
      status: _status,
      updatedAt: now,
      completedAt: _status == TaskStatus.completed
          ? (widget.existing?.completedAt ?? now)
          : null,
      clearCompletedAt: _status == TaskStatus.pending,
    );
    final ok = widget.existing == null
        ? await state.addTask(task)
        : await state.updateTask(task);
    if (!mounted) return;
    Navigator.pop(context);
    if (!ok) _showSaveFailed(context);
  }

  void _showSaveFailed(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Could not save the task.')));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return FormDialog(
      title: editing ? 'Edit task' : 'New task',
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
        TextFormField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Description (optional)', alignLabelWithHint: true),
        ),
        const FieldGap(),
        DateTimeField(
          label: 'Deadline *',
          value: _deadline,
          hint: 'Pick a date and time',
          errorText: _autoValidate && _deadline == null
              ? 'A deadline is required.'
              : null,
          onChanged: (d) => setState(() => _deadline = d),
        ),
        const FieldGap(),
        Row(
          children: [
            const Text('Priority',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<TaskPriority>(
                segments: const [
                  ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                  ButtonSegment(
                      value: TaskPriority.medium, label: Text('Medium')),
                  ButtonSegment(value: TaskPriority.high, label: Text('High')),
                ],
                selected: {_priority},
                onSelectionChanged: (s) =>
                    setState(() => _priority = s.first),
                showSelectedIcon: false,
              ),
            ),
          ],
        ),
        const FieldGap(),
        TextFormField(
          controller: _category,
          decoration: const InputDecoration(
              labelText: 'Category (optional, e.g. study, personal)'),
        ),
        if (editing) ...[
          const FieldGap(),
          Row(
            children: [
              const Text('Status',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<TaskStatus>(
                  segments: const [
                    ButtonSegment(
                        value: TaskStatus.pending, label: Text('Pending')),
                    ButtonSegment(
                        value: TaskStatus.completed, label: Text('Done')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
        ],
        const FieldGap(height: 4),
      ],
    );
  }
}

String _newId() =>
    't${DateTime.now().microsecondsSinceEpoch}_${(DateTime.now().hashCode & 0xffff).toRadixString(16)}';
