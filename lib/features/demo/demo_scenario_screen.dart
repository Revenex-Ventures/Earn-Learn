import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import 'demo_scenario_state.dart';

/// Full interactive end-to-end demo screen connecting Student, Supervisor,
/// and Super Admin on one canonical underlying record.
class DemoScenarioScreen extends ConsumerStatefulWidget {
  const DemoScenarioScreen({super.key});

  @override
  ConsumerState<DemoScenarioScreen> createState() => _DemoScenarioScreenState();
}

class _DemoScenarioScreenState extends ConsumerState<DemoScenarioScreen> {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoScenarioProvider);
    final notifier = ref.read(demoScenarioProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Live End-to-End Demo'),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _confirmReset(context, notifier),
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.clay),
            label: const Text(
              'Reset Demo',
              style: TextStyle(color: AppColors.clay, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Demo Mode Banner
              _buildDemoBanner(),
              const SizedBox(height: AppSpacing.lg),

              // 2. Stage Progress Header
              _buildStageStepper(state.stage),
              const SizedBox(height: AppSpacing.xl),

              // 3. Main Stage Content
              switch (state.stage) {
                DemoStage.profileSetup => _StudentOnboardingCard(state: state, notifier: notifier),
                DemoStage.assignmentPending ||
                DemoStage.countdownToShift ||
                DemoStage.shiftReady =>
                  _AssignmentCountdownCard(state: state, notifier: notifier),
                DemoStage.verifyingRequirements =>
                  _VerificationStepCard(state: state, notifier: notifier),
                DemoStage.shiftActive =>
                  _ActiveShiftCard(state: state, notifier: notifier),
                DemoStage.shiftSubmitted ||
                DemoStage.supervisorReview =>
                  _SupervisorReviewCard(state: state, notifier: notifier),
                DemoStage.adminAudit =>
                  _AdminAuditCard(state: state, notifier: notifier),
              },

              const SizedBox(height: AppSpacing.xxl),

              // 4. Quick Navigation / Controls
              _buildControlToolbar(state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, size: 18, color: AppColors.sage),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'ISOLATED DEMO FIXTURE — 1 Student ↔ 1 Supervisor ↔ 1 Admin',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageStepper(DemoStage activeStage) {
    final stages = [
      (DemoStage.profileSetup, '1. Profile'),
      (DemoStage.countdownToShift, '2. Countdown'),
      (DemoStage.shiftActive, '3. Shift'),
      (DemoStage.supervisorReview, '4. Review'),
      (DemoStage.adminAudit, '5. Audit'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: stages.map((item) {
            final isCurrent = _isStageCurrentOrPast(item.$1, activeStage);
            final isExact = item.$1 == activeStage ||
                (item.$1 == DemoStage.countdownToShift &&
                    (activeStage == DemoStage.shiftReady ||
                        activeStage == DemoStage.verifyingRequirements ||
                        activeStage == DemoStage.assignmentPending));

            return Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isExact
                    ? AppColors.ink
                    : isCurrent
                        ? AppColors.sage.withValues(alpha: 0.2)
                        : AppColors.paper,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                border: Border.all(
                  color: isExact ? AppColors.ink : AppColors.divider,
                ),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isExact ? FontWeight.bold : FontWeight.w500,
                  color: isExact
                      ? Colors.white
                      : isCurrent
                          ? AppColors.sage
                          : AppColors.slate,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isStageCurrentOrPast(DemoStage target, DemoStage current) {
    return target.index <= current.index;
  }

  Widget _buildControlToolbar(DemoScenarioState state, DemoScenarioNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo Presentation Controls', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/auth'),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Main Roles'),
              ),
              OutlinedButton.icon(
                onPressed: () => notifier.skipToShiftReady(),
                icon: const Icon(Icons.fast_forward, size: 16),
                label: const Text('Fast Forward Countdown'),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context, notifier),
                icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.clay),
                label: const Text('Reset Scenario', style: TextStyle(color: AppColors.clay)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, DemoScenarioNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Demo Scenario?'),
        content: const Text(
          'This will return the demo flow to the initial onboarding state (DEMO-STU-001 candidate with no active attendance). Production records are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.resetScenario();
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.clay),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAGE 1: Student Onboarding Card
// -----------------------------------------------------------------------------
class _StudentOnboardingCard extends StatefulWidget {
  const _StudentOnboardingCard({required this.state, required this.notifier});

  final DemoScenarioState state;
  final DemoScenarioNotifier notifier;

  @override
  State<_StudentOnboardingCard> createState() => _StudentOnboardingCardState();
}

class _StudentOnboardingCardState extends State<_StudentOnboardingCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _rollController;
  late final TextEditingController _deptController;
  late final TextEditingController _classController;
  late final TextEditingController _contactController;
  late final TextEditingController _collegeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.student.name);
    _rollController = TextEditingController(text: widget.state.student.rollNumber);
    _deptController = TextEditingController(text: widget.state.student.department);
    _classController = TextEditingController(text: widget.state.student.className);
    _contactController = TextEditingController(text: widget.state.student.contact);
    _collegeController = TextEditingController(text: 'Amrutvahini College of Engineering');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _deptController.dispose();
    _classController.dispose();
    _contactController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: AppColors.sage),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Stage 1: Student Profile Onboarding', style: AppTextStyles.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Candidate logs in via Google and completes required institution details.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          // IDENTITY Section
          Text(
            'IDENTITY',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.slate,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _rollController,
            decoration: const InputDecoration(
              labelText: 'Student ID / Roll No',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ACADEMICS Section
          Text(
            'ACADEMICS',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.slate,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _classController,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // CONTACT Section
          Text(
            'CONTACT',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.slate,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // INSTITUTION Section
          Text(
            'INSTITUTION',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.slate,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _collegeController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'College',
              border: OutlineInputBorder(),
              isDense: true,
              suffixIcon: Icon(Icons.verified, color: AppColors.sage, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton.icon(
            onPressed: () {
              widget.notifier.saveStudentProfile(
                name: _nameController.text.trim(),
                rollNumber: _rollController.text.trim(),
                department: _deptController.text.trim(),
                className: _classController.text.trim(),
                contact: _contactController.text.trim(),
                college: _collegeController.text.trim(),
              );
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Save Profile & View Assignment'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAGE 2: Assignment & Live 5-Min Countdown Card
// -----------------------------------------------------------------------------
class _AssignmentCountdownCard extends StatelessWidget {
  const _AssignmentCountdownCard({required this.state, required this.notifier});

  final DemoScenarioState state;
  final DemoScenarioNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final secondsRemaining = state.secondsUntilShift;
    final mins = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (secondsRemaining % 60).toString().padLeft(2, '0');
    final isReady = state.isShiftReady;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Stage 2: Shift Assignment & Countdown', style: AppTextStyles.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Official work assignment confirmed. Next shift begins in 5 minutes.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Assignment summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow('Workplace', state.location.name),
                _buildRow('Duty', state.assignment.workDescription),
                _buildRow('Supervisor', state.supervisor.name),
                _buildRow('Assigned Student', '${state.student.name} (${state.student.rollNumber})'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Dynamic Countdown Display
          Center(
            child: Column(
              children: [
                Text(
                  isReady ? 'SHIFT IS READY!' : 'SHIFT STARTS IN',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isReady ? AppColors.sage : AppColors.marigold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isReady ? '00:00' : '$mins:$secs',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!isReady)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => notifier.skipToShiftReady(),
                    icon: const Icon(Icons.fast_forward),
                    label: const Text('Skip Countdown to Ready'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => notifier.startVerification(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Shift (Location & Identity Check)'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAGE 3: Verification Step Card
// -----------------------------------------------------------------------------
class _VerificationStepCard extends StatelessWidget {
  const _VerificationStepCard({required this.state, required this.notifier});

  final DemoScenarioState state;
  final DemoScenarioNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final canCheckIn = state.locationVerified && state.identityVerified;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: AppColors.sage),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Stage 3: Pre-Shift Verification', style: AppTextStyles.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'GPS geofence check & identity selfie required before opening shift.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),

          // 1. GPS Verification Item
          _buildCheckItem(
            title: '1. GPS Workplace Geofence',
            subtitle: state.locationVerified
                ? 'Location verified inside Demo Library (19.6174, 74.2045).'
                : 'Acquiring GPS fix and checking 100m geofence...',
            isDone: state.locationVerified,
            onAction: () => notifier.setLocationVerified(true),
            actionLabel: 'Verify Location',
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Identity Verification Item
          _buildCheckItem(
            title: '2. Identity / Selfie Evidence',
            subtitle: state.identityVerified
                ? 'Selfie captured and encrypted in private storage bucket.'
                : 'Take quick attendance selfie to confirm identity.',
            isDone: state.identityVerified,
            onAction: () => notifier.setIdentityVerified(true),
            actionLabel: 'Capture Selfie',
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton.icon(
            onPressed: canCheckIn ? () => notifier.startShift() : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: canCheckIn ? AppColors.sage : AppColors.slate,
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete Check-In & Enter Duty'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool isDone,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDone ? AppColors.sage.withValues(alpha: 0.5) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? AppColors.sage : AppColors.slate,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (!isDone)
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAGE 4: Active Shift Card
// -----------------------------------------------------------------------------
class _ActiveShiftCard extends StatelessWidget {
  const _ActiveShiftCard({required this.state, required this.notifier});

  final DemoScenarioState state;
  final DemoScenarioNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final checkIn = state.session?.checkInVerifiedAt ?? DateTime.now();
    final elapsedSecs = DateTime.now().difference(checkIn).inSeconds;
    final mins = (elapsedSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (elapsedSecs % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.timelapse, color: AppColors.sage),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text('Stage 4: Active Shift in Progress', style: AppTextStyles.titleMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
                child: const Text(
                  'WORKING',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: Column(
              children: [
                Text('ELAPSED SHIFT TIME', style: AppTextStyles.labelMedium),
                const SizedBox(height: 4),
                Text(
                  '$mins:$secs',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                _buildRow('Workplace', state.location.name),
                _buildRow('Supervisor', state.supervisor.name),
                _buildRow('Location Samples', '${state.locationSamplesCount} recorded in zone'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => notifier.recordSample(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Record GPS Sample'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          FilledButton.icon(
            onPressed: () => _confirmEndShift(context, notifier),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.clay,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End Shift & Submit for Review'),
          ),
        ],
      ),
    );
  }

  void _confirmEndShift(BuildContext context, DemoScenarioNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End your shift?'),
        content: const Text(
          'Your shift will be submitted to Demo Supervisor for attendance review and verified hours computation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.endShift();
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.clay),
            child: const Text('Confirm End Shift'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAGE 5: Supervisor Review Card
// -----------------------------------------------------------------------------
class _SupervisorReviewCard extends StatelessWidget {
  const _SupervisorReviewCard({required this.state, required this.notifier});

  final DemoScenarioState state;
  final DemoScenarioNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final session = state.session;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.supervisor_account, color: AppColors.marigold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Stage 5: Supervisor Review Portal', style: AppTextStyles.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Supervisor receives student submission and decides attendance outcome.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow('Candidate', state.student.name),
                _buildRow('Roll No', state.student.rollNumber),
                _buildRow('Workplace', state.location.name),
                _buildRow('Check-In Time', '${session?.checkInVerifiedAt?.hour}:${session?.checkInVerifiedAt?.minute.toString().padLeft(2, '0')}'),
                _buildRow('Check-Out Time', '${session?.checkOutVerifiedAt?.hour}:${session?.checkOutVerifiedAt?.minute.toString().padLeft(2, '0')}'),
                _buildRow('Verified Hours', '${session?.verifiedHours.toStringAsFixed(1) ?? "3.0"}h'),
                _buildRow('GPS Verification', 'Verified ✓ (4.2m accuracy)'),
                _buildRow('Selfie Verification', 'Verified ✓ (Uploaded)'),
                _buildRow('Status', session?.review.name.toUpperCase() ?? 'PENDING'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('Review Decision:', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    notifier.supervisorReview(
                      reviewStatus: ApprovalStatus.approved,
                      supervisorName: state.supervisor.name,
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.sage),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _promptReason(context, ApprovalStatus.flagged),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.marigold),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Flag'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _promptReason(context, ApprovalStatus.rejected),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.clay),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _promptReason(BuildContext context, ApprovalStatus status) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status.name.toUpperCase()} Attendance?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide an authoritative review note / reason:'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. Early checkout without prior intimation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim().isEmpty ? 'Supervisor flagged during review' : controller.text.trim();
              notifier.supervisorReview(
                reviewStatus: status,
                supervisorName: state.supervisor.name,
                reason: reason,
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAGE 6: Super Admin Audit & Governance Card
// -----------------------------------------------------------------------------
class _AdminAuditCard extends StatelessWidget {
  const _AdminAuditCard({required this.state, required this.notifier});

  final DemoScenarioState state;
  final DemoScenarioNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: AppColors.info),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text('Stage 6: Super Admin Oversight', style: AppTextStyles.titleMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _promptAdminCorrection(context),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Manual Correction'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Admin verifies the single underlying record across candidate, supervisor, and audit trail.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Overview metrics
          Row(
            children: [
              Expanded(
                child: _buildMetric('Candidate', state.student.name, AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMetric(
                  'Outcome',
                  state.session?.review.name.toUpperCase() ?? 'APPROVED',
                  state.session?.review == ApprovalStatus.approved ? AppColors.sage : AppColors.marigold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMetric(
                  'Verified Hours',
                  '${state.session?.verifiedHours.toStringAsFixed(1) ?? "3.0"}h',
                  AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('Chronological Audit Trail (Server Authoritative):', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.sm),

          // Audit log stream
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.auditLogs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final log = state.auditLogs[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.action} [${log.actorRole}]',
                              style: AppTextStyles.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(log.details, style: AppTextStyles.bodySmall),
                            if (log.reason != null)
                              Text('Reason: ${log.reason}', style: const TextStyle(fontSize: 11, color: AppColors.clay)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _promptAdminCorrection(BuildContext context) {
    final hoursController = TextEditingController(text: '3.0');
    final reasonController = TextEditingController(text: 'Institutional attendance reconciliation');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Manual Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new verified hours:'),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Mandatory justification / reason:'),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newH = double.tryParse(hoursController.text) ?? 3.0;
              notifier.adminCorrection(
                newVerifiedHours: newH,
                adminName: 'Super Admin',
                reason: reasonController.text.trim(),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Correction'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.slate)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
