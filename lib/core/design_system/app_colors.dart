import 'package:flutter/material.dart';

/// Central colour system.
///
/// Powerful emerald + gold light-theme palette, anchored to the AVCOE brand.
/// Every legacy token below is preserved so existing screens keep compiling;
/// the new [primary*]/[gold*] tokens and gradients are additive and let the
/// redesigned surfaces read bolder.
class AppColors {
  AppColors._();

  // ---- Core neutrals ------------------------------------------------------
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF334155);
  static const slate = Color(0xFF64748B);
  static const paper = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE2E8F0);

  // ---- Brand: emerald primary --------------------------------------------
  /// Institutional AVCOE green — the primary brand anchor.
  static const avcoeGreen = Color(0xFF0F6B38);
  static const sage = Color(0xFF0F6B38);

  /// Semantic aliases for the redesign.
  static const primary = Color(0xFF0F6B38);

  /// Deep forest — the dark end of hero gradients and pressed states.
  static const primaryDeep = Color(0xFF083D20);

  /// Vivid emerald — the bright end of gradients, glows and highlights.
  static const primaryBright = Color(0xFF16A34A);

  /// Very light mint — tinted fills, chips, selected rows.
  static const primarySoft = Color(0xFFECFDF5);
  static const sageLight = Color(0xFFE8F5E9);

  // ---- Accent: gold -------------------------------------------------------
  /// Legacy marigold accent (kept for existing references).
  static const marigold = Color(0xFFC68A1B);
  static const marigoldLight = Color(0xFFFEF3C7);

  /// Vivid gold accent for the redesign.
  static const gold = Color(0xFFD79A20);
  static const goldDeep = Color(0xFF9A6B12);
  static const goldSoft = Color(0xFFFEF6E0);

  // ---- Support ------------------------------------------------------------
  static const clay = Color(0xFFB94A3D);
  static const clayLight = Color(0xFFFAE9E7);
  static const info = Color(0xFF1E3A8A);
  static const infoLight = Color(0xFFEFF6FF);

  // ---- Gradients ----------------------------------------------------------
  /// Primary hero gradient: vivid emerald → deep forest.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16A34A), Color(0xFF0A5A2E), Color(0xFF083D20)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gold accent gradient for highlights and accent chips.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0A93A), Color(0xFF9A6B12)],
  );

  /// Subtle light surface wash for elevated cards.
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F4)],
  );

  /// Returns a two-stop gradient (bright → deep) for any accent colour, used
  /// to build role-tinted heroes (student=emerald, supervisor=gold, admin=info).
  static LinearGradient accentGradient(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, Color.lerp(accent, const Color(0xFF000000), 0.36)!],
      );
}
