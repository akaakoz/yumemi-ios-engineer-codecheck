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
        RepositoryListView(repositories: viewModel.repositories)
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
            .onChange(of: isSelected) { _, isSelected in
                if !isSelected {
                    isSearchFieldFocused = false
                }
            }
    }

    private var searchHeader: some View {
        TextField("", text: $viewModel.query, prompt: Text("GitHubのリポジトリを検索できるよー"))
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
