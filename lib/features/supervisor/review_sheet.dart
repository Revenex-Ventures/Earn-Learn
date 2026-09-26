import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_text_styles.dart';
import '../../../core/design_system/status_style.dart';
import '../../../core/models/models.dart';
import '../../../data/firebase/attendance_gateway.dart';
import '../../../shared/components/status_badge.dart';

/// Supervisor review for one attendance item.
///
/// Evidence access is delegated to the server (`getEvidence` signed URLs) —
/// the tool never touches raw Storage buckets from the client. Buttons map
/// 1:1 to `GatewayReviewDecision`s submitted through the attendance gateway.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({
    super.key,
    required this.item,
    required this.onSubmit,
    this.evidenceUrlBuilder,
  });

  final VerificationItem item;
  final Future<ReviewResult> Function(ApprovalStatus decision, String? note)
      onSubmit;
  final Future<String> Function(String kind)? evidenceUrlBuilder;

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  final TextEditingController _note = TextEditingController();
  bool _submitting = false;
  Future<String>? _evidenceUrl;

  @override
  void initState() {
    super.initState();
    final builder = widget.evidenceUrlBuilder;
    if (builder != null) {
      _evidenceUrl = builder('checkin');
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(ApprovalStatus decision) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final note = _note.text.trim();
    try {
      final result = await widget.onSubmit(decision, note.isEmpty ? null : note);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Review failed: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.studentName, style: AppTextStyles.titleMedium),
                  ),
                  StatusBadge.status(
                    style: item.status.style,
                    label: item.status.label,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${item.type.label} · ${item.location}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(item.summary, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              _EvidenceCapture(itemId: item.id, evidenceUrl: _evidenceUrl),
              const SizedBox(height: AppSpacing.md),
              Text(
                'COMMON REASONS & NOTES',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: [
                  for (final reason in const [
                    'Location concern',
                    'Identity concern',
                    'Early checkout',
                    'Missing evidence',
                    'Verified on duty',
                  ])
                    ActionChip(
                      label: Text(reason, style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _note.text == reason ? AppColors.paper : AppColors.surface,
                      onPressed: () => setState(() => _note.text = reason),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Note for the student (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => _submit(ApprovalStatus.rejected),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.clay,
                        side: const BorderSide(color: AppColors.clay),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => _submit(ApprovalStatus.flagged),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.marigold,
                        side: const BorderSide(color: AppColors.marigold),
                      ),
                      child: const Text('Flag'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _submitting ? null : () => _submit(ApprovalStatus.approved),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceCapture extends StatelessWidget {
  const _EvidenceCapture({required this.itemId, required this.evidenceUrl});

  final String itemId;
  final Future<String>? evidenceUrl;

  @override
  Widget build(BuildContext context) {
    if (evidenceUrl == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text('Live evidence via supervisor route',
              style: AppTextStyles.bodySmall),
        ),
      );
    }
    return FutureBuilder<String>(
      future: evidenceUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Box(
            child: Text('Evidence URL unavailable: ${snapshot.error}',
                style: AppTextStyles.bodySmall),
          );
        }
        if (!snapshot.hasData) {
          return const _Box(child: SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ));
        }
        return Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.ink,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(snapshot.data!, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}