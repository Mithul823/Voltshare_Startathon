import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// =========================================================================
// Spacing & Layout Constants
// =========================================================================

class AppInsets {
  static const double outer = 16;
  static const double section = 24;
  static const double card = 16;
  static const double chip = 8;
  static const double element = 12;
  static const double item = 8;

  static const EdgeInsets page = EdgeInsets.fromLTRB(outer, 16, outer, 24);
  static const EdgeInsets cardPadding = EdgeInsets.all(card);
  static const EdgeInsets cardCompact = EdgeInsets.all(14);
}

class AppTypography {
  static const String fontFamily = '';

  static TextStyle pageTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 22,
    ) ?? const TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ) ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  }

  static TextStyle userName(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ) ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  }

  static const TextStyle body = TextStyle(fontSize: 14);
  static const TextStyle caption = TextStyle(fontSize: 12);
}

// =========================================================================
// Responsive Page
// =========================================================================

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    required this.child,
    this.padding = AppInsets.page,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: padding, children: [child]),
        ),
      ),
    );
  }
}

// =========================================================================
// App Bar / Page Header
// =========================================================================

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBackButton = true,
    this.fallbackRoute = '/dashboard',
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) ...[
            SizedBox(
              height: 44,
              width: 44,
              child: IconButton.filledTonal(
                tooltip: 'Back',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(fallbackRoute);
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          ...actions,
        ],
      ),
    );
  }
}

// =========================================================================
// Section Header
// =========================================================================

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.action,
    super.key,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.sectionTitle(context),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// =========================================================================
// Energy Gauge
// =========================================================================

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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 228,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(208, 208),
            painter: _GaugePainter(
              progress: progress.clamp(0, 1),
              color: colorScheme.primary,
              trackColor: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.09;
    final start = math.pi * 0.78;
    final sweep = math.pi * 1.44;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    paint.color = trackColor;
    canvas.drawArc(rect.deflate(stroke), start, sweep, false, paint);
    paint.color = color;
    canvas.drawArc(rect.deflate(stroke), start, sweep * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

// =========================================================================
// Battery Status
// =========================================================================

class BatteryStatus extends StatelessWidget {
  const BatteryStatus({
    required this.percentage,
    required this.status,
    super.key,
  });

  final int percentage;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(
          percentage >= 80
              ? Icons.battery_full_outlined
              : Icons.battery_5_bar_outlined,
          color: colorScheme.primary,
          size: 42,
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage%',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(status, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// =========================================================================
// Metric Card
// =========================================================================

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
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: AppInsets.cardCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Buttons
// =========================================================================

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

// =========================================================================
// Bottom Navigation Bar (Redesigned)
// =========================================================================

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination>? destinations;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      animationDuration: const Duration(milliseconds: 300),
      onDestinationSelected: onDestinationSelected,
      destinations: destinations ?? _defaultDestinations,
    );
  }
}

const List<NavigationDestination> _defaultDestinations = [
  NavigationDestination(
    icon: Icon(Icons.home_outlined, size: 24),
    selectedIcon: Icon(Icons.home, size: 24),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.storefront_outlined, size: 24),
    selectedIcon: Icon(Icons.storefront, size: 24),
    label: 'Market',
  ),
  NavigationDestination(
    icon: Icon(Icons.account_balance_wallet_outlined, size: 24),
    selectedIcon: Icon(Icons.account_balance_wallet, size: 24),
    label: 'Wallet',
  ),
  NavigationDestination(
    icon: Icon(Icons.analytics_outlined, size: 24),
    selectedIcon: Icon(Icons.analytics, size: 24),
    label: 'Analytics',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline, size: 24),
    selectedIcon: Icon(Icons.person, size: 24),
    label: 'Profile',
  ),
];

// =========================================================================
// Seller Card (Horizontal card for listings)
// =========================================================================

class SellerCard extends StatelessWidget {
  const SellerCard({
    required this.sellerName,
    required this.energyAvailable,
    required this.pricePerKwh,
    required this.distance,
    required this.rating,
    required this.onBuy,
    super.key,
  });

  final String sellerName;
  final String energyAvailable;
  final String pricePerKwh;
  final String distance;
  final String rating;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: AppInsets.cardCompact,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.solar_power_outlined,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sellerName, style: AppTypography.userName(context)),
                  const SizedBox(height: 2),
                  Text('Selling: $energyAvailable', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    pricePerKwh,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('$distance away • $rating rating', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton(onPressed: onBuy, child: const Text('Buy')),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Filter Chip Item
// =========================================================================

class FilterChipItem extends StatelessWidget {
  const FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}

// =========================================================================
// Transaction Timeline Item
// =========================================================================

class TransactionTimelineItem extends StatelessWidget {
  const TransactionTimelineItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
    super.key,
  });

  final String title;
  final String date;
  final String amount;
  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountColor = isCredit ? colorScheme.primary : colorScheme.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary,
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                size: 18,
                color: colorScheme.onPrimary,
              ),
            ),
            Container(width: 2, height: 34, color: colorScheme.outlineVariant),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(date, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// Profile Info Tile
// =========================================================================

class ProfileInfoTile extends StatelessWidget {
  const ProfileInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(label),
        subtitle: Text(value.isEmpty ? 'Not provided' : value),
      ),
    );
  }
}

// =========================================================================
// Weekly Energy Chart
// =========================================================================

class WeeklyEnergyChart extends StatelessWidget {
  const WeeklyEnergyChart({required this.values, super.key});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          color: colorScheme.primary,
          fillColor: colorScheme.primary.withValues(alpha: 0.14),
          gridColor: colorScheme.outlineVariant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.color,
    required this.fillColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final chartRect = Rect.fromLTWH(4, 8, size.width - 8, size.height - 34);
    final maxValue = values.reduce(math.max);
    final range = math.max(maxValue, 1);
    final stepX = values.length == 1 ? 0 : chartRect.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          chartRect.left + stepX * i,
          chartRect.bottom - ((values[i]) / range) * chartRect.height,
        ),
    ];

    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) path.lineTo(point.dx, point.dy);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final textStyle = TextStyle(color: Colors.grey.shade700, fontSize: 11);
    for (var i = 0; i < math.min(labels.length, points.length); i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartRect.bottom + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor || oldDelegate.gridColor != gridColor;
  }
}
