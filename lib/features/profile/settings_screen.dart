import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/settings_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _comingSoon(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — 다음 턴 작업 예정')),
    );
  }

  void _onPushPreview(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.pushPreview);
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
            title: '계정',
            rows: [
              SettingsRow(
                icon: Icons.person_outline_rounded,
                label: '계정 정보',
                onTap: () => _comingSoon(context, '계정 정보 (이메일·비밀번호 변경)'),
              ),
              SettingsRow(
                icon: Icons.language_rounded,
                label: '언어',
                detail: '한국어',
                onTap: () => _comingSoon(context, '언어 설정'),
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '알림',
            rows: [
              SettingsRow(
                icon: Icons.notifications_outlined,
                label: '알림 설정',
                onTap: () => _onPushPreview(context),
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '보안 & 데이터',
            rows: [
              SettingsRow(
                icon: Icons.shield_outlined,
                label: '개인정보 및 보안',
                onTap: () => _comingSoon(context, '개인정보 및 보안'),
              ),
              SettingsRow(
                icon: Icons.delete_outline_rounded,
                label: '데이터 자동 소멸 정책 (1주일)',
                onTap: () => _comingSoon(context, '데이터 자동 소멸 정책'),
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
                onTap: () => _comingSoon(context, '고객센터'),
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                label: '이용약관',
                onTap: () => _comingSoon(context, '이용약관'),
              ),
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: '개인정보처리방침',
                onTap: () => _comingSoon(context, '개인정보처리방침'),
              ),
              SettingsRow(
                icon: Icons.info_outline_rounded,
                label: '앱 정보',
                detail: 'v1.0.0',
                onTap: () => _comingSoon(context, '앱 정보'),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
