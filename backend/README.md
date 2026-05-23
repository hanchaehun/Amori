# AMORI Backend (Firebase-only)

Flutter 앱이 별도 HTTP 서버 없이 Firebase SDK만 사용하도록 백엔드 책임을 Firebase로 옮깁니다. 이 폴더에는 더 이상 Node/FastAPI/npm 서버가 없습니다.

## 선택한 구조

- 인증: Firebase Auth
- 데이터베이스: Cloud Firestore
- 파일: Firebase Storage 규칙 준비 완료. 기본 버킷 생성은 Firebase 콘솔/Blaze 설정이 필요합니다.
- 알림 토큰 저장: Firestore `notificationTokens`
- 서버 API: 없음. Flutter가 Firebase SDK로 직접 읽고 씁니다.
- LLM/매칭: 발표 전까지 mock 또는 seed 문서를 Firestore에 저장해서 사용합니다.

> 주의: Cloud Functions 없이 Firebase만 쓰면 LLM 키 보호, 서버사이드 벡터 검색, 강제 일일 quota, 감사 로그의 무결성은 완전하게 보장할 수 없습니다. 운영 단계에서 이 책임이 필요해지면 Cloud Functions, Firebase Extensions, 또는 별도 BFF가 다시 필요합니다.

## Firebase 파일

루트에 배치된 Firebase 설정 파일:

- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`

Firebase 프로젝트는 `amori-260523`으로 연결되어 있습니다.
Firestore 규칙/인덱스와 Email/Password Auth provider는 배포 완료했습니다.

## Firestore 컬렉션 계약

### `users/{uid}`

Firebase Auth UID와 같은 문서 ID를 사용합니다.

```json
{
  "displayName": "지은",
  "birthDate": "1998-01-01",
  "gender": "female",
  "interestGender": "male",
  "photoUrl": "gs://...",
  "kycStatus": "pending",
  "entitlements": {
    "plan": "free",
    "reportUnlocks": []
  },
  "dailyQuota": {
    "meetRequests": 1,
    "simulations": 5
  },
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### `personas/{uid}`

`shared/schemas/persona.schema.json`의 camelCase Firestore 버전입니다. `embedding`은 1024차원 배열이어야 합니다.

```json
{
  "userId": "firebase-uid",
  "traits": [],
  "communicationStyle": "느린 일상·진심형",
  "humorStyle": "잔잔한 유머·드라이톤",
  "valueKeywords": ["존중", "일상 공유"],
  "embedding": [0.01],
  "aiGenerated": true,
  "source": "mock",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### `matches/{matchId}`

Flutter의 매치 리스트와 리포트 진입점입니다.

```json
{
  "participantIds": ["uid-a", "uid-b"],
  "score": 84,
  "values": 86,
  "humor": 79,
  "communication": 88,
  "status": "candidate",
  "recommendedTopics": ["음악", "산책"],
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

권장 `matchId`: 두 UID를 정렬한 뒤 `_`로 연결합니다.

### `simulationJobs/{jobId}`

Cloud Functions 없이 쓰는 경우 Flutter가 mock 시뮬레이션 결과를 생성해 저장합니다.

```json
{
  "matchId": "uid-a_uid-b",
  "requestedBy": "uid-a",
  "status": "completed",
  "turns": [
    {
      "turnIndex": 0,
      "speaker": "me",
      "text": "대화 내용",
      "signal": "대화 템포 일치",
      "aiGenerated": true
    }
  ],
  "createdAt": "serverTimestamp",
  "completedAt": "serverTimestamp"
}
```

### `reports/{matchId}`

`shared/schemas/report.schema.json`의 camelCase Firestore 버전입니다.

```json
{
  "matchId": "uid-a_uid-b",
  "score": 84,
  "findings": [],
  "warnings": [],
  "places": [],
  "starters": [],
  "tip": "첫 만남 팁",
  "aiGenerated": true,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### `meetRequests/{requestId}`

```json
{
  "matchId": "uid-a_uid-b",
  "requesterId": "uid-a",
  "receiverId": "uid-b",
  "message": "가볍게 커피 한잔 어때요?",
  "status": "pending",
  "expiresAt": "timestamp",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

상태값: `pending`, `accepted`, `declined`, `expired`, `cancelled`

### `feedback/{feedbackId}`

```json
{
  "matchId": "uid-a_uid-b",
  "userId": "uid-a",
  "impression": "good",
  "accuracy": 0.8,
  "nextStep": "keepDating",
  "note": "대화 템포가 잘 맞았어요.",
  "createdAt": "serverTimestamp"
}
```

### `notificationTokens/{tokenId}`

```json
{
  "userId": "uid-a",
  "platform": "ios",
  "token": "fcm-token",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

## 기존 HTTP 엔드포인트 대체

| 기존 BFF 책임 | Firebase-only 대체 |
|---|---|
| `POST /persona/build` | Flutter가 mock persona를 생성하고 `personas/{uid}`에 저장 |
| `GET /matches/find` | `matches`에서 `participantIds array-contains uid` 쿼리 |
| `POST /simulation/run` | `simulationJobs` 문서 생성 후 mock turns 저장 |
| `GET /report/{matchId}` | `reports/{matchId}` 읽기 |
| `POST /meet/request` | `meetRequests` 문서 생성 |
| `GET /health` | Firebase SDK 초기화 성공 여부로 대체 |

## Flutter에서 필요한 패키지

Flutter 앱 쪽에는 최소한 다음 패키지가 필요합니다.

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`

FlutterFire 설정 파일도 필요합니다.

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

이 파일들은 Firebase 프로젝트가 정해진 뒤 `flutterfire configure`로 생성합니다.

## Firebase 콘솔에서 필요한 설정

1. Firebase 프로젝트 생성: `amori-260523`
2. Android 앱 등록: `com.example.amori`
3. iOS 앱 등록: `com.example.amori`
4. Web 앱 등록: `AMORI Web`
5. Cloud Firestore 생성: `(default)`, `asia-northeast3`
6. Authentication provider: 이메일/비밀번호만 사용
7. Firebase Storage 생성: 현재 미완료. 새 Firebase Storage 기본 버킷은 Blaze 요금제/콘솔 초기화가 필요할 수 있습니다.
8. Cloud Messaging 활성화
9. `firestore.rules`, `firestore.indexes.json`, `storage.rules` 배포

Firestore 배포 명령:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Auth provider 배포:

```bash
firebase deploy --only auth
```

Storage 기본 버킷을 만든 뒤에는 다음 명령으로 Storage rules를 배포합니다.

```bash
firebase deploy --only storage
```

## 남은 결정

현재 앱 ID는 Flutter 기본값인 `com.example.amori`입니다. 출시 전에 실제 Android package id와 iOS bundle id를 정하면 Firebase 앱을 추가 등록해야 합니다.
