import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';
import 'review_sheet.dart';

final _reviewItemsProvider = FutureProvider.autoDispose<List<VerificationItem>>(
  (ref) async {
    final verification = ref.watch(verificationRepositoryProvider);
    return verification.items();
  },
);

/// Supervisor approval queue (the "Reviews" tab): filter by status or search,
/// open an item and record a decision through the review sheet.
class SupervisorAttendanceScreen extends ConsumerStatefulWidget {
  const SupervisorAttendanceScreen({super.key});

  @override
  ConsumerState<SupervisorAttendanceScreen> createState() =>
      _SupervisorAttendanceScreenState();
}

class _SupervisorAttendanceScreenState
    extends ConsumerState<SupervisorAttendanceScreen> {
  static const _filters = [
    SearchFilterOption(label: 'All'),
    SearchFilterOption(label: 'Pending', value: ApprovalStatus.pending),
    SearchFilterOption(label: 'Flagged', value: ApprovalStatus.flagged),
    SearchFilterOption(label: 'Approved', value: ApprovalStatus.approved),
  ];

  String _query = '';
  Object? _filter;

  List<VerificationItem> _apply(List<VerificationItem> items) {
    final q = _query.trim().toLowerCase();
    return [
      for (final item in items)
        if ((_filter == null || item.status == _filter) &&
            (q.isEmpty ||
                '${item.studentName} ${item.location} ${item.type.label} '
                        '${item.summary}'
                    .toLowerCase()
                    .contains(q)))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(_reviewItemsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Reviews',
              dateLine: 'Approval queue',
              trailing: switch (itemsAsync.valueOrNull) {
                null => null,
                final items => _OpenCountPill(
                    count: items
                        .where((i) => i.status != ApprovalStatus.approved)
                        .length,
                  ),
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            SearchFilterBar(
              hintText: 'Search name, location or type…',
              initialQuery: _query,
              filters: _filters,
              selected: _filter,
              onQueryChanged: (value) => setState(() => _query = value),
              onFilterSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            itemsAsync.when(
              loading: () => const _CenteredNote(
                icon: Icons.hourglass_empty,
                text: 'Loading the approval queue…',
              ),
              error: (error, _) => _CenteredNote(
                icon: Icons.error_outline,
                text: error.toString(),
              ),
              data: (items) {
                final filtered = _apply(items);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      eyebrow: 'APPROVAL QUEUE',
                      title: 'Verification items',
                      trailing: Text(
                        '${filtered.length} shown',
                        style: AppTextStyles.labelMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'Nothing to review',
                        message:
                            'No verification items match the current search or filter.',
                      )
                    else
                      for (var i = 0; i < filtered.length; i++) ...[
                        _ReviewItemRow(
                          item: filtered[i],
                          onTap: () => _openReview(filtered[i]),
                        ),
                        if (i != filtered.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openReview(VerificationItem item) {
    final gateway = ref.read(attendanceGatewayProvider);
    final useServerEvidence = AppFlavor.useFirebase;
    ApprovalStatus? outcome;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => ReviewSheet(
        item: item,
        evidenceUrlBuilder: useServerEvidence
            ? (kind) => gateway.evidenceUrl(
                  sessionId: item.id,
                  studentId: item.studentId,
                  kind: kind,
                )
            : null,
        onSubmit: (decision, note) async {
          final result = await gateway.review(
            sessionId: item.id,
            studentId: item.studentId,
            decision: decision,
            note: note,
          );
          outcome = result.review;
          return result;
        },
      ),
    ).then((_) {
      if (!mounted) return;
      ref.invalidate(_reviewItemsProvider);
      final decided = outcome;
      if (decided != null) {
        _snack(_reviewMessage(item.studentName, decided));
      }
    });
  }

  String _reviewMessage(String name, ApprovalStatus review) => switch (review) {
        ApprovalStatus.approved => 'Verified — $name signed off.',
        ApprovalStatus.flagged => 'Flagged — sent back for another look.',
        ApprovalStatus.rejected => 'Rejected — $name notified.',
        ApprovalStatus.pending => 'Saved — still pending.',
      };

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReviewItemRow extends StatelessWidget {
  const _ReviewItemRow({required this.item, required this.onTap});

  final VerificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = item.status.style;
    return ListRow(
      title: item.studentName,
      subtitle: '${item.location} • ${item.type.label}',
      leading: IconWell(icon: _typeIcon(item.type), color: style.color),
      status: StatusBadge.status(style: style),
      onTap: onTap,
    );
  }
}

class _OpenCountPill extends StatelessWidget {
  const _OpenCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.clayLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$count open',
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.clay),
      ),
    );
  }
}

IconData _typeIcon(VerificationType type) => switch (type) {
      VerificationType.checkIn => Icons.login,
      VerificationType.checkOut => Icons.logout,
      VerificationType.attendanceAudit => Icons.fact_check_outlined,
      VerificationType.correction => Icons.edit_note,
    };

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(text, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}