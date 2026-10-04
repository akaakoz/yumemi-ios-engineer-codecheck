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
                    isShownAsBookmarked: viewModel.isBookmarked(repository)
                ) { isBookmarked in
                    viewModel.setBookmarked(repository, isBookmarked: isBookmarked)
                }
            }
            .onAppear {
                viewModel.loadBookmarks()
            }
            .onChange(of: isSelected) { _, isSelected in
                if isSelected {
                    viewModel.dismissInitialGuide()
                } else {
                    isSearchFieldFocused = false
                }
            }
    }

    private var searchHeader: some View {
        TextField("", text: searchFieldText)
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

    /// `isShowingInitialGuide` は必ず body の評価中に読むこと。`Binding` のクロージャ内だけで読むと変更が監視されず、
    /// タブ切り替えで案内文を消しても検索欄が更新されない。
    private var searchFieldText: Binding<String> {
        guard viewModel.isShowingInitialGuide else {
            return $viewModel.query
        }
        return Binding(
            get: { "GitHubのリポジトリを検索できるよー" },
            set: { viewModel.updateQuery($0) }
        )
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if viewModel.isSearching {
            ProgressView()
        } else if viewModel.repositories.isEmpty {
            Text("GitHubのリポジトリを検索できるよー")
                .foregroundStyle(.secondary)
        }
    }
}
