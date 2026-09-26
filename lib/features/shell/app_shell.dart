import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';

/// Navigation target for an [AppShell].
class AppShellDestination {
  const AppShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
}

/// Shared responsive application shell:
/// M3 [NavigationBar] on phones, [NavigationRail] once width >= 600dp.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.railDestinations,
    this.railHeader,
    required this.child,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppShellDestination> destinations;

  /// Optional fixed destinations for wide layouts (rail) when the phone bar
  /// uses a compact set (e.g. admin "More" hub on phones).
  final List<AppShellDestination>? railDestinations;
  final Widget? railHeader;

  /// Width threshold at which phone navigation becomes a rail layout.
  static const double breakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= breakpoint;
    final effectiveDestinations = wide && railDestinations != null
        ? railDestinations!
        : destinations;

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.marigold.withValues(alpha: 0.18),
                leading: railHeader,
                labelType: NavigationRailLabelType.all,
                selectedIconTheme:
                    const IconThemeData(color: AppColors.ink, size: 24),
                unselectedIconTheme:
                    const IconThemeData(color: AppColors.slate, size: 24),
                selectedLabelTextStyle: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                unselectedLabelTextStyle:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.slate),
                destinations: [
                  for (final d in effectiveDestinations)
                    NavigationRailDestination(
                      icon: _IconWithBadge(destination: d),
                      selectedIcon: _IconWithBadge(
                        destination: d,
                        selected: true,
                      ),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, color: AppColors.divider),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.marigold.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in effectiveDestinations)
            NavigationDestination(
              icon: _IconWithBadge(destination: d),
              selectedIcon: _IconWithBadge(destination: d, selected: true),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Brand mark shown at the top of the rail on wide layouts.
class ShellMark extends StatelessWidget {
  const ShellMark({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({required this.destination, this.selected = false});

  final AppShellDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? destination.selectedIcon : destination.icon;
    return Badge.count(
      count: destination.badgeCount,
      isLabelVisible: destination.badgeCount > 0,
      backgroundColor: AppColors.clay,
      textColor: AppColors.surface,
      child: Icon(
        icon,
        color: selected ? AppColors.ink : AppColors.slate,
      ),
    );
  }
}