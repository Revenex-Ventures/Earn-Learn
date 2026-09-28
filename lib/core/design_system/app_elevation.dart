import 'package:flutter/material.dart';

/// Shared elevation (shadow) tokens for consistent depth across the app.
/// Additive — existing screens can opt in without breaking changes.
class AppElevation {
  AppElevation._();

  /// Standard card elevation for metric cards, nav tiles, surface containers.
  /// Warm, low-alpha shadow — soft depth without the heavy dark drop that made
  /// surfaces feel harsh on open.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0E2B2620), // rgba(43,38,32,0.055)
      blurRadius: 14,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  /// Hero header elevation for gradient accent headers (login, dashboard heroes).
  /// Uses accent-tinted shadow — caller should use [heroFor] with the accent colour.
  static List<BoxShadow> heroFor(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.20),
      blurRadius: 34,
      offset: const Offset(0, 14),
      spreadRadius: 0,
    ),
  ];
}