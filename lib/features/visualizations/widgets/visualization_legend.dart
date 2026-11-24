import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';

class VisualizationLegend extends StatelessWidget {
  const VisualizationLegend({
    required this.severities,
    this.selected,
    this.onSelected,
    super.key,
  });

  final List<Severity> severities;
  final Set<Severity>? selected;
  final ValueChanged<Severity>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final severity in severities)
          InkWell(
            onTap: onSelected == null ? null : () => onSelected!(severity),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: selected == null || selected!.contains(severity)
                          ? severity.color
                          : severity.color.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    severity.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              selected == null || selected!.contains(severity)
                                  ? null
                                  : Theme.of(context).disabledColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
