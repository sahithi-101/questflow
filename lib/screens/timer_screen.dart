import 'dart:async';

import 'package:flutter/material.dart';

import '../models/time_log.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../util/dates.dart';
import '../widgets/forms/confirm_delete.dart';
import '../widgets/status_view.dart';

/// Fourth destination: a focus stopwatch. Start, pause/resume, then end the
/// session and give the log a name. Logs appear here for today and on the
/// Tasks & Events agenda under the day they started.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One tick per second keeps the big clock moving while a session runs.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = context.getInheritedWidgetOfExactType<AppScope>()?.notifier;
      if (state != null && state.timerRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _endSession(AppState data) async {
    final name = await _askLogName();
    if (name == null || !mounted) return; // discarded
    final error = await data.endTimer(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Log saved.'),
      backgroundColor: error == null ? QfColors.moss : QfColors.madder,
    ));
  }

  /// Returns the chosen name, or null when the user discards the session.
  Future<String?> _askLogName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: QfColors.pith,
        title: const Text('Name this log'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'What did you work on?',
            hintText: 'e.g. DBMS assignment',
          ),
          onSubmitted: (v) =>
              Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Discard'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              onPressed:
                  value.text.trim().isEmpty ? null : () => Navigator.pop(
                        ctx,
                        value.text.trim(),
                      ),
              child: const Text('Save log'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context);
    if (data.status != LoadStatus.ready) {
      return const StatusView();
    }

    final elapsed = data.timerElapsed();
    final statusLabel = !data.timerRunning
        ? 'Ready'
        : data.timerPaused
            ? 'Paused'
            : 'Running';

    final todaysLogs = data.timeLogs
        .where((l) => sameDay(l.startedAt, data.now))
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final totalToday = todaysLogs.fold<DateTime>(
      DateTime(1970),
      (acc, l) => acc.add(l.duration),
    ).difference(DateTime(1970));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timer', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 28),
                // The stopwatch face. The surface animates between a calm
                // neutral when idle, a green tint while running and an
                // amber tint while paused (AnimatedContainer).
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  decoration: BoxDecoration(
                    color: !data.timerRunning
                        ? QfColors.pith
                        : data.timerPaused
                            ? Color.lerp(QfColors.pith, QfColors.gamboge, 0.12)
                            : Color.lerp(QfColors.pith, QfColors.moss, 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatClock(elapsed),
                        style: QfTheme.display(56, spacing: 2),
                      ),
                      const SizedBox(height: 8),
                      // Cross-fades between Ready / Running / Paused.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          statusLabel,
                          key: ValueKey<String>(statusLabel),
                          style: const TextStyle(
                            color: QfColors.bistreSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Controls(
                        running: data.timerRunning,
                        paused: data.timerPaused,
                        onStart: () => data.startTimer(),
                        onPause: () => data.pauseTimer(),
                        onResume: () => data.resumeTimer(),
                        onEnd: () => _endSession(data),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    Expanded(
                      child: Text("Today's logs",
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Text(
                      'Total ${formatDuration(totalToday)}',
                      style: const TextStyle(
                          color: QfColors.bistreSoft, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (todaysLogs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: QfColors.pith,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'No logs yet today. Start the timer to track '
                      'your first session.',
                      style: TextStyle(color: QfColors.bistreSoft),
                    ),
                  )
                else
                  for (final log in todaysLogs) ...[
                    _LogRow(
                      log: log,
                      onDelete: () => showConfirmDelete(
                        context,
                        kind: 'log',
                        title: log.title,
                        onDelete: () => data.deleteTimeLog(log.id),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.running,
    required this.paused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  final bool running;
  final bool paused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: paused ? onResume : onPause,
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          label: Text(paused ? 'Resume' : 'Pause'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: QfColors.madder),
          onPressed: onEnd,
          icon: const Icon(Icons.stop),
          label: const Text('End & log'),
        ),
      ],
    );
  }
}

/// One saved log: name, start–end time, and how long it ran.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.onDelete});

  final TimeLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = '${clock(log.startedAt)} – ${clock(log.endedAt)}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: QfColors.pith,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: QfColors.gamboge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.timer,
                          color: QfColors.gamboge, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.title,
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(time,
                                style: const TextStyle(
                                    color: QfColors.bistreSoft, fontSize: 14)),
                          ],
                        ),
                      ),
                      Text(
                        formatDuration(log.duration),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      IconButton(
                        tooltip: 'Delete this log',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: QfColors.bistreSoft,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
