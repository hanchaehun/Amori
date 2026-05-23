import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/primary_text_field.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/backend/backend_exception.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _backend = AmoriBackend();

  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('이메일과 비밀번호를 입력하세요.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      await _backend.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _backend.ensureDemoMatches();
      if (mounted) context.go(AppRoutes.home);
    } on BackendException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        content: Text(
          message,
          style: AppTypography.label.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text('다시 만나서\n반가워요', style: AppTypography.displayMedium),
          AppSpacing.vSm,
          Text(
            '이메일과 비밀번호로 로그인합니다.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink500,
              height: 1.55,
            ),
          ),
          AppSpacing.vXl,
          PrimaryTextField(
            label: '이메일',
            hint: '이메일을 입력하세요',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          AppSpacing.vLg,
          PrimaryTextField(
            label: '비밀번호',
            hint: '비밀번호를 입력하세요',
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: AppColors.ink500,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          AppSpacing.vXl,
          GradientButton(
            label: _submitting ? '로그인 중...' : '로그인',
            onPressed: _submitting ? null : _submit,
          ),
          AppSpacing.vMd,
          Center(
            child: TextButton(
              onPressed: () => context.push(AppRoutes.signup),
              child: Text(
                '아직 계정이 없어요',
                style: AppTypography.label.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
