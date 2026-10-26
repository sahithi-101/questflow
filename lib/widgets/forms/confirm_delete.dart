import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// Red delete confirmation used by every detail view (spec 5: delete from
/// detail view with confirmation).
Future<void> showConfirmDelete(
  BuildContext context, {
  required String kind,
  required String title,
  String? warning,
  required Future<void> Function() onDelete,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: QfColors.pith,
      title: Text('Delete this $kind?'),
      content: Text(
        '"$title" will be removed permanently.'
        '${warning == null ? '' : '\n\n$warning'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep it'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: QfColors.madder),
          onPressed: () async {
            Navigator.pop(ctx);
            await onDelete();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
