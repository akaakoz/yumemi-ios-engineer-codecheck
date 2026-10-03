//
//  BookmarkListView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

/// 表示されるたびに保存済みのブックマークを読み込み直し、Search タブでの追加・削除を反映する。
struct BookmarkListView: View {

    @State private var viewModel: BookmarkViewModel

    init(viewModel: BookmarkViewModel = BookmarkViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        RepositoryListView(repositories: viewModel.bookmarks.map(\.repository))
            .overlay {
                if viewModel.bookmarks.isEmpty {
                    Text(AppStrings.BookmarkList.emptyMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(AppStrings.BookmarkList.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Repository.self) { repository in
                RepositoryDetailView(
                    repository: repository,
                    isShownAsBookmarked: viewModel.isMarked(repository)
                ) { isMarked in
                    viewModel.setMarked(repository, isMarked: isMarked)
                }
            }
            .onAppear {
                viewModel.loadBookmarks()
            }
    }
}
