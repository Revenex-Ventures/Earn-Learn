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
  // Retargeted to warm values so every screen that references these base
  // tokens directly turns calm/warm at once. Names preserved (API intact).
  static const ink = Color(0xFF2B2620); // warm near-black (was navy)
  static const inkSoft = Color(0xFF5E574C);
  static const slate = Color(0xFF988F81);
  static const paper = Color(0xFFF6F3EC); // warm cream canvas (was cold white)
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE9E2D6); // warm hairline

  // ---- Brand: emerald primary --------------------------------------------
  /// Institutional AVCOE green — softened to a muted forest.
  static const avcoeGreen = Color(0xFF2C6A47);
  static const sage = Color(0xFF2C6A47);

  /// Semantic aliases for the redesign.
  static const primary = Color(0xFF2C6A47);

  /// Deep forest — the dark end of hero gradients and pressed states.
  static const primaryDeep = Color(0xFF274E39);

  /// Emerald highlight — softened (no longer fire-bright).
  static const primaryBright = Color(0xFF3E8E63);

  /// Very light warm mint — tinted fills, chips, selected rows.
  static const primarySoft = Color(0xFFE9F1EC);
  static const sageLight = Color(0xFFE9F1EC);

  // ---- Accent: gold -------------------------------------------------------
  /// Legacy marigold accent — softened to warm ochre.
  static const marigold = Color(0xFFC39A4E);
  static const marigoldLight = Color(0xFFF1E8D4);

  /// Gold accent — softened ochre (not bright yellow).
  static const gold = Color(0xFFC39A4E);
  static const goldDeep = Color(0xFF8A6A2C);
  static const goldSoft = Color(0xFFF1E8D4);

  // ---- Support ------------------------------------------------------------
  static const clay = Color(0xFFB0574C);
  static const clayLight = Color(0xFFF1E1DC);
  static const info = Color(0xFF3A5488);
  static const infoLight = Color(0xFFEDF1F7);

  // ---- Warm-premium palette (softened, calm-on-open) ----------------------
  // Additive. These muted tokens back the warm-premium redesign so the app
  // opens easy on the eyes: no fire-bright accents, no near-black surfaces.
  static const warmCanvas = Color(0xFFF6F3EC); // app background
  static const warmIvory = Color(0xFFFBF9F3); // sunken / ivory cards
  static const warmSurface = Color(0xFFFFFFFF);
  static const warmLine = Color(0xFFE9E2D6); // hairline borders
  static const inkWarm = Color(0xFF2B2620); // primary text (softer than pure dark)
  static const inkSoftWarm = Color(0xFF5E574C);
  static const slateWarm = Color(0xFF988F81);

  // Muted brand — softened, NOT bright.
  static const forestSoft = Color(0xFF2C6A47); // primary green (muted)
  static const forestSoftBright = Color(0xFF3E8E63);
  static const forestSoftDeep = Color(0xFF274E39);
  static const goldSoftAccent = Color(0xFFC39A4E); // ochre, not bright yellow
  static const goldSoftBright = Color(0xFFD8B570);
  static const goldSoftDeep = Color(0xFF8A6A2C);
  static const goldTint = Color(0xFFF1E8D4);
  static const terraSpark = Color(0xFFBC6A4A); // clay-terracotta; LIVE actions ONLY
  static const terraTint = Color(0xFFF2E4DA);
  static const claySoftReject = Color(0xFFB0574C);
  static const clayTint = Color(0xFFF1E1DC);
  static const infoSoft = Color(0xFF3A5488);

  /// Warm off-white for text on the forest hero (never pure white).
  static const onHeroWarm = Color(0xFFF2EFE8);

  // ---- Gradients ----------------------------------------------------------
  /// Primary hero gradient — softened muted pine (calm, not near-black,
  /// not fire-bright). Retargeted from the old vivid emerald→forest ramp.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF356249), Color(0xFF2C5340), Color(0xFF274B39)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Explicit warm forest hero gradient (same as [heroGradient]); named for
  /// the warm-premium surfaces so intent is clear at call sites.
  static const heroForest = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF356249), Color(0xFF274B39)],
  );

  /// Softened gold gradient (member pills, supervisor sign-off accents).
  static const goldSoftGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD8B570), Color(0xFFB4914A)],
  );

  /// Terracotta gradient — reserved for LIVE actions only (check-in, center FAB).
  static const terraGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC67E5E), Color(0xFFA85D40)],
  );

  /// Gold accent gradient for highlights and accent chips (softened ochre).
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD8B570), Color(0xFFB4914A)],
  );

  /// Subtle light surface wash for elevated cards (warm ivory, not cold grey).
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFBF9F3)],
  );

  /// Returns a two-stop gradient (accent → gently deepened) for any accent
  /// colour, used to build role-tinted heroes (student=forest, supervisor=gold,
  /// admin=info). Deepens toward a warm dark rather than pure black so heroes
  /// never read near-black.
  static LinearGradient accentGradient(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, Color.lerp(accent, const Color(0xFF2B2620), 0.30)!],
      );
}
