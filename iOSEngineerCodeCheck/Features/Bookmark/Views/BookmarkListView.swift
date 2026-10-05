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
        RepositoryListView(repositories: viewModel.bookmarks)
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
                    isBookmarked: Binding(
                        get: { viewModel.isBookmarked(repository) },
                        set: { viewModel.setBookmarked(repository, isBookmarked: $0) }
                    )
                )
            }
            .onAppear {
                viewModel.loadBookmarks()
            }
    }
}
