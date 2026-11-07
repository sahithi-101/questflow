// Excerpt from lib/state/app_state.dart
// Validation for one quest day, implementing the specification's rules:
// future days cannot be marked, values must stay within the configured
// range, and nothing is ever silently capped.

static String? validateRecord(
    Quest quest, DateTime date, double? value, DateTime now) {
  if (!quest.isEligible(date)) {
    return 'That date is outside this quest.';
  }
  if (dateOnly(date).isAfter(dateOnly(now))) {
    return "Future days can't be marked before their day.";
  }
  if (value == null) return null; // clearing a day is always allowed
  if (value < 0) return 'The value cannot be negative.';
  if (quest.isNumeric) {
    final limit = quest.upperLimit;
    if (limit != null && value > limit) {
      return 'Above the upper limit of ${_fmt(limit)} ${quest.unit}. '
          'Change the limit if you really did more.';
    }
  } else if (value != 0 && value != 1) {
    return 'Binary quests accept only done or not done.';
  }
  return null;
}
