import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../data/firebase/attendance_gateway.dart';
import '../../shared/components/components.dart';

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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.warmLine,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const Eyebrow('Confirm sign-off'),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.studentName,
                      style: AppTextStyles.titleLarge
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PremiumBadge(
                    label: item.status.label,
                    tone: _toneFor(item.status),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${item.type.label} · ${item.location}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
              ),
              const SizedBox(height: AppSpacing.lg),
              _EvidenceCapture(itemId: item.id, evidenceUrl: _evidenceUrl),
              const SizedBox(height: AppSpacing.md),
              SoftBox(
                label: item.summary,
                tone: BadgeTone.info,
                icon: Icons.schedule,
              ),
              const SizedBox(height: AppSpacing.md),
              WarmCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(
                  children: [
                    InfoLine(label: 'Student', value: item.studentName),
                    const HairDivider(),
                    InfoLine(label: 'Location', value: item.location),
                    const HairDivider(),
                    InfoLine(label: 'Type', value: item.type.label),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Eyebrow('Common reasons & notes'),
              const SizedBox(height: AppSpacing.sm),
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
                      label: Text(reason,
                          style:
                              AppTextStyles.labelSmall.copyWith(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _note.text == reason
                          ? AppColors.goldTint
                          : AppColors.warmSurface,
                      side: const BorderSide(color: AppColors.warmLine),
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
                  filled: true,
                  fillColor: AppColors.warmIvory,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.warmLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.warmLine),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submit(ApprovalStatus.rejected),
                      icon: const Icon(Icons.close, size: 17),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.claySoftReject,
                        side: const BorderSide(color: AppColors.claySoftReject),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submit(ApprovalStatus.flagged),
                      icon: const Icon(Icons.flag_outlined, size: 17),
                      label: const Text('Flag'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldSoftDeep,
                        side: const BorderSide(color: AppColors.goldSoftDeep),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed:
                    _submitting ? null : () => _submit(ApprovalStatus.approved),
                icon: _submitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check, size: 18),
                label: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onHeroWarm,
                        ),
                      )
                    : const Text('Approve & Sign'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestSoft,
                  foregroundColor: AppColors.onHeroWarm,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BadgeTone _toneFor(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => BadgeTone.forest,
      ApprovalStatus.flagged => BadgeTone.terra,
      ApprovalStatus.rejected => BadgeTone.clay,
      ApprovalStatus.pending => BadgeTone.gold,
    };

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
          color: AppColors.warmIvory,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warmLine),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_outlined,
                  size: 26, color: AppColors.slateWarm),
              const SizedBox(height: 6),
              Text(
                'Live evidence via supervisor route',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateWarm),
              ),
            ],
          ),
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
          return const _Box(
            child: SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
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
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warmLine),
      ),
      child: child,
    );
  }
}
