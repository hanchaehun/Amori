import '../api/api_client.dart';

/// 지인 필터(주소록 연동) 상태 — GET /users/me/blocked-contacts 응답.
class BlockedContacts {
  const BlockedContacts({
    required this.enabled,
    required this.syncedCount,
    required this.manual,
  });

  /// 서버 플래그 — 본인인증 도입 전엔 false (쓰기 API도 403으로 잠김).
  final bool enabled;

  /// 주소록 동기화로 등록된 해시 수.
  final int syncedCount;

  /// 수동 등록 항목 (라벨은 마스킹/이름 — 원문 아님).
  final List<BlockedContactItem> manual;

  factory BlockedContacts.fromJson(Map<String, dynamic> json) =>
      BlockedContacts(
        enabled: json['enabled'] as bool? ?? false,
        syncedCount: json['synced_count'] as int? ?? 0,
        manual: [
          for (final item in (json['manual'] as List? ?? const []))
            BlockedContactItem.fromJson(item as Map<String, dynamic>),
        ],
      );
}

class BlockedContactItem {
  const BlockedContactItem({
    required this.id,
    required this.kind,
    this.label,
  });

  final String id;
  final String kind; // phone | email
  final String? label;

  factory BlockedContactItem.fromJson(Map<String, dynamic> json) =>
      BlockedContactItem(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? 'phone',
        label: json['label'] as String?,
      );
}

/// 주소록 동기화로 올릴 해시 한 건 — 원문은 기기 밖으로 나가지 않는다.
class ContactHashItem {
  const ContactHashItem({required this.hash, required this.kind});

  final String hash;
  final String kind;

  Map<String, dynamic> toJson() => {'hash': hash, 'kind': kind};
}

/// 지인 필터 API — 본인인증 도입 전엔 서버가 쓰기를 403으로 거부한다.
class ContactFilterRepository {
  ContactFilterRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  final ApiClient _api;

  Future<BlockedContacts> fetch() async {
    final json = await _api.getJson('/users/me/blocked-contacts');
    return BlockedContacts.fromJson(json as Map<String, dynamic>);
  }

  /// 주소록 전량 동기화 — 서버의 동기화분(source=contacts)이 교체된다.
  Future<BlockedContacts> syncContacts(List<ContactHashItem> hashes) async {
    final json = await _api.putJson('/users/me/blocked-contacts/sync', {
      'hashes': [for (final h in hashes) h.toJson()],
    });
    return BlockedContacts.fromJson(json as Map<String, dynamic>);
  }

  /// 수동 등록 — 주소록에 없는 지인의 전화번호/이메일 해시.
  Future<BlockedContactItem> addManual({
    required String hash,
    required String kind,
    String? label,
  }) async {
    final json = await _api.postJson('/users/me/blocked-contacts', {
      'hash': hash,
      'kind': kind,
      'label': ?label,
    });
    return BlockedContactItem.fromJson(json as Map<String, dynamic>);
  }

  Future<BlockedContacts> remove(String id) async {
    final json = await _api.deleteJson('/users/me/blocked-contacts/$id');
    return BlockedContacts.fromJson(json as Map<String, dynamic>);
  }
}
