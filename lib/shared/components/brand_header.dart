import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';

/// Official AVCOE Institutional Crest Logo.
class AvcoeLogo extends StatelessWidget {
  const AvcoeLogo({
    super.key,
    this.height = 44,
    this.width,
    this.fit = BoxFit.contain,
  });

  final double height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? (height * 1.41);
    return Image.asset(
      'assets/branding/avcoe_logo.png',
      height: height,
      width: effectiveWidth,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height,
          width: width ?? height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          alignment: Alignment.center,
          child: Text(
            'AVCOE',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.avcoeGreen,
            ),
          ),
        );
      },
    );
  }
}

/// Karmaveer Bhaurao Patil Sir's official circular portrait with controlled clipping and halo.
class BhauraoPortrait extends StatelessWidget {
  const BhauraoPortrait({
    super.key,
    this.size = 48,
    this.borderWidth = 1.5,
    this.borderColor,
    this.showHalo = true,
  });

  final double size;
  final double borderWidth;
  final Color? borderColor;
  final bool showHalo;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.surface;
    final haloColor = AppColors.marigold.withValues(alpha: 0.25);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showHalo
            ? [
                BoxShadow(
                  color: haloColor,
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: EdgeInsets.all(borderWidth > 0 ? borderWidth : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: effectiveBorderColor,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/branding/bhaurao_patil.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, -0.2),
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.marigoldLight,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person,
                  color: AppColors.marigold,
                  size: 24,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Unified Institutional Brand Header for Top Navigation and Screen Entrances.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.logoHeight = 40,
    this.portraitSize = 44,
    this.title = 'Earn & Learn',
    this.subtitle = 'AVCOE',
    this.showPortrait = true,
    this.onPortraitTap,
  });

  final double logoHeight;
  final double portraitSize;
  final String title;
  final String subtitle;
  final bool showPortrait;
  final VoidCallback? onPortraitTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AvcoeLogo(height: logoHeight),
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: logoHeight * 0.7,
          color: AppColors.divider,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                    letterSpacing: 0.8,
                    fontSize: 10,
                  ),
                ),
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (showPortrait) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onPortraitTap,
            child: BhauraoPortrait(size: portraitSize),
          ),
        ],
      ],
    );
  }
}

/// Institutional Bottom Wave Illustration matching reference design.
class AcademicWaveGraphic extends StatelessWidget {
  const AcademicWaveGraphic({
    super.key,
    this.height = 140,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _AcademicWavePainter(),
      ),
    );
  }
}

class _AcademicWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Subtle background architectural silhouette outline (restrained)
    final bldgPaint = Paint()
      ..color = AppColors.slate.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final bldgFill = Paint()
      ..color = AppColors.slate.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    // Central tower and colonnade silhouette
    final bldgPath = Path();
    final centerX = w * 0.45;
    final bldgBaseY = h * 0.72;
    
    // Tower
    bldgPath.moveTo(centerX - 18, bldgBaseY);
    bldgPath.lineTo(centerX - 18, bldgBaseY - 65);
    bldgPath.lineTo(centerX - 12, bldgBaseY - 65);
    bldgPath.lineTo(centerX - 12, bldgBaseY - 80);
    bldgPath.lineTo(centerX, bldgBaseY - 92);
    bldgPath.lineTo(centerX + 12, bldgBaseY - 80);
    bldgPath.lineTo(centerX + 12, bldgBaseY - 65);
    bldgPath.lineTo(centerX + 18, bldgBaseY - 65);
    bldgPath.lineTo(centerX + 18, bldgBaseY);

    // Wings
    bldgPath.moveTo(centerX - 95, bldgBaseY);
    bldgPath.lineTo(centerX - 95, bldgBaseY - 40);
    bldgPath.lineTo(centerX - 18, bldgBaseY - 40);
    bldgPath.moveTo(centerX + 18, bldgBaseY - 40);
    bldgPath.lineTo(centerX + 95, bldgBaseY - 40);
    bldgPath.lineTo(centerX + 95, bldgBaseY);

    canvas.drawPath(bldgPath, bldgFill);
    canvas.drawPath(bldgPath, bldgPaint);

    // Layer 1: Warm Gold/Amber Wave (Back wave)
    final goldPaint = Paint()
      ..color = const Color(0xFFD99A1B).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final goldPath = Path();
    goldPath.moveTo(0, h * 0.78);
    goldPath.cubicTo(
      w * 0.25, h * 0.88,
      w * 0.65, h * 0.70,
      w, h * 0.55,
    );
    goldPath.lineTo(w, h);
    goldPath.lineTo(0, h);
    goldPath.close();
    canvas.drawPath(goldPath, goldPaint);

    // Layer 2: AVCOE Deep Green Wave (Front wave)
    final greenPaint = Paint()
      ..color = const Color(0xFF4C7A5D).withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final greenPath = Path();
    greenPath.moveTo(0, h * 0.60);
    greenPath.cubicTo(
      w * 0.30, h * 0.62,
      w * 0.60, h * 0.82,
      w, h * 0.70,
    );
    greenPath.lineTo(w, h);
    greenPath.lineTo(0, h);
    greenPath.close();
    canvas.drawPath(greenPath, greenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
