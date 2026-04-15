import Contacts
import XCTest
@testable import ContactFinder
@testable import KoreanInitialMatcher

final class ContactMapperTests: XCTestCase {
  func test_fullNameOnly() {
    let cn = CNMutableContact()
    cn.givenName = "철수"
    cn.familyName = "김"

    let result = ContactMapper.map(cn)
    XCTAssertNotNil(result)
    XCTAssertTrue(result!.displayName.contains("철수"))
    XCTAssertTrue(result!.displayName.contains("김"))
    // searchKey 는 displayName 의 초성이어야 함
    XCTAssertEqual(
      result!.searchKey,
      KoreanInitialMatcher.extractChosung(result!.displayName)
    )
  }

  func test_companyNameOnly_usesOrganizationAsDisplayName() {
    let cn = CNMutableContact()
    cn.organizationName = "애플코리아"

    let result = ContactMapper.map(cn)
    XCTAssertNotNil(result)
    XCTAssertEqual(result!.displayName, "애플코리아")
    XCTAssertEqual(result!.searchKey, "ㅇㅍㅋㄹㅇ")
  }

  func test_bothNameAndCompany_prefersFullName() {
    let cn = CNMutableContact()
    cn.givenName = "철수"
    cn.familyName = "김"
    cn.organizationName = "애플코리아"

    let result = ContactMapper.map(cn)
    XCTAssertNotNil(result)
    XCTAssertFalse(result!.displayName.contains("애플"))
    XCTAssertTrue(result!.displayName.contains("철수"))
  }

  func test_emptyContact_returnsNil() {
    let cn = CNMutableContact()
    XCTAssertNil(ContactMapper.map(cn))
  }

  func test_whitespaceOnlyOrganization_returnsNil() {
    let cn = CNMutableContact()
    cn.organizationName = "   "
    XCTAssertNil(ContactMapper.map(cn))
  }

  func test_englishName_preservedInDisplayName() {
    let cn = CNMutableContact()
    cn.givenName = "John"
    cn.familyName = "Smith"

    let result = ContactMapper.map(cn)
    XCTAssertNotNil(result)
    XCTAssertTrue(result!.displayName.contains("John"))
    XCTAssertTrue(result!.displayName.contains("Smith"))
  }

  func test_fetchKeys_notEmpty() {
    XCTAssertFalse(ContactMapper.fetchKeys().isEmpty)
  }
}
