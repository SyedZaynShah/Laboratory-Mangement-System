import 'package:flutter/material.dart';
import 'accent_card.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final Widget? valueWidget;
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accentColor,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      accentColor: accentColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                valueWidget ??
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
