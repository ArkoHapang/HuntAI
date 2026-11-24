import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryCard : const Color(0xFFEEF4FF),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFD8E5FF),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fictional sample data only. No live monitoring or external services.',
            ),
          ),
        ],
      ),
    );
  }
}
