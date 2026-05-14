import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';
import '../../core/widgets/settings_row.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _allOn = true;
  bool _vibration = true;
  bool _simulationDone = true;
  bool _conversation = true;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const BackAppBar(title: '알림 설정'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          SettingsSection(
            title: '전체',
            rows: [
              SettingsSwitchRow(
                icon: Icons.notifications_active_rounded,
                label: '전체 알림',
                description: '꺼두면 모든 알림이 차단돼요',
                value: _allOn,
                onChanged: (v) => setState(() => _allOn = v),
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
                value: _vibration,
                enabled: _allOn,
                onChanged: (v) => setState(() => _vibration = v),
              ),
              SettingsSwitchRow(
                icon: Icons.psychology_rounded,
                label: '시뮬레이션 완료 알림',
                description: 'AI 에이전트끼리의 대화가 끝났을 때 알려드려요',
                value: _simulationDone,
                enabled: _allOn,
                onChanged: (v) => setState(() => _simulationDone = v),
              ),
              SettingsSwitchRow(
                icon: Icons.chat_bubble_rounded,
                label: '대화 알림',
                description: '상대방이 메시지를 보냈을 때 알려드려요',
                value: _conversation,
                enabled: _allOn,
                onChanged: (v) => setState(() => _conversation = v),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
