import XCTest

/// 4단계 남은 항목: 로드 상태 전이 검증 (스피너 억제 / 로드 중 타이핑 / 실패-재시도).
///
/// 사전조건: 권한 authorized, SeedContacts.test_seed 로 시딩된 상태 (김용훈 등 9개).
final class LoadStateUITests: XCTestCase {
  /// `CNContactStore` 는 실제 시스템 API 라 테스트에서 실패를 주입할 방법이 없다.
  /// `InitialConsonantFinderApp` 의 `-uiTestForceLoadFailure` 런치 인자(#if DEBUG 전용,
  /// Release 빌드엔 없음)로 `store.loadState` 를 직접 `.failed` 로 세팅해서 에러 화면을 재현한다.
  func test_로드실패시_에러뷰와_다시시도로_복구된다() {
    let app = XCUIApplication()
    app.launchArguments = ["-uiTestForceLoadFailure"]
    app.launch()

    XCTAssertTrue(
      app.staticTexts["연락처를 불러오지 못했어요"].waitForExistence(timeout: 5), "에러 뷰가 안 뜬다")
    let retry = app.buttons["다시 시도"]
    XCTAssertTrue(retry.exists, "'다시 시도' 버튼이 없다")

    retry.tap()

    // 재시도는 실제 loadAll() 을 호출한다 — 권한이 authorized 고 연락처가 시딩돼 있으니 정상 복구되어야 한다.
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5), "재시도 후 검색 화면으로 복구가 안 된다")
    XCTAssertFalse(app.staticTexts["연락처를 불러오지 못했어요"].exists, "재시도 후에도 에러 뷰가 남아 있다")

    app.searchFields.firstMatch.typeText("ㄱㅇㅎ")
    XCTAssertTrue(app.staticTexts["김용훈"].waitForExistence(timeout: 3), "재시도 후 검색이 정상 동작하지 않는다")
  }

  /// 로드가 끝나기 전에 타이핑해도, 로드가 완료되는 순간(연락처가 채워지는 순간) 이미 입력된
  /// 쿼리 기준으로 결과가 즉시 채워져야 한다 (재입력 불필요) — `ContactStore` 의
  /// `CombineLatest($query, $contacts)` 설계가 이걸 보장한다.
  func test_로드완료_전_타이핑해도_로드되는순간_결과가_채워진다() {
    let app = XCUIApplication()
    app.launch()

    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5), "검색 필드가 없다")
    // 검색 화면이 뜨자마자 곧바로 타이핑 — 이 시점에 로드가 끝나 있을지 여부는 보장되지 않는다.
    field.typeText("ㄱㅇㅎ")

    XCTAssertTrue(app.staticTexts["김용훈"].waitForExistence(timeout: 5), "로드 완료 후에도 결과가 안 채워진다")
  }

  /// 시딩 픽스처(9개)는 로드가 200ms 안에 끝나서 스피너("연락처 불러오는 중…")가 아예 안 떠야 한다.
  /// to-do 의 "cold boot 150ms" 목표는 실기기 기준이라 시뮬레이터에서 그대로 판정하지 않고,
  /// 여기서는 "스피너가 뜨는지 여부"만 확인한다 — 이게 실제 UI 분기 로직(200ms 지연 스피너)의 검증 대상이다.
  func test_소량_연락처는_스피너가_뜨지_않는다() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5), "검색 화면이 안 뜬다")
    // 스피너가 뜬다면 200ms 근방에 나타났다 사라질 것이므로, 화면이 뜬 직후 짧게 폴링한다.
    XCTAssertFalse(
      app.staticTexts["연락처 불러오는 중…"].waitForExistence(timeout: 1),
      "연락처 9개인데 스피너가 떴다 — 200ms 지연 로직 또는 로드 자체가 느려진 것 아닌지 확인 필요")
  }
}
