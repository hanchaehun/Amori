import '../api/api_client.dart';

/// 소개팅 가능 일정 한 칸 — 에이전트는 이 시간 중에서만 약속을 잡는다.
class AvailableSlot {
  const AvailableSlot({required this.date, required this.time});

  final String date; // yyyy-MM-dd
  final String time; // 점심 | 저녁

  Map<String, String> toJson() => {'date': date, 'time': time};

  factory AvailableSlot.fromJson(Map<String, dynamic> json) => AvailableSlot(
    date: json['date'] as String? ?? '',
    time: json['time'] as String? ?? '저녁',
  );
}

/// 수락한 약속이 점유한 칸 — 일정 시트에서 잠금 표시되고 편집할 수 없다.
class BookedSlot {
  const BookedSlot({required this.date, required this.time, this.partnerName});

  final String date; // yyyy-MM-dd
  final String time; // 점심 | 저녁
  final String? partnerName;

  factory BookedSlot.fromJson(Map<String, dynamic> json) => BookedSlot(
    date: json['date'] as String? ?? '',
    time: json['time'] as String? ?? '저녁',
    partnerName: json['partner_name'] as String?,
  );
}

/// 일정 시트가 쓰는 내 일정 현황 — 입력한 가용 일정 + 약속으로 묶인 칸.
class Availability {
  const Availability({required this.open, required this.booked});

  final List<AvailableSlot> open;
  final List<BookedSlot> booked;
}

/// 사용자 프로필 — Firestore users 컬렉션 대신 Postgres 단일 원천 (`/users/me`).
class UserRepository {
  UserRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<void> saveProfile({
    String? displayName,
    String? birthDate, // yyyy-MM-dd
    String? gender,
    String? interestGender,
    String? photoUrl,
    String? fcmToken,
    List<AvailableSlot>? availableSlots,
  }) async {
    await _api.putJson('/users/me', {
      'display_name': ?displayName,
      'birth_date': ?birthDate,
      'gender': ?gender,
      'interest_gender': ?interestGender,
      'photo_url': ?photoUrl,
      'fcm_token': ?fcmToken,
      if (availableSlots != null)
        'available_slots': [for (final s in availableSlots) s.toJson()],
    });
  }

  /// 저장된 가능 일정 + 약속으로 묶인 칸 — 프로필의 일정 편집 시트가 쓴다.
  Future<Availability> fetchAvailability() async {
    final json = await _api.getJson('/users/me') as Map<String, dynamic>;
    return Availability(
      open: [
        for (final item
            in (json['available_slots'] as List? ?? [])
                .whereType<Map<String, dynamic>>())
          AvailableSlot.fromJson(item),
      ],
      booked: [
        for (final item
            in (json['booked_slots'] as List? ?? [])
                .whereType<Map<String, dynamic>>())
          BookedSlot.fromJson(item),
      ],
    );
  }
}
