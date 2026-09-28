import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';

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

/// Shared application shell rendering the approved warm-premium phone layout:
/// a center-FAB bottom navigation over a warm canvas. On wide screens the whole
/// experience is centered in a phone-width column so it matches the mockup at
/// any window size (rather than switching to a desktop rail).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
    this.fabIcon,
    this.fabGradient,
    this.onFab,
    // Retained for backwards compatibility with existing shell callers.
    this.railDestinations,
    this.railHeader,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppShellDestination> destinations;

  /// Optional center action button (check-in, sign-off, add …).
  final IconData? fabIcon;
  final Gradient? fabGradient;
  final VoidCallback? onFab;

  final List<AppShellDestination>? railDestinations;
  final Widget? railHeader;

  /// Width beyond which the phone column is centered on a wider canvas.
  static const double phoneMaxWidth = 460;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCanvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: phoneMaxWidth),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 68),
                  child: SafeArea(bottom: false, child: child),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CenterFabNav(
                  currentIndex: currentIndex,
                  destinations: destinations,
                  onSelect: onDestinationSelected,
                  fabIcon: fabIcon,
                  fabGradient: fabGradient,
                  onFab: onFab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Center-FAB bottom navigation (mockup `.nav` + `.fab`).
class CenterFabNav extends StatelessWidget {
  const CenterFabNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
    this.fabIcon,
    this.fabGradient,
    this.onFab,
  });

  final int currentIndex;
  final List<AppShellDestination> destinations;
  final ValueChanged<int> onSelect;
  final IconData? fabIcon;
  final Gradient? fabGradient;
  final VoidCallback? onFab;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final hasFab = fabIcon != null && onFab != null;
    final split = destinations.length ~/ 2;

    final items = <Widget>[];
    for (var i = 0; i < destinations.length; i++) {
      if (hasFab && i == split) {
        items.add(const SizedBox(width: 66));
      }
      items.add(Expanded(
        child: _NavItem(
          destination: destinations[i],
          selected: i == currentIndex,
          onTap: () => onSelect(i),
        ),
      ));
    }

    return SizedBox(
      height: 70 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 70 + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset, left: 8, right: 8),
            decoration: const BoxDecoration(
              color: AppColors.warmSurface,
              border: Border(top: BorderSide(color: AppColors.warmLine)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: items,
            ),
          ),
          if (hasFab)
            Positioned(
              top: -22,
              child: GestureDetector(
                onTap: onFab,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: fabGradient ?? AppColors.terraGrad,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warmCanvas, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.terraSpark.withValues(alpha: 0.32),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(fabIcon, color: Colors.white, size: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final AppShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forestSoft : AppColors.slateWarm;
    return InkResponse(
      onTap: onTap,
      radius: 34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge.count(
            count: destination.badgeCount,
            isLabelVisible: destination.badgeCount > 0,
            backgroundColor: AppColors.claySoftReject,
            textColor: AppColors.warmSurface,
            child: Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Retained for backwards compatibility (previously the rail brand mark).
class ShellMark extends StatelessWidget {
  const ShellMark({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
    );
  }
}
