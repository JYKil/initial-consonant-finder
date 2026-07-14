import Contacts
import XCTest

/// 시뮬레이터 연락처 시딩용 개발 도구 (4단계 수동 검증 준비물).
///
/// 프로덕션 앱 코드가 아니다. 앱 타겟을 호스트로 하는 테스트라서
/// 앱 번들 ID 의 연락처 권한을 그대로 물려받는다.
///
///     xcrun simctl privacy booted grant contacts com.kilga.InitialConsonantFinder
///     xcodebuild test -scheme SeedContacts -destination 'platform=iOS Simulator,name=iPhone 17'
///
/// ⚠️ 시뮬레이터의 연락처를 **전부 지우고** 픽스처로 덮어쓴다. 실기기에서 절대 돌리지 말 것.
final class SeedContacts: XCTestCase {
  /// 초성 검색 검증용 픽스처.
  /// - "ㄱㅇㅎ" → 김용훈
  /// - "ㄱ" → 김용훈 / 김철수 / 강민수
  /// - 한자 / 이모지 이름은 크래시 없이 통과하기만 하면 된다.
  private static let fixtures: [(family: String, given: String)] = [
    ("김", "용훈"),
    ("박", "윤희"),
    ("이", "은호"),
    ("김", "철수"),
    ("최", "지우"),
    ("정", "다은"),
    ("강", "民秀"),  // 한자 이름
    ("한", "소리🌸"),  // 이모지 이름
  ]

  func test_seed() throws {
    let store = CNContactStore()
    XCTAssertEqual(
      CNContactStore.authorizationStatus(for: .contacts), .authorized,
      "먼저 실행: xcrun simctl privacy booted grant contacts com.kilga.InitialConsonantFinder")

    try wipeAll(in: store)

    let save = CNSaveRequest()
    for fixture in Self.fixtures {
      let contact = CNMutableContact()
      contact.familyName = fixture.family
      contact.givenName = fixture.given
      contact.phoneNumbers = [
        CNLabeledValue(
          label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "010-1234-5678"))
      ]
      save.add(contact, toContainerWithIdentifier: nil)
    }

    // 영문 연락처 — 비한글 경로 확인용
    let english = CNMutableContact()
    english.givenName = "John"
    english.familyName = "Smith"
    save.add(english, toContainerWithIdentifier: nil)

    try store.execute(save)

    let total = try count(in: store)
    print("✅ 시딩 완료 — 연락처 \(total)개")
    XCTAssertEqual(total, Self.fixtures.count + 1)
  }

  private func wipeAll(in store: CNContactStore) throws {
    let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
    var doomed: [CNContact] = []
    try store.enumerateContacts(with: request) { contact, _ in doomed.append(contact) }
    guard !doomed.isEmpty else { return }

    let save = CNSaveRequest()
    for contact in doomed {
      guard let mutable = contact.mutableCopy() as? CNMutableContact else { continue }
      save.delete(mutable)
    }
    try store.execute(save)
  }

  private func count(in store: CNContactStore) throws -> Int {
    let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
    var total = 0
    try store.enumerateContacts(with: request) { _, _ in total += 1 }
    return total
  }
}
