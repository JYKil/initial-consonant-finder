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
  /// ⚠️ iOS 18+ 연락처 권한은 **최소 2단계, [연락처 선택] 경로는 3단계**다. 이걸 모르면 앱이
  /// 멈춘 것처럼 보인다.
  ///   1단계: 알림 "…연락처에 접근하려고 합니다" → [허용 안 함] / [계속]
  ///   2단계: 시트 "연락처를 어떻게 공유하겠습니까?" → [연락처 선택] / [N개의 연락처 모두 공유]
  ///   (2단계에서 [연락처 선택] 을 고르면) 3단계: 피커에서 선택 → [계속] →
  ///     "N개의 연락처에 대한 접근을 허용하겠습니까?" → [선택한 연락처에 접근 허용] / [지금 안 함]
  ///
  /// 이 시트들은 springboard 에 뜨지만 **앞 단계보다 몇 초 늦게** 나타나고,
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

  /// 사전조건: `simctl privacy booted reset contacts com.kilga.InitialConsonantFinder` (notDetermined) +
  /// SeedContacts.test_seed 로 시딩된 상태 (김용훈/박윤희/이은호 포함).
  ///
  /// 2단계 시트에서 "연락처 선택" 을 고르면 시스템 피커가 뜬다. 연락처 사진 버튼을 탭하면
  /// 선택되고 [계속] 이 활성화된다(선택 전엔 disabled). 김용훈/이은호 둘만 선택하고 박윤희는
  /// 뺀 뒤, 권한이 `.limited` 로 전이돼도 앱이 크래시 없이 **공유된 연락처만** 보여주는지 확인한다.
  func test_limited_권한선택시_선택한_연락처만_보인다() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let app = XCUIApplication()
    app.launch()

    app.buttons["시작하기"].tap()
    let alert = springboard.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10), "1단계 권한 알림이 안 뜬다")
    alert.buttons["계속"].tap()

    let selectContacts = springboard.buttons["연락처 선택"]
    XCTAssertTrue(selectContacts.waitForExistence(timeout: 15), "'연락처 선택' 버튼이 없다")
    selectContacts.tap()

    let pickYongHoon = springboard.buttons["김용훈님의 연락처 사진"]
    let pickEunHo = springboard.buttons["이은호님의 연락처 사진"]
    XCTAssertTrue(pickYongHoon.waitForExistence(timeout: 10), "피커에 김용훈이 없다")
    XCTAssertTrue(pickEunHo.waitForExistence(timeout: 3), "피커에 이은호가 없다")
    pickYongHoon.tap()
    pickEunHo.tap()

    let confirm = springboard.buttons["계속"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 3), "피커의 '계속' 버튼이 없다")
    XCTAssertTrue(confirm.isEnabled, "연락처를 선택했는데 '계속' 이 여전히 비활성이다")
    confirm.tap()

    // 3단계 — "N개의 연락처에 대한 접근을 허용하겠습니까?" 최종 확인.
    let grantSelected = springboard.buttons["선택한 연락처에 접근 허용"]
    XCTAssertTrue(grantSelected.waitForExistence(timeout: 10), "3단계 최종 확인 시트가 안 뜬다")
    grantSelected.tap()

    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 15), "limited 허용 후 검색 화면이 안 뜬다")

    app.searchFields.firstMatch.typeText("ㅇㅎ")
    XCTAssertTrue(app.staticTexts["김용훈"].waitForExistence(timeout: 3), "공유한 김용훈이 안 보인다")
    XCTAssertTrue(app.staticTexts["이은호"].exists, "공유한 이은호가 안 보인다")
    XCTAssertFalse(app.staticTexts["박윤희"].exists, "공유 안 한 박윤희가 보인다 — limited 필터링 실패")
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
