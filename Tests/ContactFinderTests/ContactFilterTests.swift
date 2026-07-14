import XCTest
@testable import ContactFinder

final class ContactFilterTests: XCTestCase {
  private func make(_ id: String, _ name: String, _ searchKey: String) -> Contact {
    Contact(id: id, displayName: name, searchKey: searchKey)
  }

  // MARK: - 빈 쿼리 정책

  func test_emptyQuery_returnsAllSortedByName() {
    let all = [make("1", "이영희", "ㅇㅇㅎ"), make("2", "김철수", "ㄱㅊㅅ")]
    let result = ContactFilter.apply(all, query: "")
    XCTAssertEqual(result.map { $0.displayName }, ["김철수", "이영희"])
  }

  func test_whitespaceOnlyQuery_returnsAllSortedByName() {
    let all = [make("1", "이영희", "ㅇㅇㅎ"), make("2", "김철수", "ㄱㅊㅅ")]
    let result = ContactFilter.apply(all, query: "   ")
    XCTAssertEqual(result.map { $0.displayName }, ["김철수", "이영희"])
  }

  // MARK: - 매칭

  func test_noMatch_returnsEmpty() {
    let all = [make("1", "김철수", "ㄱㅊㅅ"), make("2", "이영희", "ㅇㅇㅎ")]
    XCTAssertTrue(ContactFilter.apply(all, query: "ㅂ").isEmpty)
  }

  func test_singleMatch() {
    let all = [
      make("1", "김철수", "ㄱㅊㅅ"),
      make("2", "이영희", "ㅇㅇㅎ")
    ]
    let result = ContactFilter.apply(all, query: "ㄱㅊ")
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.displayName, "김철수")
  }

  func test_multipleMatches() {
    let all = [
      make("1", "김철수", "ㄱㅊㅅ"),
      make("2", "이영희", "ㅇㅇㅎ"),
      make("3", "김영수", "ㄱㅇㅅ")
    ]
    let result = ContactFilter.apply(all, query: "ㄱ")
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(Set(result.map { $0.displayName }), Set(["김철수", "김영수"]))
  }

  func test_companyNameMatch() {
    // ContactMapper 가 회사명을 displayName 으로 승격한 케이스
    let all = [make("1", "애플코리아", "ㅇㅍㅋㄹㅇ")]
    let result = ContactFilter.apply(all, query: "ㅇㅍ")
    XCTAssertEqual(result.count, 1)
  }

  func test_englishNameMatch_viaFallback() {
    // 영문 이름은 searchKey 도 소문자로 보존됨 → matches 의 lowercased fallback 으로 매칭
    let all = [make("1", "John Smith", "john smith")]
    let result = ContactFilter.apply(all, query: "john")
    XCTAssertEqual(result.count, 1)
  }

  func test_preservesOriginalOrder() {
    let all = [
      make("1", "김가나", "ㄱㄱㄴ"),
      make("2", "이다라", "ㅇㄷㄹ"),
      make("3", "김마바", "ㄱㅁㅂ")
    ]
    let result = ContactFilter.apply(all, query: "ㄱ")
    XCTAssertEqual(result.map { $0.id }, ["1", "3"])
  }
}
