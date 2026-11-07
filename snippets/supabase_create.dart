// Excerpt from lib/data/supabase_repositories.dart
// The Supabase implementation of TaskRepository. Insert with .select()
// returns the stored row, so the app keeps the database-generated UUID
// rather than a local placeholder id.

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this._client);
  final SupabaseClient _client;

  static Task fromRow(Map<String, dynamic> r) {
    return Task(
      id: r['id'] as String,
      title: r['title'] as String,
      description: (r['description'] ?? '') as String,
      deadline: DateTime.parse(r['deadline_at'] as String).toLocal(),
      priority:
          TaskPriority.values.firstWhere((p) => p.name == r['priority']),
      status: TaskStatus.values.firstWhere((s) => s.name == r['status']),
      completedAt: _ts(r['completed_at']),
    );
  }

  Map<String, dynamic> _toRow(Task t) => {
        'user_id': _client.auth.currentUser?.id, // RLS scope
        'title': t.title,
        'deadline_at': t.deadline.toUtc().toIso8601String(),
        'priority': t.priority.name,
        'status': t.status.name,
        'completed_at': t.completedAt?.toUtc().toIso8601String(),
      };

  @override
  Future<Task> create(Task task) async {
    final rows = await _client.from('tasks').insert(_toRow(task)).select();
    return fromRow(rows.first); // stored row with the real id
  }

  @override
  Future<void> update(Task task) async {
    await _client.from('tasks').update(_toRow(task)).eq('id', task.id);
  }
}
