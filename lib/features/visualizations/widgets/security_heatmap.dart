import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import '../models/visualization_data.dart';
import '../services/visualization_data_service.dart';

class SecurityHeatmap extends StatefulWidget {
  const SecurityHeatmap({
    this.service = const VisualizationDataService(),
    super.key,
  });

  final VisualizationDataService service;

  @override
  State<SecurityHeatmap> createState() => _SecurityHeatmapState();
}

class _SecurityHeatmapState extends State<SecurityHeatmap> {
  String _range = '24h';
  HeatmapCellData? _selected;

  @override
  Widget build(BuildContext context) {
    final cells = widget.service.heatmap(_range);
    final byCategory = {
      for (final category in VisualizationDataService.categories)
        category: cells.where((cell) => cell.category == category).toList(),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Security event heatmap',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const Tooltip(
                  message:
                      'Synthetic aggregate counts; no event records are generated.',
                  child: Icon(Icons.info_outline, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Illustrative category intensity · synthetic aggregates',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              children: [
                for (final range in ['1h', '24h', '7d', '30d'])
                  ChoiceChip(
                    label: Text(range),
                    selected: _range == range,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _range = range;
                      _selected = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final labelWidth = constraints.maxWidth < 420 ? 100.0 : 132.0;
                final cellWidth =
                    ((constraints.maxWidth - labelWidth) / 6).clamp(22.0, 60.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: labelWidth),
                          for (final period in VisualizationDataService.periods)
                            SizedBox(
                              width: cellWidth,
                              child: Center(
                                child: Text(
                                  period,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      for (final category
                          in VisualizationDataService.categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: labelWidth,
                                child: Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              for (final cell in byCategory[category]!)
                                SizedBox(
                                  width: cellWidth,
                                  height: 27,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: _HeatCell(
                                      data: cell,
                                      selected: _selected?.category ==
                                              cell.category &&
                                          _selected?.period == cell.period,
                                      onTap: () =>
                                          setState(() => _selected = cell),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Intensity',
                    style: Theme.of(context).textTheme.labelSmall),
                for (final level in [
                  (label: '0', color: AppColors.secondaryCard),
                  (label: '1–2', color: AppColors.green.withValues(alpha: .35)),
                  (label: '3–5', color: AppColors.green.withValues(alpha: .65)),
                  (label: '6+', color: AppColors.green),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: level.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(level.label,
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _selected == null
                  ? Text(
                      'Select a cell for its aggregate breakdown.',
                      key: const ValueKey('heatmap-empty-selection'),
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  : _HeatmapSelection(
                      key: ValueKey(
                          'heatmap-${_selected!.category}-${_selected!.period}'),
                      cell: _selected!,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final HeatmapCellData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = data.total == 0
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : AppColors.green.withValues(
            alpha: (0.25 + data.total.clamp(1, 8) * .09).clamp(0.0, .95),
          );
    return Tooltip(
      message: '${data.category} · ${data.period}:00 · ${data.total} events',
      child: Semantics(
        button: true,
        label: '${data.category}, ${data.period}:00, ${data.total} events',
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor.withValues(alpha: .5),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  data.total == 0 ? '·' : '${data.total}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapSelection extends StatelessWidget {
  const _HeatmapSelection({required this.cell, super.key});

  final HeatmapCellData cell;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: key,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          '${cell.category} · ${cell.period}:00',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text('Total ${cell.total}',
            style: Theme.of(context).textTheme.labelMedium),
        for (final severity in Severity.values)
          Text(
            '${severity.label} ${cell.counts[severity] ?? 0}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: severity.color),
          ),
      ],
    );
  }
}
