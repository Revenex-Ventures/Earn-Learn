import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import 'status_badge.dart';

/// Horizontal rail of verification evidence: check-in/out moments with their
/// reviewer status. Feeds the supervisor's "today at your locations" strip.
class EvidenceRail extends StatelessWidget {
  const EvidenceRail({
    super.key,
    required this.items,
    this.now,
  });

  final List<VerificationItem> items;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final effectiveNow = now ?? DateTime.now();
    final sorted = [...items]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return SizedBox(
      height: 150,
      child: sorted.isEmpty
          ? const Center(
              child: Text('No activity yet today.', style: AppTextStyles.bodySmall),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = sorted[index];
                return _EvidenceCard(item: item, now: effectiveNow);
              },
            ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item, required this.now});

  final VerificationItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = item.status.style;
    final clock =
        DateFormat('h:mm a').format(item.evidenceTime ?? item.submittedAt).toLowerCase();
    final verb = switch (item.type) {
      VerificationType.checkIn => 'In',
      VerificationType.checkOut => 'Out',
      VerificationType.attendanceAudit => 'Audit',
      VerificationType.correction => 'Correction',
    };

    return Container(
      width: 188,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Initials(name: item.studentName, color: status.color),
              const Spacer(),
              StatusBadge.status(style: status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.studentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$verb · $clock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(color: status.color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initial = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : (parts.first.substring(0, 1) + parts.last.substring(0, 1))
                .toUpperCase();

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}