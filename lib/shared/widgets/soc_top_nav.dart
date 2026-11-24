import 'package:flutter/material.dart';

import '../../core/constants/soc_constants.dart';
import '../../core/theme/app_colors.dart';

class SocTopNav extends StatelessWidget {
  const SocTopNav({
    required this.title,
    required this.isDark,
    required this.unreadCount,
    required this.onMenuTap,
    required this.onThemeTap,
    required this.onAlertsTap,
    required this.onSettingsTap,
    required this.onThreatAnalysisTap,
    required this.onSearch,
    this.showMenuButton = false,
    super.key,
  });

  final String title;
  final bool isDark;
  final int unreadCount;
  final VoidCallback onMenuTap;
  final VoidCallback onThemeTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onThreatAnalysisTap;
  final ValueChanged<String> onSearch;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < SocConstants.fullTopNavBreakpoint;
    final narrow = width < SocConstants.mobileBreakpoint;
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              tooltip: 'Open navigation',
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu),
            ),
          if (!narrow) ...[
            Text(
              'Security Monitoring',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!compact) ...[
              const SizedBox(width: 21),
              _NavLink(label: 'Threat Analysis', onTap: onThreatAnalysisTap),
              const SizedBox(width: 16),
              _NavLink(label: 'Incident Reports', onTap: onAlertsTap),
            ],
          ] else
            Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          if (!compact) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _ThreatSearchField(onSubmitted: onSearch),
            ),
          ] else
            const Spacer(),
          if (compact)
            IconButton(
              tooltip: 'Search sample alerts',
              onPressed: () => _showMobileSearch(context),
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: 'Open alerts',
            onPressed: onAlertsTap,
            icon: _NotificationIcon(count: unreadCount),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            onPressed: onThemeTap,
            icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          if (width >= 420)
            PopupMenuButton<String>(
              tooltip: 'Demo analyst menu',
              onSelected: (value) {
                if (value == 'settings') onSettingsTap();
                if (value == 'profile') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Demo analyst · no account is connected.'),
                    ),
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_outline),
                    title: Text('Demo analyst'),
                    subtitle: Text('Local demo profile'),
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Settings'),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.person_outline, size: 19),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showMobileSearch(BuildContext context) async {
    final query = await showDialog<String>(
      context: context,
      builder: (context) => const _MobileAlertSearchDialog(),
    );
    if (query != null) onSearch(query);
  }
}

class _MobileAlertSearchDialog extends StatefulWidget {
  const _MobileAlertSearchDialog();

  @override
  State<_MobileAlertSearchDialog> createState() =>
      _MobileAlertSearchDialogState();
}

class _MobileAlertSearchDialogState extends State<_MobileAlertSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search sample alerts'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: const InputDecoration(
          hintText: 'Title, alert ID, source, or stage',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Search'),
        ),
      ],
    );
  }
}

class _ThreatSearchField extends StatefulWidget {
  const _ThreatSearchField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_ThreatSearchField> createState() => _ThreatSearchFieldState();
}

class _ThreatSearchFieldState extends State<_ThreatSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search sample alerts',
          prefixIcon: const Icon(Icons.search, size: 19),
          suffixIcon: IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              _controller.clear();
              widget.onSubmitted('');
            },
            icon: const Icon(Icons.close, size: 17),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_outlined),
        if (count > 0)
          Positioned(
            right: -7,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondaryText,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }
}
