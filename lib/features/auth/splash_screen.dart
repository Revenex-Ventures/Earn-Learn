import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/models/user_role.dart';
import '../../core/routing/route_paths.dart';
import '../../shared/components/brand_header.dart';
import '../../shared/components/warm_premium_kit.dart';
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
    final logoHeight = isCompact ? 52.0 : 60.0;
    final titleSize = isCompact ? 32.0 : (screenWidth > 600 ? 46.0 : 38.0);

    return Scaffold(
      backgroundColor: AppColors.warmCanvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? AppSpacing.lg : AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Institutional header — big background-removed AVCOE crest on
                  // the left, custodian portrait on the right, on the canvas.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvcoeLogo(height: logoHeight),
                      const SizedBox(width: 12),
                      Container(
                        width: 1.5,
                        height: logoHeight * 0.62,
                        color: AppColors.warmLine,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AVCOE',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                color: AppColors.slateWarm,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Earn & Learn',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: AppColors.inkWarm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Custodian portrait — promoted to a large, centered focal
                  // mark that fills the mid-screen space above the statement.
                  Center(
                    child: BhauraoPortrait(
                      size: isCompact ? 100 : 116,
                      borderWidth: 3.0,
                      borderColor: AppColors.warmSurface,
                    ),
                  ),
                  SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                  // Editorial statement.
                  const Eyebrow('A K.B.P. Initiative'),
                  SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
                  Text(
                    'Stronger\nTomorrow',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      height: 1.04,
                      letterSpacing: -1.2,
                      color: AppColors.inkWarm,
                    ),
                  ),
                  SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
                  const Row(
                    children: [
                      _WordMark('Earn'),
                      _Dot(),
                      _WordMark('Learn'),
                      _Dot(),
                      _WordMark('Grow'),
                    ],
                  ),
                  SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
                  Text(
                    'Empowering students through work, skills and '
                    'real-world experience.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: isCompact ? 13 : 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: AppColors.inkSoftWarm,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Progress cue + institutional footer.
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.forestSoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AVCOE  ·  Amrutvahini College of Engineering',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: AppColors.slateWarm,
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: AppColors.goldSoftDeep,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// Gold wordmark used in the "Earn · Learn · Grow" strip.
class _WordMark extends StatelessWidget {
  const _WordMark(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: AppColors.goldSoftDeep,
      ),
    );
  }
}

/// Small gold separator dot between wordmarks.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 4,
        height: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldSoftAccent,
          ),
        ),
      ),
    );
  }
}