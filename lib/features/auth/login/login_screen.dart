import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_text_styles.dart';
import '../../../core/models/user_role.dart';
import '../../../core/routing/route_paths.dart';
import '../auth_session.dart';
import '../credentials.dart';
import '../role_selection/role_selector_provider.dart';

/// Credential gate for a single role. Reached from the role-selection screen;
/// no role shell can be entered without passing through here (enforced by the
/// GoRouter redirect in app_router.dart for the local build).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  UserRole get _role => widget.role;

  Color get _accent => switch (_role) {
        UserRole.student => AppColors.avcoeGreen,
        UserRole.supervisor => AppColors.marigold,
        UserRole.admin => AppColors.info,
      };

  IconData get _icon => switch (_role) {
        UserRole.student => Icons.school_rounded,
        UserRole.supervisor => Icons.verified_user_rounded,
        UserRole.admin => Icons.admin_panel_settings_rounded,
      };

  String get _roleLabel => switch (_role) {
        UserRole.student => 'Student',
        UserRole.supervisor => 'Supervisor',
        UserRole.admin => 'Administrator',
      };

  String get _roleTagline => switch (_role) {
        UserRole.student => 'Track attendance, assignments and verified hours',
        UserRole.supervisor => 'Review, verify and approve student duty',
        UserRole.admin => 'Oversee operations, records and reports',
      };

  String get _rolePath => switch (_role) {
        UserRole.student => RoutePaths.studentHome,
        UserRole.supervisor => RoutePaths.supervisorHome,
        UserRole.admin => RoutePaths.adminOverview,
      };

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);
    final ok = DemoCredentials.validate(
      role: _role,
      username: _userCtrl.text,
      password: _passCtrl.text,
    );
    if (!ok) {
      setState(() => _error = 'Those credentials don\'t match a $_roleLabel account.');
      return;
    }
    setState(() => _submitting = true);
    AuthSession.signIn(_role);
    ref.read(roleSelectorProvider.notifier).select(_role);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) context.go(_rolePath);
  }

  void _fillDemo() {
    final cred = DemoCredentials.of(_role);
    setState(() {
      _userCtrl.text = cred.username;
      _passCtrl.text = cred.password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    final hPad = isCompact ? AppSpacing.md : AppSpacing.xl;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          _hero(isCompact),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, AppSpacing.xl, hPad, AppSpacing.xl),
              child: _loginCard(isCompact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(bool isCompact) {
    final dark = Color.lerp(_accent, Colors.black, 0.34)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent, dark],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.32), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(isCompact ? AppSpacing.md : AppSpacing.lg, AppSpacing.sm, isCompact ? AppSpacing.md : AppSpacing.lg, isCompact ? AppSpacing.lg : AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => context.go(RoutePaths.auth)),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'AVCOE  ·  Earn & Learn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w700, letterSpacing: 1.1, fontSize: 11),
                  ),
                ),
              ]),
              SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.white.withValues(alpha: 0.28))),
                child: Icon(_icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('$_roleLabel Sign In', style: AppTextStyles.headlineMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isCompact ? 24 : 28, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(_roleTagline, style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginCard(bool isCompact) {
    final cred = DemoCredentials.of(_role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(controller: _userCtrl, label: cred.identifierLabel, hint: 'e.g. ${cred.username}', icon: Icons.person_outline_rounded),
              const SizedBox(height: AppSpacing.md),
              _field(controller: _passCtrl, label: 'Password', hint: 'Enter password', icon: Icons.lock_outline_rounded, obscure: _obscure, onToggleObscure: () => setState(() => _obscure = !_obscure)),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.clay),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.clay, fontSize: 12))),
                ]),
              ],
              const SizedBox(height: AppSpacing.lg),
              _submitButton(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _demoCard(cred),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate, fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 10)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onSubmitted: (_) => _submit(),
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate.withValues(alpha: 0.6)),
            prefixIcon: Icon(icon, size: 20, color: _accent),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.slate),
                    onPressed: onToggleObscure,
                  ),
            filled: true,
            fillColor: AppColors.paper,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: _accent, width: 1.6)),
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _accent.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: _submitting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sign in as $_roleLabel', style: AppTextStyles.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _demoCard(DemoCredential cred) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _fillDemo,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.key_rounded, size: 18, color: _accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('SANDBOX DEMO LOGIN', style: AppTextStyles.labelSmall.copyWith(color: _accent, fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 10)),
                        Text('· tap to fill', style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${cred.identifierLabel}: ${cred.username}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Password: ${DemoCredentials.password}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small translucent circular icon button used on the gradient hero.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
