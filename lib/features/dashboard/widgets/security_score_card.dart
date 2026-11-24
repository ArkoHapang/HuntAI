import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import 'dashboard_panel.dart';

class SecurityScoreCard extends StatelessWidget {
  const SecurityScoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleScore = demoAlerts
        .map((alert) => alert.score)
        .reduce((first, second) => first > second ? first : second);
    return DashboardPanel(
      title: 'Security score',
      icon: Icons.speed_outlined,
      trailing: const Icon(Icons.info_outline, size: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                '$sampleScore',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5, bottom: 5),
                child: Text('/ 100 · demo priority score',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: sampleScore / 100,
              minHeight: 8,
              color: AppColors.orange,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Illustrative score based on the highest sample alert. It does not measure or prove the security of an environment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 13),
          const _ScoreSignal(
            label: 'Repeated login failures',
            points: '+35',
          ),
          const _ScoreSignal(
            label: 'Successful login after failures',
            points: '+30',
          ),
          const _ScoreSignal(
            label: 'Unusual activity time',
            points: '+27',
          ),
        ],
      ),
    );
  }
}

class _ScoreSignal extends StatelessWidget {
  const _ScoreSignal({required this.label, required this.points});

  final String label;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.add, size: 15),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(points, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
