enum TaskPriority { low, medium, high }

/// Overdue is derived (see [Task.isOverdue]), never stored.
enum TaskStatus { pending, completed }

class Task {
  // Not const: DateTime has no const constructor for the timestamp defaults.
  Task({
    required this.id,
    required this.title,
    required this.deadline,
    this.description = '',
    this.category = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : createdAt = createdAt ?? DateTime(1970),
        updatedAt = updatedAt ?? DateTime(1970);

  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime deadline;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set when the task was completed; cleared when reopened.
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool isOverdue(DateTime now) => !isCompleted && deadline.isBefore(now);

  Task copyWith({
    String? title,
    String? description,
    String? category,
    DateTime? deadline,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
