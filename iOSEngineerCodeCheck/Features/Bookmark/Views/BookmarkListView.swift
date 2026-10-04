//
//  BookmarkListView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct BookmarkListView: View {

    @State private var viewModel: BookmarkViewModel

    init(viewModel: BookmarkViewModel = BookmarkViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        RepositoryListView(repositories: viewModel.bookmarks.map(\.repository))
            .overlay {
                if viewModel.bookmarks.isEmpty {
                    Text("検索ボタンをタップして")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bookmarks")
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
