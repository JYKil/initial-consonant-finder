# 계획서 — 한글 초성 검색 연락처 앱

## 배경

아이폰 기본 연락처 앱에는 한글 초성 검색 기능이 없다. 매일 연락처를 찾을 때마다 답답함을 느끼는 한국인 아이폰 사용자(= 본인)가 스스로 쓰기 위해 만드는 앱이며, 검증 후 App Store 출시를 목표로 한다.

**핵심 요구:**
- 앱 열면 키보드 즉시 뜨고 검색바 포커스
- 초성 입력("ㅇㅎ") → 일치 연락처 즉시 필터링
- 결과 탭 → 네이티브 전화/문자로 바로 연결

**기술 제약:** iOS 연락처(`Contacts.framework`)와 네이티브 전화/문자는 **Swift 네이티브 앱에서만** 접근 가능. Flask 같은 웹 프레임워크로는 불가능.

## 차별화 가설

기존 앱스토어 경쟁자들의 공통 약점 = 광고 떡칠, 느림, UI 난잡. 이 앱의 무기는 **"아무것도 없음"** 그 자체다. 설정 없음, 광고 없음, 탭 없음, 단일 화면.

## 아키텍처

```
[ContactSearchView]  (SwiftUI, 단일 화면)
      │  @StateObject
      ▼
[ContactStore: ObservableObject]               ← 얇은 I/O 래퍼
  - @Published contacts: [Contact]
  - @Published query: String
  - @Published results: [Contact]
  - @Published loadState: LoadState            (idle/loading/loaded/failed)
  - requestAccess()    → CNContactStore 권한
  - loadAll()          → Task.detached(백그라운드)에서 enumerateContacts
                         → ContactMapper.map 으로 변환
                         → @MainActor 로 @Published 에 할당
  - search(query)      → ContactFilter.apply 위임
      │
      ├──────────────┬─────────────────┐
      ▼              ▼                 ▼
[ContactMapper]  [ContactFilter]  [KoreanInitialMatcher]
(static 순수)    (static 순수)    (순수 함수, 1단계 산출물)
CNContact        [Contact]+query  extractChosung / matches
→ Contact?       → [Contact]
```

- 외부 서버 0, DB 0, 로그인 0
- 앱 시작 시 연락처를 메모리에 한 번 로드, 이후 인메모리 필터링
- 연락처 100~1000개 수준에서는 이게 가장 빠르고 단순
- `ContactMapper`와 `ContactFilter`는 `CNContactStore`에 의존하지 않는 static 순수 함수 — 단위 테스트 대상
- 로드는 항상 백그라운드 스레드에서. UI 스레드는 절대 블록하지 않음

## 권한 상태 머신

```
App launch
  │
  ▼
CNContactStore.authorizationStatus(for: .contacts)
  │
  ├── .notDetermined → requestAccess
  │                     ├── granted → loadAll
  │                     └── denied  → PermissionDeniedView
  ├── .authorized    → loadAll
  ├── .limited       → loadAll            (iOS 18+, 허용된 것만 반환)
  ├── .denied        → PermissionDeniedView ("설정에서 허용" 버튼)
  └── .restricted    → PermissionDeniedView ("기기 정책으로 제한됨")
```

`.limited`는 v0.1에서 `.authorized`와 동일 처리. "일부만 보여요" 배너는 백로그.

## 핵심 알고리즘: 한글 초성 추출

한글 유니코드 구조를 이용:

- 한글 음절 범위: `0xAC00` ~ `0xD7A3`
- `(scalar - 0xAC00) / (21 * 28)` = 초성 인덱스 (0~18)
- 초성 테이블: `ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ`
- 한글이 아닌 문자(영문/숫자/공백)는 소문자로 유지

**엣지 케이스:**
- 쌍자음 입력("ㄲ") → 그대로 매칭
- 영문 섞인 이름("John 김") → 영문 부분 일치 + 한글 부분 초성 일치
- 회사명만 있는 연락처 → 회사명도 검색 대상 (`ContactMapper`에서 `fullName ?? organizationName`)
- 동명이인 → 탭 시 `CNContactViewController`가 네이티브 상세 뷰에서 구분 표시
- 연속 초성 일치("ㅇㅎ" → "용훈")가 단편 일치보다 우선순위 높음
- 빈 query → 빈 결과 (검색 전 화면은 비어 있음)

## 화면 구조 (단일 화면)

```
┌─────────────────────────┐
│  이름 일치 상위 항목       │
│ ─────────────────        │
│  [용] 용훈미국            │  ← 탭 → 연락처 상세 시트
│                          │
│  ┌─────────────────┐     │
│  │ 🔍 ㅇㅎ       ⓧ │  X  │
│  └─────────────────┘     │
│  ┌─────────────────┐     │
│  │   한글 키보드     │     │
│  └─────────────────┘     │
└─────────────────────────┘
```

**결과 셀 탭:** `CNContactViewController`를 `.sheet`로 present
- iOS 기본 연락처 앱의 상세 화면과 동일한 UI (애플 공식 컴포넌트)
- 전화/문자/이메일/편집 액션 전부 네이티브로 내장 — 우리 코드가 전화번호를 직접 다루지 않음
- `UIViewControllerRepresentable`로 SwiftUI 래핑 (`Views/ContactDetailSheet.swift`, ~30줄)
- 탭 시점에 `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)`로 원본 `CNContact` 재조회 → 항상 최신 데이터
- iOS에는 특정 연락처를 기본 연락처 앱에서 직접 여는 공식 URL 스킴이 없음 (`contacts://` 미지원). `CNContactViewController`가 표준 대안.

## 프로젝트 구조

```
InitialConsonantFinder/
├── InitialConsonantFinderApp.swift     # @main, 권한 상태 머신 분기
├── Views/
│   ├── ContactSearchView.swift          # 메인 화면
│   ├── ContactRow.swift                 # 결과 셀
│   ├── ContactDetailSheet.swift         # CNContactViewController 래퍼
│   └── PermissionDeniedView.swift       # 권한 거부/제한 시 폴백
├── Models/
│   ├── Contact.swift                    # id / displayName / searchKey
│   ├── ContactStore.swift               # ObservableObject (I/O 래퍼)
│   ├── ContactFilter.swift              # enum, static apply
│   └── ContactMapper.swift              # enum, CNContact → Contact?
├── Info.plist                           # NSContactsUsageDescription
└── Tests/
    ├── KoreanInitialMatcherTests.swift  # 1단계 산출물 (24개)
    ├── ContactFilterTests.swift         # 2단계 신규
    └── ContactMapperTests.swift         # 2단계 신규

(참고: KoreanInitialMatcher 는 루트의 Swift Package 로 존재하고,
 iOS 앱 타겟이 로컬 의존으로 이 패키지를 참조한다.)
```

## 필수 Info.plist 키

```xml
<key>NSContactsUsageDescription</key>
<string>연락처에서 이름을 초성으로 빠르게 찾기 위해 접근이 필요합니다.</string>
```

이 키가 없으면 iOS가 앱을 크래시시킨다. 절대 누락 금지.

## 성공 기준

- **속도:** 앱 아이콘 탭 → 검색 결과 표시까지 2초 이내 (연락처 500개 기준)
- **단순함:** 화면 1개, 설정 0개, 네비게이션 0개
- **정확성:** `KoreanInitialMatcherTests` 최소 20개 케이스 통과 (쌍자음, 영문 섞임, 공백, 특수문자, 한자 이름)
- **실사용:** v0.1을 본인이 1주일 매일 사용해서 기본 연락처 앱으로 돌아가고 싶지 않아야 함

## 배포 전략

1. **로컬 빌드 → 실기기:** Xcode Personal Team으로 본인 아이폰 설치 (무료, 7일 서명)
2. **TestFlight:** Apple Developer Program ($99/년) → 내부 테스터 (본인 + 지인 5명)
3. **App Store:** 스크린샷, 설명, 개인정보 처리방침, 심사 제출
4. **심사 주의사항:** 연락처 읽기는 민감 항목. Review Note에 "로컬 전용, 서버 전송 없음" 명시

## 미해결 질문

1. 검색 결과 정렬 가중치: 연속 초성 일치 vs 앞글자 일치 (5단계 실사용 후 결정)
2. 다국어 이름("John 김") 처리 규칙
3. 앱 아이콘, 이름, 스크린샷 (v1 이후)
4. `CNContactViewController.allowsEditing` — 기본값 true 로 두고 실기기 테스트 후 재검토

## 관련 문서

- [`README.md`](./README.md) — 프로젝트 개요
- [`to-do.md`](./to-do.md) — 구현 체크리스트
