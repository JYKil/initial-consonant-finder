import Combine
@preconcurrency import Contacts
import Foundation

/// 연락처 로드 + 검색 상태를 관리하는 ObservableObject.
///
/// ```
/// [View] ── bind ──▶ @Published query ─┐
///                                       ├─▶ ContactFilter.apply ─▶ @Published results
///                   @Published contacts ─┘
/// ```
///
/// loadAll() 은 백그라운드에서 실행되고 결과만 MainActor 로 돌아와 @Published 에 할당된다.
@MainActor
public final class ContactStore: ObservableObject {
  @Published public var contacts: [Contact] = []
  @Published public var query: String = ""
  @Published public var results: [Contact] = []
  @Published public var loadState: LoadState = .idle

  private var contactStoreChangeCancellable: AnyCancellable?

  public init() {
    // query 또는 contacts 가 바뀔 때마다 results 재계산.
    // ContactFilter.apply 는 static 순수 함수라 self 캡처가 없다.
    Publishers.CombineLatest($query, $contacts)
      .map { query, contacts in
        ContactFilter.apply(contacts, query: query)
      }
      .assign(to: &$results)

    // 편집/삭제/추가 등 시스템 어디서든 연락처 DB 가 바뀌면 CNContactStore 가 이 노티를 쏜다.
    // 상세 시트의 CNContactViewController 는 자체적으로 저장을 처리하므로, 이 노티를 구독해
    // contacts 를 재로드하지 않으면 리스트가 stale 한 상태로 남는다.
    contactStoreChangeCancellable = NotificationCenter.default
      .publisher(for: .CNContactStoreDidChange)
      .sink { [weak self] _ in
        Task { await self?.loadAll() }
      }
  }

  /// 현재 권한 상태를 반환한다.
  public var authorizationStatus: CNAuthorizationStatus {
    CNContactStore.authorizationStatus(for: .contacts)
  }

  /// 연락처 접근 권한을 요청하고 최종 상태를 반환한다.
  ///
  /// 호출측은 반환값에 따라 분기:
  /// - `.authorized` / `.limited` → `loadAll()`
  /// - `.denied` / `.restricted`   → PermissionDeniedView
  /// - `.notDetermined`             → (이론상 발생 안 함, 요청 후에도 미결정이면 폴백)
  public func requestAccess() async -> CNAuthorizationStatus {
    let current = CNContactStore.authorizationStatus(for: .contacts)
    if current != .notDetermined {
      return current
    }

    // 요청은 새 CNContactStore 인스턴스에서 수행.
    // CNContactStore 는 Sendable 이 아니므로 MainActor 에서 생성해 바로 사용하고 버린다.
    let store = CNContactStore()
    do {
      _ = try await store.requestAccess(for: .contacts)
    } catch {
      loadState = .failed("권한 요청 실패: \(error.localizedDescription)")
    }
    return CNContactStore.authorizationStatus(for: .contacts)
  }

  /// 연락처 전체를 백그라운드 스레드에서 로드한다.
  ///
  /// - `loadState` 를 `.loading` → `.loaded` 또는 `.failed(…)` 로 전이시킨다.
  /// - 실제 enumerate 는 nonisolated async 헬퍼에서 수행 → 메인 액터 블록 없음.
  /// - 결과 배열만 MainActor 로 돌아와 `contacts` 에 할당된다.
  public func loadAll() async {
    loadState = .loading
    do {
      let loaded = try await Self.fetchAllContacts()
      self.contacts = loaded
      self.loadState = .loaded
    } catch {
      self.loadState = .failed("연락처 로드 실패: \(error.localizedDescription)")
    }
  }

  /// 연락처 하나를 기기에서 완전히 삭제한다.
  ///
  /// 삭제 성공 시 `CNContactStoreDidChange` 알림이 발생해 `init` 의 구독이 자동으로
  /// `loadAll()` 을 재호출하므로, 여기서 `contacts` 를 직접 갱신할 필요는 없다.
  public func delete(_ contact: Contact) async throws {
    try await Self.deleteContact(withIdentifier: contact.id)
  }

  private static func deleteContact(withIdentifier id: String) async throws {
    let store = CNContactStore()
    // 삭제는 CNMutableContact 의 identifier 만 있으면 되므로 최소 키만 조회한다
    // (ContactsUI 의 CNContactViewController.descriptorForRequiredKeys() 는 UIKit
    // 의존이라 이 라이브러리(macOS 도 지원)에서는 쓰지 않는다).
    let existing = try store.unifiedContact(
      withIdentifier: id,
      keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
    )
    guard let mutable = existing.mutableCopy() as? CNMutableContact else { return }
    let request = CNSaveRequest()
    request.delete(mutable)
    try store.execute(request)
  }

  /// MainActor 에 격리되지 않은 정적 헬퍼.
  /// `async` 이므로 호출 시 협력 스레드 풀로 디스패치되어 메인을 블록하지 않는다.
  private static func fetchAllContacts() async throws -> [Contact] {
    let store = CNContactStore()
    let request = CNContactFetchRequest(keysToFetch: ContactMapper.fetchKeys())
    var buffer: [Contact] = []
    try store.enumerateContacts(with: request) { cn, _ in
      if let contact = ContactMapper.map(cn) {
        buffer.append(contact)
      }
    }
    return buffer
  }
}
