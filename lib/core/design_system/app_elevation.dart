import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared elevation (shadow) tokens for consistent depth across the app.
/// Additive — existing screens can opt in without breaking changes.
class AppElevation {
  AppElevation._();

  /// Standard card elevation for metric cards, nav tiles, surface containers.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.ink,
      blurRadius: 18,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  /// Hero header elevation for gradient accent headers (login, dashboard heroes).
  /// Uses accent-tinted shadow — caller should use [heroFor] with the accent colour.
  static List<BoxShadow> heroFor(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.30),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: 0,
    ),
  ];
}