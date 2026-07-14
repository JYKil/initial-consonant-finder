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
        .task { await store.loadAll() }

    case .denied, .restricted:
      PermissionDeniedView(status: authStatus)

    @unknown default:
      PermissionDeniedView(status: .denied)
    }
  }
}
