import XCTest

/// 4단계(시뮬레이터 검증) 자동화. 실행 전 시딩 필요:
///
///     xcrun simctl privacy booted grant contacts com.kilga.InitialConsonantFinder
///     xcodebuild test -scheme SeedContacts -destination '...'
///
/// 시딩 픽스처 기준 기대값:
/// - "ㅇㅎ" → 김용훈(ㄱㅇㅎ) / 박윤희(ㅂㅇㅎ) / 이은호(ㅇㅇㅎ) 3명
/// - "ㄱㅊㅅ" → 김철수 1명
final class SearchUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()
  }

  /// 앱을 열면 검색바가 이미 포커스돼 있어야 한다 (2초 목표의 핵심).
  func test_검색바가_실행직후_자동포커스된다() {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5), "검색 필드가 없다")
    // hasKeyboardFocus 는 공개 API 가 아니라 KVC 로 읽는다.
    let focused = field.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    XCTAssertTrue(focused, "검색바가 자동 포커스되지 않았다")
  }

  func test_초성_ㅇㅎ_입력시_해당_연락처만_필터된다() {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("ㅇㅎ")

    XCTAssertTrue(app.staticTexts["김용훈"].waitForExistence(timeout: 3), "김용훈이 안 걸림")
    XCTAssertTrue(app.staticTexts["박윤희"].exists, "박윤희가 안 걸림")
    XCTAssertTrue(app.staticTexts["이은호"].exists, "이은호가 안 걸림")
    XCTAssertFalse(app.staticTexts["김철수"].exists, "김철수(ㄱㅊㅅ)가 잘못 걸림")
    XCTAssertFalse(app.staticTexts["John Smith"].exists, "John Smith 가 잘못 걸림")

    attachScreenshot(named: "search-ㅇㅎ")
  }

  func test_빈쿼리는_빈리스트다() {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["김용훈"].exists, "빈 쿼리인데 결과가 보인다")
  }

  func test_매칭없는_쿼리는_빈리스트다() {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("ㅋㅋㅋ")

    XCTAssertFalse(app.staticTexts["김용훈"].exists)
    XCTAssertFalse(app.staticTexts["김철수"].exists)
  }

  /// 앱이 한국어 로케일로 돌아야 UIKit 시스템 문자열이 한국어로 나온다.
  /// ko.lproj 가 빠지면 VoiceOver 가 검색 아이콘을 "Search" 로 읽는다.
  func test_시스템_문자열이_한국어다() {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))

    XCTAssertTrue(
      field.images["magnifyingglass"].label.contains("검색"),
      "검색 아이콘 라벨이 한국어가 아니다: \(field.images["magnifyingglass"].label)")

    field.typeText("ㄱ")
    XCTAssertTrue(
      field.buttons["텍스트 지우기"].waitForExistence(timeout: 3),
      "'Clear text' 가 한국어로 안 뜬다 — ko 로컬라이제이션 확인")
  }

  /// 결과 탭 → CNContactViewController 시트가 뜨는지.
  func test_결과탭하면_연락처_상세시트가_뜬다() {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("ㄱㅊㅅ")

    let row = app.staticTexts["김철수"]
    XCTAssertTrue(row.waitForExistence(timeout: 3), "김철수가 안 걸림")
    row.tap()

    // CNContactViewController 가 뜬다 (오른쪽 Edit 는 CNContactViewController 소유).
    let sheetBar = app.navigationBars["CNContactView"]
    XCTAssertTrue(sheetBar.waitForExistence(timeout: 5), "상세 시트가 안 뜬다")

    let done = app.buttons["완료"]
    XCTAssertTrue(done.waitForExistence(timeout: 3), "완료 버튼이 없다")

    // CNContactViewController 가 소유한 버튼. ko.lproj 가 없으면 "Edit" 으로 뜬다.
    XCTAssertTrue(sheetBar.buttons["편집"].exists, "Edit 버튼이 한국어로 안 뜬다 — ko 로컬라이제이션 확인")
    XCTAssertFalse(sheetBar.buttons["Edit"].exists, "Edit 버튼이 아직 영어다")

    attachScreenshot(named: "detail-sheet")

    // 시트를 닫으면 검색 쿼리가 유지된 채 검색 화면으로 돌아와야 한다.
    done.tap()
    XCTAssertFalse(
      sheetBar.waitForExistence(timeout: 2), "완료를 눌렀는데 시트가 안 닫힘")
    XCTAssertEqual(
      app.searchFields.firstMatch.value as? String, "ㄱㅊㅅ", "시트 닫은 뒤 검색 쿼리가 날아갔다")
  }

  private func attachScreenshot(named name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }
}
