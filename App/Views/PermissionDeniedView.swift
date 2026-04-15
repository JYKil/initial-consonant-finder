import Contacts
import SwiftUI
import UIKit

/// 연락처 권한이 `.denied` 또는 `.restricted` 일 때 표시되는 폴백 화면.
///
/// - `.denied`: 유저가 거부했거나 나중에 껐음 → 설정 앱으로 유도
/// - `.restricted`: MDM / 스크린타임 등 기기 정책 → 설정 버튼 없음
struct PermissionDeniedView: View {
  let status: CNAuthorizationStatus

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Image(systemName: "person.crop.circle.badge.exclamationmark")
        .font(.system(size: 64))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)

      VStack(spacing: 12) {
        Text("연락처 접근이 필요해요")
          .font(.title2.bold())
          .multilineTextAlignment(.center)

        Text(message)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      Spacer()

      if status == .denied {
        Button {
          openSettings()
        } label: {
          Text("설정 열기")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
      }
    }
  }

  private var message: String {
    switch status {
    case .denied:
      return "연락처 접근 권한이 꺼져 있어요.\n설정에서 켜주세요."
    case .restricted:
      return "이 기기는 정책상 연락처 접근이 제한돼 있어요."
    default:
      return "연락처 접근이 필요합니다."
    }
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

#Preview("Denied") {
  PermissionDeniedView(status: .denied)
}

#Preview("Restricted") {
  PermissionDeniedView(status: .restricted)
}
