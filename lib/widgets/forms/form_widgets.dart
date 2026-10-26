import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../util/dates.dart';

/// A labelled field that opens the date picker and then the time picker.
/// Used by the task, event and quest forms so date entry behaves the same
/// everywhere.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.hint = 'Pick a date',
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;
  final String hint;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    final t = time ?? TimeOfDay.fromDateTime(initial);
    if (!context.mounted) return;
    onChanged(DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? hint
        : '${weekdayShort(value!)} ${value!.day} ${monthShort(value!.month)}, '
            '${clock(value!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: errorText,
              isDense: true,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: value == null ? QfColors.bistreSoft : QfColors.bistre,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A date-only variant (quest ranges). [firstDate] optionally blocks
/// earlier dates in the picker itself.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.firstDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  /// Dates before this cannot be picked.
  final DateTime? firstDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final floor = firstDate ?? DateTime(now.year - 5);
    // Keep the initial date inside the allowed window.
    var initial = value ?? now;
    if (initial.isBefore(floor)) initial = floor;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: floor,
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) onChanged(dateOnly(date));
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Pick a date'
        : '${weekdayShort(value!)} ${value!.day} ${monthShort(value!.month)} ${value!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: errorText,
              isDense: true,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: value == null ? QfColors.bistreSoft : QfColors.bistre,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Standard scaffold for the create/edit dialogs: fixed title, scrollable
/// form body, cancel + save row.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Save',
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: QfColors.pith,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Flexible(
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onSave,
                    child: Text(saveLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consistent spacing helper for form fields.
class FieldGap extends StatelessWidget {
  const FieldGap({super.key, this.height = 14});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

String? requiredText(String? v, String label) =>
    (v == null || v.trim().isEmpty) ? '$label is required.' : null;
