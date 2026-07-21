import 'package:flutter/material.dart';

import '../../core/state/notification_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_snackbar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/settings_row.dart';
import '../../data/backend/local_notifications.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _store = NotificationStore.instance;

  // OS 알림 권한 — null은 아직 확인 전(배너 미표시).
  bool? _osPermissionGranted;

  @override
  void initState() {
    super.initState();
    // 저장된 토글 값을 복원하고, 기기 알림 권한 상태를 반영한다.
    _store.hydrateSettings();
    _checkOsPermission();
  }

  Future<void> _checkOsPermission() async {
    // local_notifications.dart는 상태 전용 조회 API가 없어, 현재 권한 여부를
    // 돌려주는 requestPermission()으로 확인한다(이미 허용됐으면 조용히 true).
    final granted = await LocalNotifications.instance.requestPermission();
    if (!mounted) return;
    setState(() => _osPermissionGranted = granted);
  }

  Future<void> _toggle(NotificationSetting setting, bool value) async {
    final saved = await _store.setSetting(setting, value);
    if (!saved && mounted) {
      AmoriSnackbar.error(context, '알림 설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(title: '알림 설정'),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final allOn = _store.allEnabled;
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              if (_osPermissionGranted == false) const _PermissionBanner(),
              SettingsSection(
                title: '전체',
                rows: [
                  SettingsSwitchRow(
                    icon: Icons.notifications_active_rounded,
                    label: '전체 알림',
                    description: '꺼두면 모든 알림이 차단돼요',
                    value: allOn,
                    onChanged: (v) => _toggle(NotificationSetting.all, v),
                    last: true,
                  ),
                ],
              ),
              SettingsSection(
                title: '세부 설정',
                rows: [
                  SettingsSwitchRow(
                    icon: Icons.vibration_rounded,
                    label: '진동',
                    value: _store.vibrationEnabled,
                    enabled: allOn,
                    onChanged: (v) =>
                        _toggle(NotificationSetting.vibration, v),
                  ),
                  SettingsSwitchRow(
                    icon: Icons.psychology_rounded,
                    label: '시뮬레이션 완료 알림',
                    description: 'AI 에이전트끼리의 대화가 끝났을 때 알려드려요',
                    value: _store.simulationDoneEnabled,
                    enabled: allOn,
                    onChanged: (v) =>
                        _toggle(NotificationSetting.simulationDone, v),
                  ),
                  SettingsSwitchRow(
                    icon: Icons.chat_bubble_rounded,
                    label: '대화 알림',
                    description: '상대방이 메시지를 보냈을 때 알려드려요',
                    value: _store.conversationEnabled,
                    enabled: allOn,
                    onChanged: (v) =>
                        _toggle(NotificationSetting.conversation, v),
                    last: true,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// OS에서 알림 권한이 꺼져 있을 때 화면 상단에 노출하는 안내 배너.
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.notifications_off_rounded,
              size: 20,
              color: AppColors.warning,
            ),
            AppSpacing.hSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '기기 설정에서 알림을 켜주세요',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '알림이 꺼져 있어 아래 설정을 켜도 알림을 받을 수 없어요',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
