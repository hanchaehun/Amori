import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/dev_skip_button.dart';
import '../../data/backend/amori_backend.dart';

class PersonaLoadingScreen extends StatefulWidget {
  const PersonaLoadingScreen({super.key});

  @override
  State<PersonaLoadingScreen> createState() => _PersonaLoadingScreenState();
}

class _PersonaLoadingScreenState extends State<PersonaLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _progress;

  static const List<String> _stages = [
    '대화 스타일 분석 중...',
    '관계 가치관 분석 중...',
    '유머 코드 분석 중...',
    '커뮤니케이션 패턴 분석 중...',
    '페르소나 생성 마무리 중...',
  ];

  Timer? _completeTimer;
  Future<void>? _backendTask;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completeTimer = Timer(const Duration(milliseconds: 700), () {
          _goHome();
        });
      }
    });
    _backendTask = AmoriBackend().completeStoredPersonaBuild();
    _progress.forward();
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _pulse.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    try {
      await _backendTask;
    } catch (_) {
      // Dev-skip and unauthenticated preview flows still continue with local UI.
    }
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  void _skip() {
    _progress.stop();
    _completeTimer?.cancel();
    _goHome();
  }

  String _stageFor(double t) {
    if (t >= 1.0) return '완료!';
    final idx = (t * _stages.length).floor().clamp(0, _stages.length - 1);
    return _stages[idx];
  }

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: Container(
            decoration: BoxDecoration(gradient: amori.primaryGradient),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: DevSkipButton(onPressed: _skip, dark: true),
                  ),
                  AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _progress]),
                    builder: (_, _) {
                      final pulseT = Curves.easeInOut.transform(_pulse.value);
                      final progressT = _progress.value;
                      final percent = (progressT * 100).round();
                      return Column(
                        children: [
                          const Spacer(flex: 2),
                          _GlowOrb(pulseT: pulseT),
                          AppSpacing.vXxl,
                          Text(
                            '당신의 AI 에이전트를\n생성하고 있어요',
                            textAlign: TextAlign.center,
                            style: AppTypography.titleXl.copyWith(
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          AppSpacing.vMd,
                          Text(
                            _stageFor(progressT),
                            style: AppTypography.bodyLarge.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AppSpacing.vXl,
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 72,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -2.0,
                            ),
                          ),
                          AppSpacing.vLg,
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.huge,
                            ),
                            child: _ProgressTrack(value: progressT),
                          ),
                          const Spacer(flex: 3),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: Text(
                              '잠시만 기다려주세요. 약 30초 소요됩니다',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.pulseT});

  final double pulseT;

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + pulseT * 0.06;
    return RepaintBoundary(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _ring(220, 0.20),
            _ring(170, 0.35),
            Transform.scale(
              scale: scale,
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 52,
                  color: AppColors.primary,
                ),
              ),
            ),
            const Positioned(top: 20, right: 28, child: _Dot(size: 8)),
            const Positioned(
              bottom: 30,
              left: 18,
              child: _Dot(size: 6, opacity: 0.7),
            ),
            const Positioned(
              top: 56,
              left: 8,
              child: _Dot(size: 4, opacity: 0.5),
            ),
            const Positioned(
              bottom: 40,
              right: 18,
              child: _Dot(size: 5, opacity: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, double centerOpacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: centerOpacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, this.opacity = 1.0});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}
