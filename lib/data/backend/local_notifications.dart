import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 로컬 폰 알림 — 프로필 완성 넛지("사진을 추가해 주세요" 등).
///
/// 서버 푸시(FCM, "에이전트가 다녀왔어요")와 별개의 축이다: 넛지는 기기 상태만으로
/// 판단 가능해서 서버 없이 로컬 반복 알림으로 처리한다. Android 13+는
/// POST_NOTIFICATIONS 권한(매니페스트+런타임), iOS는 초회 권한 요청이 필요하다.
class LocalNotifications {
  LocalNotifications._();

  static final LocalNotifications instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _profileNudgeId = 1001;

  Future<void> _ensureInit() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // 권한은 requestPermission()에서 명시적으로 — 초기화 시 팝업 방지
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  /// 알림 권한 요청 (Android 13+ / iOS). 이미 허용됐으면 조용히 true.
  Future<bool> requestPermission() async {
    try {
      await _ensureInit();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {
      // 데스크톱/웹 등 미지원 플랫폼 — 알림 없이 동작
    }
    return false;
  }

  /// 프로필이 미완성인 동안 하루 1회 넛지. 같은 id로 재예약하면 갱신된다.
  Future<void> scheduleProfileNudge({
    required String title,
    required String body,
  }) async {
    try {
      await _ensureInit();
      await _plugin.periodicallyShow(
        id: _profileNudgeId,
        title: title,
        body: body,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'profile_nudge',
            '프로필 완성 안내',
            channelDescription: '프로필을 완성하면 매칭이 정확해져요',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // 정확한 시각이 중요하지 않은 넛지 — 정확 알람 권한 없이 동작
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // 권한 거부·미지원 플랫폼 — 인앱 배지가 대신 안내한다
    }
  }

  /// 프로필이 완성되면 넛지를 멈춘다.
  Future<void> cancelProfileNudge() async {
    try {
      await _ensureInit();
      await _plugin.cancel(id: _profileNudgeId);
    } catch (_) {}
  }
}
