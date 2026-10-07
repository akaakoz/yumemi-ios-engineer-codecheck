//
//  RepositoryListView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

/// 検索結果（`Repository`）とブックマーク（`RepositoryDetail`）の両方を表示できるようにする。
protocol RepositoryListItem: Hashable, Identifiable {
    var fullName: String { get }
    var language: String? { get }
}

extension Repository: RepositoryListItem {}

/// 値で遷移するため、詳細表示中に元の一覧から項目が消えても詳細画面は閉じない。
struct RepositoryListView<Item: RepositoryListItem, Footer: View>: View {

    let items: [Item]
    /// 一覧の一番下に表示する内容（追加読み込みの状態など）
    let footer: Footer

    init(items: [Item], @ViewBuilder footer: () -> Footer) {
        self.items = items
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        RepositoryRow(fullName: item.fullName, language: item.language)
                    }
                    .accessibilityIdentifier("repositoryRow.\(item.fullName)")
                    Divider()
                }
                footer
            }
        }
    }
}

extension RepositoryListView where Footer == EmptyView {
    /// 一番下に何も表示せず、追加読み込みもしない一覧（ブックマークなど）
    init(items: [Item]) {
        self.init(items: items) {
            EmptyView()
        }
    }
}

private struct RepositoryRow: View {

    let fullName: String
    let language: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // NavigationLink のラベルの中では複数行のテキストが中央揃えになるため、左揃えを明示する
            Text(fullName)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 16)

            if let language {
                Text(language)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        RepositoryListView(items: [
            Repository(
                fullName: "apple/swift",
                language: "C++",
                stargazersCount: 0,
                watchersCount: 0,
                forksCount: 0,
                openIssuesCount: 0,
                owner: .init(avatarURLString: "https://avatars.githubusercontent.com/u/10639145")
            )
        ])
    }
}
