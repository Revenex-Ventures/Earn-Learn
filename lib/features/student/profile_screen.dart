import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';
import '../auth/role_selection/role_selector_provider.dart';

class StudentProfileData {
  const StudentProfileData({
    required this.student,
    this.assignment,
    this.supervisor,
  });

  final Student student;
  final Assignment? assignment;
  final Supervisor? supervisor;
}

final _studentProfileProvider = FutureProvider.autoDispose<StudentProfileData>((ref) async {
  final account = ref.watch(accountRepositoryProvider);
  final students = ref.watch(studentRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);

  final user = await account.currentUser();
  final link = await account.currentAccountLink();
  final entityId = link?.entityId;
  var student = entityId == null ? null : await students.byId(entityId);
  if (student == null && !AppFlavor.useFirebase) {
    final allStudents = await students.all();
    if (allStudents.isNotEmpty) {
      student = allStudents.first;
    }
  }
  if (user == null || student == null) {
    throw StateError('No student linked to the signed-in account.');
  }

  final assignment = await assignments.forStudent(student.id);
  Supervisor? supervisor;
  if (assignment != null && assignment.supervisorId.isNotEmpty) {
    supervisor = await supervisors.byId(assignment.supervisorId);
  }

  return StudentProfileData(
    student: student,
    assignment: assignment,
    supervisor: supervisor,
  );
});

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_studentProfileProvider);

    return snapshot.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32, color: AppColors.clay),
              const SizedBox(height: AppSpacing.md),
              Text(error.toString(), style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ),
      data: (data) => _StudentProfileView(data: data),
    );
  }
}

class _StudentProfileView extends ConsumerStatefulWidget {
  const _StudentProfileView({required this.data});

  final StudentProfileData data;

  @override
  ConsumerState<_StudentProfileView> createState() => _StudentProfileViewState();
}

class _StudentProfileViewState extends ConsumerState<_StudentProfileView> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.data.student;
    final assignment = widget.data.assignment;

    if (_isEditing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContextHeader(
                greeting: 'Edit Profile',
                dateLine: 'Update your institutional records',
                trailing: InitialsAvatar(name: student.name),
              ),
              const SizedBox(height: AppSpacing.lg),
              _StudentProfileEditForm(
                student: student,
                onCancel: () => setState(() => _isEditing = false),
                onSaved: () => setState(() => _isEditing = false),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Profile',
              dateLine: student.departmentOrNA,
              trailing: InitialsAvatar(name: student.name),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  InitialsAvatar(name: student.name, size: 72),
                  const SizedBox(height: AppSpacing.md),
                  Text(student.name, style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    student.rollNumber,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student.departmentOrNA,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sageLight,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: AppColors.avcoeGreen.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Student',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.avcoeGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: AppColors.divider),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Profile Sections List
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _ProfileNavRow(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    subtitle: student.email ?? 'Email not available',
                    onTap: () => setState(() => _isEditing = true),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ProfileNavRow(
                    icon: Icons.school_outlined,
                    title: 'Academic Details',
                    subtitle: '${student.departmentOrNA} · ${student.classOrNA}',
                    onTap: () => setState(() => _isEditing = true),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ProfileNavRow(
                    icon: Icons.phone_outlined,
                    title: 'Contact Details',
                    subtitle: student.contactOrNA,
                    onTap: () => setState(() => _isEditing = true),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ProfileNavRow(
                    icon: Icons.assignment_outlined,
                    title: 'Work & Assignment',
                    subtitle: assignment != null
                        ? '${assignment.locationName} · ${assignment.shiftLabel}'
                        : 'No active placement',
                    onTap: () => context.go(RoutePaths.studentAssignment),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  const _ProfileNavRow(
                    icon: Icons.account_balance_outlined,
                    title: 'College Details',
                    subtitle: 'Amrutvahini College of Engineering',
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ProfileNavRow(
                    icon: Icons.settings_outlined,
                    title: 'Settings & Notifications',
                    subtitle: 'Preferences and reminders',
                    onTap: () => _snack(context, 'Notification settings configured.'),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ProfileNavRow(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'SDO Office · sdo@avcoe.org',
                    onTap: () => _snack(context, 'Student Development Office (SDO)'),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ProfileNavRow(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out and select role',
                    iconColor: AppColors.clay,
                    titleColor: AppColors.clay,
                    onTap: () {
                      ref.read(roleSelectorProvider.notifier).clear();
                      context.go(RoutePaths.auth);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileNavRow extends StatelessWidget {
  const _ProfileNavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.ink).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? AppColors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.slate),
          ],
        ),
      ),
    );
  }
}

class _StudentProfileEditForm extends ConsumerStatefulWidget {
  const _StudentProfileEditForm({
    required this.student,
    required this.onCancel,
    required this.onSaved,
  });

  final Student student;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<_StudentProfileEditForm> createState() => _StudentProfileEditFormState();
}

class _StudentProfileEditFormState extends ConsumerState<_StudentProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _rollCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _classCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _emailCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s.name);
    _rollCtrl = TextEditingController(text: s.rollNumber);
    _deptCtrl = TextEditingController(text: s.department ?? '');
    _classCtrl = TextEditingController(text: s.className ?? '');
    _contactCtrl = TextEditingController(text: s.contact ?? '');
    _emailCtrl = TextEditingController(text: s.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    _deptCtrl.dispose();
    _classCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final updated = widget.student.copyWith(
        name: _nameCtrl.text.trim(),
        rollNumber: _rollCtrl.text.trim(),
        department: _deptCtrl.text.trim(),
        className: _classCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref.read(studentRepositoryProvider).updateProfile(updated);
      ref.invalidate(_studentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IDENTITY SECTION
          _SectionBlock(
            title: 'IDENTITY',
            children: [
              _field(
                controller: _nameCtrl,
                label: 'Full Name *',
                hint: 'e.g. Rahul Sharma',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                controller: _rollCtrl,
                label: 'Student ID / Roll Number *',
                hint: 'e.g. DEMO-STU-001',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Roll Number is required' : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ACADEMICS SECTION
          _SectionBlock(
            title: 'ACADEMICS',
            children: isWide
                ? [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _deptCtrl,
                            label: 'Department *',
                            hint: 'e.g. Computer Engineering',
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Department is required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _field(
                            controller: _classCtrl,
                            label: 'Class / Division *',
                            hint: 'e.g. TE-A',
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Class is required' : null,
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    _field(
                      controller: _deptCtrl,
                      label: 'Department *',
                      hint: 'e.g. Computer Engineering',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Department is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      controller: _classCtrl,
                      label: 'Class / Division *',
                      hint: 'e.g. TE-A',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Class is required' : null,
                    ),
                  ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // CONTACT SECTION
          _SectionBlock(
            title: 'CONTACT',
            children: isWide
                ? [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _contactCtrl,
                            label: 'Mobile Number *',
                            hint: 'e.g. +91 9876543210',
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Contact is required';
                              if (v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter valid 10-digit phone';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _field(
                            controller: _emailCtrl,
                            label: 'Email *',
                            hint: 'e.g. student@avcoe.org',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    _field(
                      controller: _contactCtrl,
                      label: 'Mobile Number *',
                      hint: 'e.g. +91 9876543210',
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Contact is required';
                        if (v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter valid 10-digit phone';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      controller: _emailCtrl,
                      label: 'Email *',
                      hint: 'e.g. student@avcoe.org',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                  ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // INSTITUTION SECTION
          _SectionBlock(
            title: 'INSTITUTION',
            children: [
              TextFormField(
                initialValue: 'Amrutvahini College of Engineering',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'College',
                  filled: true,
                  fillColor: AppColors.paper,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  prefixIcon: const Icon(Icons.account_balance_outlined, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                        )
                      : const Text('Save Profile'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}