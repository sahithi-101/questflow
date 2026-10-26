import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

enum AddKind { task, event, quest }

/// The single "+" flow: asks what to add before opening a form (spec 3.2).
Future<AddKind?> showAddChooser(BuildContext context,
    {bool includeQuest = false}) {
  return showModalBottomSheet<AddKind>(
    context: context,
    backgroundColor: QfColors.pith,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Option(
              icon: Icons.check_box_outlined,
              color: QfColors.madder,
              title: 'Task',
              subtitle: 'Something to finish before a deadline',
              onTap: () => Navigator.pop(ctx, AddKind.task),
            ),
            _Option(
              icon: Icons.event,
              color: QfColors.woad,
              title: 'Event',
              subtitle: 'Something that happens at a set time',
              onTap: () => Navigator.pop(ctx, AddKind.event),
            ),
            if (includeQuest)
              _Option(
                icon: Icons.local_fire_department,
                color: QfColors.moss,
                title: 'Quest',
                subtitle: 'A habit or goal you track every day',
                onTap: () => Navigator.pop(ctx, AddKind.quest),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: QfColors.pith, size: 22),
      ),
      title: Text(title, style: QfTheme.display(18, weight: 650)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: QfColors.bistreSoft, fontSize: 14)),
    );
  }
}
