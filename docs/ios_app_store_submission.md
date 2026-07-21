# Amori — iOS App Store 제출 체크리스트 & 레퍼런스

> 대상: 앱 오너 / 릴리스 담당자
> 앱: **amori** (AI 프리데이팅 데이팅 앱, Flutter)
> Bundle ID: **`kr.co.vience.amori`**
> 최소 지원 버전: **iOS 13.0** (Firebase iOS SDK 최소 요구사항과 일치)
> 이 문서는 저장소에 이미 반영된 항목과, 저장소에서는 할 수 없어 **오너가 콘솔에서 직접** 해야 하는 후속 작업을 구분해 정리합니다.

---

## 1. 저장소에 이미 반영되어 있는 것 (In-Repo — Done)

아래 항목은 이미 코드/설정에 들어가 있으므로 추가 작업이 필요 없습니다. (심사 시 참고용)

- [x] **Bundle Identifier** = `kr.co.vience.amori` (iOS Runner 프로젝트에 설정됨)
- [x] **`PrivacyInfo.xcprivacy`** (Privacy Manifest) 추가 — 수집 데이터 타입 선언 포함 (§4 매핑표와 일치)
- [x] **Info.plist 권한 사용 설명 문구(usage strings)** — 주소록/사진첩 접근 등에 대한 `NS...UsageDescription`
- [x] **Push 관련 Entitlements** — `Runner.entitlements` (aps-environment) + `UIBackgroundModes`(remote-notification)
- [x] **`ITSAppUsesNonExemptEncryption = false`** (Info.plist) — 수출 규정(Export Compliance) 자동 처리용 선언
- [x] **계정 삭제(회원 탈퇴)** 구현 — 앱 내 프로필 화면에서 도달 가능. 서버 도메인 데이터(매칭·시뮬레이션·대화·리포트·만남신청·피드백·페르소나·LLM 호출 로그) + Firebase Auth 계정 삭제. (App Store Guideline 5.1.1(v) 요구사항 충족)
- [x] **차단/신고(UGC moderation)** — 대화 화면에서 "신고하기 / 차단하기" 제공. (사용자 생성 콘텐츠 앱 Guideline 1.2 요구사항)
- [x] **연령 게이트** — 만 19세 이상만 이용. 앱 피커 + 서버 API 양쪽에서 만 19세 미만 저장 거부
- [x] **인앱 개인정보처리방침 / 이용약관** — 설정·가입 화면에서 열람 가능 (`lib/features/legal/legal_screen.dart`)
- [x] **연락처 원문 미전송** — 지인 필터의 연락처는 온디바이스에서 SHA-256 해시되어 해시값만 서버로 전송

---

## 2. 콘솔에서 직접 해야 하는 후속 작업 (Console-Only — Owner MUST Do)

저장소만으로는 끝낼 수 없는, 반드시 사람이 각 콘솔에서 처리해야 하는 작업입니다. 순서대로 진행하세요.

### 2.1 Firebase Console

- [ ] Firebase 프로젝트에 **iOS 앱 추가** — Bundle ID `kr.co.vience.amori`
- [ ] **실제 `GoogleService-Info.plist` 다운로드** 후 `ios/Runner/GoogleService-Info.plist`를 **교체**
  - ⚠️ 현재 저장소의 파일은 **Bundle ID만 맞춰 넣은 placeholder**입니다. 실제 값으로 교체하지 않으면 인증/알림이 동작하지 않습니다.
- [ ] **APNs 인증 키(.p8) 업로드** → Firebase Console → Project Settings → Cloud Messaging → Apple app configuration
  - Apple Developer의 Keys에서 APNs Auth Key(.p8)를 만들어 Key ID / Team ID와 함께 업로드해야 iOS 푸시가 동작합니다.

### 2.2 Apple Developer (Certificates, Identifiers & Profiles)

- [ ] **App ID `kr.co.vience.amori` 생성** — **Push Notifications** capability 활성화
- [ ] App Store 배포용 **provisioning profile** 생성 (또는 Xcode 자동 서명 사용)
- [ ] 위 2.1의 **APNs Auth Key(.p8)** 발급 (아직 안 했다면 여기서)

### 2.3 Xcode (Mac 필요)

- [ ] `ios/Runner.xcworkspace` 열기 (`.xcodeproj` 아님 — CocoaPods 때문에 workspace로)
- [ ] Runner 타겟 → Signing & Capabilities → **Team 선택**, **Automatically manage signing** 켜기
- [ ] **Push Notifications** + **Background Modes → Remote notifications** capability가 표시되는지 확인
  - 이 두 capability는 저장소의 `Runner.entitlements`(aps-environment) 및 `Info.plist`의 `UIBackgroundModes`와 매핑됩니다. 자동으로 뜨지 않으면 수동 추가.
- [ ] Deployment Target이 **iOS 13.0**인지 확인

### 2.4 App Store Connect

- [ ] **앱 레코드 생성** (신규 앱)
- [ ] **연령 등급(Age Rating): 17+** — 데이팅/성인 대상 (Frequent/Intense Mature/Suggestive Themes 등 해당 항목 체크)
- [ ] **카테고리**: Lifestyle 또는 Social Networking
- [ ] **Privacy Policy URL** 등록 (인앱 방침과 동일 내용을 공개 URL로도 호스팅) + **Support URL** 등록
- [ ] **App Privacy 설문** 작성 — §4 매핑표 사용
- [ ] **Export Compliance**: 비면제(non-exempt) 암호화 사용 → **아니오(No)**. (`ITSAppUsesNonExemptEncryption=false`로 이미 선언되어 있어 대개 추가 질문 없이 통과)
- [ ] 스크린샷 + 설명(description) + 키워드 업로드

### 2.5 빌드 & 업로드

- [ ] Mac + Xcode 환경에서 릴리스 빌드:
  ```bash
  flutter build ipa --release
  ```
- [ ] Xcode Organizer 또는 **Transporter**로 `.ipa` 업로드
- [ ] App Store Connect에서 빌드 선택 후 **심사 제출(Submit for Review)**

---

## 3. 심사 참고 노트 (Review Notes)

### 3.1 Sign in with Apple — 필수 아님
App Store Guideline **4.8**(Sign in with Apple 요구)은 앱이 **제3자/소셜 로그인**(Google, Facebook, Kakao 등)을 제공할 때만 적용됩니다. amori는 **Firebase 이메일/비밀번호(1st-party) 로그인만** 사용하므로 Sign in with Apple을 **추가할 의무가 없습니다.** (나중에 편의 기능으로 추가하는 것은 가능하나 필수는 아님.)

### 3.2 위치
활동 지역은 사용자가 **텍스트로 직접 입력하는 시/도 단위(coarse) 정보**이며, **GPS 위치를 수집하지 않습니다.** 따라서 위치 권한 프롬프트가 없고, App Privacy 설문에서도 "Precise Location"에 해당하지 않습니다.

### 3.3 App Tracking Transparency (ATT)
**추적(tracking) 없음.** 광고 SDK/크로스앱 추적을 사용하지 않으므로 **ATT 프롬프트가 필요 없습니다.**

### 3.4 계정 삭제 경로 (Guideline 5.1.1(v))
심사자가 확인할 수 있도록, 계정 삭제는 앱 내 **프로필 화면 → "회원 탈퇴"**에서 도달합니다. 삭제 시 서버 도메인 데이터와 로그인 계정이 함께 삭제됩니다. (필요 시 심사 노트에 이 경로를 명시)

### 3.5 데모 계정
심사자가 로그인해야 기능을 볼 수 있다면, App Review Information에 **데모 계정(이메일/비밀번호)**을 제공하세요.

---

## 4. App Privacy 설문 매핑표

`PrivacyInfo.xcprivacy`와 일치. App Store Connect의 App Privacy 설문 입력 시 그대로 사용하세요.

| Data Type | Linked to User? | Used for Tracking? | Purpose |
|---|---|---|---|
| Email Address | Yes (Linked) | No | App Functionality — 계정/인증 |
| Name (표시 이름) | Yes (Linked) | No | App Functionality |
| Photos (프로필 사진) | Yes (Linked) | No | App Functionality |
| Phone Number | Yes (Linked) | No | App Functionality — 지인 필터(해시 처리) |
| User Content (페르소나·대화·시뮬레이션) | Yes (Linked) | No | App Functionality |
| Device ID / FCM Token | Yes (Linked) | No | App Functionality — 푸시 알림 |
| Coarse Location / 활동 지역 (텍스트) | Yes (Linked) | No | App Functionality |

- **Tracking: 없음 (NONE)** — 어떤 데이터도 크로스앱/크로스사이트 추적에 사용하지 않음.
- **ATT 프롬프트: 불필요.**

### 참고: 연락처(지인 필터)의 특수성
지인 필터의 연락처는 **기기에서 SHA-256으로 해시 처리된 뒤 해시값만 서버로 전송**되며, **전화번호/이메일 원문은 서버로 전송·저장되지 않습니다.** 위 표의 "Phone Number" 항목은 이 해시 기반 처리를 반영한 것으로, 원문 연락처를 수집·저장하지 않는다는 점을 App Privacy 설명 및 심사 노트에 명확히 기재하는 것을 권장합니다.

---

## 5. 데이터 처리 요약 (개인정보처리방침과 정합)

| 수집 항목 | 목적 | 처리 주체 |
|---|---|---|
| 이메일, 비밀번호 | 계정 인증 | Firebase Authentication (Google LLC) |
| 프로필 사진 | 프로필 표시 | Firebase Cloud Storage (Google LLC) |
| FCM 토큰 | 푸시 알림 | Firebase Cloud Messaging (Google LLC) |
| 표시 이름·생년월일·성별·희망 성별·지역·MBTI·소개·페르소나·대화 | 매칭/시뮬레이션/리포트 | 자체 백엔드(BFF) + Postgres |
| 온보딩 답변 / 대화 텍스트 | 페르소나 생성·시뮬레이션 | 자체 백엔드(BFF)를 거쳐 LLM API로 전송·처리 |
| 연락처(전화·이메일) 해시 | 지인 필터(서로 매칭 방지) | 온디바이스 해시 → 해시값만 자체 백엔드 저장 (원문 미전송) |

> Firebase는 **Auth + FCM + Storage** 용도로만 사용하며, 도메인 데이터의 단일 원천은 자체 백엔드 뒤의 Postgres입니다.

---

## 6. 제출 전 최종 점검 (Pre-Submit Sanity Check)

- [ ] `ios/Runner/GoogleService-Info.plist`가 **실제 파일로 교체**되었는가 (placeholder 아님)
- [ ] APNs 키가 Firebase에 업로드되어 실제 기기에서 푸시 수신이 확인되었는가
- [ ] 개인정보처리방침이 **공개 URL**로도 접근 가능한가 (App Store Connect 필수)
- [ ] 계정 삭제(회원 탈퇴)가 실제로 동작하는지 확인
- [ ] 신고/차단이 동작하는지 확인
- [ ] 연령 등급 17+ 로 설정되었는가
- [ ] Export Compliance 질문에 "No"로 답했는가

---

*이 문서는 저장소 코드/설정 기준으로 작성되었습니다. Firebase/Apple 콘솔의 실제 상태는 담당자가 확인해야 합니다.*
