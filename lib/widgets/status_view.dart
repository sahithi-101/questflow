import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/palette.dart';

/// Full-area loading, error and empty states used by the three screens
/// (spec 6.2 / acceptance: "loading, empty, error and sync-failure states").
class StatusView extends StatelessWidget {
  const StatusView({super.key, this.emptyMessage});

  /// When provided, a ready-but-empty collection shows this message
  /// instead of the normal content.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    switch (state.status) {
      case LoadStatus.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(color: QfColors.moss),
          ),
        );
      case LoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 40, color: QfColors.bistreSoft),
                const SizedBox(height: 12),
                Text(
                  state.errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: QfColors.bistreSoft),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      case LoadStatus.ready:
        if (emptyMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(emptyMessage!,
                  style: const TextStyle(color: QfColors.bistreSoft)),
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }
}

/// Slim banner for a failed save/delete, dismissible. Rendered by AppShell.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: QfColors.madder,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: QfColors.pith, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(color: QfColors.pith, fontSize: 14)),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, color: QfColors.pith, size: 18),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
