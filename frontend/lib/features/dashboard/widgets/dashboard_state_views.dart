import 'package:flutter/material.dart';

class DashboardEmptyView extends StatelessWidget {
  const DashboardEmptyView({required this.onRefresh, super.key});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.sensors_off_outlined,
      title: 'No smart-meter readings yet',
      message:
          'VoltShare could not find simulated meter readings for this session. Refresh to request a new energy snapshot.',
      actionLabel: 'Refresh',
      onAction: onRefresh,
    );
  }
}

class DashboardErrorView extends StatelessWidget {
  const DashboardErrorView({
    this.message = 'We could not load the live dashboard right now.',
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.error_outline,
      title: 'Energy readings unavailable',
      message: message,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
