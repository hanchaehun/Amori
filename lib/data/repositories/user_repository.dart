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

/// 내 프로필 스냅샷 — 프로필 화면 표시용 (`GET /users/me`).
class MyProfile {
  const MyProfile({
    this.displayName,
    this.birthDate,
    this.gender,
    this.interestGender,
    this.region,
    this.matchAgeOlder,
    this.matchAgeYounger,
    this.mbti,
    this.bio,
    this.photoUrl,
  });

  final String? displayName;
  final DateTime? birthDate;
  final String? gender;
  final String? interestGender;
  final String? region;
  // 매칭 허용 나이 — 나보다 위로/아래로 몇 살까지. null이면 서버 기본 5.
  final int? matchAgeOlder;
  final int? matchAgeYounger;
  final String? mbti;
  final String? bio;
  final String? photoUrl;

  /// 만 나이. 생년월일이 없으면 null.
  int? get age {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years -= 1;
    }
    return years;
  }

  factory MyProfile.fromJson(Map<String, dynamic> json) => MyProfile(
    displayName: json['display_name'] as String?,
    birthDate: DateTime.tryParse(json['birth_date'] as String? ?? ''),
    gender: json['gender'] as String?,
    interestGender: json['interest_gender'] as String?,
    region: json['region'] as String?,
    matchAgeOlder: json['match_age_older'] as int?,
    matchAgeYounger: json['match_age_younger'] as int?,
    mbti: json['mbti'] as String?,
    bio: json['bio'] as String?,
    photoUrl: json['photo_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'birth_date': birthDate?.toIso8601String(),
    'gender': gender,
    'interest_gender': interestGender,
    'region': region,
    'match_age_older': matchAgeOlder,
    'match_age_younger': matchAgeYounger,
    'mbti': mbti,
    'bio': bio,
    'photo_url': photoUrl,
  };

  MyProfile copyWith({
    String? region,
    int? matchAgeOlder,
    int? matchAgeYounger,
    String? mbti,
    String? bio,
  }) => MyProfile(
    displayName: displayName,
    birthDate: birthDate,
    gender: gender,
    interestGender: interestGender,
    region: region ?? this.region,
    matchAgeOlder: matchAgeOlder ?? this.matchAgeOlder,
    matchAgeYounger: matchAgeYounger ?? this.matchAgeYounger,
    mbti: mbti ?? this.mbti,
    bio: bio ?? this.bio,
    photoUrl: photoUrl,
  );
}

/// 사용자 프로필 — Firestore users 컬렉션 대신 Postgres 단일 원천 (`/users/me`).
class UserRepository {
  UserRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  final ApiClient _api;

  Future<void> saveProfile({
    String? displayName,
    String? birthDate, // yyyy-MM-dd
    String? gender,
    String? interestGender,
    String? region,
    int? matchAgeOlder,
    int? matchAgeYounger,
    String? mbti,
    String? bio,
    String? photoUrl,
    String? fcmToken,
    List<AvailableSlot>? availableSlots,
  }) async {
    await _api.putJson('/users/me', {
      'display_name': ?displayName,
      'birth_date': ?birthDate,
      'gender': ?gender,
      'interest_gender': ?interestGender,
      'region': ?region,
      'match_age_older': ?matchAgeOlder,
      'match_age_younger': ?matchAgeYounger,
      'mbti': ?mbti,
      'bio': ?bio,
      'photo_url': ?photoUrl,
      'fcm_token': ?fcmToken,
      if (availableSlots != null)
        'available_slots': [for (final s in availableSlots) s.toJson()],
    });
  }

  /// 회원 탈퇴 — 서버의 도메인 데이터(페르소나·매치·대화·리포트 등)를 삭제한다.
  /// [authToken]이 주어지면 그 토큰으로 인증한다(Firebase 계정을 먼저 삭제한
  /// 경우 미리 확보한 토큰 전달용).
  Future<void> deleteAccount({String? authToken}) async {
    await _api.deleteJson('/users/me', authorization: authToken);
  }

  /// 내 프로필 조회 — 프로필 화면의 이름·나이·지역 표시용.
  Future<MyProfile> fetchMe() async {
    final json = await _api.getJson('/users/me') as Map<String, dynamic>;
    return MyProfile.fromJson(json);
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
