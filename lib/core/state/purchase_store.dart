import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// 리포트 열람 권한 — 구독 또는 매치 단건 구매 (v1 로컬 스텁).
///
/// ⚠️ 실결제(IAP/PG) 연동 전의 테스트용 상태 저장소다. 결제 버튼을 누르면
/// 결제 없이 권한이 로컬(SharedPreferences)에 기록된다 — 서버 검증 없음.
/// 실연동 시 이 스토어의 인터페이스는 유지하고 뒷단만 영수증 검증으로 교체한다
/// (refatodo "기존 잔여 작업" 참조).
class PurchaseStore {
  PurchaseStore._();

  static final PurchaseStore instance = PurchaseStore._();

  static const _subscribedKey = 'purchase.subscribed';
  static const _unlockedKey = 'purchase.unlocked_match_ids';

  Future<bool> isSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscribedKey) ?? false;
  }

  Future<void> setSubscribed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscribedKey, value);
  }

  /// 단건 구매 기록 — 해당 매치의 리포트만 열람 가능.
  Future<void> unlockMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_unlockedKey) ?? const [];
    if (!ids.contains(matchId)) {
      await prefs.setStringList(_unlockedKey, [...ids, matchId]);
    }
  }

  /// 이 매치의 리포트를 볼 수 있는가 — 구독자이거나 단건 구매한 매치.
  ///
  /// 유료화가 꺼져 있으면(v1 스토어 배포) 항상 열람 가능 — 페이월·가격
  /// UI로 진입하지 않는다(AppConfig.paidReportsEnabled 참조).
  Future<bool> canViewReport(String matchId) async {
    if (!AppConfig.paidReportsEnabled) return true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_subscribedKey) ?? false) return true;
    return (prefs.getStringList(_unlockedKey) ?? const []).contains(matchId);
  }
}
