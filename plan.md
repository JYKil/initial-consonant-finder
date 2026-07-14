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
  ├── .notDetermined → OnboardingView (평생 1회, 사전 설명)
  │                     └── [시작하기] 탭 → requestAccess
  │                                          ├── granted → ContactSearchView
  │                                          └── denied  → PermissionDeniedView
  ├── .authorized    → ContactSearchView  (Onboarding 스킵)
  ├── .limited       → ContactSearchView  (Onboarding 스킵, iOS 18+)
  ├── .denied        → PermissionDeniedView ("설정에서 허용" 버튼)
  └── .restricted    → PermissionDeniedView ("기기 정책으로 제한됨")
```

- `.limited`는 v0.1에서 `.authorized`와 동일 처리. "일부만 보여요" 배너는 백로그.
- **OnboardingView 는 평생 1회만 표시된다.** `authorizationStatus == .notDetermined` 일 때만 분기하므로 `UserDefaults` 플래그 같은 건 불필요 — iOS 가 시스템 레벨에서 권한 상태를 기억한다. 앱 삭제 후 재설치 시에만 다시 표시됨(의도된 동작).
- 설정 앱에서 수동으로 권한을 껐다 재진입하면 `.denied` 가 되어 Onboarding 대신 `PermissionDeniedView` 로 바로 진입.

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
- 빈 query → 전체 연락처를 이름 가나다순으로 정렬해 반환 (기본 연락처 앱과 동일한 첫 화면)

## 디자인 시스템: iOS HIG

`DESIGN.md` 는 없다. **iOS Human Interface Guidelines 를 암묵적 기본 디자인 시스템으로 채택.** 네이티브 컴포넌트에 최대한 기대어 3단계 구현 비용을 최소화하고, "차별화 가설: 아무것도 없음" 을 UI 요소의 부재로 표현한다.

| 요소        | 선택                                                                           |
|-------------|--------------------------------------------------------------------------------|
| 검색 입력   | `.searchable()` 모디파이어 (상단 배치)                                          |
| 리스트      | `List` + `.plain` 스타일                                                       |
| 컬러        | 시스템 컬러 (`.systemBackground`, `.primary`, `.secondaryLabel`, `.secondarySystemFill`) |
| 컬러 모드   | 시스템 설정 따름 (`preferredColorScheme` 미지정)                               |
| 타이포      | SF Pro (`.body`, `.headline`, `.largeTitle`) + Dynamic Type 자동              |
| 아이콘      | SF Symbols (`magnifyingglass`, `phone.fill` 등)                               |
| 행 높이     | `List` 기본 (44pt+ 자동, 터치 타깃 보장)                                      |
| 구분선      | `List` 기본 hairline separator                                                |
| 포커스      | `@FocusState` + `.searchable` 자동 포커스                                      |
| 햅틱        | `List` 기본 selection feedback                                                |

**금지 사항 (v0.1):**
- 커스텀 폰트 도입 금지.
- 커스텀 컬러 토큰 금지 — 시스템 컬러만.
- 배경 그라디언트, 카드 섀도우, 커스텀 아바타 색 등 장식 요소 전부 금지.
- 다크모드 강제(`preferredColorScheme(.dark)`) 금지 — 유저 시스템 설정 존중.

## 화면 구조 (단일 화면)

```
┌─────────────────────────────┐
│ 🔍 Search                   │  ← .searchable() 시스템 검색바 (상단)
├─────────────────────────────┤
│  ⦿  용훈미국                 │  ← ContactRow (회색 원 + 이니셜 + 이름)
│  ⦿  김철수                   │
│  ⦿  이영희                   │
│                              │
│                              │
├─────────────────────────────┤
│        한글 키보드            │  ← 앱 오픈 즉시 자동 활성 (@FocusState)
└─────────────────────────────┘
```

**검색바:**
- `NavigationStack { ... }.searchable(text: $store.query, placement: .navigationBarDrawer(displayMode: .always))` 로 구현.
- iOS HIG 표준 → 스타일/다크모드/접근성/클리어 버튼/dismiss 제스처 전부 무료.
- 앱 오픈 즉시 검색바에 포커스: `@FocusState` 로 자동 활성. 키보드 즉시 올라옴.
- 리스트는 `.listStyle(.plain)` — 그룹 배경 제거, 행만 배경에 붙는 형태.

**결과 셀 (`ContactRow`):**

```
┌───────────────────────────────┐
│  ⦿   이름                      │
│ (44×44pt)   (.body SF Pro)    │
└───────────────────────────────┘
```

- 좌측: 44×44pt 회색 원(`.secondarySystemFill` 배경) + `displayName.first` 1자 가운데(`.headline`).
- 우측: `displayName` 좌측 정렬, `.body`, `.primary`.
- 애플 기본 연락처 앱 스타일과 동일. 컬러풀 아바타/커스텀 스타일 금지.
- 탭 → `@State var selectedContact: Contact?` 업데이트 → `.sheet(item:)` 트리거.
- `.accessibilityLabel("\(displayName), 연락처 상세 열기")`.

**결과 셀 탭 → 상세 시트:** `CNContactViewController` 를 `.sheet` 로 present
- iOS 기본 연락처 앱의 상세 화면과 동일한 UI (애플 공식 컴포넌트).
- 전화/문자/이메일/편집 액션 전부 네이티브로 내장 — 우리 코드가 전화번호를 직접 다루지 않음.
- `UIViewControllerRepresentable` 로 SwiftUI 래핑 (`Views/ContactDetailSheet.swift`, ~30줄).
- `UINavigationController` 로 한 번 더 감싸야 "완료" 버튼이 자동 제공됨.
- 탭 시점에 `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` 로 원본 `CNContact` 재조회 → 항상 최신 데이터.
- `keysToFetch` 는 `CNContactViewController.descriptorForRequiredKeys()` 사용.
- iOS 에는 특정 연락처를 기본 연락처 앱에서 직접 여는 공식 URL 스킴이 없음 (`contacts://` 미지원). `CNContactViewController` 가 표준 대안.
- 시트 dismiss 후 `query` 와 `@FocusState` 는 SwiftUI 기본 동작으로 유지 → 키보드 자동 재활성, 연속 검색 자연스러움.

## 상태별 화면 매트릭스

3단계 View 는 `ContactStore.loadState` + `query` 조합에 따라 다음과 같이 분기한다.

| 조건                        | loadState     | query  | 화면                                      |
|-----------------------------|---------------|--------|-------------------------------------------|
| 첫 실행, 권한 미결정         | `idle`        | `""`   | `OnboardingView` (사전 설명, 1회)          |
| 권한 거부 / restricted       | `idle`        | `*`    | `PermissionDeniedView`                    |
| 권한 있음, 로드 중 (<200ms)  | `.loading`    | `*`    | 검색바+키보드 활성, 리스트 빈              |
| 권한 있음, 로드 중 (≥200ms)  | `.loading`    | `*`    | 위 + `ProgressView` 중앙                  |
| 로드 완료, 쿼리 없음         | `.loaded`     | `""`   | 전체 연락처 목록 (이름 가나다순, 기본 연락처 앱과 동일) |
| 로드 완료, 매칭 있음         | `.loaded`     | `"ㅇㅎ"` | 결과 리스트                               |
| 로드 완료, 매칭 없음         | `.loaded`     | `"ㅈ"`  | 빈 리스트 영역 (문구 표시 없음)             |
| 로드 실패                    | `.failed(msg)` | `*`    | 중앙 에러 뷰 + `[다시 시도]` 버튼          |

**핵심 동작 원칙:**

- **로드 중에도 검색바/키보드는 즉시 활성.** 로드 중 타이핑해도 `ContactFilter.apply(loaded=[], query)` 결과는 빈 배열이지만, `loadState` 가 `.loaded` 로 전이되는 순간 `$contacts` 가 변동되고 `CombineLatest($query, $contacts)` 파이프라인이 자동으로 `$results` 재계산 → 이미 찍어둔 쿼리에 대한 결과가 즉시 채워진다. 유저 체감: "생각보다 빠르다."
- **로딩 스피너는 200ms 이상 지속될 때만 표시.** 50~150ms 깜빡임은 산만함. 500연락처 cold boot 은 보통 150ms 내외라 대부분의 경우 스피너가 아예 안 뜸.
  ```swift
  .task {
      try? await Task.sleep(for: .milliseconds(200))
      if case .loading = store.loadState { showSpinner = true }
  }
  ```
- **빈 쿼리는 전체 연락처 목록을 보여준다.** 기본 연락처 앱과 동일한 첫인상을 위해 v0.1의 "아무것도 없음" 철학에서 정책을 변경함(4-2단계). `ContactFilter.apply` 가 빈/공백 쿼리일 때 `displayName` 기준 정렬된 전체 목록을 반환한다.
- **매칭 없음(예: "ㅋㅋㅋ")에는 여전히 문구 표시하지 않는다.** 빈 리스트 영역만 남는다. 유저는 키보드 위에 아무것도 없으면 "일치하는 연락처가 없다" 를 이미 암. 5단계 실사용 후 본인이 혼란스러우면 그때 문구 추가(백로그).

## 사용자 여정 & 감정 궤적

**5-second visceral:** 앱 아이콘 탭 → 0.3s 런치 → 키보드 이미 올라와 있음 → 엄지로 "ㅇㅎ" 타이핑 → 0.1s 안에 "용훈" 셀 등장 → 탭 → 네이티브 상세 → 전화. **총 2초 이내 통화 연결.** 이게 북극성.

**5-minute behavioral:** 근육 기억. 의심 없음. 기본 연락처 앱을 안 열게 됨.

**5-year reflective:** "초성 검색 없는 iOS 기본 연락처로 못 돌아가."

**감정적으로 민감한 순간 3가지:**

1. **첫 실행 권한 요청.** iOS 시스템 팝업은 한 번 "허용 안 함" 누르면 복구가 고통스럽다. `OnboardingView` 가 시스템 팝업 직전에 "이 앱은 연락처를 읽어서 초성 검색만 합니다. 서버로 아무것도 보내지 않아요" 메시지를 전달 → 거부 확률 낮춤. **평생 딱 한 번**만 보이는 화면이지만 가장 감정적으로 무거운 순간.
2. **cold boot 로드 중.** 500연락처 로드 ~150ms. 타이핑은 즉시 허용, 로드 완료되는 순간 결과가 채워짐. 200ms 넘어가면 그제서야 스피너. 유저가 "앱이 고장났나?" 를 느끼지 않음.
3. **상세 시트 닫고 돌아왔을 때.** `.sheet` dismiss 시 `query`, `@FocusState` 가 유지됨(SwiftUI 기본 동작). 키보드 자동 재활성. 연속 검색 UX 자연스러움.

## 접근성 & 반응형

**Dynamic Type:**
- 모든 텍스트를 `.body` / `.headline` / `.largeTitle` 시스템 폰트로 사용 → Dynamic Type 자동 적용.
- 검색바, 행 이름, OnboardingView 카피 전부 자동 확장.
- 초대형(`.accessibility5`)에서 레이아웃 깨짐 확인은 4단계 시뮬레이터 검증 항목.

**VoiceOver:**
- `ContactRow`: `.accessibilityLabel("\(displayName), 연락처 상세 열기")`.
- `.searchable()` 검색 필드: 기본 라벨 "검색" 자동.
- `OnboardingView` [시작하기] 버튼: 기본 라벨 자동.

**터치 타깃:**
- `List` 행은 44pt+ 자동. 별도 지정 불필요.

**뷰포트:**
- iPhone SE (375pt) ~ Pro Max (430pt) 전부 동일 레이아웃.
- 아이패드 대응은 v1+ 백로그.

**Reduce Motion:**
- SwiftUI `List` 기본 애니메이션이 자동 존중. 별도 처리 불필요.

**컬러 대비:**
- 시스템 컬러만 사용 → 라이트/다크 모두 WCAG AA 자동 만족.

## 프로젝트 구조

```
InitialConsonantFinder/
├── InitialConsonantFinderApp.swift     # @main, 권한 상태 머신 4갈래 분기
├── Views/
│   ├── OnboardingView.swift             # 사전 설명 화면 (.notDetermined 시 1회)
│   ├── ContactSearchView.swift          # 메인 화면, .searchable() 상단
│   ├── ContactRow.swift                 # 회색 원 + 이니셜 + 이름
│   ├── ContactDetailSheet.swift         # CNContactViewController 래퍼
│   └── PermissionDeniedView.swift       # .denied / .restricted 폴백
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
5. `OnboardingView` 카피 최종안 — 방향은 "초성으로 빠르게 찾기 / 이 앱은 연락처를 읽어서 초성 검색만 합니다. 서버로 아무것도 보내지 않아요. 전부 기기 안에서." 정확한 문구는 3단계 구현 시 커밋
6. 로딩 스피너 지연 임계치 200ms 가 실제로 적절한지 — 5단계 실기기 Instruments 측정 후 재조정 가능

## 관련 문서

- [`README.md`](./README.md) — 프로젝트 개요
- [`to-do.md`](./to-do.md) — 구현 체크리스트
