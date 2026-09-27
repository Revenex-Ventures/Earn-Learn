import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/user_role.dart';
import '../../core/routing/route_paths.dart';
import '../../shared/components/brand_header.dart';
import 'auth_session.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        final activeRole = AuthSession.role;
        if (activeRole != null) {
          switch (activeRole) {
            case UserRole.student:
              context.go(RoutePaths.studentHome);
            case UserRole.supervisor:
              context.go(RoutePaths.supervisorHome);
            case UserRole.admin:
              context.go(RoutePaths.adminOverview);
          }
        } else {
          context.go(RoutePaths.auth);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenWidth < 360 || screenHeight < 700;
    final portraitSize = isCompact ? 68.0 : (screenWidth > 600 ? 96.0 : 80.0);
    final logoHeight = isCompact ? 36.0 : 44.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: AVCOE Logo + Divider + Brand Title + Bhaurao Patil Portrait
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? AppSpacing.sm : AppSpacing.lg,
                      vertical: isCompact ? AppSpacing.xs : AppSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AvcoeLogo(height: logoHeight),
                        const SizedBox(width: 8),
                        Container(
                          width: 1.5,
                          height: logoHeight * 0.7,
                          color: AppColors.divider,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'AVCOE',
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate,
                                  letterSpacing: 0.8,
                                  fontSize: isCompact ? 9 : 10,
                                ),
                              ),
                              Text(
                                'Earn & Learn',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -0.3,
                                  fontSize: isCompact ? 14 : 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        BhauraoPortrait(
                          size: portraitSize,
                          borderWidth: 2.0,
                          borderColor: AppColors.surface,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Center Institutional Identity & Mission
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? AppSpacing.md : AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Amrutvahini College of Engineering',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.slate,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: isCompact ? 10 : 11,
                          ),
                        ),
                        SizedBox(height: isCompact ? 2 : AppSpacing.xs),
                        Text(
                          'Stronger\nTomorrow',
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontSize: isCompact ? 32 : (screenWidth > 600 ? 48 : 40),
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: isCompact ? AppSpacing.xs : AppSpacing.sm),
                        Row(
                          children: [
                            Text(
                              'Earn',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.marigold,
                                fontSize: isCompact ? 14 : 16,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.marigold,
                                ),
                              ),
                            ),
                            Text(
                              'Learn',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.marigold,
                                fontSize: isCompact ? 14 : 16,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.marigold,
                                ),
                              ),
                            ),
                            Text(
                              'Grow',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.marigold,
                                fontSize: isCompact ? 14 : 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? AppSpacing.xs : AppSpacing.sm),
                        Text(
                          'Empowering students through work, skills and real-world experience.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.inkSoft,
                            height: 1.4,
                            fontSize: isCompact ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Bottom Wave Graphic & Institutional Indicator
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      AcademicWaveGraphic(
                        height: isCompact ? 90 : (screenHeight < 750 ? 115 : 140),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: isCompact ? AppSpacing.sm : AppSpacing.md,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: AppColors.marigold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'AVCOE  |  Earn & Learn',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}