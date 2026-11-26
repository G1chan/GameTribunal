# 겜문철 (GameTribunal)

> **게이머들의 억울한 교전 과실을 증거 영상과 집단 지성으로 판정하는 커뮤니티 재판소** 
> 리그 오브 레전드 · 발로란트 · 오버워치 2 지원 · Flutter + Firebase + On-Device AI

---

## 프로젝트 소개

**겜문철(GameTribunal)**은 팀 게임 중 발생하는 분쟁과 과실 논란을 **리플레이 영상 정밀 판독**, **편승 효과를 차단한 블라인드 1인 1표 투표**, **60:40 유효 판결 자동 정산**으로 공정하게 판정하는 크로스플랫폼 애플리케이션입니다.

단순 투표를 넘어 활동 보상(XP/포인트), 레벨에 따라 자동 진화하는 아바타 테두리, 누적 순위를 해치지 않는 포인트 상점 및 보관함까지 하나의 순환형 게이미피케이션 생태계로 설계되었습니다.

---

## 주요 기능

### 1. 인증 · 온보딩 · 계정 관리
* **소셜 및 이메일 인증:** 이메일/비밀번호 로그인·회원가입과 Google 소셜 로그인 지원
* **관심 종목 온보딩:** 리그 오브 레전드, 발로란트, 오버워치 2 중 관심 종목(최대 3개) 설정 → 홈 피드 우선 추천 및 알림 기준 연동
* **프로필 사진 & 게임 티어 등록:** Cloudinary 기반 프로필 사진 업로드/초기화 및 종목별 인게임 닉네임(`닉네임#태그`)·티어(언랭크~마스터 이상) 관리
* **계정 설정:** 상점 `닉네임 변경권` 소모 방식의 닉네임 변경(AI 모더레이션 적용), 비밀번호 재설정 메일 발송, 회원 탈퇴 지원

### 2. 홈 피드 · 검색 · 사건 제보
* **3단계 우선순위 피드 정렬:** `1순위 긴급 재판 부스트 사건` → `2순위 내 관심 종목 사건` → `3순위 최신순` 실시간 스트림 정렬
* **통합 키워드 검색 & 필터:** 제목, 게임명, 티어, 유형, 설명, 제보자 닉네임, 쟁점 해시태그(`#진입 타이밍` 등) 실시간 검색 및 `LIVE` 필터 제공
* **사건 제보 & 영상 업로드:** 양측(Party A 신청인 / Party B 상대방) 진술, 쟁점 태그, 투표 마감 시간 설정 및 최대 100MB 증거 영상 업로드(썸네일 자동 생성)
* **온디바이스 AI 클린 모더레이션:** 사건 제목·진술·댓글·닉네임 입력 시 내장 Gemma AI 모델로 비속어 및 비방 표현을 사전 검열

### 3. VAR 스타일 영상 판독 & 블라인드 투표
* **정밀 영상 판독 플레이어:** 5단계 배속(`0.25x`~`1.5x`), `-3초 / +3초` 미세 탐색, 구간 반복 재생(`Loop`) 지원
* **타임스탬프 판독 댓글 연동:** 영상 시청 중 `+ 현재 시간` 버튼으로 재생 시점(예: `0:14`)을 댓글에 자동 입력하고, 댓글의 시간 칩 클릭 시 영상 상단 스크롤 및 해당 시점으로 즉시 점프·재생
* **블라인드 1인 1표 투표:** Firestore 트랜잭션으로 중복 투표 차단, 투표 전 비율 비공개 처리, 투표 시 배심원의 해당 게임 티어 및 상위 티어(플래티넘 이상) 여부 기록
* **작성자 전용 관리:** 본인 사건에 한해 `긴급 부스트 적용`, `투표 즉시 마감`, `사건 삭제(하위 votes·comments 일괄 정리)` 제공

### 4. 실시간 토론 스레드
* **입장별 토론 & 대댓글:** 모든 의견에 `신청인 과실 / 상대방 과실` 입장을 명시하고, 원댓글 아래 들여쓰기된 대댓글 스레드 지원
* **배타적 공감·비공감:** 공감(좋아요)과 비공감(싫어요) 상호 전환 처리 및 부모 댓글 삭제 시 하위 대댓글 연쇄 삭제
* **전 화면 실시간 프로필 동기화:** `LiveUserAvatar`와 `LiveUserTitleBadge`가 작성자 UID를 직접 구독하여 프사·레벨 테두리·장착 칭호 변경 시 과거 댓글과 홈 카드까지 즉시 반영

### 5. 자동 정산 & 판정 시각화 리포트
* **60:40 유효 판결 정산:** 마감 시 최소 참여 인원을 충족하고 60:40 이상으로 갈린 경우에만 유효 판결 확정(미달 시 '치열한 논쟁(보류)' 처리), 앱 진입 시 미정산 투표 자동 정산 및 적중 보너스 지급
* **데이터 시각화 & 티어 비교:** `fl_chart` 도넛 차트로 최종 과실 비율을 시각화하고, **전체 배심원 vs 상위 티어(플래티넘 이상) 배심원 vs 토론 댓글 입장 비율** 비교 분석 및 공감 상위 핵심 의견 요약 제공
* **이미지 저장 & 결과 공유:** 리포트 요약 카드를 고해상도 PNG 이미지로 캡처해 저장·공유하거나 텍스트 요약본 외부 공유

### 6. 게이미피케이션 · 랭킹 · 포인트 상점 & 보관함
* **활동 보상 및 레벨 시스템:**
  * 사건 제보 `+30 XP / +10 P` · 토론 댓글 `+15 XP / +5 P` · 판정 투표 `+10 XP / +5 P` · 유효 판결 적중 `+20 XP / +15 P`
  * 레벨업 공식: `nextLevelXp = currentLevel * 100`
* **4단계 자동 진화 레벨 테두리 (`LevelUserAvatar`):**
  * `Lv.1 ~ 4` 실버 견습 (메탈 회전 광택)
  * `Lv.5 ~ 9` 사파이어 블루 (외곽 글로우 + 하단 젬)
  * `Lv.10 ~ 19` 크림슨 루비 (강한 광채 + 상단 다이아 크레스트)
  * `Lv.20+` 챌린저 골드 (골드·아쿠아 그라데이션 + 좌우 날개 윙 + 크라운 크레스트)
* **이중 포인트 경제 & 랭킹 보호:** 소비용 `points`와 랭킹용 `totalEarnedPoints`를 분리해 상점 소비 후에도 **명예의 전당(누적 포인트)** 순위가 하락하지 않도록 설계 (`배심원 랭킹(활동 XP)` 탭 및 Top 3 단상 제공)
* **포인트 상점 & 내 보관함 (`ShopPage`):**
  * **소모품:** `닉네임 변경권 (30 P)` · `긴급 재판 부스트권 (50 P)`
  * **특별 칭호:** `예리한 매의 눈 (40 P)` · `솔로랭크 판사 (60 P)` · `명예 대법관 (100 P)`
  * 보관함에서 보유 티켓 확인, 칭호 실시간 장착/해제, 4단계 레벨 테두리 도감 미리보기 지원

---

## 기술 스택 및 오픈소스

| 분류 | 기술 / 패키지 | 역할 |
| :--- | :--- | :--- |
| **Framework** | `Flutter` (Dart) | Web(Chrome) · Android · iOS 크로스플랫폼 UI 및 상태 처리 |
| **Auth** | `firebase_auth`, `google_sign_in` | 이메일·구글 로그인, 세션 관리, 비밀번호 재설정, 회원 탈퇴 |
| **Database** | `cloud_firestore` | 실시간 스트림 동기화, 1인 1표·상점 결제 트랜잭션, 배치 삭제 |
| **On-Device AI** | `flutter_edge_ai`, `litertlm_dart` | Gemma 4 E2B 모델 기반 로컬/웹 텍스트 유해성 판별 |
| **Media Cloud** | `Cloudinary API`, `http`, `file_picker` | 증거 영상(최대 100MB)·프로필 사진(최대 10MB) 업로드 및 자동 썸네일 생성 |
| **Video Player** | `video_player`, `chewie` | 네트워크 영상 스트리밍, 커스텀 배속·구간 반복·외부 타임스탬프 점프 |
| **Visualization** | `fl_chart` | 판정 리포트 과실 비율 도넛 차트 렌더링 |
| **Export & Share** | `screenshot`, `share_plus`, `cross_file` | 리포트 위젯 PNG 캡처 저장 및 결과 텍스트/이미지 외부 공유 |

---

## 핵심 아키텍처 및 데이터 흐름

### 1. 증거 영상 & 프로필 사진 업로드 파이프라인
```text
[file_picker] 파일 선택 (용량 검증: 영상 100MB / 이미지 10MB)
      │
      ▼
[VideoUploadService + http] Cloudinary REST API 업로드 (/video/upload, /image/upload)
      │
      ▼
secure_url 반환 (영상은 확장자 .jpg 치환으로 자동 썸네일 URL 생성)
      │
      ▼
[Cloud Firestore] cases/{caseId} 또는 users/{uid}.photoUrl 저장 → 전 화면 즉시 반영
```

### 2. 블라인드 투표 · 정산 · 상점 순환 구조
```text
[CaseDetailPage] 블라인드 투표 제출 (트랜잭션: 중복 방지 + 배심원 티어 기록, +10 XP / +5 P)
      │
      ▼
마감 시간 도래 또는 작성자 [즉시 마감] → 60:40 규칙으로 승자 판정 (left / right / draw)
      │
      ▼
[HomePage 진입] settleMyVotes() 자동 정산 → 적중 시 보너스 (+20 XP / +15 P) & 적중률 반영
      │
      ├── XP 누적 ──▶ 레벨업 ──▶ [LevelUserAvatar] 4단계 테두리 자동 진화
      └── points 소비 ──▶ [ShopPage] 아이템 구매 (totalEarnedPoints 유지로 랭킹 보호)
```

---

## Firestore 데이터베이스 스키마

```text
firestore
├── users/{uid}
│   ├── nickname, email, photoUrl, favoriteGames[], onboardingCompleted
│   ├── notificationsEnabled, lastNotificationReadAt
│   ├── gameAccounts: { "리그 오브 레전드": { gameId, tier }, ... }
│   ├── xp, level, points (사용 가능), totalEarnedPoints (랭킹 기준 누적)
│   ├── totalVotes, validJudgedCount, hitCount
│   ├── ownedTitles[], equippedTitleId, nicknameTickets, boostTickets
│   └── myVotes/{caseId}
│       └── caseId, caseTitle, caseGame, choice, settled, caseWinner, votedAt
│
└── cases/{caseId}
    ├── authorUid, authorNickname, game, title, type, tier, description
    ├── partyAStatement, partyBStatement, issues[]
    ├── videoUrl, thumbnailUrl, boostedUntil
    ├── leftVotes, rightVotes, commentCount, status, winner, createdAt, expiresAt
    ├── votes/{voterUid}
    │   └── uid, choice, voterTier, isHighTier, votedAt
    └── comments/{commentId}
        └── authorUid, authorNickname, content, side, parentId, likedBy[], dislikedBy[], createdAt
```

---

## 프로젝트 주요 구조

```text
lib/
├── models/
│   ├── case_model.dart           # 레거시 호환 사건 모델
│   └── shop_item.dart            # 포인트 상점 상품 카탈로그 및 메타데이터
├── services/
│   ├── auth_service.dart         # Firebase Auth 및 Google 로그인 처리
│   ├── user_service.dart         # 유저 프로필, 보상/레벨, 상점 결제, 게임 티어 관리
│   ├── case_service.dart         # 사건 CRUD, 블라인드 투표, 부스트, 대댓글/공감·비공감, 자동 정산
│   ├── video_upload_service.dart # Cloudinary 영상·이미지 업로드 및 썸네일 생성
│   ├── ai_moderation_engine.dart # Gemma 4 E2B 온디바이스 AI 엔진 관리
│   └── moderation_service.dart   # 텍스트 유해성 필터링 파이프라인
├── widgets/
│   ├── user_avatar.dart          # LevelUserAvatar(4단계 애니메이션 테두리), UserTitleBadge, Live 위젯
│   ├── case_video_player.dart    # 배속·탐색·반복·외부 타임스탬프 점프 지원 영상 플레이어
│   ├── app_header.dart           # 공통 상단 앱바 및 알림 연동
│   ├── app_bottom_navigation.dart# 하단 5탭 내비게이션
│   └── verdict_bar.dart          # 과실 비율 게이지 바
└── screens/
    ├── login.dart / onboarding_page.dart
    ├── home_page.dart            # 실시간 피드, 키워드 검색, 부스트/관심종목 우선 정렬
    ├── case_create_step1_page.dart ... # 사건 제보 및 영상 첨부 플로우
    ├── case_detail_page.dart     # 영상 판독, 블라인드 투표, 인라인 타임스탬프 댓글, 작성자 관리
    ├── discussion_page.dart      # 실시간 토론, 대댓글 스레드, 공감/비공감, 타임스탬프 점프
    ├── verdict_report_page.dart  # fl_chart 도넛 차트, 상위 티어 비교, 이미지 캡처/공유
    ├── ranking_page.dart         # 명예의 전당(누적 P) / 배심원 랭킹(활동 XP) & Top 3 단상
    ├── shop_page.dart            # 포인트 상점 & 내 보관함(티켓·칭호 장착·테두리 도감)
    ├── profile_page.dart         # 프로필 사진 업로드, 게임 계정/티어 관리, 설정 진입
    └── account_settings_page.dart# 닉네임 변경권 사용, 비밀번호 재설정, 회원 탈퇴
```

---

## 로컬 실행 방법

### 1. 사전 준비
* Flutter SDK 설치 (Dart 3.x 호환)
* Firebase 프로젝트 연동 (`firebase_options.dart` 구성 완료 상태)
* `assets/images/shop/` 경로에 상점 아트워크 이미지 배치:
  * `nickname_ticket.png` · `case_boost.png` · `title_hawk.png` · `title_judge.png` · `title_chief.png`

### 2. 패키지 설치 및 실행
```bash
# 의존성 설치
flutter pub get

# 정적 분석 확인
flutter analyze

# Chrome 웹 실행
flutter run -d chrome
```

---

## 배포 전 체크리스트

* **Firestore 보안 규칙 적용:** 개발용 테스트 모드 해제 후 인증 사용자 기반 읽기/쓰기 및 본인 소유 리소스(`users/{uid}`, 본인 작성 사건·댓글)만 수정·삭제할 수 있도록 `Firestore Rules` 게시
* **판정 정책 임계값 조정:** 실제 서비스 배포 시 `PolicyConfig`(`lib/services/user_service.dart`)의 `minVotesForValidCase`, `minValidJudgedForAccuracy` 상수를 테스트 기준(3건)에서 운영 기준(예: 10건)으로 상향 조정