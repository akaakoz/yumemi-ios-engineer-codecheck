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
struct RepositoryListView<Item: RepositoryListItem>: View {

    let items: [Item]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        RepositoryRow(fullName: item.fullName, language: item.language)
                    }
                    .accessibilityIdentifier("repositoryRow.\(item.fullName)")
                    Divider()
                }
            }
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
