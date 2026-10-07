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
        RepositoryListView(items: viewModel.bookmarks)
            .overlay {
                if viewModel.bookmarks.isEmpty {
                    Text("検索ボタンをタップして")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: RepositoryDetail.self) { bookmark in
                // ブックマークから開いた詳細は保存している値だけで表示し、通信しない
                RepositoryDetailView(source: .saved(bookmark))
            }
            .onAppear {
                viewModel.loadBookmarks()
            }
            .alert(
                "ブックマーク",
                isPresented: $viewModel.isShowingStorageError,
                presenting: viewModel.storageError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
    }
}
