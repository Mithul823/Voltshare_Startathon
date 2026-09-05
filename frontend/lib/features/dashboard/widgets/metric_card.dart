import 'package:flutter/material.dart';

import '../../../core/widgets/voltshare_ui.dart' as shared;

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title $value',
      child: shared.MetricCard(title: title, value: value, icon: icon),
    );
  }
}
