# Initial Consonant Finder (한글 초성 검색 연락처)

아이폰 기본 연락처 앱에 없는 **한글 초성 검색** 기능을 제공하는 초경량 iOS 네이티브 앱.

## 무엇을 해결하나

- "ㅇㅎ" 입력 → "용훈", "윤희", "은호" 등 일치하는 연락처 즉시 검색
- 결과 탭 → 바로 전화 / 문자 발송 (아이폰 네이티브 기능 연동)
- **앱 열면 2초 안에 원하는 사람한테 연락 완료**가 목표

## 왜 만드나

아이폰 기본 연락처 앱은 한글 이름을 초성으로 검색할 수 없음. 기존 앱스토어 대체 앱들은 광고가 많고 느리며 UI가 난잡함. 이 앱의 무기는 **뺄 것을 다 뺀 단순함** — 설정 없음, 광고 없음, 탭 없음, 앱 열면 곧장 검색.

## 기술 스택

- **언어:** Swift 5.9+
- **UI:** SwiftUI
- **프레임워크:** `Contacts.framework` (연락처 읽기), `MessageUI` (문자 발송), `UIApplication` (전화)
- **최소 iOS:** 17.0
- **외부 의존성:** 없음 (로컬 전용, 서버 통신 없음)

## 빌드 방법

`.xcodeproj` 는 커밋하지 않는다. [XcodeGen](https://github.com/yonaskolb/XcodeGen) 이 `project.yml` 로부터 생성한다.

```bash
brew install xcodegen
xcodegen generate

# 알고리즘 / 필터 단위 테스트 (Xcode 없이)
swift test

# 앱 빌드
xcodebuild -scheme InitialConsonantFinder \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

시뮬레이터 빌드에는 서명 팀이 필요 없다. Personal Team 서명은 실기기 설치 때만 필요하다.

### 시뮬레이터에서 검색 검증

```bash
xcrun simctl boot "iPhone 17"
xcrun simctl privacy booted grant contacts com.kilga.InitialConsonantFinder
xcodebuild test -scheme SeedContacts -destination 'platform=iOS Simulator,name=iPhone 17'  # 연락처 픽스처 시딩
xcodebuild test -scheme UITests      -destination 'platform=iOS Simulator,name=iPhone 17'  # 초성 검색 E2E
```

⚠️ `SeedContacts` 는 시뮬레이터 연락처를 전부 지우고 픽스처로 덮어쓴다. 실기기에서 돌리지 말 것.

## 상태

초기 개발 단계. 진행 상황은 [`to-do.md`](./to-do.md), 설계는 [`plan.md`](./plan.md) 참조.

## 라이선스

미정 (App Store 출시 예정).
