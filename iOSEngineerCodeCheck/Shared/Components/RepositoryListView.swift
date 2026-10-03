//
//  RepositoryListView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

/// 行をタップすると `Repository` を値として push する。遷移先は使う側が
/// `navigationDestination(for: Repository.self)` で決めるため、この部品は遷移先の画面に依存しない。
/// 値で遷移するため、詳細表示中に元の一覧から項目が消えても詳細画面は閉じない。
struct RepositoryListView: View {

    let repositories: [Repository]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(repositories) { repository in
                    NavigationLink(value: repository) {
                        RepositoryRow(repository: repository)
                    }
                    .accessibilityIdentifier("repositoryRow.\(repository.fullName)")
                    Divider()
                }
            }
        }
    }
}

private struct RepositoryRow: View {

    let repository: Repository

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(repository.fullName)

            Spacer(minLength: 16)

            if let language = repository.language {
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
        RepositoryListView(repositories: [
            Repository(
                fullName: "apple/swift",
                language: "C++",
                stargazersCount: 0,
                watchersCount: 0,
                forksCount: 0,
                openIssuesCount: 0,
                owner: .init(avatarUrl: "https://avatars.githubusercontent.com/u/10639145")
            )
        ])
    }
}
