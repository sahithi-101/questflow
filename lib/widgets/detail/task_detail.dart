import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../state/app_scope.dart';
import '../../theme/palette.dart';
import '../../util/dates.dart';
import '../forms/confirm_delete.dart';
import '../forms/task_form.dart';

/// Full detail view for one task, with Edit, Delete (confirmed) and a
/// complete/reopen toggle (spec 3.2, 5).
Future<void> showTaskDetail(BuildContext context, Task task) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TaskDetail(task: task),
  );
}

class _TaskDetail extends StatelessWidget {
  const _TaskDetail({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final overdue = task.isOverdue(state.now);
    final priority = switch (task.priority) {
      TaskPriority.high => 'High',
      TaskPriority.medium => 'Medium',
      TaskPriority.low => 'Low',
    };

    Widget row(String label, String value, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(
                        color: QfColors.bistreSoft, fontSize: 14)),
              ),
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: valueColor)),
              ),
            ],
          ),
        );

    return AlertDialog(
      backgroundColor: QfColors.pith,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: QfColors.madder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.title,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            task.isCompleted
                ? 'Completed'
                : overdue
                    ? 'Overdue'
                    : 'Pending',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: task.isCompleted
                  ? QfColors.moss
                  : overdue
                      ? QfColors.madder
                      : QfColors.bistreSoft,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              row('Deadline',
                  '${weekdayLong(task.deadline)} ${task.deadline.day} ${monthLong(task.deadline.month)}, ${clock(task.deadline)}'),
              row('Priority', priority),
              if (task.category.isNotEmpty) row('Category', task.category),
              if (task.description.isNotEmpty)
                row('Description', task.description),
              row('Created', _stamp(task.createdAt)),
              row('Updated', _stamp(task.updatedAt)),
              if (task.completedAt != null)
                row('Completed', _stamp(task.completedAt!)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => showConfirmDelete(
            context,
            kind: 'task',
            title: task.title,
            onDelete: () async {
              final s = AppScope.of(context);
              Navigator.pop(context);
              await s.deleteTask(task.id);
            },
          ),
          style: TextButton.styleFrom(foregroundColor: QfColors.madder),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showTaskForm(context, existing: task);
          },
          child: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () async {
            final s = AppScope.of(context);
            await s.setTaskDone(task, !task.isCompleted);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(task.isCompleted ? 'Reopen' : 'Mark done'),
        ),
      ],
    );
  }

  static String _stamp(DateTime d) =>
      '${d.day} ${monthShort(d.month)} ${d.year}, ${clock(d)}';
}
