/// One focus-timer session the user chose to keep: what they worked on and
/// when. Duration is derived, never stored, so it cannot drift from the
/// timestamps.
class TimeLog {
  TimeLog({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime(1970),
        updatedAt = updatedAt ?? DateTime(1970);

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration => endedAt.difference(startedAt);

  TimeLog copyWith({
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? updatedAt,
  }) {
    return TimeLog(
      id: id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
