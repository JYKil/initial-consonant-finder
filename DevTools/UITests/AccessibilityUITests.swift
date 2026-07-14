import XCTest

/// 4단계 접근성 / 레이아웃 검증.
///
/// 다크모드, Dynamic Type 최대(`.accessibility5`), 뷰포트(SE 375pt / Pro Max 430pt)는
/// 전부 **외부에서 시뮬레이터 상태로 세팅**하고 이 스위트를 그대로 재실행하는 방식이다
/// (`simctl ui <udid> appearance dark`, `simctl ui <udid> content_size accessibility-extra-extra-extra-large`).
/// 뷰포트는 이 스위트를 SE / Pro Max 두 destination 에 각각 돌리는 것으로 검증한다 — 코드는 공유.
///
/// 사전조건: SeedContacts.test_seed (기본 9개 픽스처), 권한 authorized.
final class AccessibilityUITests: XCTestCase {
  /// 어떤 외형(라이트/다크) · 글자 크기 · 화면 크기에서도 검색 결과 셀이 존재하고 탭 가능해야 한다.
  /// Dynamic Type 최대에서 셀이 겹치거나 잘려서 hittable 이 false 가 되는 게 대표적인 레이아웃 붕괴 신호다.
  func test_다양한_외형에서_레이아웃이_안깨진다() {
    let app = XCUIApplication()
    app.launch()

    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5), "검색 필드가 없다")
    XCTAssertTrue(field.isHittable, "검색 필드를 탭할 수 없다 (레이아웃 붕괴 의심)")

    field.typeText("ㄱ")
    let row = app.staticTexts["김용훈"]
    XCTAssertTrue(row.waitForExistence(timeout: 3), "김용훈 셀이 없다")
    XCTAssertTrue(row.isHittable, "김용훈 셀을 탭할 수 없다 (Dynamic Type 에서 레이아웃 붕괴 의심)")

    row.tap()
    XCTAssertTrue(app.buttons["완료"].waitForExistence(timeout: 5), "상세 시트 완료 버튼이 없다 (Dynamic Type 에서 시트 레이아웃 붕괴 의심)")

    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "layout-check"
    shot.lifetime = .keepAlways
    add(shot)
  }

  /// VoiceOver 라벨 확인. 화면을 눈으로 보지 않고도 이 값들만으로 스크린리더 경험을 검증한다.
  func test_VoiceOver_라벨이_올바르다() {
    let app = XCUIApplication()
    app.launch()

    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("ㄱㅊㅅ")

    let row = app.staticTexts["김철수, 연락처 상세 열기"]
    XCTAssertTrue(row.waitForExistence(timeout: 3), "VoiceOver 라벨 '이름, 연락처 상세 열기' 형식이 아니다")
  }
}
