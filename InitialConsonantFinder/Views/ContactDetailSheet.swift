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
    Coordinator(contactId: contactId, onDone: { dismiss() })
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
      detailVC.contactStore = store
      // 오른쪽은 CNContactViewController 가 자기 "Edit" 버튼으로 덮어쓴다.
      // 왼쪽은 기존 연락처 앱과 동일하게 "완료" 텍스트 대신 뒤로가기 화살표만 둔다.
      detailVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        style: .plain,
        target: context.coordinator,
        action: #selector(Coordinator.doneTapped)
      )
      // CNContactViewController 는 실기기에서도 "연락처 삭제" 행을 스스로 노출하지 않는 경우가
      // 있어(contactStore 지정 여부와 무관), 삭제는 CNSaveRequest 로 직접 구현한다.
      let deleteButton = UIBarButtonItem(
        title: "연락처 삭제",
        style: .plain,
        target: context.coordinator,
        action: #selector(Coordinator.deleteTapped)
      )
      deleteButton.tintColor = .systemRed
      detailVC.toolbarItems = [.flexibleSpace(), deleteButton, .flexibleSpace()]

      let navController = UINavigationController(rootViewController: detailVC)
      navController.isToolbarHidden = false
      context.coordinator.store = store
      context.coordinator.presentingViewController = detailVC
      return navController
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
        image: UIImage(systemName: "chevron.backward"),
        style: .plain,
        target: context.coordinator,
        action: #selector(Coordinator.doneTapped)
      )
      return UINavigationController(rootViewController: errorVC)
    }
  }

  func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    // 연락처 ID 는 sheet 생성 시점에 고정. 동일 sheet 내 갱신 불필요.
  }

  @MainActor
  final class Coordinator: NSObject {
    let contactId: String
    let onDone: () -> Void
    var store: CNContactStore?
    weak var presentingViewController: UIViewController?

    init(contactId: String, onDone: @escaping () -> Void) {
      self.contactId = contactId
      self.onDone = onDone
    }

    @objc func doneTapped() {
      onDone()
    }

    @objc func deleteTapped() {
      let alert = UIAlertController(
        title: "연락처를 삭제할까요?",
        message: "이 연락처가 기기에서 완전히 삭제됩니다.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "취소", style: .cancel))
      alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
        self?.performDelete()
      })
      presentingViewController?.present(alert, animated: true)
    }

    private func performDelete() {
      guard let store else { return }
      do {
        let existing = try store.unifiedContact(
          withIdentifier: contactId,
          keysToFetch: [CNContactViewController.descriptorForRequiredKeys()]
        )
        guard let mutable = existing.mutableCopy() as? CNMutableContact else { return }
        let request = CNSaveRequest()
        request.delete(mutable)
        try store.execute(request)
        onDone()
      } catch {
        let alert = UIAlertController(
          title: "삭제 실패",
          message: error.localizedDescription,
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        presentingViewController?.present(alert, animated: true)
      }
    }
  }
}
