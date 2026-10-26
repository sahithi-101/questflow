import '../util/dates.dart';

enum TrackingMode { binary, numeric }

/// State of one quest day, calculated from the stored value (spec 4.2).
/// The recorded value itself is never altered.
enum DayState { outside, future, none, partial, target, over }

class Quest {
  // Not const: DateTime has no const constructor for the timestamp defaults.
  Quest({
    required this.id,
    required this.title,
    required this.mode,
    required this.startsOn,
    required this.endsOn,
    required this.records,
    this.description = '',
    this.unit = '',
    this.dailyTarget = 1,
    this.upperLimit,
    this.archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime(1970),
        updatedAt = updatedAt ?? DateTime(1970);

  final String id;
  final String title;
  final String description;
  final TrackingMode mode;
  final String unit;

  /// Binary quests use 1. Numeric quests use the user-defined target.
  final double dailyTarget;
  final double? upperLimit;

  /// Calendar dates (date-only), inclusive.
  final DateTime startsOn;
  final DateTime endsOn;

  /// Set when the quest is archived; history is kept, day editing stops.
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// One value per date. Binary: 1 = done. Missing key = no record.
  final Map<DateTime, double> records;

  bool get isNumeric => mode == TrackingMode.numeric;
  bool get isArchived => archivedAt != null;

  double valueOn(DateTime date) => records[dateOnly(date)] ?? 0;

  bool isEligible(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(startsOn) && !d.isAfter(endsOn);
  }

  bool isSuccess(DateTime date) => valueOn(date) >= dailyTarget;

  DayState stateOn(DateTime date, DateTime today) {
    final d = dateOnly(date);
    if (!isEligible(d)) return DayState.outside;
    if (d.isAfter(dateOnly(today))) return DayState.future;
    final v = valueOn(d);
    if (v <= 0) return DayState.none;
    if (!isNumeric) return DayState.target;
    if (v < dailyTarget) return DayState.partial;
    if (v == dailyTarget) return DayState.target;
    return DayState.over;
  }

  Quest copyWith({
    String? title,
    String? description,
    String? unit,
    double? dailyTarget,
    Object? upperLimit = _sentinel,
    DateTime? startsOn,
    DateTime? endsOn,
    Map<DateTime, double>? records,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? updatedAt,
  }) {
    return Quest(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      mode: mode,
      unit: unit ?? this.unit,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      upperLimit:
          upperLimit == _sentinel ? this.upperLimit : upperLimit as double?,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn ?? this.endsOn,
      records: records ?? this.records,
      archivedAt:
          clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const _sentinel = Object();
}
