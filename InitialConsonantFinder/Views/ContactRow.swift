import ContactFinder
import SwiftUI

/// 검색 결과 셀. 애플 기본 연락처 앱 스타일:
/// 회색 원(36×36) + 이니셜 1자 + 이름.
struct ContactRow: View {
  let contact: Contact

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color(.secondarySystemFill))
        .frame(width: 36, height: 36)
        .overlay(
          Text(String(contact.displayName.prefix(1)))
            .font(.headline)
            .foregroundStyle(.secondary)
        )

      Text(contact.displayName)
        .font(.body)
        .foregroundStyle(.primary)

      Spacer(minLength: 0)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(contact.displayName), 연락처 상세 열기")
  }
}

#Preview {
  List {
    ContactRow(contact: Contact(id: "1", displayName: "용훈미국", searchKey: "ㅇㅎㅁㄱ"))
    ContactRow(contact: Contact(id: "2", displayName: "김철수", searchKey: "ㄱㅊㅅ"))
    ContactRow(contact: Contact(id: "3", displayName: "John Smith", searchKey: "john smith"))
  }
  .listStyle(.plain)
}
