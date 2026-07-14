import Contacts
import ContactFinder
import SwiftUI

@main
struct InitialConsonantFinderApp: App {
  @StateObject private var store = ContactStore()
  @State private var authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

  var body: some Scene {
    WindowGroup {
      rootView
    }
  }

  @ViewBuilder
  private var rootView: some View {
    switch authStatus {
    case .notDetermined:
      OnboardingView(
        onRequestAccess: {
          let newStatus = await store.requestAccess()
          authStatus = newStatus
        }
      )

    case .authorized, .limited:
      ContactSearchView(store: store)
        .task {
          // CNContactStore 는 실제 시스템 API 라 테스트에서 실패를 주입할 방법이 없다.
          // loadState 가 public 이라 여기서 바로 덮어쓰는 게 가장 침습적이지 않다.
          // #if DEBUG 로 감싸서 Release(App Store) 빌드에는 컴파일조차 안 된다.
          #if DEBUG
          if ProcessInfo.processInfo.arguments.contains("-uiTestForceLoadFailure") {
            store.loadState = .failed("테스트로 강제한 로드 실패")
            return
          }
          #endif
          await store.loadAll()
        }

    case .denied, .restricted:
      PermissionDeniedView(status: authStatus)

    @unknown default:
      PermissionDeniedView(status: .denied)
    }
  }
}
