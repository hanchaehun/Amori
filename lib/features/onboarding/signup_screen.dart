import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/primary_text_field.dart';
import '../../core/widgets/segmented_selector.dart';
import '../../core/state/profile_store.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/backend/auth_prefs.dart';
import '../../data/backend/backend_exception.dart';
import '../../data/backend/pending_profile_store.dart';
import '../../data/repositories/user_repository.dart';

enum _Gender { female, male, other }

enum _InterestGender { female, male, both }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  // 기본값을 미리 채우지 않는다 — 안 바꾸고 가입하면 가짜 나이가 서버에 남는다.
  final _birthController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Gender? _gender = _Gender.female;
  _InterestGender? _interestGender = _InterestGender.male;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _parseBirth(_birthController.text) ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      _birthController.text =
          '${picked.year}.${picked.month.toString().padLeft(2, '0')}.${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    final missing = <String>[
      if (_nameController.text.trim().isEmpty) '이름',
      if (_birthController.text.trim().isEmpty) '생년월일',
      if (_emailController.text.trim().isEmpty) '이메일',
      if (_passwordController.text.isEmpty) '비밀번호',
    ];

    if (missing.isNotEmpty) {
      final joined = missing.join(', ');
      final particle = _objectParticle(missing.last);
      _showError('$joined$particle 입력하세요.');
      return;
    }

    if (!_isEmailValid(_emailController.text.trim())) {
      _showError('올바른 이메일 형식이 아니에요. (예: name@example.com)');
      return;
    }

    if (!_isPasswordValid(_passwordController.text)) {
      _showError('비밀번호는 8자 이상, 영문·숫자·특수문자를 모두 포함해야 해요.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      await AmoriBackend().signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      // 프로필은 아직 DB에 저장하지 않는다 — 본인인증(KYC) 통과 후에만 저장
      // (2026-07-15 정책: 인증 이탈 계정이 users에 쌓이는 것 방지).
      // 로컬 대기 저장소에 보관하고, 인증 통과 후 첫 화면(페르소나 인트로)에서 커밋한다.
      await PendingProfileStore.save(
        displayName: _nameController.text.trim(),
        birthDate: _toIsoDate(_birthController.text.trim()),
        gender: (_gender ?? _Gender.other).name,
        interestGender: (_interestGender ?? _InterestGender.both).name,
      );
      // 방금 입력받은 값이 곧 프로필 — 화면 표시용 캐시는 즉시 채운다.
      ProfileStore.instance.set(MyProfile(
        displayName: _nameController.text.trim(),
        birthDate: _parseBirth(_birthController.text),
        gender: (_gender ?? _Gender.other).name,
        interestGender: (_interestGender ?? _InterestGender.both).name,
      ));
      // 페르소나 생성 전이므로, 앱을 껐다 켜면 홈이 아니라 생성 플로우로 이어진다.
      await AuthPrefs.instance.setPersonaReady(false);
      // 계정이 이미 만들어졌으니 뒤로가기로 가입 폼에 돌아가지 않도록 스택 교체.
      // 본인인증(KYC)은 스토어 출시 전 실연동 시점에 복원한다(2026-07-15 결정) —
      // 그때 AppRoutes.personaIntro → AppRoutes.kycBlock으로 되돌리면 된다.
      if (mounted) context.go(AppRoutes.personaIntro);
    } on BackendException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// '2000.03.15' → '2000-03-15' (BFF date 형식). 형식이 다르면 null.
  String? _toIsoDate(String dotted) {
    final match = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})$').firstMatch(dotted);
    if (match == null) return null;
    return '${match[1]}-${match[2]}-${match[3]}';
  }

  DateTime? _parseBirth(String dotted) {
    final iso = _toIsoDate(dotted.trim());
    return iso == null ? null : DateTime.tryParse(iso);
  }

  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    return regex.hasMatch(email);
  }

  bool _isPasswordValid(String pw) {
    if (pw.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pw);
    final hasDigit = RegExp(r'\d').hasMatch(pw);
    final hasSpecial = RegExp(r'[^A-Za-z0-9\s]').hasMatch(pw);
    return hasLetter && hasDigit && hasSpecial;
  }

  // Korean object marker: 을 after a final-consonant syllable, 를 otherwise.
  String _objectParticle(String word) {
    if (word.isEmpty) return '를';
    final last = word.runes.last;
    if (last < 0xAC00 || last > 0xD7A3) return '를';
    return (last - 0xAC00) % 28 != 0 ? '을' : '를';
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        duration: const Duration(seconds: 3),
        content: Text(
          message,
          style: AppTypography.label.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AppScaffold(
      appBar: const BackAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text('반가워요,\n몇 가지만 알려주세요', style: AppTypography.displayMedium),
                AppSpacing.vSm,
                Text(
                  'AI 에이전트가 닮아갈 핵심적인 당신의\n정보예요.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink500,
                    height: 1.55,
                  ),
                ),
                AppSpacing.vXl,
                PrimaryTextField(
                  label: '이름',
                  hint: '이름을 입력하세요',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                ),
                AppSpacing.vLg,
                PrimaryTextField(
                  label: '생년월일',
                  hint: '2000.03.15',
                  controller: _birthController,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  suffixIcon: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.ink500,
                  ),
                ),
                AppSpacing.vLg,
                _LabeledSegment<_Gender>(
                  label: '성별',
                  value: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                  options: const [
                    SegmentedOption(value: _Gender.female, label: '여성'),
                    SegmentedOption(value: _Gender.male, label: '남성'),
                    SegmentedOption(value: _Gender.other, label: '기타'),
                  ],
                ),
                AppSpacing.vLg,
                _LabeledSegment<_InterestGender>(
                  label: '관심 성별',
                  value: _interestGender,
                  onChanged: (v) => setState(() => _interestGender = v),
                  options: const [
                    SegmentedOption(value: _InterestGender.female, label: '여성'),
                    SegmentedOption(value: _InterestGender.male, label: '남성'),
                    SegmentedOption(value: _InterestGender.both, label: '모두'),
                  ],
                ),
                AppSpacing.vLg,
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
                  hint: '8자 이상, 영문·숫자·특수문자 포함',
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
              ],
            ),
          ),
          if (!keyboardOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: GradientButton(
                label: _submitting ? '계정 만드는 중...' : '계정 만들기',
                onPressed: _submitting ? null : _submit,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                  children: [
                    const TextSpan(text: '가입하면 '),
                    TextSpan(
                      text: '이용약관',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' 및 '),
                    TextSpan(
                      text: '개인정보처리방침',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '에 동의합니다.'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledSegment<T> extends StatelessWidget {
  const _LabeledSegment({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final String label;
  final T? value;
  final ValueChanged<T> onChanged;
  final List<SegmentedOption<T>> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        AppSpacing.vXs,
        SegmentedSelector<T>(
          value: value,
          onChanged: onChanged,
          options: options,
        ),
      ],
    );
  }
}
