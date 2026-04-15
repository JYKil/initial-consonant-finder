@preconcurrency import Contacts
import Foundation
import KoreanInitialMatcher

/// CNContact → Contact 변환을 담당하는 순수 함수 모음.
///
/// 프로토콜 추상화 없이도 단위 테스트가 가능하도록 설계됐다:
/// 테스트에서 CNMutableContact 를 직접 만들어 map() 에 넘기면 된다.
public enum ContactMapper {
  /// loadAll 시점에 enumerateContacts 에 넘길 키 목록.
  ///
  /// Phase 3 의 ContactDetailSheet 에서 상세 뷰 재조회 시에는
  /// `CNContactViewController.descriptorForRequiredKeys()` 를 대신 사용해야 한다.
  public static func fetchKeys() -> [CNKeyDescriptor] {
    [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactMiddleNameKey as CNKeyDescriptor,
      CNContactOrganizationNameKey as CNKeyDescriptor,
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]
  }

  /// CNContact 를 앱 내부 Contact 로 변환한다.
  ///
  /// - displayName 우선순위: fullName → organizationName
  /// - 둘 다 비어 있으면 nil (표시할 이름이 없는 연락처는 리스트에서 제외)
  public static func map(_ cn: CNContact) -> Contact? {
    let fullName = CNContactFormatter.string(from: cn, style: .fullName)?
      .trimmingCharacters(in: .whitespaces)

    let displayName: String
    if let fullName, !fullName.isEmpty {
      displayName = fullName
    } else {
      let org = cn.organizationName.trimmingCharacters(in: .whitespaces)
      guard !org.isEmpty else { return nil }
      displayName = org
    }

    return Contact(
      id: cn.identifier,
      displayName: displayName,
      searchKey: KoreanInitialMatcher.extractChosung(displayName)
    )
  }
}
