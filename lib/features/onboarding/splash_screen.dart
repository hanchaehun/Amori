import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/gradient_orb.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/state/profile_store.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/backend/auth_prefs.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // 세션이 있으면 랜딩 버튼을 그리기 전에 자동 진입을 먼저 시도한다
  // (랜딩이 한 프레임 번쩍이는 것 방지).
  late bool _resolving = AmoriBackend().currentUser != null;

  @override
  void initState() {
    super.initState();
    if (_resolving) _resolveSession();
  }

  /// 로그인 유지 ON + 세션 존재 → 자동 진입 (네트워크 호출 없음 — 오프라인
  /// 이어도 즉시). 페르소나 생성을 마친 기기는 홈, 온보딩 중단 기기는
  /// 생성 플로우로. 로그인 유지 OFF인데 세션이 남아 있으면 정리한다.
  Future<void> _resolveSession() async {
    final keep = await AuthPrefs.instance.keepLoggedIn();
    if (!mounted) return;
    if (keep) {
      // 디스크 캐시를 먼저 복원(수 ms, 네트워크 없음) — 프로필 진입 즉시
      // 이름이 뜬다. 서버 최신화는 백그라운드로.
      await ProfileStore.instance.hydrate();
      ProfileStore.instance.refresh();
      final ready = await AuthPrefs.instance.personaReady();
      if (!mounted) return;
      context.go(ready ? AppRoutes.home : AppRoutes.personaIntro);
      return;
    }
    await AmoriBackend().signOut();
    if (mounted) setState(() => _resolving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return const AppScaffold(
        body: Center(child: AmoriLogoMark(size: 56)),
      );
    }
    return AppScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),
            const _LogoBlock(),
            AppSpacing.vXl,
            Text(
              'AI 에이전트가 먼저 만나는,\n가장 나다운 인연',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink500,
                height: 1.55,
              ),
            ),
            AppSpacing.vXs,
            Text(
              'Your AI meets first.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink300,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Spacer(flex: 5),
            GradientButton(
              label: '시작하기',
              trailing: const GradientArrowTrailing(),
              onPressed: () => context.push(AppRoutes.walkthrough),
            ),
            AppSpacing.vMd,
            Center(
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.login),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: RichText(
                    text: TextSpan(
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink500,
                      ),
                      children: [
                        const TextSpan(text: '이미 계정이 있어요  '),
                        TextSpan(
                          text: '로그인',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const AmoriLogoMark(size: 56),
        AppSpacing.hMd,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GradientText(
              'amori',
              style: AppTypography.displayLarge,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: amori.primaryGradient,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
