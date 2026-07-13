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
import '../../core/state/profile_store.dart';
import '../../data/api/api_exception.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/backend/auth_prefs.dart';
import '../../data/backend/backend_exception.dart';
import '../../data/repositories/persona_repository.dart';

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
  bool _keepLoggedIn = true;
  bool _saveEmail = false;

  @override
  void initState() {
    super.initState();
    _restorePrefs();
  }

  Future<void> _restorePrefs() async {
    final keep = await AuthPrefs.instance.keepLoggedIn();
    final email = await AuthPrefs.instance.savedEmail();
    if (!mounted) return;
    setState(() {
      _keepLoggedIn = keep;
      if (email != null) {
        _saveEmail = true;
        _emailController.text = email;
      }
    });
  }

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
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await _backend.signInWithEmail(email: email, password: password);
      // 프로필 화면 첫 진입 때 이름이 즉시 뜨도록 미리 채운다 (기다리지 않음).
      ProfileStore.instance.refresh();

      await AuthPrefs.instance.setKeepLoggedIn(_keepLoggedIn);
      if (_saveEmail) {
        await AuthPrefs.instance.saveEmail(email);
      } else {
        await AuthPrefs.instance.clearEmail();
      }

      final next = await _nextRoute();
      if (mounted) context.go(next);
    } on BackendException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 페르소나가 아직 없는 계정(가입 후 중단 등)은 홈 대신 생성 플로우로.
  /// 조회 실패(타임아웃 등)는 홈으로 폴백 — 로그인 자체는 성공했으므로
  /// 여기서 사용자를 막지 않는다. 서버 기준으로 personaReady 플래그도
  /// 동기화해 다음 splash 자동 진입이 같은 곳을 향하게 한다.
  Future<String> _nextRoute() async {
    try {
      await PersonaRepository().fetchMyPersona();
      await AuthPrefs.instance.setPersonaReady(true);
      return AppRoutes.home;
    } on ApiException catch (error) {
      if (error.isNotFound) {
        await AuthPrefs.instance.setPersonaReady(false);
        return AppRoutes.personaIntro;
      }
      return AppRoutes.home;
    } catch (_) {
      return AppRoutes.home;
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
          AppSpacing.vLg,
          Row(
            children: [
              _CheckItem(
                label: '로그인 유지',
                value: _keepLoggedIn,
                onChanged: (value) => setState(() => _keepLoggedIn = value),
              ),
              AppSpacing.hMd,
              _CheckItem(
                label: '아이디 저장',
                value: _saveEmail,
                onChanged: (value) => setState(() => _saveEmail = value),
              ),
            ],
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

/// 플랫 체크 항목 — 브랜드 그라디언트 없이 primary 단색 액센트만 쓴다.
class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.ink300,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: value ? AppColors.ink900 : AppColors.ink500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
