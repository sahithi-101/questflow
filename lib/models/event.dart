class Event {
  // Not const: DateTime has no const constructor for the timestamp defaults.
  Event({
    required this.id,
    required this.title,
    required this.start,
    this.description = '',
    this.end,
    this.location,
    this.reminderOffsets = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime(1970),
        updatedAt = updatedAt ?? DateTime(1970);

  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime? end;
  final String? location;

  /// Minutes before the event to surface an in-app reminder.
  /// 0 = at event time, 10 = ten minutes before, 60 = one hour before.
  final List<int> reminderOffsets;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event copyWith({
    String? title,
    String? description,
    DateTime? start,
    Object? end = _sentinel,
    Object? location = _sentinel,
    List<int>? reminderOffsets,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end == _sentinel ? this.end : end as DateTime?,
      location: location == _sentinel ? this.location : location as String?,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const _sentinel = Object();
}
