import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';

/// Structured square icon well for semantic icons.
/// 36x36 standard, 44x44 hero; ~8px radius; 18-20px icon; soft tinted fill.
class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.icon,
    this.color = AppColors.ink,
    this.size = 36,
    this.iconSize = 18,
    this.radius = 8,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}