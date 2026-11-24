import 'package:flutter/material.dart';

import '../../core/constants/soc_constants.dart';
import '../../core/theme/app_colors.dart';

class SocSidebar extends StatelessWidget {
  const SocSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.expanded = true,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool expanded;

  static const _destinations = [
    ('Dashboard', Icons.space_dashboard_outlined),
    ('Threat analysis', Icons.query_stats_outlined),
    ('Alerts', Icons.warning_amber_rounded),
    ('Telemetry', Icons.receipt_long_outlined),
    ('Attack chain', Icons.account_tree_outlined),
    ('Investigations', Icons.folder_open_outlined),
    ('Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded
          ? SocConstants.sidebarWidth
          : SocConstants.compactSidebarWidth,
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment:
              expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(expanded ? 20 : 0, 20, 12, 24),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const _BrandIcon(),
                  if (expanded) ...[
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HuntAI',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Smart Threat Hunting',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (expanded)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 12, 10),
                child: Text(
                  'WORKSPACE',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            for (var index = 0; index < _destinations.length; index++)
              _NavigationItem(
                label: _destinations[index].$1,
                icon: _destinations[index].$2,
                selected: selectedIndex == index,
                expanded: expanded,
                onTap: () => onDestinationSelected(index),
              ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(expanded ? 16 : 8, 10, 8, 8),
              child: _FooterStatus(expanded: expanded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(11),
      ),
      child:
          const Icon(Icons.shield_outlined, color: AppColors.orange, size: 23),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.orange : AppColors.secondaryText;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 9, vertical: 3),
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: selected
              ? AppColors.orange.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: EdgeInsets.symmetric(horizontal: expanded ? 11 : 0),
              decoration: selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                        left: BorderSide(color: AppColors.orange, width: 3),
                      ),
                    )
                  : null,
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: foreground),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterStatus extends StatelessWidget {
  const _FooterStatus({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(expanded ? 12 : 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: expanded
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.orange),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Engine not connected',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.secondaryCard,
                      child: Icon(Icons.person_outline,
                          size: 18, color: AppColors.primaryText),
                    ),
                    SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo analyst',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Local session',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : const Tooltip(
              message: 'Engine not connected · Demo analyst',
              child: Icon(Icons.circle, size: 9, color: AppColors.orange),
            ),
    );
  }
}
