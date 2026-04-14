import Testing
@testable import KoreanInitialMatcher

// MARK: - extractChosung

@Test func extractChosung_용훈미국() {
  #expect(KoreanInitialMatcher.extractChosung("용훈미국") == "ㅇㅎㅁㄱ")
}

@Test func extractChosung_김철수() {
  #expect(KoreanInitialMatcher.extractChosung("김철수") == "ㄱㅊㅅ")
}

@Test func extractChosung_쌍자음_까불이() {
  #expect(KoreanInitialMatcher.extractChosung("까불이") == "ㄲㅂㅇ")
}

@Test func extractChosung_쌍자음_빠르다() {
  #expect(KoreanInitialMatcher.extractChosung("빠르다") == "ㅃㄹㄷ")
}

@Test func extractChosung_영문은_소문자() {
  #expect(KoreanInitialMatcher.extractChosung("John") == "john")
}

@Test func extractChosung_섞인_John김() {
  #expect(KoreanInitialMatcher.extractChosung("John 김") == "john ㄱ")
}

@Test func extractChosung_공백_특수문자() {
  #expect(KoreanInitialMatcher.extractChosung("김-철 수!") == "ㄱ-ㅊ ㅅ!")
}

@Test func extractChosung_빈문자열() {
  #expect(KoreanInitialMatcher.extractChosung("") == "")
}

@Test func extractChosung_이미_초성만() {
  #expect(KoreanInitialMatcher.extractChosung("ㅇㅎ") == "ㅇㅎ")
}

@Test func extractChosung_숫자() {
  #expect(KoreanInitialMatcher.extractChosung("홍길동123") == "ㅎㄱㄷ123")
}

// MARK: - matches (positive)

@Test func matches_ㅇㅎ_prefix() {
  #expect(KoreanInitialMatcher.matches(name: "용훈미국", query: "ㅇㅎ"))
}

@Test func matches_ㅎㅁ_중간연속() {
  #expect(KoreanInitialMatcher.matches(name: "용훈미국", query: "ㅎㅁ"))
}

@Test func matches_전체초성일치() {
  #expect(KoreanInitialMatcher.matches(name: "용훈미국", query: "ㅇㅎㅁㄱ"))
}

@Test func matches_빈쿼리는_true() {
  #expect(KoreanInitialMatcher.matches(name: "김철수", query: ""))
}

@Test func matches_공백쿼리는_true() {
  #expect(KoreanInitialMatcher.matches(name: "김철수", query: "   "))
}

@Test func matches_영문이름_소문자() {
  #expect(KoreanInitialMatcher.matches(name: "John Smith", query: "john"))
}

@Test func matches_영문이름_대소문자무시() {
  #expect(KoreanInitialMatcher.matches(name: "John Smith", query: "SMITH"))
}

@Test func matches_섞인이름_한글초성() {
  #expect(KoreanInitialMatcher.matches(name: "John 김철수", query: "ㄱㅊ"))
}

@Test func matches_원문_한글_부분일치() {
  #expect(KoreanInitialMatcher.matches(name: "김철수", query: "철수"))
}

@Test func matches_이모지_포함이름_크래시없음() {
  // 이모지는 구분자처럼 작동 — 이모지 양쪽 초성 블록 내부 연속 일치는 허용
  #expect(KoreanInitialMatcher.matches(name: "김🎉철수", query: "ㅊㅅ"))
  #expect(!KoreanInitialMatcher.matches(name: "김🎉철수", query: "ㄱㅊㅅ"))
}

@Test func matches_한자이름_원문일치() {
  #expect(KoreanInitialMatcher.matches(name: "金哲秀", query: "金哲"))
}

// MARK: - matches (negative)

@Test func matches_중간건너뜀_불가() {
  #expect(!KoreanInitialMatcher.matches(name: "용훈미국", query: "ㄱㅅ"))
}

@Test func matches_관련없는_쿼리() {
  #expect(!KoreanInitialMatcher.matches(name: "김철수", query: "ㅂㅈㄷ"))
}

@Test func matches_빈이름_비빈쿼리() {
  #expect(!KoreanInitialMatcher.matches(name: "", query: "ㄱ"))
}
