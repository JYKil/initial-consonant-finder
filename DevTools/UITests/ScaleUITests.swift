import XCTest

/// 4단계 스케일 검증: 연락처 0개 / 5000개.
///
/// 사전조건은 `SeedContacts.test_seedEmpty` / `test_seedLarge` 로 맞춘다 (`DevTools/verify-parallel.sh` 참조).
/// 이 파일 안에서는 권한 상태를 건드리지 않는다 — authorized 상태여야 한다.
final class ScaleUITests: XCTestCase {
  /// 사전조건: SeedContacts.test_seedEmpty (연락처 0개, 권한 authorized)
  func test_연락처0개_크래시없이_빈리스트() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5), "검색 화면이 안 뜬다")
    app.searchFields.firstMatch.typeText("ㄱ")
    // 결과가 없어야 하고, 무엇보다 크래시 없이 살아있어야 한다.
    XCTAssertTrue(app.searchFields.firstMatch.exists, "연락처 0개에서 크래시 났다")
  }

  /// 사전조건: SeedContacts.test_seedLarge (연락처 5000개 + "김용훈" 확정 픽스처, 권한 authorized)
  ///
  /// README 의 "2초 안에 연락처 도달" 목표는 **여기서 판정하지 않는다.** 그 기준은 5단계 실기기에서
  /// Instruments Time Profiler 로 재는 게 맞다 — 이 테스트는 XCUITest 드라이버 오버헤드(폴링, IPC)가
  /// 섞여 있고 시뮬레이터는 실기기보다 느리다(측정치 실측: 6.35초). 여기서 확인할 건 딱 하나,
  /// **5000개에서도 크래시 없이 로드되고 검색이 기능적으로 맞는지**다. 임계값은 "행/크래시 감지"용으로만
  /// 넉넉하게 잡는다.
  func test_연락처5000개_로드되고_검색된다() {
    let app = XCUIApplication()
    let launchStart = Date()
    app.launch()

    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5), "검색 화면이 안 뜬다")

    field.typeText("ㄱㅇㅎ")
    let row = app.staticTexts["김용훈"]
    XCTAssertTrue(row.waitForExistence(timeout: 10), "5000개 중에서 김용훈이 안 걸림 — 크래시 또는 로드 실패 의심")

    let elapsed = Date().timeIntervalSince(launchStart)
    print("⏱ cold launch → 검색 결과 표시까지: \(String(format: "%.2f", elapsed))초 (참고용 — 2초 목표 판정은 5단계 실기기에서)")
    XCTAssertLessThan(elapsed, 15.0, "5000개 로드가 행(hang) 수준으로 오래 걸린다 (\(elapsed)초)")
  }
}
