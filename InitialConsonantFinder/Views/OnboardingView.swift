import SwiftUI

/// 권한 상태가 `.notDetermined` 일 때만 표시되는 사전 설명 화면.
///
/// iOS 시스템 팝업 직전에 "로컬 전용, 서버 전송 없음" 메시지를 전달해
/// 거부 확률을 낮춘다. 앱 삭제 후 재설치 시에만 다시 나타남 (iOS 권한
/// 상태가 .notDetermined 로 리셋될 때).
struct OnboardingView: View {
  /// 상위 View 로부터 주입되는 권한 요청 클로저.
  /// 호출하면 `ContactStore.requestAccess()` 가 실행되고, 결과에 따라
  /// 상위 @State `authStatus` 가 갱신되어 rootView 가 자동 전환된다.
  let onRequestAccess: () async -> Void

  @State private var isRequesting = false

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      Image(systemName: "magnifyingglass")
        .font(.system(size: 72, weight: .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)

      VStack(spacing: 16) {
        Text("초성으로 빠르게 찾기")
          .font(.largeTitle.bold())
          .multilineTextAlignment(.center)

        Text("이 앱은 연락처를 읽어서 초성 검색만 합니다.\n서버로 아무것도 보내지 않아요.\n전부 기기 안에서.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 32)

      Spacer()

      Button {
        Task {
          isRequesting = true
          await onRequestAccess()
          isRequesting = false
        }
      } label: {
        Text("시작하기")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      }
      .buttonStyle(.borderedProminent)
      .disabled(isRequesting)
      .padding(.horizontal, 24)
      .padding(.bottom, 24)
    }
  }
}

#Preview {
  OnboardingView(onRequestAccess: {})
}
