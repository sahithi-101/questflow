// Excerpt from lib/screens/timer_screen.dart
// The stopwatch face recolours itself with AnimatedContainer as the session
// state changes (neutral when idle, green tint while running, amber tint
// while paused), and AnimatedSwitcher cross-fades the status label.

// The stopwatch face. The surface animates between a calm neutral when
// idle, a green tint while running and an amber tint while paused.
AnimatedContainer(
  duration: const Duration(milliseconds: 350),
  curve: Curves.easeOut,
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
      Text(formatClock(elapsed), style: QfTheme.display(56, spacing: 2)),
      // Cross-fades between Ready / Running / Paused.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          statusLabel,
          key: ValueKey<String>(statusLabel),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // ...
    ],
  ),
);

// The calendar's day cells use the same idea: selecting a day glides
// instead of snapping.
AnimatedContainer(
  duration: const Duration(milliseconds: 180),
  curve: Curves.easeOut,
  decoration: BoxDecoration(
    color: isSelected ? QfColors.bistre : Colors.transparent,
    borderRadius: BorderRadius.circular(4),
  ),
);
