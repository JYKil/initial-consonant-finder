import Foundation
import KoreanInitialMatcher

/// 연락처 배열에 대한 순수 필터 함수.
///
/// ContactStore 밖에 static 함수로 두어 XCTest 가 ObservableObject 를
/// 거치지 않고 스냅샷 배열에 대해 바로 검증할 수 있게 한다.
public enum ContactFilter {
  /// 쿼리로 연락처 목록을 필터링한다.
  ///
  /// - 빈 쿼리(공백만 있는 경우 포함)는 기본 연락처 앱처럼 전체 목록을
  ///   이름 가나다순으로 정렬해 반환한다.
  /// - 그 외에는 KoreanInitialMatcher.matches 로 초성 매칭 + 원문 소문자 fallback 을 수행한다.
  ///
  /// Note: searchKey 는 이미 extractChosung 결과이지만, matches 가 nameChosung 을
  /// 다시 추출하는 것은 멱등이므로 안전하다 (초성 자모는 그대로 유지됨).
  public static func apply(_ contacts: [Contact], query: String) -> [Contact] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      return contacts.sorted {
        $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
      }
    }
    return contacts.filter {
      KoreanInitialMatcher.matches(name: $0.searchKey, query: trimmed)
    }
  }
}
