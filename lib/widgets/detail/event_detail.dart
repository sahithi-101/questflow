import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../state/app_scope.dart';
import '../../theme/palette.dart';
import '../../util/dates.dart';
import '../forms/confirm_delete.dart';
import '../forms/event_form.dart';

/// Full detail view for one event, with Edit and Delete (confirmed)
/// (spec 3.2, 5).
Future<void> showEventDetail(BuildContext context, Event event) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EventDetail(event: event),
  );
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
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
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    String when(DateTime d) =>
        '${weekdayLong(d)} ${d.day} ${monthLong(d.month)}, ${clock(d)}';

    final reminders = event.reminderOffsets.isEmpty
        ? 'None'
        : (event.reminderOffsets
            .map((m) => switch (m) {
                  0 => 'at event time',
                  10 => '10 min before',
                  60 => '1 hour before',
                  _ => '$m min before',
                })
            .join(', '));

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
                  color: QfColors.woad,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(event.title,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
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
              row('Starts', when(event.start)),
              row('Ends', event.end == null ? '—' : when(event.end!)),
              row('Location', event.location == null || event.location!.isEmpty
                  ? '—'
                  : event.location!),
              row('Reminders', reminders),
              if (event.description.isNotEmpty)
                row('Description', event.description),
              row('Created', _stamp(event.createdAt)),
              row('Updated', _stamp(event.updatedAt)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => showConfirmDelete(
            context,
            kind: 'event',
            title: event.title,
            onDelete: () async {
              final s = AppScope.of(context);
              Navigator.pop(context);
              await s.deleteEvent(event.id);
            },
          ),
          style: TextButton.styleFrom(foregroundColor: QfColors.madder),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showEventForm(context, existing: event);
          },
          child: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  static String _stamp(DateTime d) =>
      '${d.day} ${monthShort(d.month)} ${d.year}, ${clock(d)}';
}
