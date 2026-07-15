import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/user_repository.dart';
import '../router/app_routes.dart';

/// 인앱 알림 한 건 — 홈 우측 상단 종 아이콘의 목록 항목.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.emoji,
    required this.title,
    required this.body,
    required this.route,
  });

  final String id; // photo | bio | mbti | daily — 시그니처(읽음 판정)에 쓰인다
  final String emoji;
  final String title;
  final String body;
  final String route;
}

/// 홈 알림 배지 — 프로필 완성 넛지 + 오늘의 질문을 기기에서 계산한다.
///
/// 서버 알림함이 아니라 "지금 하면 좋은 일" 목록이라 저장소가 필요 없다.
/// 읽음 처리는 항목 id 시그니처 단위: 같은 구성을 이미 봤으면 배지를 숨기고,
/// 새 항목이 생기면(예: 다음날 데일리) 다시 표시한다.
class NotificationStore extends ChangeNotifier {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  static const _seenKey = 'notifications.seen_signature';

  List<AppNotification> _items = const [];
  bool _seen = true;

  List<AppNotification> get items => _items;

  /// 배지에 표시할 개수 — 이 구성을 이미 봤으면 0.
  int get unseenCount => _seen ? 0 : _items.length;

  String get _signature => _items.map((n) => n.id).join(',');

  /// 프로필·데일리 상태로 알림 목록을 다시 계산한다 (홈 진입 시 호출).
  Future<void> refresh({
    MyProfile? profile,
    String? dailyScenarioCode,
  }) async {
    final items = <AppNotification>[
      if (dailyScenarioCode != null)
        AppNotification(
          id: 'daily',
          emoji: '📮',
          title: '오늘의 질문이 도착했어요',
          body: '답할수록 에이전트가 나다워져요',
          route: AppRoutes.dailyScenario(dailyScenarioCode),
        ),
      if (profile != null && (profile.photoUrl?.isEmpty ?? true))
        const AppNotification(
          id: 'photo',
          emoji: '📷',
          title: '프로필 사진을 추가해 주세요',
          body: '사진이 있으면 상대가 만남을 결정하기 쉬워져요',
          route: AppRoutes.profile,
        ),
      if (profile != null && (profile.bio?.isEmpty ?? true))
        const AppNotification(
          id: 'bio',
          emoji: '✍️',
          title: '한줄 소개를 작성해 주세요',
          body: '리포트에서 상대에게 보여지는 첫인상이에요',
          route: AppRoutes.profile,
        ),
      if (profile != null && (profile.mbti?.isEmpty ?? true))
        const AppNotification(
          id: 'mbti',
          emoji: '🧭',
          title: 'MBTI를 입력해 주세요',
          body: '에이전트가 당신을 이해하는 힌트가 돼요',
          route: AppRoutes.profile,
        ),
    ];
    _items = items;
    final prefs = await SharedPreferences.getInstance();
    _seen = _items.isEmpty || prefs.getString(_seenKey) == _signature;
    notifyListeners();
  }

  /// 알림 목록을 열어봤다 — 현재 구성을 읽음 처리해 배지를 숨긴다.
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey, _signature);
    _seen = true;
    notifyListeners();
  }
}
