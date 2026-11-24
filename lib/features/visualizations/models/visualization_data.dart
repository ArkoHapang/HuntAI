import '../../../data/demo_data.dart';

class TimelinePoint {
  const TimelinePoint({
    required this.label,
    required this.counts,
  });

  final String label;
  final Map<Severity, int> counts;

  int get total => counts.values.fold(0, (sum, count) => sum + count);
}

class HeatmapCellData {
  const HeatmapCellData({
    required this.category,
    required this.period,
    required this.counts,
  });

  final String category;
  final String period;
  final Map<Severity, int> counts;

  int get total => counts.values.fold(0, (sum, count) => sum + count);
}
