import 'package:flutter/material.dart';

import '../../../core/widgets/voltshare_ui.dart' as shared;

class EnergyGauge extends StatelessWidget {
  const EnergyGauge({
    required this.value,
    required this.label,
    required this.progress,
    super.key,
  });

  final String value;
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, _) {
          return shared.EnergyGauge(
            value: value,
            label: label,
            progress: animatedProgress,
          );
        },
      ),
    );
  }
}
