// Excerpt from lib/widgets/forms/task_form.dart and form_widgets.dart
// Every create/edit flow validates before saving. Required fields use a
// shared validator; the deadline is checked on submit.

TextFormField(
  controller: _title,
  autofocus: true,
  decoration: const InputDecoration(labelText: 'Title *'),
  validator: (v) => requiredText(v, 'Title'),
),
DateTimeField(
  label: 'Deadline *',
  value: _deadline,
  hint: 'Pick a date and time',
  errorText: _autoValidate && _deadline == null
      ? 'A deadline is required.'
      : null,
  onChanged: (d) => setState(() => _deadline = d),
),

// Shared validator used by every form.
String? requiredText(String? v, String label) =>
    (v == null || v.trim().isEmpty) ? '$label is required.' : null;

// On submit the form validates itself and reports the first problems:
void _submit() {
  setState(() => _autoValidate = true);
  if (!Form.of(context).validate()) return; // errors render under fields
  // ... build the Task and hand it to AppState
}
