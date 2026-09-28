import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
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
    final openCount = switch (itemsAsync.valueOrNull) {
      null => null,
      final items =>
        items.where((i) => i.status != ApprovalStatus.approved).length,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Approval queue'),
                      const SizedBox(height: 3),
                      Text(
                        'Reviews',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (openCount != null)
                  PremiumBadge(
                    label: '$openCount open',
                    tone: openCount == 0 ? BadgeTone.forest : BadgeTone.clay,
                  ),
              ],
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
            const SizedBox(height: AppSpacing.md),
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
                    SectionEyebrow(
                      eyebrow: 'Verification items',
                      trailing: Text(
                        '${filtered.length} shown',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.slateWarm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      const NoteBox(
                        text:
                            'No verification items match the current search or filter.',
                        icon: Icons.fact_check_outlined,
                      )
                    else
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        AccentRow(
                          accent: _accentFor(filtered[i].status),
                          lead: InitialsBubble(
                            initials: _initials(filtered[i].studentName),
                            gradient: _leadGradient(filtered[i].status),
                            foreground: _leadFg(filtered[i].status),
                          ),
                          title: filtered[i].studentName,
                          subtitle:
                              '${filtered[i].location} • ${filtered[i].type.label}',
                          trailing: PremiumBadge(
                            label: filtered[i].status.label,
                            tone: _toneFor(filtered[i].status),
                          ),
                          onTap: () => _openReview(filtered[i]),
                        ),
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

BadgeTone _toneFor(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => BadgeTone.forest,
      ApprovalStatus.flagged => BadgeTone.terra,
      ApprovalStatus.rejected => BadgeTone.clay,
      ApprovalStatus.pending => BadgeTone.gold,
    };

Color _accentFor(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => AppColors.forestSoft,
      ApprovalStatus.flagged => AppColors.terraSpark,
      ApprovalStatus.rejected => AppColors.claySoftReject,
      ApprovalStatus.pending => AppColors.goldSoftDeep,
    };

Gradient _leadGradient(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => AppColors.heroForest,
      ApprovalStatus.pending => AppColors.goldSoftGrad,
      _ => AppColors.terraGrad,
    };

Color _leadFg(ApprovalStatus status) => status == ApprovalStatus.pending
    ? const Color(0xFF4A3915)
    : AppColors.warmSurface;

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '—';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

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
