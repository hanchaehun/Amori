import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/soft_card.dart';

class KycBlockScreen extends StatelessWidget {
  const KycBlockScreen({super.key});

  void _onRealVerify(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('통신사 본인인증 — 추후 PASS / 카카오 / 네이버 SDK 연동 예정'),
      ),
    );
  }

  void _onDevSuccess(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.go(AppRoutes.personaIntro);
  }

  void _onDevFail(BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        content: const Text(
          '(개발용) 본인인증에 실패했습니다. 다시 시도해주세요.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(title: '본인인증'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.vMd,
            Text(
              '본인인증을\n진행해주세요',
              style: AppTypography.displayMedium,
            ),
            AppSpacing.vSm,
            Text(
              '안전한 만남과 법적 의무 이행을 위해\n본인 명의 인증이 필요해요.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.55,
              ),
            ),
            AppSpacing.vXl,
            const _KycExplainerCard(),
            const Spacer(),
            _TrustButton(
              label: '통신사로 본인인증',
              onPressed: () => _onRealVerify(context),
            ),
            AppSpacing.vSm,
            Center(
              child: Text(
                'PASS · 카카오 · 네이버 인증 지원',
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
            ),
            // 개발 전용 우회 버튼 — 릴리스(devUid=null)에선 노출하지 않는다.
            if (AppConfig.devUid != null) ...[
              AppSpacing.vXl,
              const _SectionDivider(label: '개발 전용'),
              AppSpacing.vMd,
              Row(
                children: [
                  Expanded(
                    child: _DevButton(
                      label: '인증 실패',
                      color: AppColors.danger,
                      icon: Icons.close_rounded,
                      onPressed: () => _onDevFail(context),
                    ),
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: _DevButton(
                      label: '인증 성공',
                      color: AppColors.success,
                      icon: Icons.check_rounded,
                      onPressed: () => _onDevSuccess(context),
                    ),
                  ),
                ],
              ),
            ],
            AppSpacing.vLg,
          ],
        ),
      ),
    );
  }
}

class _KycExplainerCard extends StatelessWidget {
  const _KycExplainerCard();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return SoftCard(
      gradient: amori.softGradient,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: ShapeDecoration(
              gradient: amori.primaryGradient,
              shape: const CircleBorder(),
              shadows: amori.glowShadow,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('법령에 따른 필수 절차예요',
                    style: AppTypography.titleMedium),
                AppSpacing.vXs,
                Text(
                  '인증 정보는 본인 확인 외 용도로 사용되지 않으며, '
                  '암호화되어 안전하게 보관됩니다.',
                  style: AppTypography.bodySmall.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
            child: Divider(color: AppColors.ink100, thickness: 1, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.ink500),
          ),
        ),
        const Expanded(
            child: Divider(color: AppColors.ink100, thickness: 1, height: 1)),
      ],
    );
  }
}

class _TrustButton extends StatefulWidget {
  const _TrustButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_TrustButton> createState() => _TrustButtonState();
}

class _TrustButtonState extends State<_TrustButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.ink900,
            borderRadius: AppRadius.rXl,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0B0F1A),
                blurRadius: 20,
                offset: Offset(0, 10),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _SecureBadge(),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: AppTypography.button.copyWith(
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.lock_rounded,
        color: Colors.white,
        size: 15,
      ),
    );
  }
}

class _DevButton extends StatefulWidget {
  const _DevButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_DevButton> createState() => _DevButtonState();
}

class _DevButtonState extends State<_DevButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: AppRadius.rMd,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 18),
              const SizedBox(width: 6),
              Text(
                '(개발용) ${widget.label}',
                style: AppTypography.label.copyWith(color: widget.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
