import XCTest

/// 권한 상태 머신 검증 (`InitialConsonantFinderApp.rootView` 의 4갈래).
///
/// `SearchUITests` 와 달리 **실행 전에 권한 상태를 외부에서 세팅해야** 한다.
/// 테스트 프로세스 안에서는 `simctl` 을 못 부르므로 `DevTools/verify.sh` 가
/// 상태를 잡고 각 테스트를 따로 실행한다. 혼자 돌리면 앞선 테스트가 남긴
/// 권한 상태 때문에 실패한다.
final class PermissionUITests: XCTestCase {
  /// 사전조건: `simctl privacy booted reset contacts com.kilga.InitialConsonantFinder` (notDetermined)
  ///
  /// ⚠️ iOS 18+ 연락처 권한은 **2단계**다. 이걸 모르면 앱이 멈춘 것처럼 보인다.
  ///   1단계: 알림 "…연락처에 접근하려고 합니다" → [허용 안 함] / [계속]
  ///   2단계: 시트 "연락처를 어떻게 공유하겠습니까?" → [연락처 선택] / [N개의 연락처 모두 공유]
  ///
  /// 2단계 시트는 springboard 에 뜨지만 **1단계보다 몇 초 늦게** 나타나고,
  /// `springboard.alerts` 로는 안 잡힌다 (alert 가 아니라 sheet). 앱 프로세스 트리에도 안 보인다.
  /// `CNContactStore.requestAccess` 는 2단계까지 끝나야 completion 이 온다 — 그때까지 앱이
  /// 온보딩에 머무는 건 **정상 동작**이다 ([시작하기] 버튼이 disabled 로 남는다).
  func test_첫실행_온보딩_권한허용_검색화면() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(
      app.staticTexts["초성으로 빠르게 찾기"].waitForExistence(timeout: 5),
      "notDetermined 인데 온보딩이 안 뜬다")
    XCTAssertFalse(app.searchFields.firstMatch.exists, "권한 전인데 검색 화면이 보인다")

    app.buttons["시작하기"].tap()

    // 1단계
    let alert = springboard.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10), "1단계 권한 알림이 안 뜬다")
    // 사용 목적 설명이 Info.plist(ko.lproj) 에서 한국어로 나오는지
    XCTAssertTrue(
      alert.staticTexts["연락처에서 이름을 초성으로 빠르게 찾기 위해 접근이 필요합니다."].exists,
      "권한 알림의 사용 목적 설명이 안 뜬다")
    alert.buttons["계속"].tap()

    // 2단계 — 버튼 라벨에 연락처 개수가 박히므로("9개의 연락처 모두 공유") 술어로 매칭한다.
    let shareAll = springboard.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "모두 공유")
    ).firstMatch
    XCTAssertTrue(shareAll.waitForExistence(timeout: 15), "2단계 '모두 공유' 시트가 안 뜬다")
    shareAll.tap()

    // 전체 접근 허용 → 온보딩이 사라지고 검색 화면으로.
    XCTAssertTrue(
      app.searchFields.firstMatch.waitForExistence(timeout: 15), "권한 허용 후 검색 화면이 안 뜬다")
    XCTAssertFalse(app.staticTexts["초성으로 빠르게 찾기"].exists, "권한 허용 후에도 온보딩이 남아 있다")
  }

  /// 사전조건: `simctl privacy booted grant contacts ...` (authorized)
  /// 온보딩은 평생 1회 — 권한이 이미 있으면 곧장 검색 화면이어야 한다.
  func test_권한있으면_온보딩_스킵하고_바로_검색화면() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5), "검색 화면이 안 뜬다")
    XCTAssertFalse(app.staticTexts["초성으로 빠르게 찾기"].exists, "권한이 있는데 온보딩이 또 뜬다")
  }

  /// 사전조건: `simctl privacy booted revoke contacts ...` (denied)
  func test_권한거부시_안내화면과_설정열기버튼() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(
      app.staticTexts["연락처 접근이 필요해요"].waitForExistence(timeout: 5),
      "denied 인데 PermissionDeniedView 가 안 뜬다")
    XCTAssertFalse(app.searchFields.firstMatch.exists, "denied 인데 검색 화면이 보인다")
    XCTAssertTrue(app.buttons["설정 열기"].exists, "denied 인데 '설정 열기' 버튼이 없다")

    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "permission-denied"
    shot.lifetime = .keepAlways
    add(shot)
  }
}
