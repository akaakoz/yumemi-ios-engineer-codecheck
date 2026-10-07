//
//  RepositorySearchView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositorySearchView: View {

    let isSelected: Bool

    @State private var viewModel: RepositorySearchViewModel
    @FocusState private var isSearchFieldFocused: Bool
    @State private var listScrollPosition = ScrollPosition(edge: .top)

    init(isSelected: Bool, viewModel: RepositorySearchViewModel = RepositorySearchViewModel()) {
        self.isSelected = isSelected
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        RepositoryListView(items: viewModel.repositories) {
            loadMoreFooter
        }
            .scrollPosition($listScrollPosition)
            .scrollDismissesKeyboard(.automatic)
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
                RepositoryDetailView(source: .remote(fullName: repository.fullName))
            }
            .onChange(of: viewModel.phase) { _, phase in
                // 新しい検索の結果は一番上から表示する
                if phase == .loading {
                    listScrollPosition.scrollTo(edge: .top)
                }
            }
            .onChange(of: isSelected) { _, isSelected in
                if !isSelected {
                    isSearchFieldFocused = false
                }
            }
    }

    /// 検索欄。入力欄だと分かるよう先頭に虫眼鏡を置き、入力中は末尾のボタンで入力をまとめて消せる
    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("", text: $viewModel.query, prompt: Text("リポジトリを検索"))
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    viewModel.search()
                }
                .accessibilityIdentifier("repositorySearch.field")
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("入力を消去")
                .accessibilityIdentifier("repositorySearch.clearButton")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// 一覧の一番下に、追加読み込みの状態を表示する。
    /// 次のページがある間はローディングを表示し、それが画面に現れたら続きを読み込む。
    @ViewBuilder
    private var loadMoreFooter: some View {
        switch viewModel.loadMorePhase {
        case .idle where viewModel.canLoadMore:
            loadMoreIndicator
                .onAppear {
                    viewModel.loadMoreIfNeeded()
                }
        case .idle:
            EmptyView()
        case .loading:
            loadMoreIndicator
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

    private var loadMoreIndicator: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .accessibilityIdentifier("repositorySearch.loadMoreIndicator")
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
