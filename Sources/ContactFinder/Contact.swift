import Foundation

/// 앱 내부용 연락처 스냅샷.
///
/// CNContact 원본은 보관하지 않는다. 탭 시점에
/// CNContactStore.unifiedContact(withIdentifier:keysToFetch:) 로 재조회해
/// CNContactViewController 에 넘긴다 (항상 최신 데이터 + 메모리 절약).
public struct Contact: Identifiable, Hashable, Sendable {
  public let id: String
  public let displayName: String
  /// 로드 시점에 1회 계산해 캐시한 초성 시퀀스.
  /// 매 keystroke 마다 extractChosung 재실행을 피하기 위함.
  public let searchKey: String

  public init(id: String, displayName: String, searchKey: String) {
    self.id = id
    self.displayName = displayName
    self.searchKey = searchKey
  }
}
