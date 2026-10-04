//
//  RepositorySearchView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositorySearchView: View {

    /// Search タブが選択されているか。選択されたら案内文を消し、外れたら検索欄のフォーカスを外す
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
            .navigationTitle(AppStrings.RepositorySearch.navigationTitle)
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
                // 旧実装はタブ切り替え時に検索欄へフォーカスする意図だったが、実際にはフォーカスされていなかった。
                // 挙動を変えないよう、ここではフォーカスしない（stability 課題で見直す）
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

    /// 案内文を表示している間は入力値として案内文を見せる。編集すると案内文に続けて入力される（旧実装の挙動を維持）
    ///
    /// `isShowingInitialGuide` は必ず body の評価中に読むこと。`Binding` のクロージャ内だけで読むと変更が監視されず、
    /// タブ切り替えで案内文を消しても検索欄が更新されない。
    private var searchFieldText: Binding<String> {
        guard viewModel.isShowingInitialGuide else {
            return $viewModel.query
        }
        return Binding(
            get: { AppStrings.RepositorySearch.initialFieldText },
            set: { viewModel.updateQuery($0) }
        )
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if viewModel.isSearching {
            ProgressView()
        } else if viewModel.repositories.isEmpty {
            Text(AppStrings.RepositorySearch.emptyMessage)
                .foregroundStyle(.secondary)
        }
    }
}
