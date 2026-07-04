import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class _PushNoti {
  const _PushNoti({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.target,
  });

  final IconData icon;
  final String title;
  final String body;
  final String time;
  final String target;
}

class PushPreviewScreen extends StatelessWidget {
  const PushPreviewScreen({super.key});

  static const List<_PushNoti> _notifications = [
    _PushNoti(
      icon: Icons.mark_email_unread_rounded,
      title: '서민준님이 만남을 신청했어요',
      body: '88점 케미 · "안녕하세요! 프로필에서 영화 취향이..."',
      time: '지금',
      target: AppRoutes.meetRequestReceive,
    ),
    _PushNoti(
      icon: Icons.check_circle_rounded,
      title: '민준님이 신청을 수락했어요!',
      body: '대화를 시작해보세요. AI 코치가 도와드릴게요.',
      time: '5분 전',
      target: AppRoutes.chat,
    ),
    _PushNoti(
      icon: Icons.calendar_month_rounded,
      title: '내일 저녁 약속이 있어요',
      body: '김현우님과 첫 만남 — 채팅에서 확정한 약속이에요',
      time: '1시간 전',
      target: AppRoutes.chat, // 약속은 직접 채팅에서 잡는다 (스케줄링 목업 제거)
    ),
    _PushNoti(
      icon: Icons.auto_awesome_rounded,
      title: '오늘의 검증된 매칭이 도착했어요',
      body: '4명의 새로운 인연이 75점 이상으로 매칭됐어요',
      time: '오전 9:00',
      target: AppRoutes.matchList,
    ),
  ];

  void _onClose(BuildContext context) {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.profile);
    }
  }

  void _onTapNotification(BuildContext context, _PushNoti n) {
    HapticFeedback.lightImpact();
    context.go(n.target);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1A38), Color(0xFF1A1A1A)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _PreviewBar(onClose: () => _onClose(context)),
                  AppSpacing.vMd,
                  const _LockTime(),
                  AppSpacing.vXxl,
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => AppSpacing.vXs,
                      itemBuilder: (_, i) => _NotificationCard(
                        noti: _notifications[i],
                        onTap: () =>
                            _onTapNotification(context, _notifications[i]),
                      ),
                    ),
                  ),
                  const _LockFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '미리보기',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.close_rounded,
                  size: 22, color: Colors.white),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockTime extends StatelessWidget {
  const _LockTime();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '월요일, 5월 5일',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '9:41',
          style: TextStyle(
            fontSize: 76,
            fontWeight: FontWeight.w200,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -2,
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({required this.noti, required this.onTap});
  final _PushNoti noti;
  final VoidCallback onTap;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      gradient: amori.primaryGradient,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Icon(widget.noti.icon,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'amori',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.noti.time,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.noti.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.noti.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockFooter extends StatelessWidget {
  const _LockFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(icon: Icons.flashlight_on_rounded),
          _CircleButton(icon: Icons.camera_alt_rounded),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}
