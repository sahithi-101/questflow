import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/quest.dart';
import '../models/task.dart';
import '../util/dates.dart';
import 'repositories.dart';

/// Supabase-backed repositories implementing the same interfaces as the
/// in-memory ones. RLS scopes every query to the signed-in user, so the
/// repositories never filter by hand.
///
/// Row shapes follow supabase/schema.sql.

DateTime? _ts(dynamic v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this._client);
  final SupabaseClient _client;

  static Task fromRow(Map<String, dynamic> r) {
    return Task(
      id: r['id'] as String,
      title: r['title'] as String,
      description: (r['description'] ?? '') as String,
      category: (r['category'] ?? '') as String,
      deadline: DateTime.parse(r['deadline_at'] as String).toLocal(),
      priority: TaskPriority
          .values.firstWhere((p) => p.name == r['priority']),
      status:
          TaskStatus.values.firstWhere((s) => s.name == r['status']),
      createdAt: _ts(r['created_at']) ?? DateTime(1970),
      updatedAt: _ts(r['updated_at']) ?? DateTime(1970),
      completedAt: _ts(r['completed_at']),
    );
  }

  Map<String, dynamic> _toRow(Task t) => {
        'user_id': _client.auth.currentUser?.id,
        'title': t.title,
        'description': t.description,
        'category': t.category,
        'deadline_at': t.deadline.toUtc().toIso8601String(),
        'priority': t.priority.name,
        'status': t.status.name,
        'completed_at': t.completedAt?.toUtc().toIso8601String(),
      };

  @override
  Future<List<Task>> list() async {
    final rows =
        await _client.from('tasks').select().order('deadline_at');
    return [for (final r in rows) fromRow(r)];
  }

  @override
  Future<Task> create(Task task) async {
    final rows = await _client.from('tasks').insert(_toRow(task)).select();
    return fromRow(rows.first);
  }

  @override
  Future<void> update(Task task) async {
    await _client.from('tasks').update(_toRow(task)).eq('id', task.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }
}

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository(this._client);
  final SupabaseClient _client;

  static Event fromRow(Map<String, dynamic> r) {
    return Event(
      id: r['id'] as String,
      title: r['title'] as String,
      description: (r['description'] ?? '') as String,
      start: DateTime.parse(r['starts_at'] as String).toLocal(),
      end: r['ends_at'] == null
          ? null
          : DateTime.parse(r['ends_at'] as String).toLocal(),
      location: r['location'] as String?,
      reminderOffsets: [
        for (final v in (r['reminder_offsets'] as List? ?? const [])) v as int,
      ],
      createdAt: _ts(r['created_at']) ?? DateTime(1970),
      updatedAt: _ts(r['updated_at']) ?? DateTime(1970),
    );
  }

  Map<String, dynamic> _toRow(Event e) => {
        'user_id': _client.auth.currentUser?.id,
        'title': e.title,
        'description': e.description,
        'starts_at': e.start.toUtc().toIso8601String(),
        'ends_at': e.end?.toUtc().toIso8601String(),
        'location': (e.location == null || e.location!.isEmpty)
            ? null
            : e.location,
        'reminder_offsets': e.reminderOffsets,
      };

  @override
  Future<List<Event>> list() async {
    final rows =
        await _client.from('events').select().order('starts_at');
    return [for (final r in rows) fromRow(r)];
  }

  @override
  Future<Event> create(Event event) async {
    final rows = await _client.from('events').insert(_toRow(event)).select();
    return fromRow(rows.first);
  }

  @override
  Future<void> update(Event event) async {
    await _client.from('events').update(_toRow(event)).eq('id', event.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('events').delete().eq('id', id);
  }
}

class SupabaseQuestRepository implements QuestRepository {
  SupabaseQuestRepository(this._client);
  final SupabaseClient _client;

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.parse(v);
    return 0;
  }

  /// '2026-10-26' -> local midnight, never shifted by timezone conversion.
  static DateTime _date(String s) => DateTime.parse(s);

  static String _dateValue(DateTime d) {
    final n = dateOnly(d);
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static Quest fromRow(
      Map<String, dynamic> r, Iterable<Map<String, dynamic>> recordRows) {
    final mode = r['tracking_mode'] == 'numeric'
        ? TrackingMode.numeric
        : TrackingMode.binary;
    final records = <DateTime, double>{};
    for (final rec in recordRows) {
      final date = _date(rec['record_date'] as String);
      final isBinary = mode == TrackingMode.binary;
      final value = isBinary
          ? ((rec['binary_completed'] ?? false) as bool ? 1.0 : 0.0)
          : _num(rec['recorded_value']);
      records[date] = value;
    }
    return Quest(
      id: r['id'] as String,
      title: r['title'] as String,
      description: (r['description'] ?? '') as String,
      mode: mode,
      unit: (r['unit'] ?? '') as String,
      dailyTarget: _num(r['daily_target']),
      upperLimit: r['upper_limit'] == null ? null : _num(r['upper_limit']),
      startsOn: _date(r['starts_on'] as String),
      endsOn: _date(r['ends_on'] as String),
      records: records,
      archivedAt: _ts(r['archived_at']),
      createdAt: _ts(r['created_at']) ?? DateTime(1970),
      updatedAt: _ts(r['updated_at']) ?? DateTime(1970),
    );
  }

  Map<String, dynamic> _toRow(Quest q) => {
        'user_id': _client.auth.currentUser?.id,
        'title': q.title,
        'description': q.description,
        'tracking_mode': q.mode.name,
        'unit': q.isNumeric ? q.unit : '',
        'daily_target': q.dailyTarget,
        'upper_limit': q.isNumeric ? q.upperLimit : null,
        'starts_on': _dateValue(q.startsOn),
        'ends_on': _dateValue(q.endsOn),
        'archived_at': q.archivedAt?.toUtc().toIso8601String(),
      };

  @override
  Future<List<Quest>> list() async {
    final questRows = await _client
        .from('quests')
        .select()
        .order('created_at', ascending: true);
    final recordRows =
        await _client.from('quest_daily_records').select();
    final byQuest = <String, List<Map<String, dynamic>>>{};
    for (final rec in recordRows) {
      byQuest.putIfAbsent(rec['quest_id'] as String, () => []).add(rec);
    }
    return [
      for (final q in questRows)
        fromRow(q, byQuest[q['id'] as String] ?? const []),
    ];
  }

  @override
  Future<Quest> create(Quest quest) async {
    final rows = await _client.from('quests').insert(_toRow(quest)).select();
    final realId = rows.first['id'] as String;
    // Any pre-filled records are written under the database id.
    for (final entry in quest.records.entries) {
      await _upsertRecord(realId, entry.key, entry.value);
    }
    return Quest(
      id: realId,
      title: quest.title,
      description: quest.description,
      mode: quest.mode,
      unit: quest.unit,
      dailyTarget: quest.dailyTarget,
      upperLimit: quest.upperLimit,
      startsOn: quest.startsOn,
      endsOn: quest.endsOn,
      records: quest.records,
      archivedAt: quest.archivedAt,
      createdAt: quest.createdAt,
      updatedAt: quest.updatedAt,
    );
  }

  @override
  Future<void> update(Quest quest) async {
    await _client.from('quests').update(_toRow(quest)).eq('id', quest.id);
  }

  @override
  Future<void> delete(String id) async {
    // Records cascade in the database, but delete them explicitly too so the
    // call works even without the composite FK cascade.
    await _client.from('quest_daily_records').delete().eq('quest_id', id);
    await _client.from('quests').delete().eq('id', id);
  }

  @override
  Future<void> setRecord(String questId, DateTime date, double? value) async {
    await _upsertRecord(questId, date, value);
  }

  Future<void> _upsertRecord(
      String questId, DateTime date, double? value) async {
    final d = dateOnly(date);
    if (value == null) {
      await _client
          .from('quest_daily_records')
          .delete()
          .eq('quest_id', questId)
          .eq('record_date', _dateValue(d));
      return;
    }
    final row = {
      'user_id': _client.auth.currentUser?.id,
      'quest_id': questId,
      'record_date': _dateValue(d),
      'recorded_value': value,
      'binary_completed': value >= 1,
    };
    await _client
        .from('quest_daily_records')
        .upsert(row, onConflict: 'quest_id,record_date');
  }
}

/// The bundle used in cloud mode.
RepositoryBundle supabaseBundle(SupabaseClient client) => RepositoryBundle(
      tasks: SupabaseTaskRepository(client),
      events: SupabaseEventRepository(client),
      quests: SupabaseQuestRepository(client),
    );
