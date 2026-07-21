import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/amori_theme_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amori_snackbar.dart';
import '../../core/widgets/amori_states.dart';
import '../../core/widgets/amori_tab_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/exit_guard.dart';
import '../../core/state/profile_store.dart';
import '../../core/widgets/settings_row.dart';
import '../../data/backend/amori_backend.dart';
import '../../data/backend/backend_exception.dart';
import '../../data/backend/profile_photo_uploader.dart';
import '../../data/repositories/user_repository.dart';
import 'match_pref_sheet.dart';
import 'mbti_sheet.dart';
import 'region_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 캐시를 먼저 그린다 — 로그인/앱 시작 때 미리 채워져 있어 즉시 이름이 뜬다.
  MyProfile? _profile = ProfileStore.instance.profile;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  /// 백그라운드 최신화 — 실패해도 캐시(또는 '—')를 그대로 둔다.
  Future<void> _refreshProfile() async {
    await ProfileStore.instance.refresh();
    final latest = ProfileStore.instance.profile;
    if (mounted && latest != null) setState(() => _profile = latest);
  }

  void _onSettings(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.settings);
  }

  void _comingSoon(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    AmoriSnackbar.show(context, '$label — 다음 턴 작업 예정');
  }

  bool _uploadingPhoto = false;

  Future<void> _onAvatarChange(BuildContext context) async {
    if (_uploadingPhoto) return;
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploadingPhoto = true);
    try {
      final url = await ProfilePhotoUploader().pickAndUpload();
      if (url == null) return; // 선택 취소
      await UserRepository().saveProfile(photoUrl: url);
      await ProfileStore.instance.refresh();
      final latest = ProfileStore.instance.profile;
      if (mounted && latest != null) setState(() => _profile = latest);
      messenger.showSnackBar(const SnackBar(content: Text('프로필 사진을 변경했어요.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('사진을 올리지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _onPersonaInsight(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.personaPreview);
  }

  void _onPersonaRelearn(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.personaIntro);
  }

  Future<void> _onRegion(BuildContext context) async {
    HapticFeedback.lightImpact();
    final region = await showRegionSheet(context, current: _profile?.region);
    if (region == null || region == _profile?.region) return;
    try {
      await UserRepository().saveProfile(region: region);
      final updated = (_profile ?? const MyProfile()).copyWith(region: region);
      ProfileStore.instance.set(updated);
      if (mounted) setState(() => _profile = updated);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지역을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _onMatchPref(BuildContext context) async {
    HapticFeedback.lightImpact();
    final pref = await showMatchPrefSheet(
      context,
      currentOlder: _profile?.matchAgeOlder,
      currentYounger: _profile?.matchAgeYounger,
      myAge: _profile?.age,
    );
    if (pref == null) return;
    try {
      await UserRepository().saveProfile(
        matchAgeOlder: pref.older,
        matchAgeYounger: pref.younger,
      );
      final updated = (_profile ?? const MyProfile()).copyWith(
        matchAgeOlder: pref.older,
        matchAgeYounger: pref.younger,
      );
      ProfileStore.instance.set(updated);
      if (mounted) setState(() => _profile = updated);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매칭 선호를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _onMbti(BuildContext context) async {
    HapticFeedback.lightImpact();
    final mbti = await showMbtiSheet(context, current: _profile?.mbti);
    if (mbti == null || mbti == (_profile?.mbti ?? '')) return;
    try {
      await UserRepository().saveProfile(mbti: mbti);
      // copyWith로는 삭제('' → null)를 표현할 수 없어 서버 재조회로 동기화한다.
      await ProfileStore.instance.refresh();
      final latest = ProfileStore.instance.profile;
      if (mounted && latest != null) setState(() => _profile = latest);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MBTI를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _onBio(BuildContext context) async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController(text: _profile?.bio ?? '');
    final bio = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('한줄 소개', style: AppTypography.titleMedium),
            AppSpacing.vXs,
            Text(
              '만남이 성사된 상대에게 보여져요.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
            ),
            AppSpacing.vMd,
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: '예: 주말엔 한강에서 러닝해요. 맛집 탐방 좋아합니다!',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.ink300,
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            AppSpacing.vSm,
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                child: Text('저장', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (bio == null || bio == (_profile?.bio ?? '')) return;
    try {
      await UserRepository().saveProfile(bio: bio);
      await ProfileStore.instance.refresh();
      final latest = ProfileStore.instance.profile;
      if (mounted && latest != null) setState(() => _profile = latest);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('한줄 소개를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _onLogout(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: '로그아웃 할까요?',
        body: '다시 로그인하기 전까지 알림을 받을 수 없어요.',
        confirmLabel: '로그아웃',
        danger: false,
      ),
    );
    if (confirmed == true && context.mounted) {
      // 세션을 실제로 끊어야 splash 자동 로그인이 홈으로 되돌려보내지 않는다.
      await AmoriBackend().signOut();
      if (context.mounted) context.go(AppRoutes.splash);
    }
  }

  Future<void> _onDeleteAccount(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: '정말 회원 탈퇴할까요?',
        body: '모든 데이터(페르소나·매칭·대화)가 즉시 삭제되며 복구할 수 없어요.',
        confirmLabel: '탈퇴하기',
        danger: true,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final router = GoRouter.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    // 처리 중 블로킹 로더 — 삭제는 서버 왕복이 있어 즉시 끝나지 않는다.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: AmoriLoader()),
      ),
    );
    final backend = AmoriBackend();
    try {
      // 순서 중요(좀비 계정 방지): ①토큰 확보 → ②Firebase 계정 삭제(재인증
      // 필요 시 여기서 중단, 서버 미삭제) → ③확보한 토큰으로 서버 데이터 삭제.
      final token = await backend.captureBearerToken();
      await backend.deleteFirebaseAccount();
      await UserRepository().deleteAccount(authToken: token);
      backend.clearSession();
      rootNav.pop(); // 로더 닫기
      router.go(AppRoutes.splash);
    } on BackendException catch (e) {
      rootNav.pop(); // 로더 닫기 (서버 데이터는 아직 삭제되지 않음)
      if (context.mounted) AmoriSnackbar.error(context, e.message);
    } catch (_) {
      rootNav.pop(); // 로더 닫기
      if (context.mounted) {
        AmoriSnackbar.error(context, '회원 탈퇴에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      child: AppScaffold(
        bottomBar: const AmoriTabBar(active: AmoriTab.profile),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _TopBar(onSettings: () => _onSettings(context)),
            ),
            SliverToBoxAdapter(
              child: _ProfileHero(
                profile: _profile,
                onCameraTap: () => _onAvatarChange(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: _AgentCard(
                  onInsight: () => _onPersonaInsight(context),
                  onRelearn: () => _onPersonaRelearn(context),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SettingsList(
                regionDetail: _profile?.region ?? '미설정',
                matchPrefDetail:
                    '위 ${_profile?.matchAgeOlder ?? kDefaultAgeGap} · '
                    '아래 ${_profile?.matchAgeYounger ?? kDefaultAgeGap}',
                mbtiDetail: _profile?.mbti ?? '미설정',
                bioDetail: (_profile?.bio?.isNotEmpty ?? false) ? '작성됨' : '미설정',
                onRegion: () => _onRegion(context),
                onMatchPref: () => _onMatchPref(context),
                onMbti: () => _onMbti(context),
                onBio: () => _onBio(context),
                // 주소록 지인 필터가 열리기 전(본인인증 도입 전)엔 준비 중 안내만
                onLinkedApps: AppConfig.contactFilterEnabled
                    ? () => context.push(AppRoutes.linkedApps)
                    : () => _comingSoon(
                        context, '연동 앱 (주소록 · Spotify · Strava)'),
                onLogout: () => _onLogout(context),
                onDeleteAccount: () => _onDeleteAccount(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Text('프로필', style: AppTypography.titleLarge),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.ink900,
              ),
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.onCameraTap});
  final MyProfile? profile;
  final VoidCallback onCameraTap;

  String get _name {
    final name = profile?.displayName?.trim();
    return (name == null || name.isEmpty) ? '—' : name;
  }

  /// "27세 · 서울" — 없는 값은 뺀다. 둘 다 없으면 빈 문자열.
  String get _subtitle {
    final age = profile?.age;
    final region = profile?.region;
    return [
      if (age != null) '$age세',
      if (region != null && region.isNotEmpty) region,
    ].join(' · ');
  }

  Widget _initialAvatar() {
    return Text(
      _name == '—' ? '' : _name.characters.first,
      style: AppTypography.displayMedium.copyWith(
        color: AppColors.ink700,
        fontSize: 36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: (profile?.photoUrl?.isNotEmpty ?? false)
                      ? Image.network(
                          profile!.photoUrl!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          // 로딩·실패 시 빈 회색 원 대신 이니셜 폴백을 보장한다.
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const AmoriLoader(size: 20),
                          errorBuilder: (context, _, _) => _initialAvatar(),
                        )
                      : _initialAvatar(),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onCameraTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          Text(_name, style: AppTypography.titleLarge.copyWith(fontSize: 22)),
          if (_subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _subtitle,
              style: AppTypography.bodySmall.copyWith(color: AppColors.ink500),
            ),
          ],
          AppSpacing.vSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: const ShapeDecoration(
              color: AppColors.surfaceMuted,
              shape: StadiumBorder(),
            ),
            child: Text(
              '일반 멤버',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.onInsight, required this.onRelearn});
  final VoidCallback onInsight;
  final VoidCallback onRelearn;

  @override
  Widget build(BuildContext context) {
    final amori = context.amori;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 AI 에이전트',
          style: AppTypography.titleMedium.copyWith(fontSize: 14),
        ),
        AppSpacing.vSm,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.rLg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  gradient: amori.primaryGradient,
                  shape: const CircleBorder(),
                  shadows: amori.glowShadow,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "내 AI",
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '대표 질문 기반 · 답변 보완 가능',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                        fontSize: 12,
                      ),
                    ),
                    AppSpacing.vSm,
                    _AgentLink(label: '성향 분석 카드 보기', onTap: onInsight),
                    const SizedBox(height: 4),
                    _AgentLink(label: '페르소나 답변 보완하기', onTap: onRelearn),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentLink extends StatelessWidget {
  const _AgentLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.regionDetail,
    required this.matchPrefDetail,
    required this.mbtiDetail,
    required this.bioDetail,
    required this.onRegion,
    required this.onMatchPref,
    required this.onMbti,
    required this.onBio,
    required this.onLinkedApps,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final String regionDetail;
  final String matchPrefDetail;
  final String mbtiDetail;
  final String bioDetail;
  final VoidCallback onRegion;
  final VoidCallback onMatchPref;
  final VoidCallback onMbti;
  final VoidCallback onBio;
  final VoidCallback onLinkedApps;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
      child: Column(
        children: [
          SettingsSection(
            title: '매칭',
            rows: [
              SettingsRow(
                icon: Icons.place_rounded,
                label: '활동 지역',
                detail: regionDetail,
                onTap: onRegion,
              ),
              SettingsRow(
                icon: Icons.psychology_rounded,
                label: 'MBTI',
                detail: mbtiDetail,
                onTap: onMbti,
              ),
              SettingsRow(
                icon: Icons.edit_note_rounded,
                label: '한줄 소개',
                detail: bioDetail,
                onTap: onBio,
              ),
              SettingsRow(
                icon: Icons.favorite_rounded,
                label: '매칭 선호 설정',
                detail: matchPrefDetail,
                onTap: onMatchPref,
              ),
              SettingsRow(
                icon: Icons.link_rounded,
                label: '연동 앱',
                onTap: onLinkedApps,
                last: true,
              ),
            ],
          ),
          SettingsSection(
            title: '계정',
            rows: [
              SettingsRow(
                icon: Icons.logout_rounded,
                label: '로그아웃',
                danger: true,
                onTap: onLogout,
                last: true,
              ),
            ],
          ),
          AppSpacing.vLg,
          GestureDetector(
            onTap: onDeleteAccount,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '회원 탈퇴',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'amori v${AppConfig.appVersion}',
            style: AppTypography.caption.copyWith(
              color: AppColors.ink300,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleLarge),
            AppSpacing.vSm,
            Text(
              body,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink500,
                height: 1.5,
              ),
            ),
            AppSpacing.vLg,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundColor: AppColors.ink900,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: AppTypography.label.copyWith(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: danger
                          ? AppColors.danger
                          : AppColors.ink900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rMd,
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
