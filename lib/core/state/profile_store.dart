import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/user_repository.dart';

/// 내 프로필 캐시 — 메모리 + 디스크 2단.
///
/// 프로필 화면이 열릴 때마다 서버 응답을 기다리면 이름이 '—'로 보인다.
/// 서버 응답은 디스크(SharedPreferences)에도 저장해 두고, 앱 시작(splash)에서
/// 네트워크 없이 즉시 복원한다 — 화면은 캐시를 먼저 그리고 백그라운드 갱신을
/// 반영한다(stale-while-revalidate). 로그아웃 시 메모리·디스크 모두 지운다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  static const _prefsKey = 'profile.cache';

  MyProfile? _profile;
  MyProfile? get profile => _profile;

  /// 디스크 캐시 복원 — splash가 홈으로 보내기 전에 1회 호출한다(수 ms).
  Future<void> hydrate() async {
    if (_profile != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      _profile = MyProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      // 손상된 캐시 — 서버 갱신이 덮어쓴다.
    }
  }

  void set(MyProfile profile) {
    _profile = profile;
    _persist(profile);
    notifyListeners();
  }

  /// 서버에서 갱신. 실패는 조용히 넘긴다 — 있던 캐시를 그대로 쓴다.
  Future<void> refresh() async {
    try {
      final profile = await UserRepository().fetchMe();
      _profile = profile;
      _persist(profile);
      notifyListeners();
    } catch (_) {
      // 네트워크/콜드스타트 실패 — 다음 진입 때 다시 시도한다.
    }
  }

  Future<void> _persist(MyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(profile.toJson()));
  }

  void reset() {
    _profile = null;
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_prefsKey));
  }
}
