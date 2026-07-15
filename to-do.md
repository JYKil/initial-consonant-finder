# To-Do — 구현 체크리스트

단계별로 순서대로 진행. 각 단계가 끝나면 체크 표시.

## 0단계: 준비

- [x] macOS에 최신 Xcode 15+ 설치
- [x] Apple ID로 Xcode 로그인 (Personal Team)
- [x] 실기기 테스트용 아이폰 준비 (USB 케이블 또는 같은 Wi-Fi)

### 주의사항 (폴더 구조 / Xcode 프로젝트 생성 시)

- **현재 레포 폴더(`initial-consonant-finder/`)에서 그대로 진행한다.** 하위 폴더를 새로 만들지 않음. Swift Package, Xcode 프로젝트 모두 이 폴더 루트에 바로 생성.
- **Xcode에서 "New Project" 할 때 주의:** 기본값이 "Create Git Repository" + "새 하위 폴더 만들기"로 되어 있음. 둘 다 **체크 해제** 필수. 이미 git 레포이고 현재 폴더에 바로 생성해야 함.
- **`.gitignore`에 Xcode 전용 항목 추가 필요** (프로젝트 생성 직후):
  ```
  # Xcode
  xcuserdata/
  *.xcuserstate
  DerivedData/
  build/
  *.xcscmblueprint
  *.xccheckout
  # Swift Package Manager
  .build/
  .swiftpm/
  Package.resolved
  ```
- **Swift Package + Xcode 프로젝트 공존 전략:** 1단계에서 `swift package init`으로 알고리즘 라이브러리를 먼저 만들고, 3단계에서 iOS 앱 프로젝트(`.xcodeproj`)를 같은 폴더에 추가. iOS 앱은 이 라이브러리를 로컬 패키지로 의존.

## 리뷰 스킬 타이밍 가이드

`/plan-eng-review`, `/plan-design-review` 등은 언제 돌려야 의미 있는지 기록.

- **1단계(알고리즘 구현) = 리뷰 불필요.** 순수 함수 + 단위 테스트뿐이라 아키텍처가 없음. `swift test` 초록이면 그게 리뷰다.
- **2단계(ContactStore + 권한) 시작 전 = `/plan-eng-review` 권장.** 권한 처리, 연락처 로드 시점(앱 시작? on-demand?), 에러 경로 등 구조 결정이 생김. 이 지점에서 리뷰.
- **3단계(SwiftUI 화면 조립) 시작 전 = `/plan-design-review` 권장.** 실제 UI 스코프가 생기는 첫 시점. 목업 → 화면 구조 → 상태(빈/로딩/에러/권한거부) 전부 리뷰 대상.
- **5단계(실기기 테스트) 후 = `/design-review`(플랜이 아닌 라이브 사이트 리뷰) 권장.** 실제 빌드된 앱을 눈으로 보고 AI slop 없는지, 2초 목표 달성했는지 확인.
- **7단계(App Store 제출 전) = `/review` 권장.** 전체 diff 대상 pre-landing 리뷰.

**현재(1단계)는 리뷰 건너뛰고 코드 작성으로 바로 진행.**

## 1단계: 핵심 알고리즘 먼저 (UI 없음)

**이 단계가 이번 주의 Assignment다. 이게 안 되면 나머지 전부 무의미.**

**전략 변경:** Xcode 없이 Swift Package로 먼저 알고리즘만 개발/검증한다. iOS 앱 프로젝트는 3단계에서 추가하고 이 패키지를 로컬 의존으로 연결한다. Claude Code 친화적인 방식.

- [x] ~~Xcode에서 프로젝트 생성~~ → Swift Package로 대체
- [x] `swift package init --type library --name KoreanInitialMatcher` 실행
- [x] `.gitignore`에 Xcode / Swift Package Manager 항목 추가
- [x] `Sources/KoreanInitialMatcher/KoreanInitialMatcher.swift`에 실제 로직 작성
  - 한글 음절 범위(`0xAC00` ~ `0xD7A3`)에서 초성 인덱스 추출
  - 초성 테이블 19자 매핑
  - 비한글 문자는 소문자로 유지
  - `public static func extractChosung(_ text: String) -> String`
  - `public static func matches(name: String, query: String) -> Bool`
- [x] `Tests/KoreanInitialMatcherTests/KoreanInitialMatcherTests.swift`에 24개 케이스 작성
- [x] `swift test` 실행 → 전부 초록 확인 (24/24)

## 2단계: 연락처 접근 (UI 없음, 콘솔 로그까지)

**진행 상태:** Swift Package 내 신규 타겟 `ContactFinder` 로 구현 완료. iOS 앱 타겟 연결 + 시뮬레이터 수동 검증은 3단계에서 함께.

- [x] Swift Package `Package.swift` 에 `ContactFinder` 라이브러리 + 테스트 타겟 추가 (iOS 17/ macOS 14)
- [x] `Sources/ContactFinder/Contact.swift` — `id`, `displayName`, `searchKey` 3필드 Sendable struct
- [x] `Sources/ContactFinder/LoadState.swift` — `idle/loading/loaded/failed(String)`
- [x] `Sources/ContactFinder/ContactMapper.swift` — `static func map(_:) -> Contact?`, `static func fetchKeys()`
  - [x] `CNContactFormatter.string(style: .fullName) ?? organizationName` → displayName
  - [x] displayName 비어 있으면 `nil` 반환
  - [x] `searchKey = KoreanInitialMatcher.extractChosung(displayName)` 캐시
- [x] `Sources/ContactFinder/ContactFilter.swift` — `static func apply(_:query:)`
  - [x] 빈/공백 query → 빈 배열
  - [x] 그 외는 `KoreanInitialMatcher.matches(name: searchKey, query:)` 필터
- [x] `Sources/ContactFinder/ContactStore.swift` — `@MainActor ObservableObject`
  - [x] `@Published contacts / query / results / loadState`
  - [x] init 에서 `Publishers.CombineLatest($query, $contacts)` → `ContactFilter.apply` → `$results`
  - [x] `requestAccess()` — 5가지 권한 상태 분기 (결과는 호출측이 분기)
  - [x] `loadAll()` — `nonisolated static` 헬퍼로 백그라운드 enumerate, 결과만 MainActor 로 할당
- [x] `Tests/ContactFinderTests/ContactFilterTests.swift` — 8개 케이스
- [x] `Tests/ContactFinderTests/ContactMapperTests.swift` — 7개 케이스 (`CNMutableContact` 직접 생성)
- [x] `swift test` → 전부 초록 (KoreanInitialMatcher 24개 + ContactFilter 8개 + ContactMapper 7개)
- [ ] `Info.plist` 에 `NSContactsUsageDescription` 추가 **→ 3단계에서 iOS 앱 타겟 만들 때 함께**
- [ ] 시뮬레이터 연락처 테스트 데이터 10개 추가 **→ 3단계**
- [ ] 콘솔 로그로 권한/로드/검색 동작 확인 **→ 3단계**

## 3단계: UI 조립

디자인 결정은 plan.md 의 "디자인 시스템: iOS HIG", "화면 구조", "상태별 화면 매트릭스", "사용자 여정", "접근성 & 반응형" 섹션을 최종 참조.

**진행 상태:** 완료. 앱이 시뮬레이터에서 실제로 돌아가고 초성 검색이 동작한다.

**중요 — 기존 계획의 틀린 전제를 정정함:** "Xcode 프로젝트는 CLI 로 만들 수 없어서 GUI 작업이 필요하다" 는 틀렸다.
1. **XcodeGen** 으로 `.xcodeproj` 를 선언적으로 생성한다 (`project.yml`).
2. **시뮬레이터 빌드·실행에는 서명 팀이 아예 필요 없다.** Personal Team 서명은 5단계(실기기)에서 처음 필요하다.

따라서 3~4단계는 Xcode GUI 없이 전부 CLI 로 돌아간다. Xcode 를 처음 여는 시점은 5단계다.

### 3-1. Xcode 프로젝트 & 앱 타겟 생성 (XcodeGen)
- [x] `brew install xcodegen`
- [x] `project.yml` 작성 — 앱 타겟 + 로컬 Swift Package 의존(`KoreanInitialMatcher`, `ContactFinder`)
- [x] iOS 17.0 최소 배포 타겟, 번들 ID `com.kilga.InitialConsonantFinder`, iPhone 전용
- [x] `INFOPLIST_KEY_NSContactsUsageDescription` 을 빌드 설정으로 주입 (별도 Info.plist 파일 없음)
- [x] `App/` staging → `InitialConsonantFinder/` 로 이동, 구식 `App/README.md` 삭제
- [x] `.xcodeproj` 는 `.gitignore` 처리 — `project.yml` 이 진실의 원천. 클론 후 `xcodegen generate` 로 복원
- [x] `xcodebuild ... build` → **빌드 성공, 에러/경고 0개** (Swift 6 strict concurrency 통과)

### 재현 방법 (클론 직후)

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme InitialConsonantFinder \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 3-2. `@main` 앱 엔트리 (권한 상태 머신 4갈래)
- [x] `App/InitialConsonantFinderApp.swift` — 작성 완료
  - [x] `@StateObject var store = ContactStore()`
  - [x] `@State var authStatus: CNAuthorizationStatus`
  - [x] `.notDetermined` → `OnboardingView(onRequestAccess:)`
  - [x] `.authorized` / `.limited` → `ContactSearchView(store:)` + `.task { await store.loadAll() }`
  - [x] `.denied` / `.restricted` → `PermissionDeniedView(status:)`
  - [x] `@unknown default` → `PermissionDeniedView(.denied)` 폴백

### 3-3. `OnboardingView` (사전 설명, 평생 1회)
- [x] `App/Views/OnboardingView.swift` — 작성 완료
  - [x] 중앙 SF Symbol `magnifyingglass` (72pt, `.symbolRenderingMode(.hierarchical)`)
  - [x] 헤드라인: "초성으로 빠르게 찾기" (`.largeTitle.bold()`)
  - [x] 본문 3줄: "이 앱은 연락처를 읽어서 초성 검색만 합니다. / 서버로 아무것도 보내지 않아요. / 전부 기기 안에서."
  - [x] 하단 `buttonStyle(.borderedProminent)` "시작하기" → `onRequestAccess()` 호출
  - [x] `@State isRequesting` 로 중복 탭 방지
  - [x] 시스템 컬러만 사용

### 3-4. `ContactSearchView` (메인 화면, `.searchable()` 상단)
- [x] `App/Views/ContactSearchView.swift` — 작성 완료
  - [x] `NavigationStack` + `.navigationTitle("연락처 검색")` + `.inline`
  - [x] `.searchable(text: $store.query, isPresented: $isSearchActive, placement: .navigationBarDrawer(displayMode: .always), prompt: "이름 초성")`
  - [x] `onAppear { isSearchActive = true }` — iOS 17 자동 포커스 (4단계 시뮬 검증 필요)
  - [x] `.listStyle(.plain)`
  - [x] `@State selectedContact: Contact?` → `.sheet(item:)` → `ContactDetailSheet`
  - [x] 200ms 지연 스피너: `.task(id: isLoading) { await updateSpinnerVisibility() }`
  - [x] `loadState == .failed(msg)` → 에러 뷰 + `[다시 시도]` 버튼
  - [x] 빈 쿼리 / 매칭 없음 → 빈 리스트 (문구 없음)

### 3-5. `ContactRow` (애플 Contacts 스타일)
- [x] `App/Views/ContactRow.swift` — 작성 완료
  - [x] `HStack(spacing: 12)`: 44pt Circle(`.secondarySystemFill`) + 이니셜(`.headline`) + displayName(`.body`)
  - [x] `.contentShape(Rectangle())`
  - [x] `.accessibilityElement(children: .combine)`
  - [x] `.accessibilityLabel("\(displayName), 연락처 상세 열기")`
  - [x] `#Preview` 3개 케이스 (한글/한글/영문)

### 3-6. `ContactDetailSheet` (`CNContactViewController` 래퍼)
- [x] `App/Views/ContactDetailSheet.swift` — 작성 완료
  - [x] `struct ContactDetailSheet: UIViewControllerRepresentable`
  - [x] `CNContactStore().unifiedContact(withIdentifier:keysToFetch:)` 재조회
  - [x] `keysToFetch = [CNContactViewController.descriptorForRequiredKeys()]`
  - [x] 조회 실패 시 "연락처를 불러올 수 없어요" 폴백 뷰
  - [x] `UINavigationController(rootViewController:)` 로 감쌈
  - [x] ~~우상단 `.done` 버튼~~ → **좌상단 "완료" 버튼으로 수정함 (실제 버그였음)**
    - `allowsEditing = true` 인 `CNContactViewController` 는 자기 "Edit" 버튼으로 `rightBarButtonItem` 을 **덮어쓴다.**
      그래서 완료 버튼이 화면에 아예 없었고, 시트를 스와이프로만 닫을 수 있었다.
    - 오른쪽은 Edit 이 점유 → 완료는 `leftBarButtonItem` 으로. iOS 관례에도 맞다.
    - 시스템 `.done` 아이템은 앱에 한국어 로컬라이제이션이 없어 "Done" 으로 뜬다 → 제목을 `"완료"` 로 직접 지정.
  - [x] `Coordinator` 로 `@Environment(\.dismiss)` 연결
  - [x] `allowsEditing = true`, `allowsActions = true`

### 3-7. `PermissionDeniedView`
- [x] `App/Views/PermissionDeniedView.swift` — 작성 완료
  - [x] SF Symbol `person.crop.circle.badge.exclamationmark` (64pt)
  - [x] 제목 "연락처 접근이 필요해요" (`.title2.bold()`)
  - [x] `.denied` vs `.restricted` 분기 카피
  - [x] `.denied` 일 때만 "설정 열기" 버튼 표시
  - [x] 버튼: `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`
  - [x] `#Preview` 2개 (denied / restricted)

### 3-8. 디자인 정합 체크 (Xcode 통합 + 빌드 성공 후 최종 검증)
- [ ] `preferredColorScheme` 지정 없음 (시스템 따름)
- [ ] 커스텀 `Font` / `Color` 사용 0개 — 시스템 토큰만
- [ ] 배경 그라디언트, 카드 섀도우, 장식 요소 0개
- [ ] 하드코딩된 `.system(size:)` 가 OnboardingView 의 `magnifyingglass`(72pt), PermissionDeniedView 의 아이콘(64pt) 외에는 없음
- [ ] 모든 텍스트가 Dynamic Type 자동 적용 (`.font(.body)` 등 사용)

## 4단계: 시뮬레이터 검증 ✅ 완료

**진행 상태:** 계획된 검증 항목 전부 XCUITest 로 자동화해서 통과. 수동으로 남은 항목 없음.
`./DevTools/verify.sh`(순차, 단일 디바이스) + `./DevTools/verify-parallel.sh`(4개 디바이스 병렬)
합쳐서 XCUITest 24개 + 단위 테스트 39개 전부 초록.

### 실행 방법

```bash
./DevTools/verify.sh
```

권한 상태(`notDetermined` / `denied` / `authorized`)는 테스트 프로세스 안에서 못 바꾼다 (`simctl` 은 호스트 도구).
그래서 `verify.sh` 가 상태를 세팅하고 해당 테스트만 골라 실행한다.

연락처 시딩도 `simctl` 로는 못 한다. vCard 를 `simctl openurl` 로 열면 임포트 시트가 뜨지만
"저장"을 **손으로 눌러야** 해서 자동화가 안 된다. 그래서 앱을 호스트로 하는 테스트 타겟
(`DevTools/SeedContacts/`)이 `CNSaveRequest` 로 직접 픽스처를 넣는다.

⚠️ `SeedContacts` 는 **연락처를 전부 지우고** 픽스처로 덮어쓴다. 실기기에서 절대 돌리지 말 것.

### ⚠️ iOS 18+ 연락처 권한은 2단계다 (검증하다 알게 된 것)

1. **알림**: "…연락처에 접근하려고 합니다" → `[허용 안 함]` / `[계속]`
2. **시트**: "연락처를 어떻게 공유하겠습니까?" → `[연락처 선택]` / `[N개의 연락처 모두 공유]`

`CNContactStore.requestAccess` 의 completion 은 **2단계까지 끝나야** 온다. 그전까지 앱이 온보딩에
머물고 [시작하기] 가 disabled 로 남아 있는 건 **정상 동작**이다 (앱 버그가 아님 — 한 번 오진했다).

2단계 시트는 자동화할 때 함정이 셋 있다:
- `springboard.alerts` 로 안 잡힌다 (alert 가 아니라 sheet). `springboard.buttons` 로 잡아야 한다.
- 1단계보다 **몇 초 늦게** 뜬다. 3초 대기로는 못 잡는다.
- 앱 프로세스 트리에도 안 보인다 → `app.debugDescription` 으로 디버깅하면 아무것도 안 나온다.
- 버튼 라벨에 연락처 개수가 박힌다("9개의 연락처 모두 공유") → 술어 매칭 필수.
  연락처가 0개면 문구가 달라지므로 **시딩을 권한 테스트보다 먼저** 해야 한다.

### 자동화 완료 (XCUITest 9개 통과)

권한 상태 머신:
- [x] `notDetermined` → `OnboardingView` → [시작하기] → 시스템 팝업 2단계 → 검색 화면
- [x] 권한 알림에 한국어 사용 목적 설명이 뜸 (ko.lproj 확인)
- [x] `authorized` → `OnboardingView` 스킵, 바로 검색 화면 (평생 1회 보장)
- [x] `denied` → `PermissionDeniedView` + "설정 열기" 버튼

검색:
- [x] 앱 실행 시 검색바 자동 포커스 + 한글 키보드 즉시 올라옴
- [x] "ㅇㅎ" 입력 → 김용훈 / 박윤희 / 이은호만 필터, 김철수·John Smith 제외
- [x] 빈 query / 매칭 없는 query("ㅋㅋㅋ") → 빈 리스트 (문구 없음)
- [x] 결과 셀 탭 → `CNContactViewController` 시트 (전화/문자/영상/메일 버튼 정상)
- [x] 시트 "완료" 탭 → 닫히고 검색 쿼리 유지
- [x] 시스템 문자열 한국어 확인 (편집 / 검색 / 텍스트 지우기)
- [x] 한자("강民秀") / 이모지("한소리🌸") 이름 크래시 없음 (시딩 픽스처에 포함)

### 병렬 검증 자동화 완료 (`DevTools/verify-parallel.sh`, XCUITest 16개 실행 전부 통과)

`verify.sh`(순차, 단일 디바이스)로는 못 보는 항목 — 여러 디바이스에서만 의미 있는 것들.
`build-for-testing` 으로 1회 빌드 후 `test-without-building` 으로 4개 시뮬레이터(iPhone 17 /
iPhone SE 3rd gen / iPhone 17 Pro Max / iPhone Air)에 나눠 돌린다.

- [x] 앱 삭제 후 재설치 → `OnboardingView` 재등장. 문자 그대로의 `simctl uninstall`+`install` 은
      아래 3번 이유로 테스트 자동화에 못 쓰고, 최종적으로 `simctl privacy reset` 방식(사용자 삭제가
      실제로 하는 일인 TCC 초기화)으로 XCUITest 검증 완료 — 별도로 uninstall+install 조합도
      스크린샷으로 한 번 더 실측 확인함(둘 다 온보딩 재등장 확인)
- [x] iOS 18 `.limited` 권한(2단계에서 [연락처 선택] → 피커에서 일부만 선택) → **선택한 연락처만**
      보이고 나머지는 안 보임, 크래시 없음 (`test_limited_권한선택시_선택한_연락처만_보인다`)
- [x] 다크모드(Pro Max) / 라이트모드(SE) 전환 → 시스템 따라 자동 변경, 레이아웃 안 깨짐
- [x] Dynamic Type 최대(`.accessibility5`, Pro Max 에 세팅) → 셀 hittable 유지, 시트 레이아웃 안 깨짐
- [x] VoiceOver 라벨 — 전용 XCUITest 로 "이름, 연락처 상세 열기" 형식 확정 검증 (SE/Pro Max 둘 다)
- [x] iPhone SE (375pt) 와 Pro Max (430pt) 두 뷰포트에서 동일 테스트 스위트 통과
- [x] 연락처 0개 → 크래시 없이 빈 리스트
- [x] 연락처 5000개 → 크래시 없이 로드되고 "ㄱㅇㅎ" 검색으로 확정 픽스처 발견됨
      (⚠️ **2초 목표 자체는 여기서 판정 안 함** — 시뮬레이터 + XCUITest 드라이버 오버헤드가 섞여 실측
      6.35초 나옴. 진짜 2초 판정은 5단계 실기기에서 Instruments Time Profiler 로.)

**병렬화 과정에서 디버깅하며 알게 된 것 3가지:**

1. **동시 실행 때문이라는 첫 진단은 틀렸다.** 처음엔 "재설치 테스트를 다른 xcodebuild 프로세스와
   동시에 돌리면 실패한다"고 봤는데, 단독 실행으로 바꿔도 똑같이 실패해서 오진으로 판명났다.
2. **진짜 원인 ①: 디바이스 이름 충돌.** 이 머신에 iOS 26.4 / 26.5 런타임이 둘 다 깔려 있어서
   "iPhone 17" 같은 이름의 시뮬레이터가 **UDID 가 다른 두 개**로 동시에 존재한다
   (`simctl list devices` 로 확인). `simctl <verb> "이름"` 과 `xcodebuild -destination name=...`
   이 이 모호함을 서로 다르게 풀어서, `simctl` 로 재설치한 디바이스와 `xcodebuild` 가 테스트를
   돌리는 디바이스가 물리적으로 다른 시뮬레이터가 됐다 → **UDID 로 확정**해서 해결.
3. **진짜 원인 ②: UDID를 고정해도 여전히 실패.** `simctl uninstall` + `install` 은 그 디바이스에서
   **이전에 `xcodebuild test-without-building` 세션이 한 번이라도 돈 적이 있으면** 더 이상 TCC 를
   리셋하지 않는다 — 재설치해도 authorized 로 남는다(Xcode 온디바이스 테스트 에이전트가 뭔가
   pairing/daemon 상태를 남기는 것으로 추정). 실사용자는 `xcodebuild test` 를 거칠 일이 없으니
   앱 버그가 아니라 테스트 도구의 한계다. "삭제 후 재설치" 가 실제로 검증하려는 건 **TCC 초기화**
   뿐이므로(이 앱엔 UserDefaults 등 다른 영속 상태가 없음 — `ContactStore.swift` 확인됨),
   문자 그대로의 uninstall/install 대신 `simctl privacy reset` 으로 대체했다. `verify.sh` 의
   동일 테스트도 원래 이 방식으로 통과하고 있었다.

macOS 시스템 bash 는 3.2 라 `declare -A`(연관 배열)이 없다. 스크립트는 평범한 변수로 대체했다.
`"$VAR개"` 처럼 변수 뒤에 한글이 바로 붙으면 변수명 파싱이 깨져 "unbound variable" 이 난다 —
`"${VAR}개"` 로 중괄호 필수.

### 로드 상태 전이 자동화 완료 (`DevTools/UITests/LoadStateUITests.swift`, XCUITest 3개 통과)

- [x] 로드 완료 전 타이핑 → 로드되는 순간(이미 입력된 쿼리 기준으로) 결과가 즉시 채워짐.
      `ContactStore` 의 `CombineLatest($query, $contacts)` 설계가 재입력 없이 이걸 보장한다.
- [x] 연락처 9개(소량)는 200ms 지연 스피너가 뜨지 않고 바로 결과 표시
- [x] 로드 실패 → 에러 뷰("연락처를 불러오지 못했어요" + 메시지) + [다시 시도] → 정상 복구

**로드 실패는 어떻게 시뮬레이션했나:** `CNContactStore` 는 실제 iOS 시스템 API 라 테스트에서 "지금
실패해라" 라고 지시할 방법이 없다. 대신 `ContactStore.loadState` 가 `public` 세터인 걸 이용해서,
`InitialConsonantFinderApp.swift` 에 `#if DEBUG` 로 감싼 런치 인자 훅(`-uiTestForceLoadFailure`)을
추가해 `store.loadState` 를 직접 `.failed(...)` 로 세팅했다.
- `Sources/ContactFinder`(실제 라이브러리)는 한 글자도 안 건드림 — 훅은 앱 타겟의 진입점에만 있다.
- `#if DEBUG` 라서 Release(App Store 심사/배포) 빌드에는 이 코드 자체가 컴파일되지 않는다.
- iOS UI 테스트에서 흔한 "런치 인자로 테스트 시나리오 주입" 패턴 그대로다.
- 재시도(`[다시 시도]`) 버튼은 실제 `loadAll()` 을 다시 호출하므로, 정상 복구까지 실제 경로로 검증된다.

### 4-1. 한국어 로컬라이제이션 ✅ 완료

**증상:** 앱에 한국어 로컬라이제이션이 없어서 시스템 UIKit 문자열이 전부 영어로 폴백했다.
상세 시트 우상단이 "Edit", 검색 아이콘 VoiceOver 라벨이 "Search", 지우기 버튼이 "Clear text".

**원인:** 빌드된 번들에 `CFBundleDevelopmentRegion = en` 이고 `.lproj` 디렉터리가 **하나도 없었다.**
iOS 는 앱이 지원하는 로컬라이제이션 목록으로 앱의 실행 로케일을 정하는데, 지원 언어가 영어뿐이니
앱 전체가 영어 로케일로 돌았다. 앱 자체 문구는 한국어 리터럴이라 안 드러났고, **UIKit 이 그리는
문자열만** 영어로 나왔다.

**해결 (둘 다 있어야 효과가 있다):**
- [x] `project.yml` → `options.developmentLanguage: ko` (`CFBundleDevelopmentRegion = ko`)
- [x] `InitialConsonantFinder/ko.lproj/InfoPlist.strings` 추가 — 이 **디렉터리의 존재 자체가**
      "한국어 지원" 선언이다. 빌드 설정만 바꾸고 `.lproj` 가 없으면 안 먹는다.
- [x] `NSContactsUsageDescription` 을 `InfoPlist.strings` 로 이관 (빌드 설정 키는 폴백으로 유지)
- [x] 상세 시트 "Edit" → **"편집"** 으로 뜨는 것 확인 (스크린샷)
- [x] 검색 아이콘 라벨 "Search" → **"검색"**, 지우기 버튼 → **"텍스트 지우기"**
- [x] XCUITest `test_시스템_문자열이_한국어다` 로 회귀 방지 못박음

**주의:** 이 앱은 한국어 **전용**이다 (초성 검색이라는 기능 자체가 한글 전제). 영어 로케일 기기에서도
`developmentLanguage: ko` 폴백으로 한국어가 뜬다 — 의도한 동작이다. 다국어를 지원할 계획이 생기면
`en.lproj` 를 추가하고 앱 내 한국어 리터럴부터 `Localizable.xcstrings` 로 빼야 한다.

### 4-2. 빈 쿼리 정책 변경: 기본 연락처 앱처럼 전체 목록 표시

**배경:** 4단계에서는 "아무것도 없음" 철학에 따라 빈 쿼리 → 빈 리스트가 의도된 동작이었다.
그런데 실제 배포 후 써보니 기본 연락처 앱처럼 입력 전에도 전체 연락처 목록(가나다순)이
보이길 원한다는 피드백. 정책을 변경한다.

- [x] `Sources/ContactFinder/ContactFilter.swift` — 빈/공백 쿼리일 때 빈 배열 대신
      `displayName` 기준 `localizedStandardCompare` 정렬한 전체 목록 반환
- [x] `Tests/ContactFinderTests/ContactFilterTests.swift` — `test_emptyQuery_returnsEmpty` /
      `test_whitespaceOnlyQuery_returnsEmpty` 를 전체 목록 반환 기대값으로 교체
- [x] `DevTools/UITests/SearchUITests.swift` — `test_빈쿼리는_빈리스트다` →
      `test_빈쿼리는_전체목록을_보여준다` 로 교체 (전체 목록이 보이는지 확인)
- [x] `./DevTools/verify.sh` 전체 재실행으로 회귀 확인 — UI 테스트 15개 + 단위 테스트 39개 전부 통과
- [x] `InitialConsonantFinder/Views/ContactDetailSheet.swift` — 좌상단 "완료" 텍스트 버튼을
      기본 연락처 앱과 동일한 텍스트 없는 뒤로가기 화살표(`chevron.backward`)로 교체.
      접근성 라벨은 ko.lproj 덕분에 시스템이 자동으로 "뒤로" 를 붙여준다.
      → `SearchUITests.test_결과탭하면_연락처_상세시트가_뜬다` 와
      `AccessibilityUITests.test_다양한_외형에서_레이아웃이_안깨진다` 가 `app.buttons["완료"]`
      를 찾다가 깨져서 `app.buttons["뒤로"]` 로 갱신함
- [x] `plan.md` 의 "빈 query → 빈 결과" 관련 서술(핵심 알고리즘 엣지케이스, 상태별 화면 매트릭스,
      핵심 동작 원칙 섹션) 을 새 정책에 맞게 갱신

## 5단계: 실기기 테스트

- [ ] Xcode에서 본인 아이폰을 Run target으로 선택
- [ ] Personal Team 서명으로 설치
- [ ] 본인 실제 연락처(~500개)로 검색 시도
- [ ] Instruments Time Profiler로 앱 런치~첫 결과까지 시간 측정 → 2초 목표 확인
- [ ] 1주일간 매일 실사용 → 기본 연락처 앱으로 돌아가고 싶은지 자가 평가

## 5-1단계: 실기기 사용 중 발견된 버그 (2026-07-16 실사용 피드백)

작업 순서 추천: 1 → 2 → 5 → 3 → 4 (쉬운 것 → 어려운 것 순).

- [ ] **1. 아이콘 이미지 정리** — `AppIcon.appiconset/icon-1024.png` 교체.
      알파 채널 없이, 둥근 모서리 직접 넣지 말고, 여백 없이 꽉 채운 1024×1024.
- [x] **2. 줄 간격 줄이기** — `ContactRow`: 원 44×44 → 36으로 축소, `.padding(.vertical, 4)` → 2로.
      `ContactSearchView`의 리스트에 `.listRowInsets(.init(top:2, leading:16, bottom:2, trailing:16))` +
      `.environment(\.defaultMinListRowHeight, 40)` 적용 완료.
- [ ] **4. 블루투스 키보드 연결/해제 시 입력창이 안 뜨는 문제** — `.searchable(isPresented:)`가 하드웨어
      키보드 연결/해제 때 포커스를 잃고 바인딩이 false로 죽는 SwiftUI 고질 버그로 추정.
      현재 `onAppear`에서만 `isSearchActive = true`를 주고 있어 복구가 안 됨.
      1차 처방: `GCKeyboardDidConnect/DidDisconnect` 노티 + `scenePhase` 활성 시점에 `isSearchActive` 재설정.
      그래도 안 되면 `.searchable` 버리고 직접 `TextField` + `@FocusState`로 전환 (5개 중 제일 지저분함).
- [x] **5. 편집 시 삭제 기능 누락** — `contactStore` 지정만으로 해결된다는 최초 가설은 **실기기 검증에서
      틀린 것으로 확인됨**: 지정해도 Edit 모드에 "연락처 삭제" 행이 안 뜸(iOS 18+ 실기기 재현).
      `CNContactViewController` 는 애초에 삭제 UI를 신뢰성 있게 노출하지 않는 것으로 보고됨.
      최종 해결: `ContactDetailSheet.swift`에 하단 툴바 버튼("연락처 삭제", 빨간색) 직접 추가 →
      확인 알림(`UIAlertController`) → `CNSaveRequest().delete(mutableContact)` 로 직접 삭제 실행.
      `Coordinator` 를 `@MainActor` 로 지정해야 Swift 6 strict concurrency 통과함
      (CNKeyDescriptor/UIAlertAction 클로저가 non-Sendable이라 nonisolated 컨텍스트에서 에러).
- [x] **6. 조회 시 연락처 정렬 순서** — 원인: 빈 쿼리일 때만 정렬하고 있었고, 실제 검색(필터링) 결과는
      `CNContactFetchRequest`의 enumerate 순서(정렬 미보장) 그대로 나갔다.
      `ContactFilter.apply`에서 필터링 후에도 `localizedStandardCompare`로 가나다순 정렬하도록 수정.
- [x] **3. 편집 후 바로 반영 안 되는 문제** — `ContactStore.init`에서 `CNContactStoreDidChange` 알림을
      구독해 어디서든(상세 시트의 편집/삭제 포함) 연락처 DB가 바뀌면 자동으로 `loadAll()`을 재호출하도록
      구현 (시트 닫힘 감지보다 더 정석적인 방법 — 삭제 등 다른 변경 경로도 함께 커버됨).

## 6단계: TestFlight 배포

- [ ] Apple Developer Program 가입 ($99/년)
- [ ] App Store Connect에서 앱 레코드 생성
- [ ] Archive → Upload to App Store Connect
- [ ] TestFlight 내부 테스터 초대 (본인 + 지인 5명)
- [ ] 테스터 피드백 수집 → 크리티컬 버그만 픽스

## 7단계: App Store 출시

- [x] 앱 아이콘 디자인 → `asset/icon.png` 를 `Assets.xcassets/AppIcon.appiconset` 로 등록 완료.
      원본이 정사각형이 아니고(2016×2110) 알파 채널이 있었다 — iOS 앱 아이콘은 정사각형 +
      완전 불투명이어야 해서(둥근 모서리는 iOS 가 자동 적용), 흰 배경에 합성해 알파를 지우고
      1024×1024 로 리사이즈했다. `project.yml` 에 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
      추가. 시뮬레이터 홈 화면에서 정상 표시 확인함.
- [ ] 앱 이름 확정 (초성 검색, 빠른 연락처 등 — 중복 확인 필수)
- [ ] 스크린샷 제작 (6.7" iPhone 필수, 다크 모드)
- [ ] 앱 설명 작성 (한국어 + 영어)
- [ ] 개인정보 처리방침 URL 준비 (연락처 접근 있으니 필수)
- [ ] Review Note에 "로컬 전용, 서버 전송 없음" 명시
- [ ] 심사 제출
- [ ] 심사 리젝 시 피드백 반영 → 재제출
- [ ] 출시 🎉

## 백로그 (v1 이후)

- [ ] 즐겨찾기 / 최근 통화 탭 (요구되면)
- [ ] 검색 가중치 조정 (연속 일치 우선도)
- [ ] 아이패드 레이아웃 대응
- [ ] 위젯 (홈 화면에서 바로 검색)
