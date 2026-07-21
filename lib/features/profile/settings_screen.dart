import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/settings_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _onNotificationSettings(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.notificationSettings);
  }

  void _openLegal(BuildContext context, String route) {
    HapticFeedback.selectionClick();
    context.push(route);
  }

  void _showInfo(BuildContext context, String title, String body) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: Text(title, style: AppTypography.titleMedium),
        content: Text(
          body,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink700,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(title: '설정'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          SettingsSection(
            title: '알림',
            rows: [
              SettingsRow(
                icon: Icons.notifications_outlined,
                label: '알림 설정',
                onTap: () => _onNotificationSettings(context),
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '약관 & 정책',
            rows: [
              SettingsRow(
                icon: Icons.description_outlined,
                label: '이용약관',
                onTap: () => _openLegal(context, AppRoutes.terms),
              ),
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: '개인정보처리방침',
                onTap: () => _openLegal(context, AppRoutes.privacy),
              ),
              SettingsRow(
                icon: Icons.delete_outline_rounded,
                label: '데이터 보관 정책',
                onTap: () => _showInfo(
                  context,
                  '데이터 보관 정책',
                  'amori는 최소한의 정보만 보관합니다. 매칭·대화 데이터는 서비스 제공에 필요한 기간 동안만 보관되며, 회원 탈퇴 시 관련 법령에 따라 보관이 필요한 정보를 제외하고 지체 없이 파기됩니다.',
                ),
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '도움말',
            rows: [
              SettingsRow(
                icon: Icons.chat_bubble_outline_rounded,
                label: '고객센터',
                onTap: () => _showInfo(
                  context,
                  '고객센터',
                  '문의하실 내용이 있으면 아래로 연락해 주세요.\n\n이메일: help@amori.app\n운영시간: 평일 10:00–18:00',
                ),
              ),
              SettingsRow(
                icon: Icons.language_rounded,
                label: '언어',
                detail: '한국어',
                onTap: () => _showInfo(
                  context,
                  '언어',
                  '현재 amori는 한국어만 지원합니다. 더 많은 언어를 준비하고 있어요.',
                ),
              ),
              SettingsRow(
                icon: Icons.info_outline_rounded,
                label: '앱 정보',
                detail: 'v${AppConfig.appVersion}',
                onTap: () => _showInfo(
                  context,
                  'amori',
                  'AI 프리데이팅 — 내 AI 에이전트가 먼저 만나고, 나는 미리보기를 보고 결정합니다.\n\n버전 ${AppConfig.appVersion}\n© 2026 amori',
                ),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
