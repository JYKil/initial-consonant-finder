import ContactFinder
import SwiftUI

/// 메인 검색 화면.
///
/// - `.searchable()` 모디파이어로 iOS HIG 표준 검색바 상단 배치
/// - 앱 오픈 즉시 검색바 자동 활성 (키보드 바로 올라옴)
/// - 상태별 분기: 로딩(200ms 지연 스피너) / 정상 / 에러
/// - 셀 탭 → `CNContactViewController` 시트 present
struct ContactSearchView: View {
  @ObservedObject var store: ContactStore

  @State private var selectedContact: Contact?
  @State private var showSpinner = false
  @State private var isSearchActive = true
  @State private var contactPendingDelete: Contact?
  @State private var deleteErrorMessage: String?

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("연락처 검색")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
          text: $store.query,
          isPresented: $isSearchActive,
          placement: .navigationBarDrawer(displayMode: .always),
          prompt: "이름 초성"
        )
        .onAppear {
          // iOS 17: isPresented 바인딩으로 검색 필드 활성 → 키보드 자동 노출
          isSearchActive = true
        }
        .sheet(item: $selectedContact) { contact in
          ContactDetailSheet(contactId: contact.id)
        }
        .task(id: isLoading) {
          await updateSpinnerVisibility()
        }
        .alert(
          "연락처를 삭제할까요?",
          isPresented: Binding(
            get: { contactPendingDelete != nil },
            set: { if !$0 { contactPendingDelete = nil } }
          ),
          presenting: contactPendingDelete
        ) { contact in
          Button("취소", role: .cancel) {}
          Button("삭제", role: .destructive) {
            deleteContact(contact)
          }
        } message: { contact in
          Text("\(contact.displayName)이(가) 기기에서 완전히 삭제됩니다.")
        }
        .alert(
          "삭제 실패",
          isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
          ),
          presenting: deleteErrorMessage
        ) { _ in
          Button("확인", role: .cancel) {}
        } message: { message in
          Text(message)
        }
    }
  }

  // MARK: - Content 분기

  @ViewBuilder
  private var content: some View {
    switch store.loadState {
    case .failed(let message):
      errorView(message: message)

    case .loading:
      if showSpinner {
        loadingView
      } else {
        // 200ms 지연 전에는 빈 리스트 (검색바는 유지)
        resultsList
      }

    case .idle, .loaded:
      resultsList
    }
  }

  private var resultsList: some View {
    List(store.results) { contact in
      ContactRow(contact: contact)
        .contentShape(Rectangle())
        .onTapGesture { selectedContact = contact }
        .listRowSeparator(.visible)
        .listRowInsets(.init(top: 2, leading: 16, bottom: 2, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) {
            contactPendingDelete = contact
          } label: {
            Label("삭제", systemImage: "trash")
          }
        }
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 40)
  }

  private func deleteContact(_ contact: Contact) {
    Task {
      do {
        try await store.delete(contact)
      } catch {
        deleteErrorMessage = error.localizedDescription
      }
    }
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("연락처 불러오는 중…")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("연락처를 불러오지 못했어요")
        .font(.headline)

      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button("다시 시도") {
        Task { await store.loadAll() }
      }
      .buttonStyle(.borderedProminent)
      .padding(.top, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - 200ms 지연 스피너

  /// `store.loadState` 가 `.loading` 인지 여부. `.task(id:)` 의 identity 로 사용.
  private var isLoading: Bool {
    if case .loading = store.loadState { return true }
    return false
  }

  private func updateSpinnerVisibility() async {
    guard isLoading else {
      showSpinner = false
      return
    }
    // 200ms 이상 지속될 때만 스피너 노출 → 깜빡임 방지
    try? await Task.sleep(for: .milliseconds(200))
    if isLoading {
      showSpinner = true
    }
  }
}
