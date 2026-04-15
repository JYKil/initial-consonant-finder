import Foundation

/// ContactStore 의 로드 진행 상태.
///
/// 3단계 UI 가 이 상태에 따라 스피너/빈 뷰/에러 뷰/결과 리스트로 분기한다.
public enum LoadState: Equatable, Sendable {
  case idle
  case loading
  case loaded
  /// 실패 시 사용자에게 보여줄 메시지. Error 원본은 보관하지 않음 (Sendable 경계 단순화).
  case failed(String)
}
