import Contacts
import ContactsUI
import SwiftUI
import UIKit

/// `CNContactViewController` 를 SwiftUI `.sheet` 로 띄우기 위한 래퍼.
///
/// - 탭 시점에 `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` 로
///   원본 `CNContact` 를 재조회 → 항상 최신 데이터 + 메모리 절약
/// - `UINavigationController` 로 한 번 더 감싸서 상단바 + "완료" 버튼 확보
/// - 기본 연락처 앱의 상세 화면과 동일한 UI, 전화/문자/이메일/편집 네이티브 지원
struct ContactDetailSheet: UIViewControllerRepresentable {
  let contactId: String
  @Environment(\.dismiss) private var dismiss

  func makeCoordinator() -> Coordinator {
    Coordinator(onDone: { dismiss() })
  }

  func makeUIViewController(context: Context) -> UINavigationController {
    let store = CNContactStore()
    let keys = [CNContactViewController.descriptorForRequiredKeys()]

    do {
      let cnContact = try store.unifiedContact(
        withIdentifier: contactId,
        keysToFetch: keys
      )
      let detailVC = CNContactViewController(for: cnContact)
      detailVC.allowsEditing = true
      detailVC.allowsActions = true
      // 오른쪽은 CNContactViewController 가 자기 "Edit" 버튼으로 덮어쓴다. 완료는 왼쪽에 둔다.
      // 앱에 한국어 로컬라이제이션이 없어서 시스템 .done 은 "Done" 으로 뜬다 → 제목을 직접 지정.
      detailVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
        title: "완료",
        style: .done,
        target: context.coordinator,
        action: #selector(Coordinator.doneTapped)
      )
      return UINavigationController(rootViewController: detailVC)
    } catch {
      let errorVC = UIViewController()
      errorVC.view.backgroundColor = .systemBackground

      let label = UILabel()
      label.text = "연락처를 불러올 수 없어요"
      label.textAlignment = .center
      label.textColor = .secondaryLabel
      label.font = .preferredFont(forTextStyle: .body)
      label.translatesAutoresizingMaskIntoConstraints = false
      errorVC.view.addSubview(label)
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: errorVC.view.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: errorVC.view.centerYAnchor)
      ])

      errorVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
        title: "완료",
        style: .done,
        target: context.coordinator,
        action: #selector(Coordinator.doneTapped)
      )
      return UINavigationController(rootViewController: errorVC)
    }
  }

  func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    // 연락처 ID 는 sheet 생성 시점에 고정. 동일 sheet 내 갱신 불필요.
  }

  final class Coordinator: NSObject {
    let onDone: () -> Void

    init(onDone: @escaping () -> Void) {
      self.onDone = onDone
    }

    @objc func doneTapped() {
      onDone()
    }
  }
}
