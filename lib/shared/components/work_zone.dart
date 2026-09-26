import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import 'section_header.dart';
import 'status_badge.dart';

/// Geographic picture of where students are right now: location zones with
/// their on-duty supervisors and coverage numbers.
class WorkZone extends StatelessWidget {
  const WorkZone({
    super.key,
    required this.locations,
    required this.supervisors,
    this.title = 'Work zones',
    this.eyebrow,
    this.onTap,
  });

  final List<Location> locations;
  final List<Supervisor> supervisors;
  final String title;
  final String? eyebrow;
  final void Function(Location location)? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(eyebrow: eyebrow, title: title),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < locations.length; i++) ...[
          _ZoneTile(
            location: locations[i],
            onDuty: supervisors
                .where((s) => s.assignedLocationIds.contains(locations[i].id))
                .where((s) => s.status == SupervisorStatus.onDuty)
                .toList(),
            onTap: onTap == null ? null : () => onTap!(locations[i]),
          ),
          if (i != locations.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.location, required this.onDuty, this.onTap});

  final Location location;
  final List<Supervisor> onDuty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = location.status.style;

    return Material(
      color: AppColors.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: location.status == LocationStatus.attention
                  ? status.color
                  : AppColors.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(status.icon, size: 18, color: status.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      location.name,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  StatusBadge.status(style: status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (location.description != null) ...[
                Text(
                  location.description!,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                '${location.studentIds.length} students stationed',
                style: AppTextStyles.bodySmall,
              ),
              if (onDuty.isEmpty && location.supervisorIds.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No supervisor on duty',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.clay,
                  ),
                ),
              ] else if (onDuty.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in onDuty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sageLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.sage,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                s.name,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.sage,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}