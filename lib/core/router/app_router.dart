import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/onboarding/kyc_block_screen.dart';
import '../../features/onboarding/signup_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/walkthrough_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/persona/persona_intro_screen.dart';
import '../../features/persona/persona_loading_screen.dart';
import '../../features/persona/scenario_player_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.walkthrough,
        pageBuilder: (context, state) =>
            _slidePage(state, const WalkthroughScreen()),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (context, state) =>
            _slidePage(state, const SignupScreen()),
      ),
      GoRoute(
        path: AppRoutes.kycBlock,
        pageBuilder: (context, state) =>
            _slidePage(state, const KycBlockScreen()),
      ),
      GoRoute(
        path: AppRoutes.personaIntro,
        pageBuilder: (context, state) =>
            _slidePage(state, const PersonaIntroScreen()),
      ),
      GoRoute(
        path: AppRoutes.scenarioPlayer,
        pageBuilder: (context, state) =>
            _slidePage(state, const ScenarioPlayerScreen()),
      ),
      GoRoute(
        path: AppRoutes.personaLoading,
        pageBuilder: (context, state) =>
            _fadePage(state, const PersonaLoadingScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) =>
            _fadePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.agentChat,
        pageBuilder: (context, state) => _slidePage(
            state, const _ComingSoon(title: 'S07-AgentChat · AI ↔ AI 시뮬레이션')),
      ),
      GoRoute(
        path: AppRoutes.matchList,
        pageBuilder: (context, state) =>
            _fadePage(state, const _ComingSoon(title: 'S08 · 매칭 리스트')),
      ),
      GoRoute(
        path: AppRoutes.lockedReport,
        pageBuilder: (context, state) =>
            _slidePage(state, const _ComingSoon(title: 'S09 · 잠금 리포트 프리뷰')),
      ),
      GoRoute(
        path: AppRoutes.inbox,
        pageBuilder: (context, state) =>
            _fadePage(state, const _ComingSoon(title: 'S15 · 받은편지함')),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _fadePage(state, const _ComingSoon(title: 'S20 · 프로필 / 설정')),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _slidePage(state, const _ComingSoon(title: '로그인')),
      ),
    ],
    errorBuilder: (context, state) =>
        _ComingSoon(title: 'Route not found: ${state.uri}'),
  );

  static CustomTransitionPage<T> _fadePage<T>(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, _, c) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: c,
        );
      },
    );
  }

  static CustomTransitionPage<T> _slidePage<T>(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, _, c) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: c,
          ),
        );
      },
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});
  final String title;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.ink900,
          onPressed: () => _back(context),
        ),
        title: Text(title, style: AppTypography.titleMedium),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded,
                size: 56, color: AppColors.ink300),
            const SizedBox(height: 16),
            Text(
              '곧 만들어집니다',
              style:
                  AppTypography.bodyLarge.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () => _back(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('돌아가기'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
