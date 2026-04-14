import Foundation

public enum KoreanInitialMatcher {
  private static let chosungTable: [Character] = [
    "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
    "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
  ]

  private static let chosungSet: Set<Character> = Set(chosungTable)

  private static let syllableBase: UInt32 = 0xAC00
  private static let syllableEnd: UInt32 = 0xD7A3
  private static let jungsungCount: UInt32 = 21
  private static let jongsungCount: UInt32 = 28

  /// 문자열을 초성 시퀀스로 변환한다.
  /// - 한글 음절: 초성 자모로 치환
  /// - 이미 초성 자모(ㄱ~ㅎ)인 경우: 그대로 유지
  /// - 그 외(영문/숫자/기호): 소문자로 변환해 유지
  public static func extractChosung(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    for scalar in text.unicodeScalars {
      let value = scalar.value
      if value >= syllableBase && value <= syllableEnd {
        let offset = value - syllableBase
        let index = Int(offset / (jungsungCount * jongsungCount))
        result.append(chosungTable[index])
      } else {
        let ch = Character(scalar)
        if chosungSet.contains(ch) {
          result.append(ch)
        } else {
          result.append(contentsOf: String(ch).lowercased())
        }
      }
    }
    return result
  }

  /// 이름이 쿼리와 매칭되는지 확인한다.
  /// - 이름의 초성 시퀀스에 쿼리의 초성 시퀀스가 연속 부분 문자열로 포함되면 true
  /// - 원문 소문자 비교로도 포함되면 true (한자/영문 fallback)
  public static func matches(name: String, query: String) -> Bool {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if trimmedQuery.isEmpty { return true }

    let nameChosung = extractChosung(name)
    let queryChosung = extractChosung(trimmedQuery)

    if !queryChosung.isEmpty && nameChosung.contains(queryChosung) {
      return true
    }

    let lowerName = name.lowercased()
    let lowerQuery = trimmedQuery.lowercased()
    return lowerName.contains(lowerQuery)
  }
}
