# App/ — 3단계 SwiftUI 소스 (Xcode 프로젝트 통합 가이드)

이 폴더는 iOS 앱 타겟의 SwiftUI 소스를 **staging** 합니다.
Xcode 프로젝트는 CLI 로 생성할 수 없어서 (Personal Team 서명 등 GUI 작업) 다음 순서로 진행하세요.

## 1. Xcode 프로젝트 생성 (3-1)

1. Xcode 실행 → **File → New → Project**
2. **iOS → App** 선택 → Next
3. 설정:
   - **Product Name:** `InitialConsonantFinder`
   - **Team:** 본인 Apple ID (Personal Team)
   - **Organization Identifier:** 예) `com.kilga`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None
   - **Include Tests:** 체크 해제 (이미 Swift Package 에 테스트 있음)
4. 저장 위치:
   - 이 레포 루트(`initial-consonant-finder/`)를 선택
   - **"Create Git Repository on my Mac" 체크 해제** (이미 git 레포)
   - **"새 하위 폴더 만들기" 체크 해제 불가능할 수 있음** — Xcode 는 기본적으로 `InitialConsonantFinder/` 하위 폴더를 만든다. 허용.
5. 결과 구조:
   ```
   initial-consonant-finder/
   ├── InitialConsonantFinder.xcodeproj
   ├── InitialConsonantFinder/
   │   ├── InitialConsonantFinderApp.swift  ← Xcode 기본 생성
   │   ├── ContentView.swift                 ← Xcode 기본 생성
   │   └── Assets.xcassets
   ├── Package.swift                          ← 기존
   ├── Sources/                               ← 기존
   ├── Tests/                                 ← 기존
   └── App/                                   ← 이 폴더 (staging)
   ```

## 2. 프로젝트 설정 (3-1 계속)

### iOS Deployment Target
- 프로젝트 네비게이터에서 **InitialConsonantFinder** 프로젝트 선택
- **Targets → InitialConsonantFinder** → **General** 탭
- **Minimum Deployments → iOS 17.0** 으로 설정 (Package.swift 와 일치)

### Info.plist 에 연락처 권한 설명 추가
- **Info** 탭 → **Custom iOS Target Properties**
- `+` 버튼 → `Privacy - Contacts Usage Description` 키 추가
- Value: `연락처에서 이름을 초성으로 빠르게 찾기 위해 접근이 필요합니다.`

### 로컬 Swift Package 의존 추가
- **File → Add Package Dependencies…**
- 좌하단 **Add Local…** 버튼
- 이 레포 루트(`initial-consonant-finder/`) 선택
- 라이브러리 선택 시 **`KoreanInitialMatcher`** 와 **`ContactFinder`** 모두 체크
- Add Package

## 3. 이 폴더의 Swift 파일을 프로젝트에 추가 (3-2 ~ 3-7)

### 방법 A: 드래그 앤 드롭 (권장)
1. Finder 에서 `App/` 폴더 안의 파일들을 선택:
   - `InitialConsonantFinderApp.swift`
   - `Views/OnboardingView.swift`
   - `Views/ContactSearchView.swift`
   - `Views/ContactRow.swift`
   - `Views/ContactDetailSheet.swift`
   - `Views/PermissionDeniedView.swift`
2. Xcode 프로젝트 네비게이터의 `InitialConsonantFinder/` 폴더 안으로 드래그
3. 다이얼로그:
   - **Copy items if needed:** 체크 해제 (원본 위치 유지)
   - **Create groups** 선택
   - **Add to targets: InitialConsonantFinder** 체크
4. Xcode 가 자동 생성한 `InitialConsonantFinderApp.swift` 와 `ContentView.swift` 는 **프로젝트 네비게이터에서 삭제** (이 폴더의 파일과 중복됨)
   - 다이얼로그에서 **"Move to Trash"** 선택

### 방법 B: 파일 이동 (원본 위치를 Xcode 프로젝트 폴더로 옮기고 싶을 때)
Finder 에서 `App/` 안의 파일들을 `InitialConsonantFinder/` 로 이동 → Xcode 네비게이터에 드래그.

### 방법 C: 전체 폴더 대체
```bash
# 터미널에서 (레포 루트)
rm InitialConsonantFinder/InitialConsonantFinderApp.swift
rm InitialConsonantFinder/ContentView.swift
cp App/InitialConsonantFinderApp.swift InitialConsonantFinder/
mkdir -p InitialConsonantFinder/Views
cp App/Views/*.swift InitialConsonantFinder/Views/
```
그 다음 Xcode 에서 **파일 추가** (네비게이터 우클릭 → Add Files to "InitialConsonantFinder"…).

## 4. 빌드 확인

- `Cmd+B` → 빌드 성공 확인
- 에러가 나면 대부분 다음 둘 중 하나:
  - **Package 의존 누락:** "No such module 'ContactFinder'" → 2단계의 Package 의존 추가 재확인
  - **타겟 멤버십 누락:** 파일이 프로젝트에 추가됐지만 타겟에 속하지 않음 → 파일 선택 → File Inspector → Target Membership 체크

## 5. 시뮬레이터에서 실행 (3-2 ~ 3-7 검증)

- iPhone 15 시뮬레이터 선택 → `Cmd+R`
- 첫 실행: `OnboardingView` → [시작하기] → 시스템 팝업 → 허용
- 시뮬레이터의 연락처 앱에 테스트 데이터 추가 후 재실행해서 검색 동작 확인

## 6. staging 폴더 정리 (선택)

Xcode 프로젝트에 파일이 잘 통합되고 빌드가 성공하면 이 `App/` staging 폴더는 삭제해도 됩니다:

```bash
rm -rf App/
git add -A && git commit -m "chore: App/ staging 폴더 제거, 파일 InitialConsonantFinder/ 로 이동"
```

단, 파일을 **복사** 한 경우 (방법 C)에만 안전하게 삭제하세요.
방법 A/B 로 원본 참조 관계를 만든 경우 삭제하면 Xcode 에서 파일이 사라집니다.

---

**관련 문서:**
- [`../plan.md`](../plan.md) — 전체 기획 & 디자인 결정
- [`../to-do.md`](../to-do.md) — 단계별 체크리스트
