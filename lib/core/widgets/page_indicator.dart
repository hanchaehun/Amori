import 'package:flutter/material.dart';

import '../theme/amori_theme_ext.dart';
import '../theme/app_colors.dart';

class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: i == index ? 24 : 8,
            decoration: BoxDecoration(
              gradient: i == index ? amori.primaryGradient : null,
              color: i == index ? null : AppColors.ink100,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}
