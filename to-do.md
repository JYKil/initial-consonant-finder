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

## 2단계: 연락처 접근

- [ ] `Info.plist`에 `NSContactsUsageDescription` 추가
- [ ] `Models/Contact.swift` 정의 (`id`, `displayName`, `phoneNumbers: [String]`)
- [ ] `Models/ContactStore.swift` 구현
  - [ ] `@Published var contacts: [Contact]`
  - [ ] `@Published var query: String`
  - [ ] `@Published var results: [Contact]`
  - [ ] `requestAccess()` — `CNContactStore.requestAccess`
  - [ ] `loadAll()` — `enumerateContacts` → `Contact` 배열로 변환
  - [ ] `search(_:)` — `KoreanInitialMatcher.matches`로 필터 + 정렬
- [ ] 시뮬레이터 연락처에 테스트 데이터 10개 추가
- [ ] 콘솔 로그로 연락처 로드 동작 확인

## 3단계: UI 조립

- [ ] `Views/ContactSearchView.swift` — 목업대로 단일 화면
  - [ ] `TextField` + `FocusState`로 앱 열자마자 키보드 자동 활성
  - [ ] 결과 `List` — "이름 일치 상위 항목" 섹션 헤더
  - [ ] 빈 결과 상태 처리
  - [ ] 검은 배경 + 시스템 다크 모드 고정
- [ ] `Views/ContactRow.swift` — 이니셜 원형 아바타 + 이름
- [ ] 셀 탭 → ActionSheet `[전화] [문자] [취소]`
  - [ ] 전화: `UIApplication.shared.open(URL(string: "tel://\(number)"))`
  - [ ] 문자: `MFMessageComposeViewController` 모달 (SwiftUI `UIViewControllerRepresentable` 래퍼 필요)
- [ ] `Views/PermissionDeniedView.swift` — 권한 거부 시 "설정 열기" 버튼
- [ ] `InitialConsonantFinderApp.swift`에서 권한 상태에 따라 분기

## 4단계: 시뮬레이터 검증

- [ ] Xcode에서 `Cmd+U`로 `KoreanInitialMatcher` 테스트 실행 → 전부 초록 (iOS 앱이 로컬 패키지를 올바르게 의존하는지 확인)
- [ ] 앱 실행 시 키보드 즉시 올라옴 확인
- [ ] "ㅇㅎ" 입력 시 해당 연락처만 필터됨
- [ ] 결과 탭 → ActionSheet 정상
- [ ] 전화 탭 → `tel://` 핸들러 (시뮬레이터는 실제 전화 안 됨, URL 열림 확인)
- [ ] 문자 탭 → MessageUI 모달 뜸
- [ ] 권한 거부 → `PermissionDeniedView` 표시
- [ ] 연락처 0개/5000개/한자 이름/이모지 이름 각각 크래시 없음

## 5단계: 실기기 테스트

- [ ] Xcode에서 본인 아이폰을 Run target으로 선택
- [ ] Personal Team 서명으로 설치
- [ ] 본인 실제 연락처(~500개)로 검색 시도
- [ ] Instruments Time Profiler로 앱 런치~첫 결과까지 시간 측정 → 2초 목표 확인
- [ ] 1주일간 매일 실사용 → 기본 연락처 앱으로 돌아가고 싶은지 자가 평가

## 6단계: TestFlight 배포

- [ ] Apple Developer Program 가입 ($99/년)
- [ ] App Store Connect에서 앱 레코드 생성
- [ ] Archive → Upload to App Store Connect
- [ ] TestFlight 내부 테스터 초대 (본인 + 지인 5명)
- [ ] 테스터 피드백 수집 → 크리티컬 버그만 픽스

## 7단계: App Store 출시

- [ ] 앱 아이콘 디자인 (단색 배경 + 단순 심볼)
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
