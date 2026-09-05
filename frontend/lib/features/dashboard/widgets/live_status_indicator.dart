import 'package:flutter/material.dart';

class LiveStatusIndicator extends StatelessWidget {
  const LiveStatusIndicator({required this.lastUpdated, super.key});

  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(lastUpdated);
    final formatted = time.format(context);

    return Semantics(
      label: 'Live energy readings. Last updated $formatted',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 9,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                'Live • $formatted',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
