import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_row.dart';

/// 연동 앱 — 외부 데이터 연동 허브.
///
/// 현재 실기능은 주소록(지인 필터) 하나다. 이 화면 자체가
/// AppConfig.contactFilterEnabled(본인인증 도입 게이트) 뒤에 있어,
/// 플래그가 꺼진 빌드에선 프로필의 '연동 앱' 버튼이 준비 중 안내만 띄운다.
class LinkedAppsScreen extends StatelessWidget {
  const LinkedAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.ink900,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Text('연동 앱', style: AppTypography.titleLarge),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                SettingsSection(
                  title: '지인 보호',
                  rows: [
                    SettingsRow(
                      icon: Icons.contacts_rounded,
                      label: '주소록 (지인 필터)',
                      onTap: () => context.push(AppRoutes.contactFilter),
                      last: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
