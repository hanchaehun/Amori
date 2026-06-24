import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_row.dart';
import 'availability_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _comingSoon(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label — 다음 턴 작업 예정')));
  }

  void _onSettings(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.settings);
  }

  void _onAvatarChange(BuildContext context) =>
      _comingSoon(context, '프로필 사진 변경');

  void _onPersonaInsight(BuildContext context) =>
      _comingSoon(context, '성향 분석 카드');

  void _onPersonaRelearn(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.personaIntro);
  }

  void _onAvailability(BuildContext context) {
    HapticFeedback.lightImpact();
    showAvailabilitySheet(context);
  }

  Future<void> _onLogout(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: '로그아웃 할까요?',
        body: '다시 로그인하기 전까지 알림을 받을 수 없어요.',
        confirmLabel: '로그아웃',
        danger: false,
      ),
    );
    if (confirmed == true && context.mounted) {
      context.go(AppRoutes.splash);
    }
  }

  Future<void> _onDeleteAccount(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: '정말 회원 탈퇴할까요?',
        body: '모든 데이터(페르소나·매칭·대화)가 즉시 삭제되며 복구할 수 없어요.',
        confirmLabel: '탈퇴하기',
        danger: true,
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 탈퇴 처리 중... — 다음 턴 작업 예정')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bottomBar: const AmoriTabBar(active: AmoriTab.profile),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(onSettings: () => _onSettings(context)),
          ),
          SliverToBoxAdapter(
            child: _ProfileHero(onCameraTap: () => _onAvatarChange(context)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: _AgentCard(
                onInsight: () => _onPersonaInsight(context),
                onRelearn: () => _onPersonaRelearn(context),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsList(
              onAvailability: () => _onAvailability(context),
              onComingSoon: (label) => _comingSoon(context, label),
              onLogout: () => _onLogout(context),
              onDeleteAccount: () => _onDeleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Text('프로필', style: AppTypography.titleLarge),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.ink900,
              ),
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.onCameraTap});
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '지',
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.ink700,
                      fontSize: 36,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onCameraTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          Text('이지은', style: AppTypography.titleLarge.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            '26세 · 서울',
            style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
          ),
          AppSpacing.vSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: ShapeDecoration(
              gradient: amori.primaryGradient,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '프리미엄 멤버',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.onInsight, required this.onRelearn});
  final VoidCallback onInsight;
  final VoidCallback onRelearn;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 AI 에이전트',
          style: AppTypography.titleMedium.copyWith(fontSize: 14),
        ),
        AppSpacing.vSm,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.rLg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  gradient: amori.primaryGradient,
                  shape: const CircleBorder(),
                  shadows: amori.glowShadow,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "지은's AI",
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '대표 질문 기반 · 답변 보완 가능',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                        fontSize: 12,
                      ),
                    ),
                    AppSpacing.vSm,
                    _AgentLink(label: '성향 분석 카드 보기', onTap: onInsight),
                    const SizedBox(height: 4),
                    _AgentLink(label: '페르소나 답변 보완하기', onTap: onRelearn),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentLink extends StatelessWidget {
  const _AgentLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.onAvailability,
    required this.onComingSoon,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final VoidCallback onAvailability;
  final ValueChanged<String> onComingSoon;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
      child: Column(
        children: [
          SettingsSection(
            title: '매칭',
            rows: [
              SettingsRow(
                icon: Icons.event_available_rounded,
                label: '소개팅 가능 일정',
                onTap: onAvailability,
              ),
              SettingsRow(
                icon: Icons.favorite_rounded,
                label: '매칭 선호 설정',
                onTap: () => onComingSoon('매칭 선호 설정'),
              ),
              SettingsRow(
                icon: Icons.link_rounded,
                label: '연동 앱',
                onTap: () =>
                    onComingSoon('연동 앱 (Spotify · Strava · Instagram)'),
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '결제 & 구독',
            rows: [
              SettingsRow(
                icon: Icons.credit_card_rounded,
                label: '구독 관리',
                detail: '프리미엄',
                onTap: () => onComingSoon('구독 관리'),
              ),
              SettingsRow(
                icon: Icons.receipt_long_rounded,
                label: '결제 내역',
                onTap: () => onComingSoon('결제 내역'),
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '기타',
            rows: [
              SettingsRow(
                icon: Icons.block_rounded,
                label: '차단 목록',
                onTap: () => onComingSoon('차단 목록'),
              ),
              SettingsRow(
                icon: Icons.logout_rounded,
                label: '로그아웃',
                danger: true,
                onTap: onLogout,
                last: true,
              ),
            ],
          ),
          AppSpacing.vLg,
          GestureDetector(
            onTap: onDeleteAccount,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '회원 탈퇴',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'amori v1.0.0',
            style: AppTypography.caption.copyWith(
              color: AppColors.ink300,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleLarge),
            AppSpacing.vSm,
            Text(
              body,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.5,
              ),
            ),
            AppSpacing.vLg,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: AppTypography.label.copyWith(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: danger
                          ? AppColors.danger
                          : AppColors.ink900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
