import '../util/dates.dart';
import 'quest.dart';

/// Statistics for one quest, following spec section 4.4.
class QuestStats {
  const QuestStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.successDays,
    required this.elapsedDays,
    required this.overloadDays,
  });

  /// Consecutive successful days ending today if today is successful;
  /// otherwise ending yesterday if today is still incomplete; otherwise 0.
  final int currentStreak;

  /// Largest consecutive sequence of successful eligible days.
  final int longestStreak;

  /// 0..1: successful eligible days / elapsed eligible days (future excluded).
  final double completionRate;

  /// Successful days among elapsed eligible days.
  final int successDays;

  /// Eligible days from [Quest.startsOn] through today or [Quest.endsOn],
  /// whichever is earlier. Zero when the quest has not started.
  final int elapsedDays;

  /// Numeric only: elapsed days strictly above target (overload). Binary
  /// quests never have overload days.
  final int overloadDays;

  static QuestStats of(Quest q, DateTime now) {
    final today = dateOnly(now);
    final last = today.isAfter(q.endsOn) ? q.endsOn : today;
    if (last.isBefore(q.startsOn)) {
      return const QuestStats(
        currentStreak: 0,
        longestStreak: 0,
        completionRate: 0,
        successDays: 0,
        elapsedDays: 0,
        overloadDays: 0,
      );
    }

    var elapsed = 0;
    var ok = 0;
    var overload = 0;
    var longest = 0;
    var run = 0;
    for (var d = q.startsOn; !d.isAfter(last); d = addDays(d, 1)) {
      elapsed++;
      final success = q.isSuccess(d);
      if (success) {
        ok++;
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
      if (q.isNumeric && q.valueOn(d) > q.dailyTarget) overload++;
    }

    // Streak ends today if today succeeded, else yesterday while today is
    // still open, else zero (spec 4.4).
    var cursor = last;
    if (sameDay(cursor, today) && !q.isSuccess(cursor)) {
      cursor = addDays(cursor, -1);
    }
    var streak = 0;
    while (!cursor.isBefore(q.startsOn) && q.isSuccess(cursor)) {
      streak++;
      cursor = addDays(cursor, -1);
    }

    return QuestStats(
      currentStreak: streak,
      longestStreak: longest,
      completionRate: elapsed == 0 ? 0 : ok / elapsed,
      successDays: ok,
      elapsedDays: elapsed,
      overloadDays: overload,
    );
  }
}
