import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/event.dart';
import '../models/task.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/dates.dart';
import '../widgets/add_chooser.dart';
import '../widgets/detail/event_detail.dart';
import '../widgets/detail/task_detail.dart';
import '../widgets/forms/event_form.dart';
import '../widgets/forms/task_form.dart';
import '../widgets/status_view.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.filter, this.add});

  /// 'tasks' | 'events' | 'overdue' | null
  final String? filter;

  /// 'task' | 'event' | null: open the add flow on arrival (from Home).
  final String? add;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected;
  late DateTime _month;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final data = AppScope.of(context);
    var start = dateOnly(data.now);
    if (widget.filter == 'overdue') {
      final overdue = data.tasks.where((t) => t.isOverdue(data.now)).toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
      if (overdue.isNotEmpty) start = dateOnly(overdue.first.deadline);
    }
    _selected = start;
    _month = DateTime(start.year, start.month);

    final add = widget.add;
    if (add == 'task' || add == 'event') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          add == 'task'
              ? showTaskForm(context)
              : showEventForm(context);
        }
      });
    }
  }

  List<Task> _tasksFor(AppState d) {
    switch (widget.filter) {
      case 'events':
        return const [];
      case 'overdue':
        return d.tasks.where((t) => t.isOverdue(d.now)).toList();
      default:
        return d.tasks;
    }
  }

  List<Event> _eventsFor(AppState d) {
    final f = widget.filter;
    return (f == 'tasks' || f == 'overdue') ? const [] : d.events;
  }

  String? get _filterLabel {
    switch (widget.filter) {
      case 'tasks':
        return 'Tasks only';
      case 'events':
        return 'Events only';
      case 'overdue':
        return 'Overdue tasks only';
      default:
        return null;
    }
  }

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  void _goToday(DateTime now) => setState(() {
        _selected = dateOnly(now);
        _month = DateTime(now.year, now.month);
      });

  Future<void> _add() async {
    final kind = await showAddChooser(context);
    if (kind == null || !mounted) return;
    switch (kind) {
      case AddKind.task:
        showTaskForm(context);
      case AddKind.event:
        showEventForm(context);
      case AddKind.quest:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context);
    if (data.status != LoadStatus.ready) {
      return const StatusView();
    }
    final tasks = _tasksFor(data);
    final events = _eventsFor(data);

    final calendar = _MonthGrid(
      month: _month,
      selected: _selected,
      now: data.now,
      tasks: tasks,
      events: events,
      onSelect: (d) => setState(() => _selected = d),
      onPrev: () => _shiftMonth(-1),
      onNext: () => _shiftMonth(1),
      onToday: () => _goToday(data.now),
    );
    final agenda = _Agenda(
      date: _selected,
      now: data.now,
      tasks: tasks.where((t) => sameDay(t.deadline, _selected)).toList(),
      events: events.where((e) => sameDay(e.start, _selected)).toList(),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Add a task or event',
        child: const Icon(Icons.add, size: 28),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final twoColumns = box.maxWidth >= 760;
          final pad = box.maxWidth >= 640 ? 40.0 : 20.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, pad >= 40 ? 40 : 24, pad, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasks & Events',
                        style: Theme.of(context).textTheme.headlineMedium),
                    if (_filterLabel != null) ...[
                      const SizedBox(height: 12),
                      InputChip(
                        label: Text(_filterLabel!),
                        onDeleted: () => context.go('/calendar'),
                        deleteButtonTooltipMessage: 'Show everything',
                        backgroundColor: QfColors.pith,
                        side: const BorderSide(color: QfColors.rule),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (twoColumns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 480, child: calendar),
                          const SizedBox(width: 40),
                          Expanded(child: agenda),
                        ],
                      )
                    else ...[
                      calendar,
                      const SizedBox(height: 28),
                      agenda,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.now,
    required this.tasks,
    required this.events,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime now;
  final List<Task> tasks;
  final List<Event> events;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // Monday-first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final total = ((lead + days) / 7).ceil() * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${monthLong(month.month)} ${month.year}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: onPrev,
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(onPressed: onToday, child: const Text('Today')),
            IconButton(
              onPressed: onNext,
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(l,
                      style: const TextStyle(
                          color: QfColors.bistreSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.92,
          children: [
            for (var i = 0; i < total; i++)
              if (i < lead || i >= lead + days)
                const SizedBox.shrink()
              else
                _buildDay(DateTime(month.year, month.month, i - lead + 1)),
          ],
        ),
        const SizedBox(height: 12),
        const _MarkerLegend(),
      ],
    );
  }

  Widget _buildDay(DateTime day) {
    final dayTasks = tasks.where((t) => sameDay(t.deadline, day)).toList();
    final dayEvents = events.where((e) => sameDay(e.start, day)).toList();
    return _DayCell(
      day: day,
      isSelected: sameDay(day, selected),
      isToday: sameDay(day, now),
      pendingTasks: dayTasks.where((t) => !t.isCompleted).length,
      doneTasks: dayTasks.where((t) => t.isCompleted).length,
      events: dayEvents.length,
      onTap: () => onSelect(day),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.pendingTasks,
    required this.doneTasks,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final int pendingTasks;
  final int doneTasks;
  final int events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? QfColors.pith : QfColors.bistre;
    final markers = <Widget>[
      if (pendingTasks > 0) _Marker.task(filled: true, onDark: isSelected),
      if (doneTasks > 0) _Marker.task(filled: false, onDark: isSelected),
      if (events > 0) _Marker.event(onDark: isSelected),
    ];
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${weekdayLong(day)} ${day.day} ${monthLong(day.month)}: '
          '${pendingTasks + doneTasks} tasks, $events events',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? QfColors.bistre : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isToday && !isSelected
                  ? Border.all(color: QfColors.gamboge, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Text('${day.day}',
                      style: QfTheme.display(16,
                          weight: isToday ? 700 : 500, color: fg, spacing: 0)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < markers.length; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        markers[i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tasks are squares (filled = pending, outlined = done); events are circles.
/// Shape carries the kind so colour is never the only signal.
class _Marker extends StatelessWidget {
  const _Marker.task({required this.filled, required this.onDark})
      : _isTask = true;
  const _Marker.event({required this.onDark})
      : _isTask = false,
        filled = true;

  final bool _isTask;
  final bool filled;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final base = _isTask ? QfColors.madder : QfColors.woad;
    // madder/woad are dark; on a bistre cell lift them to pith for contrast
    final color = onDark ? QfColors.pith : base;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(_isTask ? 2 : 4),
      ),
    );
  }
}

class _MarkerLegend extends StatelessWidget {
  const _MarkerLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget marker, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            marker,
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        item(const _Marker.task(filled: true, onDark: false), 'Pending task'),
        item(const _Marker.task(filled: false, onDark: false), 'Done task'),
        item(const _Marker.event(onDark: false), 'Event'),
      ],
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.date,
    required this.now,
    required this.tasks,
    required this.events,
  });

  final DateTime date;
  final DateTime now;
  final List<Task> tasks;
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    // One chronological list: tasks by deadline, events by start.
    final rows = <({DateTime at, Widget row})>[
      for (final t in tasks)
        (
          at: t.deadline,
          row: _TaskRow(
            task: t,
            now: now,
            onTap: () => showTaskDetail(context, t),
          ),
        ),
      for (final e in events)
        (
          at: e.start,
          row: _EventRow(
            event: e,
            onTap: () => showEventDetail(context, e),
          ),
        ),
    ]..sort((a, b) => a.at.compareTo(b.at));

    final relative = dayLabel(date, now);
    final named = relative == 'Today' ||
        relative == 'Tomorrow' ||
        relative == 'Yesterday';
    final heading = '${named ? '$relative, ' : ''}'
        '${weekdayLong(date)} ${date.day} ${monthLong(date.month)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: QfColors.pith,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Nothing on this day. Use + to add a task or an event.',
              style: TextStyle(color: QfColors.bistreSoft),
            ),
          )
        else
          for (final r in rows) ...[r.row, const SizedBox(height: 8)],
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingColor,
    this.struck = false,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final Color? trailingColor;
  final bool struck;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: QfColors.pith,
        child: IntrinsicHeight(
          child: InkWell(
            onTap: onTap,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    decoration:
                                        struck ? TextDecoration.lineThrough : null,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: QfColors.bistreSoft, fontSize: 14)),
                          ],
                        ),
                      ),
                      if (trailing != null)
                        Text(trailing!,
                            style: TextStyle(
                                color: trailingColor ?? QfColors.bistre,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.now, this.onTap});
  final Task task;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue(now);
    final priority = switch (task.priority) {
      TaskPriority.high => 'high priority',
      TaskPriority.medium => 'medium priority',
      TaskPriority.low => 'low priority',
    };
    return _AgendaRow(
      color: QfColors.madder,
      icon: task.isCompleted ? Icons.task_alt : Icons.check_box_outline_blank,
      title: task.title,
      subtitle: 'Due ${clock(task.deadline)}, $priority',
      struck: task.isCompleted,
      trailing: overdue ? 'Overdue' : (task.isCompleted ? 'Done' : null),
      trailingColor: overdue ? QfColors.madder : QfColors.moss,
      onTap: onTap,
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.onTap});
  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = event.end == null
        ? clock(event.start)
        : '${clock(event.start)} to ${clock(event.end!)}';
    return _AgendaRow(
      color: QfColors.woad,
      icon: Icons.event,
      title: event.title,
      subtitle: event.location == null ? time : '$time, ${event.location}',
      onTap: onTap,
    );
  }
}
