import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 타이핑 인디케이터 점 — `.` → `..` → `...` 로 개수가 늘어나며 반복된다.
///
/// 시차 송출(라이브 관전) 중 "다음 발화가 오고 있다"는 신호로,
/// 상대 차례면 상대 말풍선 안에, 내 에이전트 차례면 내 입력창 안에 넣는다.
/// 자체 티커를 가지므로 부모에 vsync를 요구하지 않는다.
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    this.color = AppColors.ink500,
    this.dotSize = 6,
    this.spacing = 4,
  });

  final Color color;
  final double dotSize;
  final double spacing;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        // 주기를 4등분: 1개 → 2개 → 3개 → 3개 유지 후 처음으로.
        final visibleCount = ((_controller.value * 4).floor() + 1).clamp(1, 3);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              AnimatedOpacity(
                opacity: i < visibleCount ? 1.0 : 0.15,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (i < 2) SizedBox(width: widget.spacing),
            ],
          ],
        );
      },
    );
  }
}
