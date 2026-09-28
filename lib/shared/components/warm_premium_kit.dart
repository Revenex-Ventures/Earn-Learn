import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';

/// Warm-premium component kit.
///
/// Additive, self-contained widgets that reproduce the approved editorial
/// mockup (ui-preview-batch3.html): forest-espresso hero cards, gold/glass
/// pills, trust triads, ledger-ticket receipts, a conic duty ring, left-accent
/// list rows, metric tiles, soft status boxes and a center-FAB bottom nav.
///
/// Everything reads real seed data passed in by callers and renders honest
/// gaps as plain strings ("Not specified", "Not assigned", …). Nothing here
/// touches the attendance state machine or backend — it only *expresses* state.
class WarmKit {
  WarmKit._();

  // Espresso hero gradient (matches mockup --espresso). Reuses the shared
  // heroGradient tokens so the whole app stays in one palette.
  static const espresso = AppColors.heroGradient;
  static const espressoBase = Color(0xFF2C5340);
  static const onHero = AppColors.onHeroWarm;

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0E2B2620), blurRadius: 14, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x142B2620), blurRadius: 28, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> shadowHero = [
    BoxShadow(color: Color(0x33263E2D), blurRadius: 38, offset: Offset(0, 16)),
  ];
}

/// Uppercase gold eyebrow used above sections and inside cards.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.onDark = false});

  final String text;
  final Color? color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        height: 1.3,
        color: color ??
            (onDark ? WarmKit.onHero.withValues(alpha: 0.7) : AppColors.goldSoftDeep),
      ),
    );
  }
}

/// Section header: gold eyebrow + optional bold title, with optional trailing.
class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow({
    super.key,
    required this.eyebrow,
    this.title,
    this.trailing,
  });

  final String eyebrow;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(eyebrow),
          if (title != null) ...[
            const SizedBox(height: 3),
            Text(
              title!,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.inkWarm,
                height: 1.15,
              ),
            ),
          ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small pill used on hero cards. [gold] gives the warm gold gradient chip,
/// otherwise a translucent glass chip for use on the espresso hero.
class HeroPill extends StatelessWidget {
  const HeroPill({super.key, required this.label, this.icon, this.gold = false});

  final String label;
  final IconData? icon;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final fg = gold ? const Color(0xFF4A3915) : WarmKit.onHero;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        gradient: gold ? AppColors.goldSoftGrad : null,
        color: gold ? null : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: gold
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Semantic tone for [PremiumBadge], mapped to the mockup's badge palette.
enum BadgeTone { forest, gold, clay, slate, terra, info }

/// Pill badge with a soft tinted background (mockup `.bdg`).
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.label, this.tone = BadgeTone.gold, this.dot = false});

  final String label;
  final BadgeTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.forest => (const Color(0xFFE9F6EE), AppColors.forestSoft),
      BadgeTone.gold => (AppColors.goldTint, AppColors.goldSoftDeep),
      BadgeTone.clay => (AppColors.clayTint, AppColors.claySoftReject),
      BadgeTone.slate => (const Color(0xFFF0ECE4), AppColors.slateWarm),
      BadgeTone.terra => (AppColors.terraTint, AppColors.terraSpark),
      BadgeTone.info => (const Color(0xFFE9EDFA), AppColors.infoSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single figure inside the hero's translucent stat strip.
class HeroStat {
  const HeroStat({required this.label, required this.value, this.gold = false});
  final String label;
  final String value;
  final bool gold;
}

/// A single trust chip (icon + two-line label) in the hero trust triad.
class TrustItem {
  const TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The signature forest-espresso hero card (mockup `.hero`).
///
/// A large monospace figure with unit, a caption, optional glass/gold pills,
/// an optional translucent stat strip and an optional trust triad.
class EspressoHero extends StatelessWidget {
  const EspressoHero({
    super.key,
    required this.value,
    required this.unit,
    required this.caption,
    this.leftPill,
    this.rightPill,
    this.stats = const [],
    this.trust,
    this.child,
  });

  final String value;
  final String unit;
  final String caption;
  final Widget? leftPill;
  final Widget? rightPill;
  final List<HeroStat> stats;
  final List<TrustItem>? trust;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: WarmKit.espresso,
        color: WarmKit.espressoBase,
        borderRadius: BorderRadius.circular(26),
        boxShadow: WarmKit.shadowHero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leftPill != null || rightPill != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: leftPill ?? const SizedBox.shrink()),
                if (rightPill != null) ...[
                  const SizedBox(width: 8),
                  rightPill!,
                ],
              ],
            ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  height: 0.9,
                  letterSpacing: -1,
                  color: WarmKit.onHero,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    color: WarmKit.onHero.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: WarmKit.onHero.withValues(alpha: 0.65),
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _HeroKv(stat: stats[i])),
                ],
              ],
            ),
          ],
          if (trust != null && trust!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < trust!.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _TrustChip(item: trust![i])),
                ],
              ],
            ),
          ],
          if (child != null) ...[const SizedBox(height: 16), child!],
        ],
      ),
    );
  }
}

class _HeroKv extends StatelessWidget {
  const _HeroKv({required this.stat});
  final HeroStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: WarmKit.onHero.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: stat.gold ? AppColors.goldSoftBright : WarmKit.onHero,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.item});
  final TrustItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Icon(item.icon, size: 16, color: WarmKit.onHero),
          const SizedBox(height: 5),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0.3,
              color: WarmKit.onHero.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded tinted icon square used as a list-row / quick-action lead.
class WarmIconWell extends StatelessWidget {
  const WarmIconWell({
    super.key,
    required this.icon,
    this.background,
    this.gradient,
    this.foreground = Colors.white,
    this.size = 40,
    this.radius = 13,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color? background;
  final Gradient? gradient;
  final Color foreground;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (background ?? WarmKit.espressoBase) : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

/// Circular initials avatar.
class InitialsBubble extends StatelessWidget {
  const InitialsBubble({
    super.key,
    required this.initials,
    this.gradient,
    this.background,
    this.foreground = Colors.white,
    this.size = 40,
  });

  final String initials;
  final Gradient? gradient;
  final Color? background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (background ?? WarmKit.espressoBase) : null,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: size * 0.31,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

/// A three-up quick action card (mockup `.qa .q`).
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    this.onTap,
    this.iconGradient,
    this.iconColor,
    this.iconFg = Colors.white,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback? onTap;
  final Gradient? iconGradient;
  final Color? iconColor;
  final Color iconFg;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warmSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.warmLine),
            boxShadow: WarmKit.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              WarmIconWell(
                icon: icon,
                gradient: iconGradient,
                background: iconColor,
                foreground: iconFg,
                size: 36,
                radius: 11,
                iconSize: 17,
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkWarm,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slateWarm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain warm surface card.
class WarmCard extends StatelessWidget {
  const WarmCard({super.key, required this.child, this.padding, this.ivory = false, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool ivory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ivory ? AppColors.warmIvory : AppColors.warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warmLine),
        boxShadow: WarmKit.shadowSm,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: card),
    );
  }
}

/// List row with a colored left accent bar (mockup `.lr`).
class AccentRow extends StatelessWidget {
  const AccentRow({
    super.key,
    required this.accent,
    required this.lead,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Color accent;
  final Widget lead;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warmSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.warmLine),
            boxShadow: WarmKit.shadowSm,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: accent),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: lead,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkWarm,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slateWarm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ?trailing,
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chevron trailing glyph for navigable rows.
class RowChevron extends StatelessWidget {
  const RowChevron({super.key});
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.chevron_right, size: 22, color: AppColors.slateWarm);
}

/// Soft tinted status box (mockup `.soft`).
class SoftBox extends StatelessWidget {
  const SoftBox({super.key, required this.label, required this.tone, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.forest => (const Color(0xFFE9F6EE), AppColors.forestSoft),
      BadgeTone.gold => (AppColors.goldTint, AppColors.goldSoftDeep),
      BadgeTone.clay => (AppColors.clayTint, AppColors.claySoftReject),
      BadgeTone.slate => (AppColors.warmIvory, AppColors.inkSoftWarm),
      BadgeTone.terra => (AppColors.terraTint, AppColors.terraSpark),
      BadgeTone.info => (const Color(0xFFE9EDFA), AppColors.infoSoft),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed-border informational note (mockup `.note`).
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.text, this.icon = Icons.info_outline, this.iconColor});

  final String text;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warmLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor ?? AppColors.goldSoftAccent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppColors.inkSoftWarm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A key/value line inside cards and tickets (mockup `.il`).
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.slateWarm,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.inkWarm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin warm divider used between info lines.
class HairDivider extends StatelessWidget {
  const HairDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.warmLine);
}

/// Data for one metric tile.
class MetricTileData {
  const MetricTileData({
    required this.label,
    required this.value,
    required this.desc,
    this.tone = BadgeTone.forest,
  });
  final String label;
  final String value;
  final String desc;
  final BadgeTone tone;
}

/// A single stat tile (mockup `.met .m`).
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.data});
  final MetricTileData data;

  @override
  Widget build(BuildContext context) {
    final valueColor = switch (data.tone) {
      BadgeTone.forest => AppColors.forestSoft,
      BadgeTone.gold => AppColors.goldSoftDeep,
      BadgeTone.clay => AppColors.claySoftReject,
      BadgeTone.terra => AppColors.terraSpark,
      BadgeTone.info => AppColors.infoSoft,
      BadgeTone.slate => AppColors.inkWarm,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warmLine),
        boxShadow: WarmKit.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.slateWarm,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.slateWarm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column grid of [MetricTile]s.
class MetricTileGrid extends StatelessWidget {
  const MetricTileGrid({super.key, required this.items});
  final List<MetricTileData> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = MetricTile(data: items[i]);
      final hasRight = i + 1 < items.length;
      // IntrinsicHeight gives the row a finite height so `stretch` (equal-height
      // tiles) is well-defined. Without it, inside a vertically-unbounded
      // SingleChildScrollView `stretch` forces the tiles to infinite height,
      // which collapses the whole page body to zero size (blank screen).
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: 11),
            Expanded(
              child: hasRight
                  ? MetricTile(data: items[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
      if (i + 2 < items.length) rows.add(const SizedBox(height: 11));
    }
    return Column(children: rows);
  }
}

/// One headline figure inside a [LedgerTicket].
class LedgerFigure {
  const LedgerFigure({required this.label, required this.value, this.forest = false});
  final String label;
  final String value;
  final bool forest;
}

/// Data for one [InfoLine] row (used by [LedgerTicket]).
class InfoLineData {
  const InfoLineData({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
}

/// Perforated ledger-ticket receipt (mockup `.ticket`).
class LedgerTicket extends StatelessWidget {
  const LedgerTicket({
    super.key,
    required this.eyebrow,
    required this.name,
    required this.statusLabel,
    this.statusTone = BadgeTone.gold,
    this.figures = const [],
    this.rows = const [],
    this.refLeft,
    this.refRight,
  });

  final String eyebrow;
  final String name;
  final String statusLabel;
  final BadgeTone statusTone;
  final List<LedgerFigure> figures;
  final List<InfoLineData> rows;
  final String? refLeft;
  final String? refRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warmLine),
        boxShadow: WarmKit.shadowMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFDF9), Color(0xFFF5EEDF)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(eyebrow, color: AppColors.goldSoftDeep),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkWarm,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PremiumBadge(label: statusLabel, tone: statusTone),
              ],
            ),
          ),
          const _Perforation(),
          if (figures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Row(
                children: [
                  for (var i = 0; i < figures.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: _LedgerCell(fig: figures[i])),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const HairDivider(),
                  InfoLine(
                    label: rows[i].label,
                    value: rows[i].value,
                    valueColor: rows[i].valueColor,
                  ),
                ],
                if (refLeft != null || refRight != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EFE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            refLeft ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 10.5,
                              color: AppColors.slateWarm,
                            ),
                          ),
                        ),
                        if (refRight != null)
                          Text(
                            refRight!,
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 10.5,
                              color: AppColors.slateWarm,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerCell extends StatelessWidget {
  const _LedgerCell({required this.fig});
  final LedgerFigure fig;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warmLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fig.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.slateWarm,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            fig.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: fig.forest ? AppColors.forestSoft : AppColors.inkWarm,
            ),
          ),
        ],
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          _Notch(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CustomPaint(painter: _DashPainter(), size: const Size(double.infinity, 2)),
            ),
          ),
          _Notch(),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 0),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.warmCanvas,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.warmLine),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.warmLine
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Conic duty ring with a centered figure (mockup `.ring`), drawn on the
/// espresso hero. [progress] is 0..1.
class DutyRing extends StatelessWidget {
  const DutyRing({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    this.size = 118,
  });

  final double progress;
  final String value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    const band = 9.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress.clamp(0, 1), band: band),
          ),
          Container(
            width: size - band * 2,
            height: size - band * 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF356249), Color(0xFF274B39)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: WarmKit.onHero,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: WarmKit.onHero.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.band});
  final double progress;
  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - band) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = band
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = band
      ..strokeCap = StrokeCap.round
      ..color = AppColors.forestSoftBright;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.band != band;
}
