import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/onboarding/kyc_block_screen.dart';
import '../../features/onboarding/login_screen.dart';
import '../../features/onboarding/signup_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/walkthrough_screen.dart';
import '../../features/home/agent_chat_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/matching/free_lock_report_screen.dart';
import '../../features/matching/full_report_screen.dart';
import '../../features/matching/locked_report_screen.dart';
import '../../features/matching/match_list_screen.dart';
import '../../features/matching/paywall_screen.dart';
import '../../data/dummy/conversations.dart';
import '../../features/meet/chat_screen.dart';
import '../../features/meet/failed_matches_screen.dart';
import '../../features/meet/feedback_screen.dart';
import '../../features/meet/inbox_screen.dart';
import '../../features/meet/meet_request_receive_screen.dart';
import '../../features/meet/meet_request_send_screen.dart';
import '../../features/meet/quota_exceeded_screen.dart';
import '../../features/meet/request_declined_screen.dart';
import '../../features/meet/request_status_screen.dart';
import '../../features/meet/request_timeout_screen.dart';
import '../../features/persona/persona_intro_screen.dart';
import '../../features/persona/persona_loading_screen.dart';
import '../../features/persona/persona_preview_screen.dart';
import '../../features/persona/scenario_player_screen.dart';
import '../../features/profile/contact_filter_screen.dart';
import '../../features/profile/linked_apps_screen.dart';
import '../../features/profile/notification_settings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/push_preview_screen.dart';
import '../../features/profile/settings_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
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
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'daily'
              ? ScenarioPlayerMode.daily
              : ScenarioPlayerMode.initial;
          final code = state.uri.queryParameters['code'];
          return _slidePage(
            state,
            ScenarioPlayerScreen(
              mode: mode,
              scenarioCodes: code == null ? null : [code],
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.personaLoading,
        pageBuilder: (context, state) =>
            _fadePage(state, const PersonaLoadingScreen()),
      ),
      GoRoute(
        path: AppRoutes.personaPreview,
        pageBuilder: (context, state) => _slidePage(
          state,
          PersonaPreviewScreen(
            fromOnboarding: state.uri.queryParameters['from'] == 'onboarding',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _fadePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.agentChat,
        pageBuilder: (context, state) =>
            _slidePage(state, const AgentChatScreen()),
      ),
      GoRoute(
        path: AppRoutes.matchList,
        pageBuilder: (context, state) =>
            _fadePage(state, const MatchListScreen()),
      ),
      GoRoute(
        path: AppRoutes.lockedReport,
        pageBuilder: (context, state) => _slidePage(
          state,
          LockedReportScreen(matchId: state.uri.queryParameters['id']),
        ),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) => _slidePage(
          state,
          PaywallScreen(matchId: state.uri.queryParameters['id']),
        ),
      ),
      GoRoute(
        path: AppRoutes.fullReport,
        pageBuilder: (context, state) => _fadePage(
          state,
          FullReportScreen(matchId: state.uri.queryParameters['id']),
        ),
      ),
      GoRoute(
        path: AppRoutes.meetRequestSend,
        pageBuilder: (context, state) => _slidePage(
          state,
          MeetRequestSendScreen(matchId: state.uri.queryParameters['id']),
        ),
      ),
      GoRoute(
        path: AppRoutes.quotaExceeded,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const QuotaExceededScreen(),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.requestStatus,
        pageBuilder: (context, state) =>
            _fadePage(state, const RequestStatusScreen()),
      ),
      GoRoute(
        path: AppRoutes.requestDeclined,
        pageBuilder: (context, state) =>
            _fadePage(state, const RequestDeclinedScreen()),
      ),
      GoRoute(
        path: AppRoutes.requestTimeout,
        pageBuilder: (context, state) =>
            _slidePage(state, const RequestTimeoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.meetRequestReceive,
        pageBuilder: (context, state) =>
            _slidePage(state, const MeetRequestReceiveScreen()),
      ),
      GoRoute(
        path: AppRoutes.chat,
        pageBuilder: (context, state) => _slidePage(
          state,
          ChatScreen(
            conversationId: state.uri.queryParameters['id'],
            // '닿지 않은 인연'에서 진입한 읽기 전용 열람 — 잠금 문구가 바뀐다
            failed: state.uri.queryParameters['failed'] == '1',
            peer: state.extra is Conversation
                ? state.extra as Conversation
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        pageBuilder: (context, state) =>
            _slidePage(state, const FeedbackScreen()),
      ),
      GoRoute(
        path: AppRoutes.inbox,
        pageBuilder: (context, state) => _fadePage(state, const InboxScreen()),
      ),
      GoRoute(
        path: AppRoutes.linkedApps,
        pageBuilder: (context, state) =>
            _slidePage(state, const LinkedAppsScreen()),
      ),
      GoRoute(
        path: AppRoutes.contactFilter,
        pageBuilder: (context, state) =>
            _slidePage(state, const ContactFilterScreen()),
      ),
      GoRoute(
        path: AppRoutes.failedMatches,
        pageBuilder: (context, state) => _slidePage(
          state,
          FailedMatchesScreen(
            items: state.extra is List<FailedMatch>
                ? state.extra as List<FailedMatch>
                : const [],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _fadePage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.freeLockReport,
        pageBuilder: (context, state) =>
            _slidePage(state, const FreeLockReportScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            _slidePage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        pageBuilder: (context, state) =>
            _slidePage(state, const NotificationSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.pushPreview,
        pageBuilder: (context, state) =>
            _fadePage(state, const PushPreviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _slidePage(state, const LoginScreen()),
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
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
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
            const Icon(
              Icons.construction_rounded,
              size: 56,
              color: AppColors.ink300,
            ),
            const SizedBox(height: 16),
            Text(
              '곧 만들어집니다',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.ink500),
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
