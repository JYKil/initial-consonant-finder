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

  public init() {
    // query 또는 contacts 가 바뀔 때마다 results 재계산.
    // ContactFilter.apply 는 static 순수 함수라 self 캡처가 없다.
    Publishers.CombineLatest($query, $contacts)
      .map { query, contacts in
        ContactFilter.apply(contacts, query: query)
      }
      .assign(to: &$results)
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
