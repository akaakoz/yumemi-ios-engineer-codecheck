//
//  RepositorySearchView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositorySearchView: View {

    let isSelected: Bool

    @State private var viewModel: RepositorySearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    init(isSelected: Bool, viewModel: RepositorySearchViewModel = RepositorySearchViewModel()) {
        self.isSelected = isSelected
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        RepositoryListView(
            items: viewModel.repositories,
            onLastItemAppear: { viewModel.loadMoreIfNeeded() },
            footer: { loadMoreFooter }
        )
            // 検索中は前回の画面を操作できないようにする
            .disabled(viewModel.phase == .loading)
            .safeAreaInset(edge: .top) {
                searchHeader
            }
            .overlay {
                statusOverlay
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Repository.self) { repository in
                RepositoryDetailView(
                    source: .remote(fullName: repository.fullName),
                    isBookmarked: { viewModel.isBookmarked(fullName: repository.fullName) },
                    addBookmark: { viewModel.addBookmark($0) },
                    removeBookmark: { viewModel.removeBookmark(fullName: repository.fullName) }
                )
            }
            .onAppear {
                viewModel.loadBookmarks()
            }
            .alert(
                "ブックマーク",
                isPresented: $viewModel.isShowingBookmarkStorageError,
                presenting: viewModel.bookmarkStorageError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .onChange(of: isSelected) { _, isSelected in
                if !isSelected {
                    isSearchFieldFocused = false
                }
            }
    }

    private var searchHeader: some View {
        TextField("", text: $viewModel.query, prompt: Text("リポジトリを検索"))
            .textFieldStyle(.roundedBorder)
            .submitLabel(.search)
            .focused($isSearchFieldFocused)
            .onSubmit {
                viewModel.search()
            }
            .accessibilityIdentifier("repositorySearch.field")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
    }

    /// 一覧の一番下に、追加読み込みの状態を表示する
    @ViewBuilder
    private var loadMoreFooter: some View {
        switch viewModel.loadMorePhase {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .accessibilityIdentifier("repositorySearch.loadMoreIndicator")
        case .failed(let error):
            VStack(spacing: 8) {
                Text(RepositorySearchViewModel.failureMessage(for: error))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("再試行") {
                    viewModel.retryLoadMore()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case .idle where viewModel.repositories.isEmpty:
            Text("GitHubのリポジトリを検索できるよー")
                .foregroundStyle(.secondary)
        case .loaded where viewModel.repositories.isEmpty:
            Text("該当するリポジトリがありません")
                .foregroundStyle(.secondary)
        case .failed(let error):
            Text(RepositorySearchViewModel.failureMessage(for: error))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        case .idle, .loaded:
            EmptyView()
        }
    }
}
