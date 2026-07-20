import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/state/agent_session_store.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/repositories/agent_flow.dart';

class PersonaLoadingScreen extends StatefulWidget {
  const PersonaLoadingScreen({super.key});

  @override
  State<PersonaLoadingScreen> createState() => _PersonaLoadingScreenState();
}

class _PersonaLoadingScreenState extends State<PersonaLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _progress;

  bool _leaving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _progress = AnimationController(vsync: this);

    // 진행률은 파이프라인 단계(실측)에 앵커 — 단계 안에서만 천천히 긴다.
    // LLM 콜 한 번의 내부 진행률은 알 수 없으니, 단계 도달이 곧 실제 진행이다.
    // (실측: persona 생성 콜 16~33초 → 고정 8초 애니메이션이 100%에서
    //  한참 머무는 문제의 원인이었다.)
    // 이 화면은 페르소나 생성까지만 책임진다 — 매칭·시뮬레이션은 백엔드
    // 스케줄러가 하루 랜덤 N회 알아서 실행한다 (services/auto_sim.py).
    AgentSessionStore.instance.addListener(_onPhaseChanged);
    _start();
  }

  void _start() {
    AgentFlow().run().whenComplete(() {
      // 단계 신호를 못 받는 경로(조기 실패 등) 안전망.
      // 실패로 이미 에러 화면을 띄운 경우엔 _finish가 스스로 무시한다.
      if (mounted) _finish();
    });
    _crawlTo(0.90, const Duration(seconds: 50)); // buildingPersona 진입 전 시작
  }

  void _onPhaseChanged() {
    if (!mounted || _leaving) return;
    switch (AgentSessionStore.instance.phase) {
      case AgentFlowPhase.buildingPersona:
        _crawlTo(0.90, const Duration(seconds: 50));
      case AgentFlowPhase.matching:
      case AgentFlowPhase.simulating:
      case AgentFlowPhase.reporting:
      case AgentFlowPhase.done:
        _finish();
      case AgentFlowPhase.failed:
        // 생성 실패 — 100%·"완료" 위장 없이 전용 에러 상태를 노출한다.
        _onFailed();
      case AgentFlowPhase.idle:
        break;
    }
  }

  void _onFailed() {
    if (_leaving || _failed) return;
    _progress.stop();
    setState(() => _failed = true);
  }

  void _retry() {
    if (_leaving) return;
    setState(() => _failed = false);
    _progress.value = 0.0;
    _start();
  }

  /// easeOut 크롤 — 처음엔 빠르게, 목표치 근처에선 거의 멈춘 듯 기어간다.
  /// 단계가 끝나기 전엔 목표치(<100%)를 넘지 않으니 "100%인데 안 넘어감"이 없다.
  void _crawlTo(double target, Duration duration) {
    if (_progress.value >= target) return;
    _progress.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    // 실패 상태에서는 완료 애니메이션·이동을 하지 않는다(위장 방지).
    if (_leaving || _failed ||
        AgentSessionStore.instance.phase == AgentFlowPhase.failed) {
      return;
    }
    _leaving = true;
    await _progress.animateTo(
      1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );
    _goHome();
  }

  @override
  void dispose() {
    AgentSessionStore.instance.removeListener(_onPhaseChanged);
    _pulse.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    // 성공 경로 전용 — 미리보기·수정으로 이동해 첫인상에서 "나 같은지"
    // 직접 확인·교정한다 (refatodo P0-C). 실패는 _onFailed가 처리한다.
    context.go('${AppRoutes.personaPreview}?from=onboarding');
  }

  /// "나중에" — 답변은 ScenarioAnswersStore에 남아 있어 나중에 다시 시도할 수 있다.
  void _goLater() {
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  String _stageFor(double t) {
    if (t >= 0.99) return '에이전트 준비 완료!';
    if (t < 0.3) return '대화 스타일 분석 중...';
    if (t < 0.6) return '관계 가치관 분석 중...';
    return '페르소나 생성 중...';
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
              child: _failed
                  ? _FailureBody(onRetry: _retry, onLater: _goLater)
                  : Stack(
                children: [
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
                              '실제 AI가 생성하고 있어요. 1분 정도 걸릴 수 있어요',
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

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.onRetry, required this.onLater});

  final VoidCallback onRetry;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            child: const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          AppSpacing.vXl,
          Text(
            '에이전트 생성에 실패했어요',
            textAlign: TextAlign.center,
            style: AppTypography.titleXl.copyWith(color: Colors.white),
          ),
          AppSpacing.vMd,
          Text(
            '네트워크가 잠시 불안정했을 수 있어요.\n답변은 그대로 남아 있으니 다시 시도해 주세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          AppSpacing.vXxl,
          WhiteSurfaceButton(label: '다시 시도', onPressed: onRetry),
          AppSpacing.vSm,
          TextButton(
            onPressed: onLater,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              '나중에 할게요',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
