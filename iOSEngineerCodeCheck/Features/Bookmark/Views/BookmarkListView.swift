//
//  BookmarkListView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct BookmarkListView: View {

    /// ブックマークが無いときに、リポジトリを探しに Search タブへ移る
    let showSearch: () -> Void

    @State private var viewModel: BookmarkViewModel

    init(viewModel: BookmarkViewModel = BookmarkViewModel(), showSearch: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.showSearch = showSearch
    }

    var body: some View {
        RepositoryListView(items: viewModel.bookmarks)
            .overlay {
                if viewModel.bookmarks.isEmpty {
                    emptyGuide
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

    /// ブックマークが無いときに、追加の方法と、探しに行く操作を示す
    private var emptyGuide: some View {
        ContentUnavailableView {
            Label("ブックマークはまだありません", systemImage: "bookmark")
        } description: {
            Text("Search タブでリポジトリを探し、詳細画面の「Add to Bookmark」で追加できます。")
        } actions: {
            Button("リポジトリを探す") {
                showSearch()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
