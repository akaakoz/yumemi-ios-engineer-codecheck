//
//  RepositoryListView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

/// 検索結果（`Repository`）とブックマーク（`RepositoryDetail`）の両方を表示できるようにする。
protocol RepositoryListItem: Hashable, Identifiable {
    var fullName: String { get }
    var description: String? { get }
    var language: String? { get }
    var stargazersCount: Int { get }
    var pushedAt: Date? { get }
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
                        RepositoryRow(item: item)
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

/// 開かずに目的のリポジトリか判断できるよう、名前に加えて説明文・Star 数・言語・最終更新を表示する
private struct RepositoryRow<Item: RepositoryListItem>: View {

    let item: Item

    var body: some View {
        // NavigationLink のラベルの中では複数行のテキストが中央揃えになるため、左揃えを明示する
        VStack(alignment: .leading, spacing: 6) {
            Text(item.fullName)
                .font(.headline)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(item.stargazersCount)", systemImage: "star")
                if let language = item.language {
                    Text(language)
                }
                if let pushedAt = item.pushedAt {
                    Label(pushedAt.formatted(.relative(presentation: .named)), systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
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
                description: "The Swift Programming Language",
                language: "C++",
                stargazersCount: 67000,
                watchersCount: 67000,
                forksCount: 0,
                openIssuesCount: 0,
                pushedAt: .now.addingTimeInterval(-3 * 24 * 60 * 60),
                owner: .init(avatarURLString: "https://avatars.githubusercontent.com/u/10639145")
            )
        ])
    }
}
